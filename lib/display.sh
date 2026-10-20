# shellcheck shell=bash
# Private X displays from TigerVNC's Xvnc: "install" drives Install.exe unseen,
# "web" backs the browser viewer. Each takes an X cookie, and its VNC side
# listens only on a 0600 unix socket, so other users of a shared machine can
# neither see nor type into it. The web viewer adds a VNC password because
# websockify has to listen on a localhost TCP port for the SSH tunnel.

vb_cookie() { od -An -N16 -tx1 /dev/urandom | tr -d ' \n'; }

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
  rm -f -- "$d/xauth" "$d/vnc.sock"
  (umask 077 && : >"$d/xauth")
  xauth -q -f "$d/xauth" add ":$n" . "$(vb_cookie)"
  # -rfbport -1 turns the TCP listener off (0 would mean 5900+display on every
  # interface); -localhost is a second guard in case that ever changes.
  local args=(":$n" -auth "$d/xauth" -geometry "$geom" -depth 24 -dpi 96
    -rfbport -1 -localhost -rfbunixpath "$d/vnc.sock" -rfbunixmode 0600
    -nolisten tcp -desktop VedaBase -SecurityTypes "$sec" -AlwaysShared)
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
  rm -f -- "$d/xvnc.pid" "$d/display" "$d/vnc.sock"
}

# --- browser viewer -------------------------------------------------------------

vb_web_port() { printf '%s\n' "${VEDABASE_WEB_PORT:-6080}"; }

vb_web_password() {
  local d=$VB_RUN/web
  mkdir -p "$d"
  chmod 700 "$VB_RUN" "$d"
  if [[ ! -s $d/password ]]; then
    # VNC passwords are 8 characters at most; 8 hex digits from urandom.
    (umask 077 && od -An -N4 -tx1 /dev/urandom | tr -d ' \n' >"$d/password")
  fi
  (umask 077 && tigervncpasswd -f <"$d/password" >"$d/vncpasswd")
  cat "$d/password"
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
  vb_web_password >/dev/null
  vb_display_start web "$1" VncAuth
  vb_websockify_alive && return 0
  if [[ -n $(ss -Htln "sport = :$port" 2>/dev/null) ]]; then
    vb_die "port $port is already in use; pick another with VEDABASE_WEB_PORT=6081 vedabase web"
  fi
  novnc=$(vb_novnc_dir) || vb_die "noVNC is missing; re-run install.sh"
  # Ubuntu's websockify package targets the system python3, not pyenv/uv ones.
  PYTHONPATH=$VB_TOOLS/usr/lib/python3/dist-packages${PYTHONPATH:+:$PYTHONPATH} \
    setsid /usr/bin/python3 -m websockify --web "$novnc" --unix-target="$d/vnc.sock" \
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
