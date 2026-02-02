#!/bin/bash
# Commands executed inside the base-image chroot during build-base, after the standard apt install + snpguest installation.
# Fail fast is recommended.
set -euo pipefail

# Example: install extra packages
# apt-get update
# apt-get install -y --no-install-recommends jq tmux

# Example: drop a marker
# echo "built-with-build-extra: EVIL DEPLOYMENT" >/etc/alman-build-extra

git clone https://github.com/salzg/simple-attestation-verifier-service /opt/simple-attestation-verifier-service
cd /opt/simple-attestation-verifier-service/client
cat > client_config.json <<'EOF'
{
  "server_ip": "<INSERT SERVER IP HERE>",
  "server_port": 8443,
  "deployment_name": "my-deployment",
  "requester_name": "alice",
  "tls_verify": false,
  "timeout_seconds": 25,
  "work_dir": "/tmp/snp_client",
  "keep_artifacts": true
}
EOF
cat > adjust-config.sh <<'EOF'
#!/usr/bin/env sh
set -eu

CONFIG_PATH="${1:-client_config.json}"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Error: $CONFIG_PATH not found" >&2
  exit 1
fi

SYSTEM_NAME="$(hostname)"
DEPLOYMENT_NAME="$(printf '%s' "$SYSTEM_NAME" | cut -c1-3)"

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: jq not found in PATH. Install with: sudo apt install jq\n' >&2
  exit 1
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT HUP INT TERM

jq \
  --arg requester "$SYSTEM_NAME" \
  --arg deployment "$DEPLOYMENT_NAME" \
  '.requester_name = $requester | .deployment_name = $deployment' \
  "$CONFIG_PATH" > "$tmp"

mv "$tmp" "$CONFIG_PATH"
trap - EXIT

echo "Updated $CONFIG_PATH:"
echo "  requester_name = $SYSTEM_NAME"
echo "  deployment_name = $DEPLOYMENT_NAME"
EOF

chmod +x adjust-config.sh

# webfrontend
apt-get install -y --no-install-recommends ufw
ufw allow 9443/tcp

apt-get install -y --no-install-recommends jq python3-requests
