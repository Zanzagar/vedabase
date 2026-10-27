# shellcheck shell=bash
# Private X displays from TigerVNC's Xvnc: "install" drives Install.exe unseen,
# "web" backs the browser viewer. Each takes an X cookie, and its VNC side
# listens only on a 0600 unix socket, so other users of a shared machine can
# neither see nor type into it. The web viewer adds a VNC password because
# websockify has to listen on a localhost TCP port for the SSH tunnel.

vb_cookie() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }

# Unix socket paths are limited to 107 bytes, too short for a deep
# VEDABASE_HOME, so the sockets live in a short private directory in /tmp:
# /tmp/vedabase-<uid>, or a new randomly named one if another user has taken
# that name. run/sockdir remembers which, so every command finds the same
# sockets. The file name carries a hash of the home so that two installs never
# share one.
vb_sock_dir_ok() { # DIR: ours, private, not a symlink
  [[ -d $1 ]] || mkdir -m 700 "$1" 2>/dev/null || [[ -d $1 ]] || return 1
  [[ -O $1 && ! -L $1 ]] || return 1
  chmod 700 "$1"
}
vb_sock() { # NAME
  local d='' rec=$VB_RUN/sockdir
  [[ -s $rec ]] && d=$(<"$rec")
  if [[ -z $d ]] || ! vb_sock_dir_ok "$d"; then
    d=/tmp/vedabase-$(id -u)
    vb_sock_dir_ok "$d" || d=$(mktemp -d /tmp/vedabase-XXXXXXXX) ||
      vb_die "could not make a private directory for VedaBase's sockets in /tmp"
    mkdir -p "$VB_RUN"
    chmod 700 "$VB_RUN"
    printf '%s\n' "$d" >"$rec"
  fi
  printf '%s/%s-%s.sock\n' "$d" "$1" "$(printf '%s' "$VB_HOME" | cksum | cut -d' ' -f1)"
}

vb_display_alive() { # NAME
  local d=$VB_RUN/$1 pid
  [[ -s $d/xvnc.pid && -s $d/display ]] || return 1
  pid=$(<"$d/xvnc.pid")
  kill -0 "$pid" 2>/dev/null && [[ $(ps -o comm= -p "$pid" 2>/dev/null) == Xtigervnc* ]]
}

vb_display_use() { # NAME: point DISPLAY/XAUTHORITY at it
  export DISPLAY XAUTHORITY
  DISPLAY=$(<"$VB_RUN/$1/display")
  XAUTHORITY=$VB_RUN/$1/xauth
}

# vb_display_start NAME GEOMETRY SECURITY   (SECURITY: None or VncAuth)
vb_display_start() {
  local name=$1 geom=$2 sec=$3 d=$VB_RUN/$1 n='' i sock cookie pid
  mkdir -p "$d"
  chmod 700 "$VB_RUN" "$d"
  if vb_display_alive "$name"; then
    vb_display_use "$name"
    return 0
  fi
  sock=$(vb_sock "$name")
  rm -f -- "$d/xauth" "$sock"
  (umask 077 && : >"$d/xauth" && : >"$d/displayfd") # displayfd exists before Xvnc writes to it
  # Xvnc accepts the cookie whatever display it is filed under; clients look it
  # up by display, so it is filed again under the one Xvnc picks. Fed on
  # stdin: argv is readable by every user on a shared machine.
  cookie=$(vb_cookie)
  printf 'add :0 . %s\n' "$cookie" | xauth -q -f "$d/xauth" source -
  # -displayfd: Xvnc takes the first display number whose sockets it can claim
  # completely and reports it, so a number another user has squatted is
  # skipped, never shared. -rfbport -1 turns the TCP listener off (0 would
  # mean 5900+display on every interface); -localhost is a second guard in case
  # that ever changes. Wine's virtual desktop cannot follow a resized screen,
  # so resizing is refused.
  local args=(-displayfd 3 -auth "$d/xauth" -geometry "$geom" -depth 24 -dpi 96
    -rfbport -1 -localhost -rfbunixpath "$sock" -rfbunixmode 0600
    -nolisten tcp -desktop VedaBase -SecurityTypes "$sec" -AlwaysShared
    -AcceptSetDesktopSize=0)
  # With a new 48-bit password each start, guessing is hopeless, so failed
  # logins need no lockout, which any local user could otherwise trigger
  # through the localhost port to lock you out.
  [[ $sec == VncAuth ]] && args+=(-rfbauth "$d/vncpasswd" -UseBlacklist=0)
  setsid Xtigervnc "${args[@]}" 3>"$d/displayfd" >"$d/xvnc.log" 2>&1 </dev/null &
  pid=$!
  printf '%s\n' "$pid" >"$d/xvnc.pid"
  for i in {1..50}; do
    kill -0 "$pid" 2>/dev/null || break
    n=$(tr -dc '0-9' <"$d/displayfd" 2>/dev/null) || n=''
    [[ -n $n ]] && break
    sleep 0.2
  done
  if [[ -z $n ]] || ! kill -0 "$pid" 2>/dev/null; then
    vb_display_stop "$name"
    vb_die "Xvnc did not start; see $d/xvnc.log"
  fi
  printf 'add :%s . %s\n' "$n" "$cookie" | xauth -q -f "$d/xauth" source -
  printf ':%s\n' "$n" >"$d/display"
  vb_display_use "$name"
  if [[ $(ss -Htlnp 2>/dev/null) == *"pid=$pid,"* ]]; then
    vb_display_stop "$name"
    vb_die "Xvnc opened a TCP port despite -rfbport -1; stopped it (see $d/xvnc.log)"
  fi
  xdotool getdisplaygeometry >/dev/null 2>&1 || {
    vb_display_stop "$name"
    vb_die "Xvnc does not answer on :$n; see $d/xvnc.log"
  }
}

vb_display_stop() { # NAME
  local d=$VB_RUN/$1 pid
  if [[ -s $d/xvnc.pid ]]; then
    pid=$(<"$d/xvnc.pid")
    if [[ $(ps -o comm= -p "$pid" 2>/dev/null) == Xtigervnc* ]]; then kill "$pid" 2>/dev/null || true; fi
  fi
  rm -f -- "$d/xvnc.pid" "$d/display" "$d/displayfd" "$(vb_sock "$1")"
}

# --- browser viewer -------------------------------------------------------------

vb_web_port() { printf '%s\n' "${VEDABASE_WEB_PORT:-6080}"; }

# A new password each time the viewer starts. VNC passwords stop at 8
# characters; 6 random bytes in URL-safe base64 fill them (48 bits).
vb_web_password() {
  local d=$VB_RUN/web
  mkdir -p "$d"
  chmod 700 "$VB_RUN" "$d"
  (umask 077 && head -c 6 /dev/urandom | base64 | tr -d '\n' | tr '+/' '-_' >"$d/password")
  (umask 077 && tigervncpasswd -f <"$d/password" >"$d/vncpasswd")
}

vb_novnc_dir() {
  local d
  for d in /usr/share/novnc "$VB_TOOLS/usr/share/novnc"; do
    [[ -f $d/vnc.html ]] && { printf '%s\n' "$d"; return 0; }
  done
  return 1
}

vb_websockify_alive() {
  local pidf=$VB_RUN/web/websockify.pid
  [[ -s $pidf ]] && kill -0 "$(<"$pidf")" 2>/dev/null
}

# Wine 11.0 puts a copy made in Folio on the X clipboard only when an X event
# wakes it (lib/x11-nudge.py says why), and with no window manager nothing on
# the viewer's display makes one, so noVNC's clipboard panel would never see a
# copy: a nudger nudges it once a second, which costs Folio nothing measurable.
# The X server itself keeps it single: once its first nudge has gone through,
# the nudger owns an X selection, which the server frees when either goes
# away, and a second one finding it taken leaves. Nothing finds it by PID or
# lock file, and it ends with its display. On $DISPLAY: start one unless one
# runs, and say so if none comes up within 3 s.
vb_nudger_ensure() {
  local i
  setsid python3 -I "$VB_REPO/lib/x11-nudge.py" every 1 >>"$VB_RUN/web/nudge.log" 2>&1 </dev/null &
  for i in {1..15}; do
    python3 -I "$VB_REPO/lib/x11-nudge.py" running >/dev/null 2>&1 && return 0
    sleep 0.2
  done
  vb_warn "text copied in VedaBase will not reach the browser's clipboard panel: its helper did not start (see $VB_RUN/web/nudge.log)"
}

vb_web_start() { # GEOMETRY
  local d=$VB_RUN/web port novnc
  port=$(vb_web_port)
  vb_display_alive web || vb_web_password
  vb_display_start web "$1" VncAuth
  if ! vb_websockify_alive; then
    if [[ -n $(ss -Htln "sport = :$port" 2>/dev/null) ]]; then
      vb_die "port $port is already in use; pick another with VEDABASE_WEB_PORT=6081 vedabase web"
    fi
    novnc=$(vb_novnc_dir) || vb_die "noVNC is missing; re-run install.sh"
    # Ubuntu's websockify package targets the system python3, not pyenv/uv ones.
    PYTHONPATH=$VB_TOOLS/usr/lib/python3/dist-packages${PYTHONPATH:+:$PYTHONPATH} \
      setsid /usr/bin/python3 -m websockify --web "$novnc" --unix-target="$(vb_sock web)" \
      "127.0.0.1:$port" >"$d/websockify.log" 2>&1 </dev/null &
    printf '%s\n' "$!" >"$d/websockify.pid"
  fi
  sleep 1
  vb_websockify_alive || vb_die "websockify did not start; see $d/websockify.log"
  vb_nudger_ensure
}

vb_web_stop() {
  local pidf=$VB_RUN/web/websockify.pid display='' i
  if vb_websockify_alive; then kill "$(<"$pidf")" 2>/dev/null || true; fi
  rm -f -- "$pidf"
  if [[ -s $VB_RUN/web/display ]]; then display=$(<"$VB_RUN/web/display"); fi
  vb_display_stop web
  # The nudger ends with the display. A display that still answers 5 s later
  # lives on (a dying one may take a connection and never reply: timeout).
  [[ -n $display ]] || return 0
  for i in {1..25}; do
    DISPLAY=$display XAUTHORITY=$VB_RUN/web/xauth timeout 2 xdotool getdisplaygeometry \
      >/dev/null 2>&1 || return 0
    sleep 0.2
  done
  vb_warn "the browser viewer's display $display did not stop; see $VB_RUN/web/xvnc.log"
}
