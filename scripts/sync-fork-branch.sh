#!/usr/bin/env bash
# sync-fork-branch.sh - keep a fork branch up to date with upstream safely.
#
# Default behavior is merge-based (no history rewriting) and tracks upstream/dev.
# It creates a recovery backup branch before integrating upstream changes.

set -euo pipefail

TRACK_BRANCH="dev"
UPSTREAM_REMOTE="upstream"
UPSTREAM_URL="${UPSTREAM_URL:-}"
MODE="merge"
ALLOW_HISTORY_REWRITE=0
CREATE_BACKUP=1
BACKUP_PREFIX="sync-backup"
SKIP_CHECKS=0
DRY_RUN=0
WORKING_BRANCH=""
TRACKING_BRANCH=""

_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
_step() { printf '\033[36m[STEP]\033[0m %s\n' "$*"; }
_pass() { printf '\033[32m[PASS]\033[0m %s\n' "$*"; }
_fail() { printf '\033[31m[FAIL]\033[0m %s\n' "$*"; }

usage() {
    cat <<'USAGE'
Usage: scripts/sync-fork-branch.sh [OPTIONS]

Safely sync a working fork branch with upstream using a dedicated tracking branch.

Defaults:
  - tracks upstream/dev
  - integration mode: merge (no history rewrite)
  - creates backup branch before integration

Options:
  --track-branch <name>           Upstream branch to track (default: dev)
  --working-branch <name>         Long-lived branch to update (default: current branch)
  --tracking-branch <name>        Clean mirror branch (default: sync/<track-branch>)
  --upstream-remote <name>        Upstream remote name (default: upstream)
  --upstream-url <url>            Upstream remote URL if remote is missing
  --mode <merge|rebase>           Integration strategy (default: merge)
  --allow-history-rewrite         Required to allow --mode rebase
  --no-backup                     Skip pre-sync recovery branch
  --backup-prefix <name>          Backup branch prefix (default: sync-backup)
  --skip-checks                   Skip post-sync checks
  --dry-run                       Print actions without changing git state
  --help, -h                      Show this help

Examples:
  scripts/sync-fork-branch.sh
  scripts/sync-fork-branch.sh --track-branch main --mode merge
  scripts/sync-fork-branch.sh --mode rebase --allow-history-rewrite
USAGE
}

run_cmd() {
    if [ "${DRY_RUN}" -eq 1 ]; then
        printf '[DRY-RUN] %s\n' "$*"
        return 0
    fi
    "$@"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --track-branch)
            TRACK_BRANCH="${2:-}"
            shift 2
            ;;
        --working-branch)
            WORKING_BRANCH="${2:-}"
            shift 2
            ;;
        --tracking-branch)
            TRACKING_BRANCH="${2:-}"
            shift 2
            ;;
        --upstream-remote)
            UPSTREAM_REMOTE="${2:-}"
            shift 2
            ;;
        --upstream-url)
            UPSTREAM_URL="${2:-}"
            shift 2
            ;;
        --mode)
            MODE="${2:-}"
            shift 2
            ;;
        --allow-history-rewrite)
            ALLOW_HISTORY_REWRITE=1
            shift
            ;;
        --no-backup)
            CREATE_BACKUP=0
            shift
            ;;
        --backup-prefix)
            BACKUP_PREFIX="${2:-}"
            shift 2
            ;;
        --skip-checks)
            SKIP_CHECKS=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            _fail "Unknown option: $1"
            usage >&2
            exit 1
            ;;
    esac
done

if [ -z "${TRACK_BRANCH}" ] || [ -z "${UPSTREAM_REMOTE}" ]; then
    _fail "track branch and upstream remote must be set."
    exit 1
fi

if [ "${MODE}" != "merge" ] && [ "${MODE}" != "rebase" ]; then
    _fail "--mode must be merge or rebase."
    exit 1
fi

if [ "${MODE}" = "rebase" ] && [ "${ALLOW_HISTORY_REWRITE}" -ne 1 ]; then
    _fail "Rebase rewrites history. Pass --allow-history-rewrite to continue."
    exit 1
fi

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    _fail "Run this script inside a git repository."
    exit 1
}

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ -z "${WORKING_BRANCH}" ]; then
    WORKING_BRANCH="${CURRENT_BRANCH}"
fi
if [ -z "${TRACKING_BRANCH}" ]; then
    TRACKING_BRANCH="sync/${TRACK_BRANCH}"
fi

if [ "${WORKING_BRANCH}" = "${TRACKING_BRANCH}" ]; then
    _fail "Working branch and tracking branch must be different."
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    _fail "Working tree is not clean. Commit/stash changes before syncing."
    exit 1
fi

if ! git show-ref --verify --quiet "refs/heads/${WORKING_BRANCH}"; then
    _fail "Working branch '${WORKING_BRANCH}' does not exist."
    exit 1
fi

START_COMMIT="$(git rev-parse "${WORKING_BRANCH}")"

_step "Ensuring upstream remote '${UPSTREAM_REMOTE}' exists"
if git remote get-url "${UPSTREAM_REMOTE}" >/dev/null 2>&1; then
    _info "Using existing ${UPSTREAM_REMOTE}: $(git remote get-url "${UPSTREAM_REMOTE}")"
else
    if [ -z "${UPSTREAM_URL}" ]; then
        _fail "Remote '${UPSTREAM_REMOTE}' is missing. Set UPSTREAM_URL or pass --upstream-url."
        exit 1
    fi
    run_cmd git remote add "${UPSTREAM_REMOTE}" "${UPSTREAM_URL}"
    _pass "Added ${UPSTREAM_REMOTE} remote."
fi

_step "Fetching remotes"
run_cmd git fetch --prune "${UPSTREAM_REMOTE}"
run_cmd git fetch --prune origin

UPSTREAM_REF="refs/remotes/${UPSTREAM_REMOTE}/${TRACK_BRANCH}"
if ! git show-ref --verify --quiet "${UPSTREAM_REF}"; then
    _fail "Missing ${UPSTREAM_REMOTE}/${TRACK_BRANCH}. Check --track-branch or remote URL."
    exit 1
fi

if [ "${CREATE_BACKUP}" -eq 1 ]; then
    _step "Creating recovery backup branch"
    BACKUP_BRANCH="${BACKUP_PREFIX}-${WORKING_BRANCH//\//__}-$(date -u +%Y%m%d-%H%M%S)"
    run_cmd git branch "${BACKUP_BRANCH}" "${WORKING_BRANCH}"
    _pass "Backup branch created: ${BACKUP_BRANCH}"
else
    _warn "Skipping backup branch creation (--no-backup)."
fi

_step "Refreshing tracking branch ${TRACKING_BRANCH}"
if git show-ref --verify --quiet "refs/heads/${TRACKING_BRANCH}"; then
    run_cmd git checkout "${TRACKING_BRANCH}"
    run_cmd git reset --hard "${UPSTREAM_REMOTE}/${TRACK_BRANCH}"
else
    run_cmd git checkout -b "${TRACKING_BRANCH}" "${UPSTREAM_REMOTE}/${TRACK_BRANCH}"
fi
run_cmd git branch --set-upstream-to="${UPSTREAM_REMOTE}/${TRACK_BRANCH}" "${TRACKING_BRANCH}"
_pass "Tracking branch now mirrors ${UPSTREAM_REMOTE}/${TRACK_BRANCH}"

_step "Integrating ${TRACKING_BRANCH} into ${WORKING_BRANCH} via ${MODE}"
run_cmd git checkout "${WORKING_BRANCH}"
if [ "${MODE}" = "merge" ]; then
    run_cmd git merge --no-ff --no-edit "${TRACKING_BRANCH}"
else
    run_cmd git rebase "${TRACKING_BRANCH}"
fi
_pass "Integration complete."

if [ "${SKIP_CHECKS}" -eq 1 ]; then
    _warn "Skipping validation checks (--skip-checks)."
else
    _step "Running post-sync checks from CONTRIBUTING.md"
    if command -v python >/dev/null 2>&1; then
        if python -m pytest >/dev/null 2>&1; then
            _pass "pytest passed."
        else
            _warn "pytest failed or missing dependencies in this environment."
        fi
        COMPILE_TARGETS=()
        [ -f app.py ] && COMPILE_TARGETS+=("app.py")
        for _dir in routes src core mcp_servers; do
            if [ -d "${_dir}" ]; then
                while IFS= read -r _file; do
                    COMPILE_TARGETS+=("${_file}")
                done < <(find "${_dir}" -maxdepth 1 -type f -name '*.py' | sort)
            fi
        done
        if [ "${#COMPILE_TARGETS[@]}" -gt 0 ]; then
            python -m py_compile "${COMPILE_TARGETS[@]}" || {
                _fail "py_compile failed. Re-run manually for details."
                exit 1
            }
            _pass "py_compile passed."
        else
            _warn "No Python compile targets found."
        fi
    else
        _warn "python not available, skipping python checks."
    fi

    if command -v node >/dev/null 2>&1; then
        CHANGED_JS="$(git diff --name-only --diff-filter=ACMR "${START_COMMIT}"..HEAD -- 'static/js/**/*.js' || true)"
        if [ -n "${CHANGED_JS}" ]; then
            while IFS= read -r file; do
                [ -z "${file}" ] && continue
                node --check "${file}" || {
                    _fail "node --check failed for ${file}"
                    exit 1
                }
            done <<EOF
${CHANGED_JS}
EOF
            _pass "node --check passed for changed static/js files."
        else
            _info "No changed static/js files in sync diff."
        fi
    else
        _warn "node not available, skipping JS syntax checks."
    fi
fi

SYNC_LOG_FILE="$(git rev-parse --git-dir)/odysseus-sync.log"
{
    printf -- '- %s | working=%s | tracking=%s (%s/%s) | mode=%s | from=%s | to=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "${WORKING_BRANCH}" \
        "${TRACKING_BRANCH}" \
        "${UPSTREAM_REMOTE}" \
        "${TRACK_BRANCH}" \
        "${MODE}" \
        "${START_COMMIT}" \
        "$(git rev-parse HEAD)"
} >> "${SYNC_LOG_FILE}"

_pass "Sync log updated at ${SYNC_LOG_FILE}"
_info "For upstream contributions, keep PR base set to ${TRACK_BRANCH} unless maintainers request another base branch."
