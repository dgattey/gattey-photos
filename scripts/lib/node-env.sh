# shellcheck shell=bash
# Node via mise (do not use Homebrew node for this project).

export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"

if command -v mise >/dev/null 2>&1; then
  if [[ -f mise.toml ]]; then
    mise trust -y >/dev/null 2>&1 || true
  fi
  eval "$(mise activate bash --shims 2>/dev/null)" || true
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm not found. Ensure mise provides node (e.g. mise use -g node@22) and ~/.local/share/mise/shims is on PATH." >&2
  exit 1
fi

# A launcher that spawns daemons and returns gets reaped with its shell when
# that shell has no terminal (agent / CI), taking the daemons down. Call this
# last with the daemon pid to watch. A real terminal returns immediately; a
# headless shell blocks here until the daemon dies, keeping it alive. Sequencing
# scripts that need the launcher to return set GATTEY_FOREGROUND_HOLD=0.
hold_foreground_if_headless() {
  if [[ "${GATTEY_FOREGROUND_HOLD:-}" == "0" ]] || [[ -t 1 ]]; then
    return 0
  fi
  echo "Headless shell: holding foreground so background daemons stay up (stop-server.sh or end this shell to stop)."
  while kill -0 "$1" 2>/dev/null; do sleep 5; done
}
