# shellcheck shell=bash
# Private X displays from TigerVNC's Xvnc: "install" drives Install.exe unseen,
# "web" backs the browser viewer. Each takes an X cookie, and its VNC side
# listens only on a 0600 unix socket, so other users of a shared machine can
# neither see nor type into it. The web viewer adds a VNC password because
# websockify has to listen on a localhost TCP port for the SSH tunnel.

vb_cookie() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }

# Unix socket paths are limited to 107 bytes, too short for a deep
# VEDABASE_HOME, so the sockets live in a short private directory: /tmp, or
# the login session's runtime directory if another user has taken the /tmp
# name, or failing both the install's own run/ folder. The file name carries a
# hash of the home so that two installs never share one.
vb_sock_dir_ok() { # DIR: ours, private, not a symlink
  [[ -d $1 ]] || mkdir -m 700 "$1" 2>/dev/null || [[ -d $1 ]] || return 1
  [[ -O $1 && ! -L $1 ]] || return 1
  chmod 700 "$1"
}
vb_sock() { # NAME
  local d
  for d in "/tmp/vedabase-$(id -u)" "${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/vedabase}" "$VB_RUN"; do
    [[ -n $d ]] && vb_sock_dir_ok "$d" && break
  done
  printf '%s/%s-%s.sock\n' "$d" "$1" "$(printf '%s' "$VB_HOME" | cksum | cut -d' ' -f1)"
}

vb_free_display() {
  local n
  for n in {40..99}; do
    [[ -e /tmp/.X11-unix/X$n || -e /tmp/.X$n-lock ]] || { printf '%s\n' "$n"; return 0; }
  done
  return 1
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
  local name=$1 geom=$2 sec=$3 d=$VB_RUN/$1 n i
  mkdir -p "$d"
  chmod 700 "$VB_RUN" "$d"
  if vb_display_alive "$name"; then
    vb_display_use "$name"
    return 0
  fi
  n=$(vb_free_display) || vb_die "no free X display number between :40 and :99"
  local sock
  sock=$(vb_sock "$name")
  rm -f -- "$d/xauth" "$sock"
  (umask 077 && : >"$d/xauth")
  # Fed on stdin: argv is readable by every user on a shared machine.
  printf 'add :%s . %s\n' "$n" "$(vb_cookie)" | xauth -q -f "$d/xauth" source -
  # -rfbport -1 turns the TCP listener off (0 would mean 5900+display on every
  # interface); -localhost is a second guard in case that ever changes. Wine's
  # virtual desktop cannot follow a resized screen, so resizing is refused.
  local args=(":$n" -auth "$d/xauth" -geometry "$geom" -depth 24 -dpi 96
    -rfbport -1 -localhost -rfbunixpath "$sock" -rfbunixmode 0600
    -nolisten tcp -desktop VedaBase -SecurityTypes "$sec" -AlwaysShared
    -AcceptSetDesktopSize=0)
  [[ $sec == VncAuth ]] && args+=(-rfbauth "$d/vncpasswd")
  setsid Xtigervnc "${args[@]}" >"$d/xvnc.log" 2>&1 </dev/null &
  local pid=$!
  printf '%s\n' "$pid" >"$d/xvnc.pid"
  printf ':%s\n' "$n" >"$d/display"
  vb_display_use "$name"
  for i in {1..50}; do
    if xdotool getdisplaygeometry >/dev/null 2>&1; then
      if [[ $(ss -Htlnp 2>/dev/null) == *"pid=$pid,"* ]]; then
        vb_display_stop "$name"
        vb_die "Xvnc opened a TCP port despite -rfbport -1; stopped it (see $d/xvnc.log)"
      fi
      return 0
    fi
    sleep 0.2
  done
  vb_die "Xvnc did not start; see $d/xvnc.log"
}

vb_display_stop() { # NAME
  local d=$VB_RUN/$1
  if vb_display_alive "$1"; then kill "$(<"$d/xvnc.pid")" 2>/dev/null || true; fi
  rm -f -- "$d/xvnc.pid" "$d/display" "$(vb_sock "$1")"
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

vb_web_start() { # GEOMETRY
  local d=$VB_RUN/web port novnc
  port=$(vb_web_port)
  vb_display_alive web || vb_web_password
  vb_display_start web "$1" VncAuth
  vb_websockify_alive && return 0
  if [[ -n $(ss -Htln "sport = :$port" 2>/dev/null) ]]; then
    vb_die "port $port is already in use; pick another with VEDABASE_WEB_PORT=6081 vedabase web"
  fi
  novnc=$(vb_novnc_dir) || vb_die "noVNC is missing; re-run install.sh"
  # Ubuntu's websockify package targets the system python3, not pyenv/uv ones.
  PYTHONPATH=$VB_TOOLS/usr/lib/python3/dist-packages${PYTHONPATH:+:$PYTHONPATH} \
    setsid /usr/bin/python3 -m websockify --web "$novnc" --unix-target="$(vb_sock web)" \
    "127.0.0.1:$port" >"$d/websockify.log" 2>&1 </dev/null &
  printf '%s\n' "$!" >"$d/websockify.pid"
  sleep 1
  vb_websockify_alive || vb_die "websockify did not start; see $d/websockify.log"
}

vb_web_stop() {
  local pidf=$VB_RUN/web/websockify.pid
  if vb_websockify_alive; then kill "$(<"$pidf")" 2>/dev/null || true; fi
  rm -f -- "$pidf"
  vb_display_stop web
}
