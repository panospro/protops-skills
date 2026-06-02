#!/usr/bin/env bash
# scan-target.sh — list ship-ready's TARGET set and run the cheap deterministic
# checks over it. Read-only; reports only (never edits/commits).
#
# Target depends on mode (default = all uncommitted changes):
#   changes  (default)  staged ∪ unstaged ∪ untracked           ← normal per-commit use
#   staged              only `git diff --cached`
#   branch              files changed vs origin/main (or main)
#   range A..B          files changed in A..B
#   full                the whole publish set                   ← pre-distribution sweep
#                       ({ git ls-files } ∪ untracked-not-ignored)
#
# Folder-agnostic: nothing assumes seeds/ or docs/. Semantic checks
# (dead code, PII judgement, doc-slop classification) need file reading —
# see check-catalog.md. This is the fast first pass.
#
# Usage:  bash scan-target.sh [changes|staged|branch|full|range] [A..B]
#         bash scan-target.sh --list [mode]      # just print the target files

set -uo pipefail
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT" || exit 2

LIST=0; [ "${1:-}" = "--list" ] && { LIST=1; shift; }
MODE="${1:-changes}"; RANGE="${2:-}"
LOCK_RE='package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Pipfile\.lock|poetry\.lock|composer\.lock|Gemfile\.lock|Cargo\.lock|go\.sum'
CODE_RE='\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|cs|c|cc|cpp|h|hpp|sh|bash|md|mdx|ya?ml|toml)$'
MAXLEN=500

target_files() {
  case "$MODE" in
    changes) { git diff --cached --name-only --diff-filter=ACMR; git diff --name-only --diff-filter=ACMR; git ls-files --others --exclude-standard; } ;;
    staged)  git diff --cached --name-only --diff-filter=ACMR ;;
    branch)  git diff --name-only --diff-filter=ACMR "$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null)"..HEAD ;;
    range)   [ -n "$RANGE" ] && git diff --name-only --diff-filter=ACMR "$RANGE" ;;
    full)    { git ls-files; git ls-files --others --exclude-standard; } ;;
    *) echo "unknown mode: $MODE" >&2; exit 2 ;;
  esac | sort -u | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done
}

if [ "$LIST" = 1 ]; then target_files; exit 0; fi

mapfile -t FILES < <(target_files | grep -vE "$LOCK_RE")
mapfile -t CODE  < <(target_files | grep -vE "$LOCK_RE" | grep -E "$CODE_RE")
echo "mode: $MODE${RANGE:+ $RANGE}   target: ${#FILES[@]} files (${#CODE[@]} code/doc)"
[ "${#FILES[@]}" -eq 0 ] && { echo "(no uncommitted changes — try 'full' for a whole-repo sweep)"; exit 0; }

GIT_NAME="$(git config user.name 2>/dev/null)"; GIT_USER="$(git config user.email 2>/dev/null | cut -d@ -f1)"; OS_USER="${USER:-$(id -un 2>/dev/null)}"

SCAN=()
scan() { # scan "Label" "regex" [filter] [grepflags]   filter "v=<re>"=exclude, "<re>"=keep-only; grepflags e.g. -i
  local label="$1" re="$2" filt="${3:-}" flags="${4:-}" out
  [ "${#SCAN[@]}" -eq 0 ] && return 0
  out="$(printf '%s\0' "${SCAN[@]}" | xargs -0 grep -nIE $flags "$re" 2>/dev/null | awk -v m="$MAXLEN" 'length($0)<m')" || true
  [ -z "$out" ] && return 0
  if [ -n "$filt" ]; then
    if [ "${filt#v=}" != "$filt" ]; then out="$(printf '%s\n' "$out" | grep -vE $flags "${filt#v=}")" || true
    else out="$(printf '%s\n' "$out" | grep -E $flags "$filt")" || true; fi
  fi
  [ -z "$out" ] && return 0
  echo; echo "## $label"; printf '%s\n' "$out" | head -40
}

echo; echo "============================== audit-core (sensitive data + slop) =============================="
SCAN=("${FILES[@]}")   # secrets / paths / identifiers / PII shapes — any file type
scan "Secrets (Blocker)" 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{36,}|glpat-[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{24,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY|(api[_-]?key|secret|password|token)[[:space:]]*[=:][[:space:]]*['"'"'"][^'"'"'"]{8,}'
scan "Env-style secret assignment (Blocker)" '(api[_-]?key|access[_-]?key|secret|secret[_-]?key|password|passwd|pwd|token|auth[_-]?token|private[_-]?key|client[_-]?secret)[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9/+_.=-]{12,}' 'v=example|changeme|your[_-]|placeholder|redacted|dummy|\$\{|<[a-z]' '-i'
scan "Hardcoded home/user paths (Blocker)" '/(home|Users)/[a-zA-Z][a-zA-Z0-9._-]+/|/mnt/c/Users/[^/ ]+|[A-Za-z]:[\\/]{1,2}Users[\\/]{1,2}[a-zA-Z]'
scan "PII shapes — IBAN / long IDs / DOB (review; audience-gated)" '\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b|\b[0-9]{11}\b|\b(19|20)[0-9]{2}-[01][0-9]-[0-3][0-9]\b' 'v=0{6,}'
scan "Emails (review)" '[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.(gr|com|net|org)' 'v=example\.com|@types/|w3\.org'
[ -n "$OS_USER" ]  && scan "OS username '$OS_USER'" "\\b${OS_USER}\\b"
[ -n "$GIT_USER" ] && [ "$GIT_USER" != "$OS_USER" ] && scan "git user '$GIT_USER'" "\\b${GIT_USER}\\b"
[ -n "$GIT_NAME" ] && scan "owner name '$GIT_NAME'" "$GIT_NAME"
SCAN=("${CODE[@]}")    # comment-voice / leakage — code+doc only, skip data blobs
scan "Workflow/AI leakage (Warning)" '/[a-z-]+:[a-z-]+|create-sandbox|\bCap [0-9]+|SKELETON:|AGENT:|\b(claude code|anthropic)\b|Generated:[[:space:]]*20[0-9]{2}-[0-9]{2}-[0-9]{2}T' 'v=https?://'
scan "First-person in comments (Warning)" '(//|#|^[[:space:]]*\*).*\b(we|our|us|let'"'"'s|we'"'"'ll|we'"'"'re)\b' 'v=https?://'
scan "'Note:' comment prefix (Warning)" '(//|#|^[[:space:]]*\*)[[:space:]]*[Nn]ote:'

echo; echo "============================== gen-hygiene =============================="
SCAN=("${CODE[@]}")    # {{var}} NOT flagged — legit in Postman/Handlebars/Jinja
scan "Unsubstituted template placeholders" '\[Controller\]|<%=|__[A-Z]{3,}__'
scan "Stale stub/for-later headers" 'service stub generated|for later implementation|not yet implemented|TODO: ?Implement'

echo; echo "============================== doc-slop (filename heuristic, any folder) =============================="
printf '%s\n' "${FILES[@]}" | grep -iE '(^|/)([a-z0-9_-]*-?(report|parity|status|plan|notes|todo|session|scratch|wip|draft)[a-z0-9_-]*|.*-v[0-9]+)\.(md|mdx|txt)$' | sed 's/^/  /' || echo "  none by name (still read docs in target for content-slop)"

echo; echo "============================== gitignore-doctor =============================="
# (a) committed refs to gitignored paths — skip common build/dep tokens + globs
DENY='^(node_modules|dist|build|out|target|bin|obj|coverage|\.next|\.nuxt|\.cache|\.venv|venv|__pycache__|\.vscode|\.idea|\.DS_Store|\.env|\.env\..*|.*\.(log|pyc|swp)|Thumbs\.db|\*.*)$'
IGN="$(grep -vE '^\s*#|^\s*$' .gitignore 2>/dev/null | sed 's#/$##' | grep -vE "$DENY" | awk '{ if (length($0)>=3) print }' | head -60)"
if [ -n "$IGN" ]; then
  echo; echo "## Committed references to gitignored paths (dangling on clone)"
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    h="$(printf '%s\0' "${CODE[@]}" | xargs -0 grep -nIF "$pat" 2>/dev/null | awk -v m="$MAXLEN" 'length($0)<m' | grep -vE '^\.gitignore:' | head -4)"
    [ -n "$h" ] && echo "  [$pat]" && printf '%s\n' "$h" | sed 's/^/     /'
  done <<< "$IGN"
fi
# (b) target files that look like they SHOULD be ignored but aren't
echo; echo "## Target files that may need gitignoring"
printf '%s\n' "${FILES[@]}" | grep -iE '(^|/)(\.env(\.[a-z]+)?$|.*-report\.(json|md)$|.*\.log$)' | grep -vE '\.env\.example$' | sed 's/^/  /' || echo "  none obvious"

echo; echo "(semantic checks — dead-config, PII judgement, doc-slop content — need file reading; see check-catalog.md)"
exit 0
