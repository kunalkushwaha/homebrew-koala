#!/bin/bash
# OpenClaw's gateway in a Koala VM: no internet, the model key on your computer
# (through Koala's broker), its state on a volume, and the Control UI on
# 127.0.0.1. Tested on Linux and macOS with OpenClaw 2026.10.7. See README.md.
#
#   openclaw.sh up [--model M] [--origin URL] [--port N]
#                              create and start the VM (asks for your API key once)
#   openclaw.sh approve [ID]   list the devices waiting for approval, or approve one
#   openclaw.sh logs [N]       the gateway's last N output lines (default 50)
#   openclaw.sh down [--forget]
#                              remove the VM; --forget also removes its volume
#                              (OpenClaw's state), the gateway token and the policy
#
# Environment: KOALA (the koala command; default koala), KOALA_SOCKET (a
# manager socket), OPENCLAW_VM (claw), OPENCLAW_IMAGE
# (ghcr.io/openclaw/openclaw:latest).
set -euo pipefail
HERE="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
VM="${OPENCLAW_VM:-claw}"
IMAGE="${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}"
POLICY="$VM-openai"
TOKEN_SECRET="$VM-gateway-token"
VOLUME="$VM-state"

K() {
  if [[ -n "${KOALA_SOCKET:-}" ]]; then "${KOALA:-koala}" --socket "$KOALA_SOCKET" "$@"; else "${KOALA:-koala}" "$@"; fi
}

quiet() {  # ARGS...: a koala command whose output is shown only if it fails
  local out status=0
  out="$(K "$@" 2>&1)" || status=$?
  [[ $status -eq 0 ]] || printf '%s\n' "$out" >&2
  return $status
}

as_node() {  # ARGS...: an OpenClaw command in the VM, as the user that owns its state
  K exec --user node "$VM" -- "$@" </dev/null
}

healthy() {  # the gateway answers /healthz, from inside the VM
  K exec --user node "$VM" -- node -e \
    "fetch('http://127.0.0.1:18789/healthz').then(r => process.exit(r.ok ? 0 : 1), () => process.exit(1))" \
    </dev/null >/dev/null 2>&1
}

up() {
  local model=gpt-4.1-mini origin="" port=18789
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --model) model="${2:?--model M}"; shift ;;
      --origin) origin="${2:?--origin URL}"; shift ;;
      --port) port="${2:?--port N}"; shift ;;
      *) echo "openclaw.sh up: unknown option $1" >&2; exit 2 ;;
    esac
    shift
  done
  # 1. The model key, on your Mac: a broker policy that allows only this model.
  if K policy list | awk '{print $1}' | grep -qx "$POLICY"; then
    echo "using the policy $POLICY"
  else
    K policy create "$POLICY" --template openai --model "$model" ${origin:+--origin "$origin"}
  fi
  # 2. The gateway's token: a Koala secret, given to the VM as OPENCLAW_GATEWAY_TOKEN.
  if K secret inspect "$TOKEN_SECRET" >/dev/null 2>&1; then
    echo "using the stored gateway token ($TOKEN_SECRET)"
  else
    local token
    token="$(openssl rand -hex 24)"
    printf '%s' "$token" | quiet secret set "$TOKEN_SECRET" --value-stdin
    echo "the gateway token, which the Control UI asks for (keep it; koala won't show it again):"
    echo "  $token"
  fi
  # 3. OpenClaw's state.
  if K volume list | awk 'NR > 1 {print $1}' | grep -qx "$VOLUME"; then
    echo "using the volume $VOLUME (OpenClaw's state is kept)"
  else
    quiet volume create "$VOLUME" --size 4GiB --wait
  fi
  # 4. The VM: no internet; the broker grant, the published Control UI, the
  # volume, the token, and this folder (read-only) for vm/start.sh.
  quiet create "$VM" --image "$IMAGE" --mode service --cpus 2 --memory 2048 --disk 8192 \
    --user root --workdir /app --entrypoint /bin/sh \
    --env HOME=/home/node --env OPENCLAW_DISABLE_BONJOUR=1 --env "KOALA_MODEL=$model" --env "KOALA_UI_PORT=$port" \
    --no-internet --broker "openai=$POLICY" --publish "$port:18789" \
    --volume "$VOLUME:/home/node/.openclaw" --mount "$HERE:/openclaw:ro" \
    --secret-env "$TOKEN_SECRET=OPENCLAW_GATEWAY_TOKEN" \
    --wait --timeout 1800 -- /openclaw/vm/start.sh
  quiet start "$VM" --wait --timeout 1800
  echo "starting (the first start downloads the image, about 1.3 GB)"
  local ready=""
  for _ in $(seq 120); do
    if healthy; then ready=1; break; fi
    sleep 5
  done
  [[ -n "$ready" ]] || { echo "the gateway isn't answering after 10 minutes; see: $0 logs" >&2; exit 1; }
  echo "ready. Control UI: http://127.0.0.1:$port (sign in with the gateway token)"
  echo "if OpenClaw asks to approve your browser: $0 approve, then $0 approve ID"
}

case "${1:-}" in
  up) shift; up "$@" ;;
  approve)
    if [[ -n "${2:-}" ]]; then as_node openclaw devices approve "$2"; else as_node openclaw devices list; fi ;;
  logs) K logs "$VM" | tail -n "${2:-50}" ;;
  down)
    K stop "$VM" --wait --timeout 300 >/dev/null 2>&1 || true
    quiet rm "$VM" --wait --timeout 300
    if [[ "${2:-}" == "--forget" ]]; then
      quiet volume rm "$VOLUME"
      quiet secret rm "$TOKEN_SECRET"
      quiet policy rm "$POLICY"
      echo "removed the VM, its volume, the gateway token and the policy"
      echo "your API key is still stored as the credential $POLICY (koala credential rm $POLICY removes it)"
    else
      echo "removed the VM; the volume $VOLUME keeps OpenClaw's state (down --forget removes it)"
    fi ;;
  *) sed -n '2,16p' "$0" >&2; exit 2 ;;
esac
