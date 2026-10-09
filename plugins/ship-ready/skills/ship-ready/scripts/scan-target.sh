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
# Lines scanned: the diff modes scan only the ADDED lines of their diff (an
# untracked file counts as all added). --whole-files scans every line of the
# changed files instead; `full` always scans every line.
#
# Private denylist: terms that must never reach a repo (internal hosts, login
# codes, confidential project names) are read from $SHIP_READY_DENYLIST, default
# ~/.claude/ship-ready-denylist.txt. One entry per line, '#' lines are comments;
# a 're:' prefix makes the entry an extended regex, otherwise it is fixed text;
# both match case-insensitively. A trailing ' @src' flags the entry only outside
# test/fixture/sandbox paths.
#
# Usage:  bash scan-target.sh [changes|staged|branch|full|range A..B] [--whole-files]
#         bash scan-target.sh --list [mode]      # just print the target files

set -uo pipefail
export GIT_OPTIONAL_LOCKS=0   # never refresh the index as a side effect
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo" >&2; exit 2; }
ROOT="$(git rev-parse --show-toplevel)"; cd "$ROOT" || exit 2

LIST=0; WHOLE=0; ARGS=()
for a in "$@"; do
  case "$a" in
    --list) LIST=1 ;;
    --whole-files) WHOLE=1 ;;
    --full) ARGS+=(full) ;;
    *) ARGS+=("$a") ;;
  esac
done
MODE="${ARGS[0]:-changes}"; RANGE="${ARGS[1]:-}"
[ "$MODE" = full ] && WHOLE=1
LOCK_RE='package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Pipfile\.lock|poetry\.lock|composer\.lock|Gemfile\.lock|Cargo\.lock|go\.sum'
CODE_RE='\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|cs|c|cc|cpp|h|hpp|sh|bash|md|mdx|ya?ml|toml)$'
DOC_RE='\.(md|mdx|txt|rst)$'
TEST_RE='(^|/)(tests?|__tests__|__mocks__|mocks?|spec|fixtures?|sandbox|e2e|examples?)/|[._-](test|spec)\.[A-Za-z]+$'
MAXLEN=500

MB=""
if [ "$MODE" = branch ]; then
  MB="$(git merge-base HEAD origin/main 2>/dev/null || git merge-base HEAD main 2>/dev/null)"
  [ -n "$MB" ] || { echo "ERROR: branch mode needs origin/main or main to compare against" >&2; exit 2; }
fi

target_files() {
  case "$MODE" in
    changes) { git diff --cached --name-only --diff-filter=ACMR; git diff --name-only --diff-filter=ACMR; git ls-files --others --exclude-standard; } ;;
    staged)  git diff --cached --name-only --diff-filter=ACMR ;;
    branch)  git diff --name-only --diff-filter=ACMR "$MB"..HEAD ;;
    range)   [ -n "$RANGE" ] && git diff --name-only --diff-filter=ACMR "$RANGE" ;;
    full)    { git ls-files; git ls-files --others --exclude-standard; } ;;
    *) echo "unknown mode: $MODE" >&2; exit 2 ;;
  esac | sort -u | while IFS= read -r f; do
    # changes/full read the working tree; the other modes read git, so a file need not be on disk
    case "$MODE" in changes|full) [ -f "$f" ] || continue ;; esac
    printf '%s\n' "$f"
  done
}

if [ "$LIST" = 1 ]; then target_files; exit 0; fi

mapfile -t FILES < <(target_files | grep -vE "$LOCK_RE")
mapfile -t CODE  < <(printf '%s\n' ${FILES[@]+"${FILES[@]}"} | grep -E "$CODE_RE")
[ "${#FILES[@]}" -eq 0 ] && { echo "mode: $MODE${RANGE:+ $RANGE}   target: 0 files"; echo "(no changes in this mode — try 'full' for a whole-repo sweep)"; exit 0; }

# ---------------------------------------------------------------- corpus
# Every scanned line goes into two parallel files: META holds "path:line",
# TEXT holds the line itself, so grep runs on the text alone.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
META="$TMP/meta"; TEXT="$TMP/text"; : > "$META"; : > "$TEXT"

add_tree() { # every line of each working-tree text file
  [ "$#" -eq 0 ] && return 0
  printf './%s\0' "$@" | xargs -0 grep -lI --null '' -- 2>/dev/null |
    xargs -0 env LC_ALL=C awk -v M="$META" -v T="$TEXT" '{ f = FILENAME; sub(/^\.\//, "", f); print f ":" FNR >> M; print >> T }'
}

add_blobs() { # every line of each text file as stored at <rev> (":" = the index)
  local rev="$1" f; shift
  for f in "$@"; do
    git show "$rev$f" > "$TMP/blob" 2>/dev/null || continue
    grep -qI '' "$TMP/blob" || continue
    F="$f" LC_ALL=C awk -v M="$META" -v T="$TEXT" '{ print ENVIRON["F"] ":" FNR >> M; print >> T }' "$TMP/blob"
  done
}

add_diff() { # the added lines of `git diff <args>`
  git -c core.quotepath=off diff --no-color --no-ext-diff --no-textconv -U0 --src-prefix=a/ --dst-prefix=b/ --diff-filter=ACMR "$@" |
    LC_ALL=C awk -v M="$META" -v T="$TEXT" '
      /^diff --git / { hunk = 0; next }
      !hunk && /^\+\+\+ / { f = substr($0, 7); sub(/\t$/, "", f); next }
      /^@@/ { hunk = 1; match($0, /\+[0-9]+/); n = substr($0, RSTART + 1, RLENGTH - 1) + 0; next }
      hunk && /^\+/ { print f ":" n >> M; print substr($0, 2) >> T; n++ }'
}

if [ "$WHOLE" = 1 ]; then
  case "$MODE" in
    staged) add_blobs ":" "${FILES[@]}" ;;
    branch) add_blobs "HEAD:" "${FILES[@]}" ;;
    range)
      if [[ "$RANGE" == *..* ]]; then REV="${RANGE##*..}"; add_blobs "${REV:-HEAD}:" "${FILES[@]}"
      else add_tree "${FILES[@]}"; fi ;;
    *) add_tree "${FILES[@]}" ;;
  esac
else
  case "$MODE" in
    changes)
      BASE=HEAD; git rev-parse -q --verify HEAD >/dev/null || BASE="$(git hash-object -t tree /dev/null)"
      add_diff "$BASE" -- "${FILES[@]}"
      mapfile -t UNTRACKED < <(git ls-files --others --exclude-standard | grep -vE "$LOCK_RE")
      add_tree ${UNTRACKED[@]+"${UNTRACKED[@]}"} ;;
    staged) add_diff --cached -- "${FILES[@]}" ;;
    branch) add_diff "$MB" HEAD -- "${FILES[@]}" ;;
    range)  add_diff "$RANGE" -- "${FILES[@]}" ;;
  esac
fi

SCOPE="added lines"; [ "$WHOLE" = 1 ] && SCOPE="every line"
echo "mode: $MODE${RANGE:+ $RANGE}   scope: $SCOPE   target: ${#FILES[@]} files (${#CODE[@]} code/doc), $(wc -l < "$META" | tr -d ' ') lines"

# ---------------------------------------------------------------- matching
read -r -d '' JOIN_AWK <<'AWK'
BEGIN {
  nwant = split(ENVIRON["SETS"], want, " ")
  c = "[A-Za-z0-9_/+=-]"; LONG = ""
  for (i = 0; i < 20; i++) LONG = LONG c
  LONG = LONG c "*"
}
NR == FNR { k = $0; sub(/:.*/, "", k); t = $0; sub(/^[0-9]+:/, "", t); hit[k] = t; order[++n] = k; next }
FNR in hit { meta[FNR] = $0 }
END {
  for (i = 1; i <= n; i++) {
    loc = meta[order[i]]; path = loc; sub(/:[0-9]+$/, "", path)
    if (!inset(path)) continue
    text = hit[order[i]]
    if (ENVIRON["MASK"] == "1") text = mask(text)
    print loc ":" text
  }
}
function inset(p,   i, s, c, d, t) {
  if (nwant == 0) return 1
  c = p ~ ENVIRON["CODE_RE"]; d = p ~ ENVIRON["DOC_RE"]; t = p ~ ENVIRON["TEST_RE"]
  for (i = 1; i <= nwant; i++) {
    s = want[i]
    if ((s == "code" && c) || (s == "docs" && d) || (s == "test" && t && !d) || (s == "nontest" && !t) || (s == "src" && c && !d && !t)) return 1
  }
  return 0
}
# A value after ':' or '=', and any long token-like run, keep 4 characters and their length.
function maskv(v) { return length(v) < 6 ? v : substr(v, 1, 4) "…(" length(v) ")" }
function mask(s,   out, m, p) {
  out = ""
  while (match(s, /[:=][ \t]*["']?[^"' \t,;)]+/)) {
    m = substr(s, RSTART, RLENGTH); p = m; sub(/[^:= \t"'].*$/, "", p)
    out = out substr(s, 1, RSTART - 1) p maskv(substr(m, length(p) + 1))
    s = substr(s, RSTART + RLENGTH)
  }
  s = out s; out = ""
  while (match(s, LONG)) { out = out substr(s, 1, RSTART - 1) maskv(substr(s, RSTART, RLENGTH)); s = substr(s, RSTART + RLENGTH) }
  return out s
}
AWK

# hits <regex | @patternfile> [opt...] — corpus lines whose text matches, as path:line:text.
#   -i case-insensitive · -F fixed strings · v=<re> drop lines matching <re> · k=<re> keep only those
#   code | src | test | docs | nontest — keep paths in any listed set (default: every path);
#     a doc is always `docs`, never `test`; src = code that is neither a doc nor a test/fixture/sandbox path
#   mask — shorten credential-like values in the printed text
hits() {
  local re="$1"; shift
  local matcher=-E icase="" drop="" keep="" sets="" mask=0 o out
  for o in "$@"; do
    case "$o" in
      -i) icase=-i ;; -F) matcher=-F ;;
      v=*) drop="${o#v=}" ;; k=*) keep="${o#k=}" ;;
      mask) mask=1 ;;
      *) sets="$sets $o" ;;
    esac
  done
  if [ "${re#@}" != "$re" ]; then out="$(grep -an $matcher $icase -f "${re#@}" "$TEXT" 2>/dev/null)"
  else out="$(grep -an $matcher $icase -e "$re" "$TEXT" 2>/dev/null)"; fi
  out="$(printf '%s\n' "$out" | awk -v m="$MAXLEN" 'NF && length($0) < m')"
  [ -n "$drop" ] && [ -n "$out" ] && { out="$(printf '%s\n' "$out" | grep -avE $icase -e "$drop")" || true; }
  [ -n "$keep" ] && [ -n "$out" ] && { out="$(printf '%s\n' "$out" | grep -aE $icase -e "$keep")" || true; }
  [ -z "$out" ] && return 0
  printf '%s\n' "$out" | SETS="$sets" MASK="$mask" CODE_RE="$CODE_RE" DOC_RE="$DOC_RE" TEST_RE="$TEST_RE" LC_ALL=C awk "$JOIN_AWK" - "$META"
}

section() { echo; echo "============================== $1 =============================="; }
report() { [ -z "$2" ] && return 0; echo; echo "## $1"; printf '%s\n' "$2" | head -40; }
scan() { local label="$1"; shift; report "$label" "$(hits "$@")"; }

GIT_NAME="$(git config user.name 2>/dev/null)"; GIT_USER="$(git config user.email 2>/dev/null | cut -d@ -f1)"; OS_USER="${USER:-$(id -un 2>/dev/null)}"

section "audit-core (sensitive data + slop)"
scan "Secrets (Blocker)" 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{36,}|glpat-[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{24,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY|(api[_-]?key|secret|password|token)[[:space:]]*[=:][[:space:]]*['"'"'"][^'"'"'"]{8,}' mask
scan "Env-style secret assignment (Blocker)" '(api[_-]?key|access[_-]?key|secret|secret[_-]?key|password|passwd|pwd|token|auth[_-]?token|private[_-]?key|client[_-]?secret)[[:space:]]*[:=][[:space:]]*"?[A-Za-z0-9/+_.=-]{12,}' 'v=example|changeme|your[_-]|placeholder|redacted|dummy|\$\{|<[a-z]' -i mask
scan "Hardcoded home/user paths (Blocker)" '/(home|Users)/[a-zA-Z][a-zA-Z0-9._-]+/|/mnt/c/Users/[^/ ]+|[A-Za-z]:[\\/]{1,2}Users[\\/]{1,2}[a-zA-Z]'
scan "PII shapes — IBAN / long IDs / DOB (review; audience-gated)" '\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b|\b[0-9]{11}\b|\b(19|20)[0-9]{2}-[01][0-9]-[0-3][0-9]\b' 'v=0{6,}'
scan "Emails (review)" '[A-Za-z0-9._-]+@[A-Za-z0-9.-]+\.(gr|com|net|org)' 'v=example\.com|@types/|w3\.org'
# The identity values stay out of the labels: whatever reads this output never sees them unless a file holds them.
[ -n "$OS_USER" ]  && scan "OS username (\$USER)" "\\b${OS_USER}\\b"
[ -n "$GIT_USER" ] && [ "$GIT_USER" != "$OS_USER" ] && scan "git e-mail local part (user.email)" "\\b${GIT_USER}\\b"
[ -n "$GIT_NAME" ] && scan "owner name (git user.name)" "$GIT_NAME" -F -i
scan "Workflow/AI leakage (Warning)" '/[a-z-]+:[a-z-]+|create-sandbox|\bCap [0-9]+|SKELETON:|AGENT:|\b(claude code|anthropic)\b|Generated:[[:space:]]*20[0-9]{2}-[0-9]{2}-[0-9]{2}T' code 'v=https?://'
scan "First-person in comments (Warning)" '(//|#|^[[:space:]]*\*).*\b(we|our|us|let'"'"'s|we'"'"'ll|we'"'"'re)\b' code 'v=https?://'
scan "'Note:' comment prefix (Warning)" '(//|#|^[[:space:]]*\*)[[:space:]]*[Nn]ote:' code
scan "Hardcoded domain literal in logic (Warning)" '(===?|!==?|case[[:space:]])[[:space:]]*['"'"'"][0-9]{6,}['"'"'"]' code

# Where the knowledge came from (who said it, when, in which run) instead of what the code does.
PROV='\bowner(.s)?[[:space:],:(]+(rul(ing|ings|ed)|said|says|wants?|wanted|asked|confirmed|decided|words|verbatim)|\bowner\b[^.;]{0,40}\b20[0-9]{2}-[01][0-9]-[0-3][0-9]|\((the )?owner[,)]|\b(confirmed|agreed|checked|cleared) with (the )?(owner|user|team|client|business|po|pm|lead)\b|\bas (discussed|agreed)\b|\bper (the|our|that) (chat|ticket|call|meeting|thread|discussion|e-?mail)\b|\bthe user (told|asked|wants|wanted|said|confirmed|requested|reported)\b|\b(live|qa) run\b|\b(in|during) (this|the last|our) (session|chat)\b|\b(seen|saw|observed|noticed|captured)\b[^.;]{0,30}\b(on|in|against|during) (the )?(qa|prod|production|staging|uat|live|sweep)\b|\bfound (on|in|against|during) (the )?(qa|prod|production|staging|uat|live|sweep)\b|\bthe (qa )?sweep\b|\btold (me|us)\b'
COMMENT='(//|#|/\*|^[[:space:]]*\*|<!--)'
TITLE='\b(it|test|describe|context|suite)(\.[a-z]+)?\([[:space:]]*["'"'"'`]'
scan "Provenance / hearsay in code comments and test titles (Warning)" "($COMMENT|$TITLE).*($PROV)" src -i
scan "Provenance / hearsay in tests (Warning)" "$PROV" test -i
scan "Provenance / hearsay in docs (review — a role-only decision record may stay)" "$PROV" docs -i
scan "Work-note dates and tags in comments and test titles (Info)" "($COMMENT|$TITLE).*(\b20[0-9]{2}-[01][0-9]-[0-3][0-9]\b|\bF[0-9]+ fix\b|\bfix [0-9]+:|\b(added|done|fixed) in sprint [0-9]+)" src test -i

section "internal infrastructure"
scan "Private / raw IP addresses (Blocker)" '\b(10\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])|192\.168)\.[0-9]{1,3}\.[0-9]{1,3}\b|https?://[0-9]{1,3}(\.[0-9]{1,3}){3}\b' 'v=127\.0\.0\.1|0\.0\.0\.0'
scan "Cloud / internal hostnames (Warning)" '\b[a-z0-9][a-z0-9.-]*\.(azurewebsites\.net|cloudapp\.azure\.com|azurecr\.io|core\.windows\.net|vault\.azure\.net|database\.windows\.net|servicebus\.windows\.net|azure-api\.net|azure-devices\.net|amazonaws\.com|cloudfront\.net|run\.app|appspot\.com|svc\.cluster\.local)\b|(//|@)[a-z0-9][a-z0-9.-]*\.(internal|intranet|corp|lan|local|localdomain)\b' -i

DENY="${SHIP_READY_DENYLIST:-$HOME/.claude/ship-ready-denylist.txt}"
if [ -f "$DENY" ]; then
  DENY_DIR="$(cd "$(dirname "$DENY")" && pwd -P)"
  case "$DENY_DIR/" in
    "$(pwd -P)/"*) git check-ignore -q -- "$DENY_DIR/$(basename "$DENY")" ||
      report "Private denylist is inside this repo and not ignored (Blocker)" "  $DENY — committing it publishes every term it lists" ;;
  esac
  LC_ALL=C awk -v D="$TMP/deny" '
    { sub(/\r$/, ""); sub(/^[ \t]+/, ""); sub(/[ \t]+$/, "") }
    $0 == "" || /^#/ { next }
    { where = "all"; if (sub(/[ \t]+@src$/, "")) where = "src"
      kind = "F"; if (sub(/^re:/, "")) kind = "E"
      if ($0 != "") print > (D "-" kind "-" where) }' "$DENY"
  DENY_HITS="$(
    [ -s "$TMP/deny-F-all" ] && hits "@$TMP/deny-F-all" -F -i
    [ -s "$TMP/deny-E-all" ] && hits "@$TMP/deny-E-all" -i
    [ -s "$TMP/deny-F-src" ] && hits "@$TMP/deny-F-src" -F -i nontest
    [ -s "$TMP/deny-E-src" ] && hits "@$TMP/deny-E-src" -i nontest
  )"
  report "Private denylist (Blocker — cite the entry, never quote the term)" "$DENY_HITS"
else
  echo; echo "  (no private denylist at ${DENY/#"$HOME"/"~"} — see check-catalog.md §1h)"
fi

section "debug leftovers"
scan "Debug output / breakpoints (Warning)" 'console\.(log|debug|trace|dir|table)\(|^[[:space:]]*debugger\b|\bbreakpoint\(\)|pdb\.set_trace\(|^[[:space:]]*import i?pdb\b|binding\.pry|\bbyebug\b|\bvar_dump\(' src
scan "Focused tests — the rest of the suite stops running (Blocker)" '\b(it|test|describe|context|suite)\.only\(|\bf(it|describe)\(|\bonly:[[:space:]]*true\b' code
scan "Local / dev endpoints in non-test code (Warning)" '\b(localhost|127\.0\.0\.1|0\.0\.0\.0):[0-9]{2,5}\b' src
scan "TLS verification turned off (Blocker)" 'NODE_TLS_REJECT_UNAUTHORIZED[[:space:]]*[=:][[:space:]]*["'"'"']?0|rejectUnauthorized[[:space:]]*:[[:space:]]*false|strictSSL[[:space:]]*[:=][[:space:]]*false|\bverify[[:space:]]*=[[:space:]]*False\b|InsecureSkipVerify:[[:space:]]*true|\bcurl\b.*[[:space:]](-k|--insecure)\b|GIT_SSL_NO_VERIFY' nontest
scan "Dev switch defaulting on (Warning)" '\b[A-Z0-9_]*(SKIP_AUTH|DISABLE_AUTH|AUTH_DISABLED|NO_AUTH|BYPASS_AUTH|INSECURE|ALLOW_ALL|DEV_MODE|DEBUG|SANDBOX|USE_MOCKS?|MOCK|FAKE)[A-Z0-9_]*["'"'"']?[[:space:]]*(=|:|\?\?|\|\|)[[:space:]]*["'"'"']?(true|1|yes|on)\b' nontest
scan "Non-test code importing test / sandbox / mock code (Warning)" '(\bfrom[[:space:]]+|\brequire\(|\bimport\()[[:space:]]*["'"'"'](\.{0,2}/)*([^"'"'"']*/)?(tests?|__tests__|__mocks__|mocks?|fixtures?|sandbox)/' src

section "gen-hygiene"
# {{var}} NOT flagged — legit in Postman/Handlebars/Jinja
scan "Unsubstituted template placeholders" '\[Controller\]|<%=|__[A-Z]{3,}__' code
scan "Stale stub/for-later headers" 'service stub generated|for later implementation|not yet implemented|TODO: ?Implement' code

section "doc-slop (filename heuristic, any folder)"
printf '%s\n' "${FILES[@]}" | grep -iE '(^|/)([a-z0-9_-]*-?(report|parity|status|plan|notes|todo|session|scratch|wip|draft)[a-z0-9_-]*|.*-v[0-9]+)\.(md|mdx|txt)$' | sed 's/^/  /' || echo "  none by name (still read docs in target for content-slop)"

section "gitignore-doctor"
# (a) refs to gitignored paths — skip common build/dep tokens + globs
DENY_TOK='^(node_modules|dist|build|out|target|bin|obj|coverage|\.next|\.nuxt|\.cache|\.venv|venv|__pycache__|\.vscode|\.idea|\.DS_Store|\.env|\.env\..*|.*\.(log|pyc|swp)|Thumbs\.db|\*.*)$'
IGN="$(grep -vE '^\s*#|^\s*$' .gitignore 2>/dev/null | sed 's#/$##' | grep -vE "$DENY_TOK" | awk '{ if (length($0)>=3) print }' | head -60)"
if [ -n "$IGN" ]; then
  REFS="$(while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    h="$(hits "$pat" -F code | grep -vE '^\.gitignore:' | head -4)"
    [ -n "$h" ] && echo "  [$pat]" && printf '%s\n' "$h" | sed 's/^/     /'
  done <<< "$IGN")"
  [ -n "$REFS" ] && { echo; echo "## References to gitignored paths (dangling on clone)"; printf '%s\n' "$REFS"; }
fi
# (b) target files that look like they SHOULD be ignored but aren't
echo; echo "## Target files that may need gitignoring"
printf '%s\n' "${FILES[@]}" | grep -iE '(^|/)(\.env(\.[a-z]+)?$|.*-report\.(json|md)$|.*\.log$)' | grep -vE '\.env\.example$' | sed 's/^/  /' || echo "  none obvious"

echo
echo "(semantic checks — dead-config, PII judgement, doc-slop content — need file reading; see check-catalog.md)"
[ "$WHOLE" = 0 ] && echo "(older lines of the changed files were not scanned — add --whole-files to include them)"
exit 0
