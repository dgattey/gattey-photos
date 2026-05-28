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
