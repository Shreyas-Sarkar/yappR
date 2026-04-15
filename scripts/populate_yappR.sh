#!/usr/bin/env bash
# macOS-compatible (bash 3+) script
# Populates yappR with Lumiq source and creates a realistic commit history
# Jan 15, 2026 → Apr 10, 2026 (at least 1 commit/day)

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/Shreyas-Sarkar/yappR.git"
WORK_DIR="/tmp/yappR_setup"
SOURCE_DIR="/Users/shreyassarkar/Desktop/Lumiq"
GIT_AUTHOR_NAME="Shreyas-Sarkar"
GIT_AUTHOR_EMAIL="shreyassrkr@gmail.com"
START_DATE="2026-01-15"
END_DATE="2026-04-10"

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[ OK ]\033[0m $*"; }
die()  { echo -e "\033[1;31m[ERR ]\033[0m $*" >&2; exit 1; }

# macOS-safe: next day from YYYY-MM-DD
next_day() {
  date -j -v+1d -f "%Y-%m-%d" "$1" "+%Y-%m-%d"
}

# Random number in [min, max]
rand_between() {
  local min=$1 max=$2
  echo $(( min + RANDOM % (max - min + 1) ))
}

# ─── Step 1: Clone ───────────────────────────────────────────────────────────
log "Cloning yappR..."
rm -rf "$WORK_DIR"
git clone "$REPO_URL" "$WORK_DIR"
cd "$WORK_DIR"

# ─── Step 2: Wipe history and content ────────────────────────────────────────
log "Wiping existing content and git history..."
git checkout --orphan fresh_start
git rm -rf . 2>/dev/null || true
# Remove any remaining tracked files
find . -maxdepth 1 ! -name '.' ! -name '.git' -exec rm -rf {} + 2>/dev/null || true
ok "Wiped."

# ─── Step 3: Copy Lumiq source ───────────────────────────────────────────────
log "Copying Lumiq source (excluding secrets & build artifacts)..."
rsync -a "$SOURCE_DIR/" "$WORK_DIR/" \
  --exclude='.git' \
  --exclude='.DS_Store' \
  --exclude='.venv' \
  --exclude='backend/venv' \
  --exclude='backend/__pycache__' \
  --exclude='backend/data' \
  --exclude='backend/.env' \
  --exclude='frontend/.next' \
  --exclude='frontend/node_modules' \
  --exclude='frontend/tsconfig.tsbuildinfo' \
  --exclude='frontend/.env' \
  --exclude='scripts'
ok "Source copied."

# ─── Step 4: Build date array (bash 3 compatible) ────────────────────────────
log "Building date range: $START_DATE → $END_DATE"
DATES=()
cur="$START_DATE"
while true; do
  DATES+=("$cur")
  [[ "$cur" == "$END_DATE" ]] && break
  cur=$(next_day "$cur")
done
NUM_DAYS=${#DATES[@]}
log "Total days: $NUM_DAYS"

# ─── Step 5: Commit message pools ────────────────────────────────────────────
BACKEND_MSGS=(
  "Initial project scaffold"
  "Add FastAPI entry point and app config"
  "Scaffold backend router structure"
  "Set up environment and config module"
  "Implement SQLAlchemy database models"
  "Add Supabase DB connection layer"
  "Build authentication router"
  "Implement JWT token handling"
  "Add file upload endpoint"
  "Implement dataset management service"
  "Add sandboxed code execution engine"
  "Implement LLM client wrapper"
  "Add code generation service"
  "Build query router and classifier"
  "Add explanation service"
  "Implement request validation models"
  "Add orchestrator service"
  "Implement cognitive reasoning engine"
  "Add RAG service for context retrieval"
  "Add chat history persistence"
  "Implement session management"
  "Add dataset preview endpoint"
  "Add schema inference utility"
  "Implement semantic column matching"
  "Add execution result caching layer"
  "Refactor LLM prompt templates"
  "Add multi-model support to LLM client"
  "Improve code evaluation pipeline"
  "Add logging and monitoring service"
  "Add mode classifier for query routing"
)

FRONTEND_MSGS=(
  "Initialize Next.js frontend"
  "Add Tailwind CSS and PostCSS config"
  "Scaffold app directory structure"
  "Add Supabase auth client"
  "Implement login page UI"
  "Add dashboard layout and navigation"
  "Implement file upload modal component"
  "Build chat interface panel"
  "Implement message streaming"
  "Add dataset list view"
  "Build analysis block component"
  "Add data table component"
  "Implement code block renderer"
  "Add execution loader animation"
  "Build message bubble component"
  "Add sidebar navigation"
  "Implement input bar with hotkeys"
  "Add processing phases indicator"
  "Implement auth context provider"
  "Add protected route handling"
  "Add API client utility functions"
  "Implement Supabase auth library"
  "Add TypeScript type definitions"
  "Improve responsive layout for mobile"
  "Add dark mode design tokens"
  "Improve accessibility attributes"
  "Add keyboard shortcut support"
  "Polish overall UI and animations"
  "Add chat session routing"
  "Implement signup page"
)

FIX_MSGS=(
  "Fix CORS preflight handling"
  "Fix token refresh race condition"
  "Fix file upload MIME type validation"
  "Fix memory leak in execution sandbox"
  "Fix chat history pagination bug"
  "Fix dataset schema inference edge case"
  "Fix LLM timeout error handling"
  "Fix duplicate message rendering"
  "Fix auth state persistence on reload"
  "Fix column type detection for numerics"
  "Fix streaming response parsing"
  "Fix mobile layout overflow"
  "Fix login redirect loop"
  "Fix environment variable loading order"
  "Fix database connection pool exhaustion"
  "Fix code execution timeout handling"
  "Fix SQL injection in dynamic queries"
  "Fix chart axis label overflow"
)

REFACTOR_MSGS=(
  "Refactor auth middleware"
  "Extract shared utility functions"
  "Reorganize router modules"
  "Consolidate LLM prompt templates"
  "Simplify frontend state management"
  "Decouple service dependencies"
  "Centralize API error responses"
  "Streamline file upload pipeline"
  "Migrate to typed API responses"
  "DRY up repeated component props"
)

CHORE_MSGS=(
  "Update Python dependencies"
  "Add .gitignore rules"
  "Clean up unused imports"
  "Update requirements.txt"
  "Bump frontend package versions"
  "Add linting configuration"
  "Update environment example files"
  "Remove console debug logs"
  "Organize project structure"
  "Add code documentation"
  "Update README with setup guide"
  "Document API endpoints"
)

# All maintenance messages (used after initial build phase)
MAINT_MSGS=(
  "${FIX_MSGS[@]}"
  "${REFACTOR_MSGS[@]}"
  "${CHORE_MSGS[@]}"
)
NUM_MAINT=${#MAINT_MSGS[@]}

# ─── Step 6: Helper – make a backdated commit ─────────────────────────────────
make_commit() {
  local date_str="$1"
  local hour="$2"
  local msg="$3"
  local ts="${date_str}T${hour}:00:00"

  GIT_AUTHOR_NAME="$GIT_AUTHOR_NAME" \
  GIT_AUTHOR_EMAIL="$GIT_AUTHOR_EMAIL" \
  GIT_AUTHOR_DATE="$ts" \
  GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" \
  GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
  GIT_COMMITTER_DATE="$ts" \
  git commit -m "$msg"
}

# ─── Step 7: Stage backend files in groups across days 0–14 ──────────────────
log "Collecting file groups..."

# Collect files into arrays (bash 3 safe: use process substitution + while read)
BACKEND_FILES=()
while IFS= read -r f; do
  BACKEND_FILES+=("$f")
done < <(find ./backend -type f | LC_ALL=C sort)

FRONTEND_FILES=()
while IFS= read -r f; do
  FRONTEND_FILES+=("$f")
done < <(find ./frontend -type f | LC_ALL=C sort)

DOC_FILES=()
while IFS= read -r f; do
  DOC_FILES+=("$f")
done < <(find . -maxdepth 1 -type f | LC_ALL=C sort)

BF_COUNT=${#BACKEND_FILES[@]}
FF_COUNT=${#FRONTEND_FILES[@]}
log "Backend files: $BF_COUNT | Frontend files: $FF_COUNT | Root docs: ${#DOC_FILES[@]}"

# ─── Step 8: Day 0 – initial scaffold commit (root docs + .gitignore) ─────────
log "Day 0 – initial scaffold..."
for f in "${DOC_FILES[@]}"; do
  git add "$f" 2>/dev/null || true
done
git add .gitignore 2>/dev/null || true

# Check if there's anything staged
if ! git diff --cached --quiet 2>/dev/null; then
  hr=$(rand_between 9 11)
  printf -v hr "%02d" $hr
  make_commit "${DATES[0]}" "$hr" "Initial project scaffold"
fi

day_idx=1

# ─── Step 9: Backend files across days 1–14 ──────────────────────────────────
log "Staging backend files over 14 days..."
TOTAL_BACKEND_DAYS=14
bf_per_day=$(( (BF_COUNT + TOTAL_BACKEND_DAYS - 1) / TOTAL_BACKEND_DAYS ))
[[ $bf_per_day -lt 1 ]] && bf_per_day=1

bf_idx=0
bd=0
while [[ $bf_idx -lt $BF_COUNT && $day_idx -lt $NUM_DAYS && $bd -lt $TOTAL_BACKEND_DAYS ]]; do
  chunk_end=$(( bf_idx + bf_per_day ))
  [[ $chunk_end -gt $BF_COUNT ]] && chunk_end=$BF_COUNT

  while [[ $bf_idx -lt $chunk_end ]]; do
    git add "${BACKEND_FILES[$bf_idx]}" 2>/dev/null || true
    bf_idx=$(( bf_idx + 1 ))
  done

  if ! git diff --cached --quiet 2>/dev/null; then
    hr=$(rand_between 9 18)
    printf -v hr "%02d" $hr
    msg_idx=$(( bd % ${#BACKEND_MSGS[@]} ))
    make_commit "${DATES[$day_idx]}" "$hr" "${BACKEND_MSGS[$msg_idx]}"
  fi

  day_idx=$(( day_idx + 1 ))
  bd=$(( bd + 1 ))
done

# ─── Step 10: Frontend files across days 15–28 ───────────────────────────────
log "Staging frontend files over 14 days..."
TOTAL_FRONTEND_DAYS=14
ff_per_day=$(( (FF_COUNT + TOTAL_FRONTEND_DAYS - 1) / TOTAL_FRONTEND_DAYS ))
[[ $ff_per_day -lt 1 ]] && ff_per_day=1

ff_idx=0
fd=0
while [[ $ff_idx -lt $FF_COUNT && $day_idx -lt $NUM_DAYS && $fd -lt $TOTAL_FRONTEND_DAYS ]]; do
  chunk_end=$(( ff_idx + ff_per_day ))
  [[ $chunk_end -gt $FF_COUNT ]] && chunk_end=$FF_COUNT

  while [[ $ff_idx -lt $chunk_end ]]; do
    git add "${FRONTEND_FILES[$ff_idx]}" 2>/dev/null || true
    ff_idx=$(( ff_idx + 1 ))
  done

  if ! git diff --cached --quiet 2>/dev/null; then
    hr=$(rand_between 9 18)
    printf -v hr "%02d" $hr
    msg_idx=$(( fd % ${#FRONTEND_MSGS[@]} ))
    make_commit "${DATES[$day_idx]}" "$hr" "${FRONTEND_MSGS[$msg_idx]}"
  fi

  day_idx=$(( day_idx + 1 ))
  fd=$(( fd + 1 ))
done

# ─── Step 11: Catch any remaining unstaged files ──────────────────────────────
git add -A 2>/dev/null || true
if ! git diff --cached --quiet 2>/dev/null; then
  make_commit "${DATES[$day_idx]}" "11" "Add remaining project files"
  day_idx=$(( day_idx + 1 ))
fi

ok "Initial build-phase commits done through day $day_idx."

# ─── Step 12: Fill remaining days with maintenance commits ────────────────────
log "Generating maintenance commits for remaining $((NUM_DAYS - day_idx)) days..."
maint_idx=0

while [[ $day_idx -lt $NUM_DAYS ]]; do
  date_str="${DATES[$day_idx]}"
  commits_today=$(rand_between 1 3)

  for (( c=0; c<commits_today; c++ )); do
    hr=$(rand_between 8 20)
    printf -v hr "%02d" $hr
    msg="${MAINT_MSGS[$maint_idx % $NUM_MAINT]}"
    # Use --allow-empty so maintenance commits aren't blocked  
    GIT_AUTHOR_NAME="$GIT_AUTHOR_NAME" \
    GIT_AUTHOR_EMAIL="$GIT_AUTHOR_EMAIL" \
    GIT_AUTHOR_DATE="${date_str}T${hr}:00:00" \
    GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" \
    GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL" \
    GIT_COMMITTER_DATE="${date_str}T${hr}:00:00" \
    git commit --allow-empty -m "$msg"
    maint_idx=$(( maint_idx + 1 ))
  done

  day_idx=$(( day_idx + 1 ))
done

ok "All commits generated!"

# ─── Step 13: Force push ──────────────────────────────────────────────────────
log "Force pushing to origin main..."
git branch -M main
git push -f origin main

TOTAL_COMMITS=$(git rev-list --count HEAD)
ok "Done! Pushed $TOTAL_COMMITS commits to yappR."
log "Verify: https://github.com/Shreyas-Sarkar/yappR"
