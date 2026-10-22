#!/usr/bin/env bash
# Exit 0 when this commit should produce a new macOS release build.
set -euo pipefail

if [[ "${GITHUB_EVENT_NAME:-}" == "workflow_dispatch" ]]; then
  exit 0
fi

if [[ -z "${GITHUB_EVENT_BEFORE:-}" && -f "${GITHUB_EVENT_PATH:-}" && -r "$GITHUB_EVENT_PATH" ]]; then
  GITHUB_EVENT_BEFORE="$(jq -r '.before // empty' "$GITHUB_EVENT_PATH")"
fi

if [[ "${GITHUB_EVENT_NAME:-}" == "push" && -n "${GITHUB_EVENT_BEFORE:-}" && "${GITHUB_EVENT_BEFORE}" != "0000000000000000000000000000000000000000" ]]; then
  if git diff --name-only "$GITHUB_EVENT_BEFORE" "$GITHUB_SHA" | grep -qE \
    '^(macos/|scripts/(package-macos|package-release|ci-build-macos-release|macos-release-inputs-changed|export-ci-secrets|lib/signing|next-release-version|release-notes|setup-self-signed-cert|fetch-previous-appcast)\.sh$|\.github/workflows/release-macos\.yml$)'; then
    exit 0
  fi
  exit 1
fi

# Missing before SHA or unknown event: do not build.
exit 1
