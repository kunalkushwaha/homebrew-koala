#!/bin/bash
# The X agent's VM: its main command (the service's process, as root, in
# debian:trixie-slim; x-agent.sh up runs it from /x-agent/vm/start.sh).
# On the first start it installs Debian's Chromium (the standard browser),
# fonts, the virtual screen, the live view, and Python with the Playwright
# package (for the agent). The VM's disk keeps them. It makes a VNC password
# on first start (kept with the browser profile on the /profile volume), then
# runs:
#   Xvfb :99 (1280x900), x11vnc on 127.0.0.1:5900 (password), websockify +
#   noVNC on 0.0.0.0:6080, and Chromium as the user `browser` on that screen,
#   with its profile in /profile/chromium and DevTools on 127.0.0.1:9222 only.
# Chromium keeps its own sandbox if the kernel allows it; otherwise it runs
# with --no-sandbox, and the VM is the boundary. The choice is made at every
# boot and written to /profile/sandbox.txt. If Chromium exits, it is
# started again. The agent (/x-agent/agent/xagent.py) runs whenever its
# settings exist (/profile/xagent/config.json). The log is /profile/start.log.
set -u
PROFILE=/profile
LOG=$PROFILE/start.log
mkdir -p "$PROFILE"
exec >>"$LOG" 2>&1
echo "== start $(date -u +%FT%TZ)"

if [ -e /var/lib/koala-d07.installed ]; then
  echo "packages: already installed"
else
  echo "packages: installing"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q && apt-get install -y -q --no-install-recommends \
      chromium fonts-noto-core fonts-noto-cjk fonts-noto-color-emoji ca-certificates \
      xvfb x11vnc novnc websockify x11-apps procps python3 python3-pip \
    || { echo "packages: FAILED"; exit 1; }
  pip3 install -q --break-system-packages "playwright==${PLAYWRIGHT_VERSION:-1.63.0}" \
    || { echo "packages: playwright FAILED"; exit 1; }
  id browser >/dev/null 2>&1 || useradd -m -s /bin/bash browser
  touch /var/lib/koala-d07.installed
  echo "packages: installed ($(chromium --version 2>/dev/null))"
fi

# The live view's password: 8 characters (VNC's limit), private to the volume.
if [ ! -s "$PROFILE/vnc-password.txt" ]; then
  (umask 077; python3 -c 'import secrets, string; a = string.ascii_letters + string.digits; print("".join(secrets.choice(a) for _ in range(8)))' \
    >"$PROFILE/vnc-password.txt")
fi
chmod 600 "$PROFILE/vnc-password.txt"
# -storepasswd asks before overwriting: write a fresh file, never prompt.
rm -f /root/.vnc-passwd
x11vnc -storepasswd "$(cat "$PROFILE/vnc-password.txt")" /root/.vnc-passwd </dev/null >/dev/null 2>&1

export DISPLAY=:99
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99  # left by the previous boot: /tmp is on the VM's disk
# The screen and the live view run in sessions of their own, as Chromium does:
# `koala stop`'s SIGTERM reaches only this script, which closes the browser
# first. (An X server stopped under Chromium ends it at once, unsaved.)
setsid Xvfb :99 -screen 0 1280x900x24 -nolisten tcp -ac &  # local socket only; the browser user's Chromium connects
XVFB_PID=$!
for _ in $(seq 50); do [ -e /tmp/.X11-unix/X99 ] && break; sleep 0.1; done
setsid x11vnc -display :99 -rfbauth /root/.vnc-passwd -localhost -rfbport 5900 -forever -shared -quiet &
VNC_PID=$!
setsid websockify --web /usr/share/novnc 0.0.0.0:6080 127.0.0.1:5900 &
VIEW_PID=$!

CHROME=/usr/bin/chromium
[ -x "$CHROME" ] || { echo "chromium: FAILED, $CHROME is missing"; exit 1; }
echo "chromium: $("$CHROME" --version 2>/dev/null)"
mkdir -p "$PROFILE/chromium"; chown -R browser:browser "$PROFILE/chromium"
FLAGS=(--user-data-dir=$PROFILE/chromium --remote-debugging-address=127.0.0.1 --remote-debugging-port=9222
       --no-first-run --no-default-browser-check --disable-dev-shm-usage --password-store=basic
       --window-position=0,0 --window-size=1280,900 --start-maximized about:blank)

devtools() { python3 -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:9222/json/version", timeout=2)' 2>/dev/null; }
launch() {  # [--no-sandbox]
  # Each boot has a new hostname: Chromium would take its own last boot's lock
  # for "another computer" and refuse the profile. Only this script runs it.
  rm -f "$PROFILE/chromium/SingletonLock" "$PROFILE/chromium/SingletonCookie" "$PROFILE/chromium/SingletonSocket"
  # Its own session: `koala stop`'s SIGTERM reaches this script's process
  # group, not Chromium's helpers (its network service keeps the cookies).
  # This script then asks the browser alone to close, and it closes its
  # helpers in order, writing what they hold.
  setsid runuser -u browser -- env DISPLAY=:99 HOME=/home/browser "$CHROME" "$@" "${FLAGS[@]}" &
  CHROME_PID=$!
  for _ in $(seq 30); do devtools && return 0; kill -0 "$CHROME_PID" 2>/dev/null || return 1; sleep 0.5; done
  return 1
}
if launch; then
  echo "kept" >"$PROFILE/sandbox.txt"
else
  kill "${CHROME_PID:-0}" 2>/dev/null; wait "${CHROME_PID:-0}" 2>/dev/null
  echo "chromium: its sandbox is not available here; --no-sandbox (the VM is the boundary)"
  echo "disabled" >"$PROFILE/sandbox.txt"
  launch --no-sandbox || { echo "chromium: FAILED to start"; exit 1; }
fi
echo "chromium: sandbox $(cat "$PROFILE/sandbox.txt"), ready"

# `koala stop` sends SIGTERM: let Chromium close cleanly, so it writes
# its cookies and session, then exit.
# SIGTERM to Chromium ends its network service (which keeps the cookies)
# mid-write, so the browser is closed as automation tools close it: the
# DevTools command Browser.close, which shuts every part down in order. Only
# if that fails, SIGTERM. Then wait until no Chromium process is left.
stopping() {
  echo "stop: SIGTERM $(date -u +%FT%TZ)"
  # The agent first, so it never acts on a closing browser (up to 4 s).
  if [ -n "${AGENT_PID:-}" ] && kill -0 "$AGENT_PID" 2>/dev/null; then
    kill -TERM "$AGENT_PID"
    for _ in $(seq 40); do kill -0 "$AGENT_PID" 2>/dev/null || break; sleep 0.1; done
    kill -KILL "$AGENT_PID" 2>/dev/null && echo "stop: agent killed" || echo "stop: agent stopped"
  fi
  if timeout 6 python3 -c 'from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.connect_over_cdp("http://127.0.0.1:9222")
    try:
        browser.new_browser_cdp_session().send("Browser.close")
    except Exception:
        pass  # the connection ends as the browser closes' >/dev/null 2>&1; then
    echo "stop: Browser.close sent"
  else
    echo "stop: Browser.close failed; SIGTERM"; kill -TERM "$CHROME_PID" 2>/dev/null
  fi
  for _ in $(seq 80); do pgrep -f -- "--user-data-dir=$PROFILE/chromium" >/dev/null || break; sleep 0.1; done
  echo "stop: chromium closed $(date -u +%FT%TZ); $(pgrep -f -- "--user-data-dir=$PROFILE/chromium" | wc -l) processes left"
  kill -TERM "$VIEW_PID" "$VNC_PID" "$XVFB_PID" 2>/dev/null
  exit 0
}
trap stopping TERM INT

# The agent runs when /profile/xagent/config.json exists and there is no
# STOP file beside it: as the user browser, in its own session, with the
# model's two variables (from the broker, or from x-agent.sh up --ollama).
# It attaches to this Chromium over DevTools.
AGENT="${XAGENT:-/x-agent/agent/xagent.py}"
AGENT_PID=""
start_agent() {
  [ -f "$PROFILE/xagent/config.json" ] && [ ! -e "$PROFILE/xagent/STOP" ] && [ -f "$AGENT" ] || return 0
  chown -R browser:browser "$PROFILE/xagent"
  setsid runuser -u browser -- env HOME=/home/browser PYTHONUNBUFFERED=1 OPENAI_BASE_URL="${OPENAI_BASE_URL:-}" \
    OPENAI_API_KEY="${OPENAI_API_KEY:-}" python3 "$AGENT" "$PROFILE/xagent/config.json" \
    >>"$PROFILE/xagent/agent.stderr" 2>&1 &
  AGENT_PID=$!
  echo "agent: started $(date -u +%FT%TZ)"
}

# Supervise, every 5 s: Chromium is started again if it exits; the agent is
# started (again) whenever it is configured and not running.
while true; do
  sleep 5 & wait $!
  if ! kill -0 "$CHROME_PID" 2>/dev/null; then
    echo "chromium: exited $(date -u +%FT%TZ); starting again"
    if [ "$(cat "$PROFILE/sandbox.txt")" = "disabled" ]; then launch --no-sandbox; else launch; fi
  fi
  if [ -z "$AGENT_PID" ] || ! kill -0 "$AGENT_PID" 2>/dev/null; then
    [ -n "$AGENT_PID" ] && { echo "agent: exited $(date -u +%FT%TZ)"; AGENT_PID=""; }
    start_agent
  fi
done
