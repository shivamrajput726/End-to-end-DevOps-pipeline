#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPO_URL="${1:-${GITHUB_REPO_URL:-}}"
if [[ -z "$REPO_URL" ]]; then
  echo "Usage: ./scripts/git-setup.sh <github-repo-url>" >&2
  echo "Example: ./scripts/git-setup.sh https://github.com/USER/REPO.git" >&2
  exit 1
fi

command -v git >/dev/null 2>&1 || { echo "git not found" >&2; exit 1; }

if [[ ! -d ".git" ]]; then
  git init
fi

git branch -M main

if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi

git add -A

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  # Repo already has commits. Only commit if there are staged changes.
  if ! git diff --cached --quiet; then
    git commit -m "Initial DevOps pipeline setup"
  fi
else
  git commit -m "Initial DevOps pipeline setup"
fi

git push -u origin main

echo "Done: pushed to origin main"

