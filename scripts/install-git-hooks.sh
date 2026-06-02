#!/usr/bin/env bash
# Install repo git hooks (pre-push runs scripts/verify.sh).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS="$ROOT/.git/hooks"
mkdir -p "$HOOKS"

cat > "$HOOKS/pre-push" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
exec "$ROOT/scripts/verify.sh"
EOF
chmod +x "$HOOKS/pre-push"
echo "Installed $HOOKS/pre-push -> scripts/verify.sh"
