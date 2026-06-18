#!/usr/bin/env bash
# Exit 0 when this commit should produce a new macOS release build.
set -euo pipefail

if [[ "${GITHUB_EVENT_NAME:-}" == "push" && -n "${GITHUB_EVENT_BEFORE:-}" && "${GITHUB_EVENT_BEFORE}" != "0000000000000000000000000000000000000000" ]]; then
  if git diff --name-only "$GITHUB_EVENT_BEFORE" "$GITHUB_SHA" | grep -qE \
    '^(macos/|scripts/(package-macos|package-release|ci-build-macos-release|export-ci-secrets|lib/signing|next-release-version|setup-self-signed-cert|fetch-live-macos-release)\.sh|\.github/workflows/release-macos\.yml)'; then
    exit 0
  fi
  exit 1
fi

# First push, workflow_dispatch, or local: build when macos sources exist.
[[ -d macos/Sources ]]
