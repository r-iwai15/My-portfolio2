#!/usr/bin/env bash
# Pre-push safety check for public GitHub
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
FAIL=0

echo "▶ Checking for secrets..."
PATTERN='AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )PRIVATE'
if command -v rg >/dev/null 2>&1; then
  if rg -i "$PATTERN" --glob '!**/node_modules/**' --glob '!.terraform/**' -q . 2>/dev/null; then
    echo "  ✗ Possible secret found — review rg output"
    FAIL=1
  else
    echo "  ✓ No obvious secret patterns"
  fi
elif git grep -E -i "$PATTERN" -- ':!**/node_modules' ':!**/.terraform' 2>/dev/null | grep -q .; then
  echo "  ✗ Possible secret found — review git grep output"
  FAIL=1
else
  echo "  ✓ No obvious secret patterns (git grep)"
fi

echo "▶ Checking staged / tracked forbidden paths..."
FORBIDDEN_RE='node_modules|\.terraform/|\.tfstate|\.mmdb$|plan\.tfplan$|\.zip$|backends/s3\.hcl$'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if command -v rg >/dev/null 2>&1; then
    BAD=$(git ls-files 2>/dev/null | rg "$FORBIDDEN_RE" || true)
  else
    BAD=$(git ls-files 2>/dev/null | grep -E "$FORBIDDEN_RE" || true)
  fi
  if [[ -n "$BAD" ]]; then
    echo "$BAD"
    echo "  ✗ Forbidden paths are tracked — fix .gitignore and git rm --cached"
    FAIL=1
  else
    echo "  ✓ No forbidden paths in git index"
  fi
else
  echo "  ⚠ Not a git repo yet — run: git init && git add . && re-run"
fi

echo "▶ Checking disk clutter (should be gitignored)..."
CLUTTER=$(find . -path './.git' -prune -o \
  \( -name node_modules -o -name .terraform -o -name '*.mmdb' \) -print 2>/dev/null | head -5)
if [[ -n "$CLUTTER" ]]; then
  echo "  ℹ Present on disk (OK if gitignored):"
  echo "$CLUTTER" | sed 's/^/    /'
  [[ $(echo "$CLUTTER" | wc -l) -ge 5 ]] && echo "    ..."
fi

if [[ $FAIL -eq 0 ]]; then
  echo "✅ Ready for public push (review README disclaimer)"
else
  echo "❌ Fix issues above before pushing"
  exit 1
fi
