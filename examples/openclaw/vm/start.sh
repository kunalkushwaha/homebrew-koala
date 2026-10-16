#!/bin/sh
# OpenClaw's gateway in a Koala VM: the VM's main command, run as root from
# /openclaw/vm/start.sh (openclaw.sh up shares this folder there, read-only).
# Not tested on Koala; written from OpenClaw's documentation of its image.
#
# 1. Gives the state volume (/home/node/.openclaw) to node, the user
#    OpenClaw's image runs as (uid 1000).
# 2. On the first start only (no openclaw.json yet), runs OpenClaw's own
#    non-interactive onboarding as node. That writes OpenClaw's configuration:
#    local mode on the VM's network, the gateway token from
#    OPENCLAW_GATEWAY_TOKEN, and the model ($KOALA_MODEL) through Koala's
#    broker as an OpenAI-compatible provider. Koala never reads or writes
#    that file itself.
# 3. On every start, with the gateway not yet running (as `config set`
#    requires), allows the Control UI's address on the Mac ($KOALA_UI_PORT).
# 4. Runs the image's own entrypoint as node, with the gateway.
set -e
STATE=/home/node/.openclaw
UI_PORT="${KOALA_UI_PORT:-18789}"

as_node() { setpriv --reuid=node --regid=node --init-groups -- "$@"; }

chown node:node "$STATE"

if [ ! -s "$STATE/openclaw.json" ]; then
  as_node openclaw onboard \
    --non-interactive --accept-risk --skip-health --skip-daemon --mode local \
    --gateway-bind lan --gateway-port 18789 \
    --gateway-auth token --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
    --auth-choice custom-api-key --custom-compatibility openai \
    --custom-base-url http://openai.broker.koala.internal/v1 \
    --custom-model-id "$KOALA_MODEL" --custom-api-key koala-brokered --secret-input-mode plaintext \
    --skip-channels --skip-skills --skip-search --skip-ui
fi

as_node openclaw config set --batch-json \
  "[{\"path\": \"gateway.controlUi.allowedOrigins\", \"value\": [\"http://127.0.0.1:$UI_PORT\", \"http://localhost:$UI_PORT\"]}]"

cd /app
exec setpriv --reuid=node --regid=node --init-groups -- \
  tini -s -- node /app/docker-entrypoint.mjs node dist/index.js gateway --bind lan --port 18789
