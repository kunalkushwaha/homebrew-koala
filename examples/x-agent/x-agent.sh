#!/bin/bash
# The X agent in a Koala VM: Chromium you sign in to through a live view,
# and an agent that reads X, drafts, and posts only within its guardrails.
# See README.md.
#
#   x-agent.sh up [--ollama | --broker POLICY] [--port N] [--host-service ADDR]...
#   x-agent.sh password            the live view's password
#   x-agent.sh check               read the timeline once (no agent running)
#   x-agent.sh config FILE         install settings; the agent starts within 5 s
#   x-agent.sh logs [N]            the agent's last N log lines (default 30)
#   x-agent.sh drafts              the drafts, numbered, each beside its post
#   x-agent.sh approve N...        go live with only those reply drafts, as they are
#   x-agent.sh approve post        go live with the latest post draft, as it is
#   x-agent.sh stop-agent          the agent stops within a round
#   x-agent.sh down [--forget]     remove the VM; --forget also removes its volume
#                                  (your sign-in and the agent's records)
#
# Environment: KOALA (the koala command; default koala), KOALA_SOCKET (a
# manager socket), X_AGENT_VM (x-agent), X_AGENT_VOLUME (x-agent-profile),
# X_AGENT_IMAGE (docker.io/library/debian:trixie-slim).
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
VM="${X_AGENT_VM:-x-agent}"
VOLUME="${X_AGENT_VOLUME:-x-agent-profile}"
IMAGE="${X_AGENT_IMAGE:-docker.io/library/debian:trixie-slim}"
OLLAMA=127.0.0.1:11434

K() {
  if [[ -n "${KOALA_SOCKET:-}" ]]; then "${KOALA:-koala}" --socket "$KOALA_SOCKET" "$@"; else "${KOALA:-koala}" "$@"; fi
}

quiet() {  # ARGS...: a koala command whose output is shown only if it fails
  local out status=0
  out="$(K "$@" 2>&1)" || status=$?
  [[ $status -eq 0 ]] || printf '%s\n' "$out" >&2
  return $status
}

vm() {  # SCRIPT: run in the VM as root; koala's own notes are shown only on failure
  local err status=0
  err="$(mktemp)"
  K exec "$VM" -- /bin/bash -c "$1" </dev/null 2>"$err" || status=$?
  [[ $status -eq 0 ]] || grep -v '^execution ' "$err" >&2 || true
  rm -f "$err"
  return $status
}

ready() {  # Chromium is ready since the VM's last start
  vm 'awk "/^== start/ {r = 0} /, ready\$/ {r = 1} END {exit !r}" /profile/start.log' 2>/dev/null
}

agent_running() { vm 'pgrep -f "python3 /x-agent/agent/[x]agent.py" >/dev/null' 2>/dev/null; }

up() {
  local model=ollama policy="" port=6080 extra=() model_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ollama) model=ollama ;;
      --broker) model=broker; policy="${2:?--broker POLICY}"; shift ;;
      --port) port="${2:?--port N}"; shift ;;
      --host-service) extra+=(--host-service "${2:?--host-service ADDRESS:PORT}"); shift ;;
      *) echo "x-agent.sh up: unknown option $1" >&2; exit 2 ;;
    esac
    shift
  done
  if [[ $model == ollama ]]; then
    curl -s -m 3 "http://$OLLAMA/api/version" >/dev/null \
      || { echo "Ollama isn't answering on $OLLAMA: start it, or use --broker POLICY" >&2; exit 1; }
    # The first host-service grant is host-1.koala.internal in the VM. Ollama
    # needs no key; the agent sends a placeholder.
    model_args=(--host-service "$OLLAMA" --env "OPENAI_BASE_URL=http://host-1.koala.internal:11434/v1"
                --env "OPENAI_API_KEY=ollama")
  else
    model_args=(--broker "ai=$policy")  # the broker sets OPENAI_BASE_URL and a placeholder key
  fi
  if K volume list | awk 'NR > 1 {print $1}' | grep -qx "$VOLUME"; then
    echo "using the volume $VOLUME (your sign-in, if any, is kept)"
  else
    quiet volume create "$VOLUME" --size 2GiB --wait
  fi
  quiet create "$VM" --image "$IMAGE" --mode service --memory 4096 --cpus 4 --disk 6144 \
    --volume "$VOLUME:/profile" --mount "$HERE:/x-agent:ro" --publish "$port:6080" \
    "${model_args[@]}" ${extra[@]+"${extra[@]}"} --wait --timeout 1800 -- /bin/bash /x-agent/vm/start.sh
  quiet start "$VM" --wait --timeout 1800
  echo "starting: the first start installs Chromium (about a minute)"
  for _ in $(seq 240); do ready && break; sleep 5; done
  ready || { echo "Chromium isn't ready; see: koala exec $VM -- tail /profile/start.log" >&2; exit 1; }
  echo "ready. Live view: http://127.0.0.1:$port/vnc.html?autoconnect=1&resize=scale"
  echo "its password: $0 password"
}

case "${1:-}" in
  up) shift; up "$@" ;;
  password) vm 'cat /profile/vnc-password.txt' ;;
  check)
    if agent_running; then echo "the agent is running: stop-agent first" >&2; exit 1; fi
    vm 'python3 /x-agent/agent/check.py /x-agent/agent/xagent.py' ;;
  config)
    [[ -f "${2:-}" ]] || { echo "usage: $0 config FILE" >&2; exit 2; }
    vm 'mkdir -p /profile/xagent'
    quiet cp "$2" "$VM:/profile/xagent/config.new.json"
    vm 'python3 /x-agent/agent/settings.py install /profile/xagent/config.new.json; s=$?; rm -f /profile/xagent/config.new.json; exit $s' ;;
  logs) vm "tail -n ${2:-30} /profile/xagent/agent.log" ;;
  drafts) vm 'python3 /x-agent/agent/settings.py drafts' ;;
  approve)
    shift
    [[ $# -gt 0 ]] || { echo "usage: $0 approve N... | approve post" >&2; exit 2; }
    for a in "$@"; do [[ "$a" =~ ^([0-9]+|post)$ ]] || { echo "not a draft number: $a" >&2; exit 2; }; done
    vm "python3 /x-agent/agent/settings.py approve $*" ;;
  stop-agent) vm 'mkdir -p /profile/xagent && touch /profile/xagent/STOP' && echo "the agent stops within a round" ;;
  down)
    K stop "$VM" --wait --timeout 300 >/dev/null 2>&1 || true
    quiet rm "$VM" --wait --timeout 300
    if [[ "${2:-}" == "--forget" ]]; then quiet volume rm "$VOLUME"; echo "removed the VM and its volume"
    else echo "removed the VM; the volume $VOLUME keeps your sign-in (down --forget removes it)"; fi ;;
  *) sed -n '2,20p' "$0" >&2; exit 2 ;;
esac
