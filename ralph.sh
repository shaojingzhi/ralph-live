#!/bin/bash

set -euo pipefail

TOOL="codex"
MAX_ITERATIONS=10
OPENCODE_AGENT="build"
OPENCODE_MODEL="${OPENCODE_MODEL:-codexzh/gpt-5.4}"
CODEX_MODEL="${CODEX_MODEL:-}"
CODEX_SANDBOX_MODE="${RALPH_CODEX_SANDBOX:-workspace-write}"
CODEX_APPROVAL_POLICY="${RALPH_CODEX_APPROVAL:-never}"
CODEX_PROFILE="${RALPH_CODEX_PROFILE:-}"
MODEL_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --agent)
      OPENCODE_AGENT="$2"
      shift 2
      ;;
    --agent=*)
      OPENCODE_AGENT="${1#*=}"
      shift
      ;;
    --model)
      MODEL_OVERRIDE="$2"
      shift 2
      ;;
    --model=*)
      MODEL_OVERRIDE="${1#*=}"
      shift
      ;;
    --codex-sandbox)
      CODEX_SANDBOX_MODE="$2"
      shift 2
      ;;
    --codex-sandbox=*)
      CODEX_SANDBOX_MODE="${1#*=}"
      shift
      ;;
    --codex-approval)
      CODEX_APPROVAL_POLICY="$2"
      shift 2
      ;;
    --codex-approval=*)
      CODEX_APPROVAL_POLICY="${1#*=}"
      shift
      ;;
    --codex-profile)
      CODEX_PROFILE="$2"
      shift 2
      ;;
    --codex-profile=*)
      CODEX_PROFILE="${1#*=}"
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

if [ -n "$MODEL_OVERRIDE" ]; then
  if [[ "$TOOL" == "opencode" ]]; then
    OPENCODE_MODEL="$MODEL_OVERRIDE"
  elif [[ "$TOOL" == "codex" ]]; then
    CODEX_MODEL="$MODEL_OVERRIDE"
  fi
fi

if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "codex" && "$TOOL" != "opencode" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', 'codex', or 'opencode'."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$SCRIPT_DIR")"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

archive_previous_run() {
  if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
    CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
    LAST_BRANCH=$(<"$LAST_BRANCH_FILE")

    if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
      DATE=$(date +%Y-%m-%d)
      FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
      ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

      echo "Archiving previous run: $LAST_BRANCH"
      mkdir -p "$ARCHIVE_FOLDER"
      [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
      [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
      echo "Archived to: $ARCHIVE_FOLDER"

      {
        echo "# Ralph Progress Log"
        echo "Started: $(date)"
        echo "---"
      } > "$PROGRESS_FILE"
    fi
  fi
}

track_current_branch() {
  if [ -f "$PRD_FILE" ]; then
    CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ]; then
      echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
    fi
  fi
}

ensure_progress_file() {
  if [ ! -f "$PROGRESS_FILE" ]; then
    {
      echo "# Ralph Progress Log"
      echo "Started: $(date)"
      echo "---"
    } > "$PROGRESS_FILE"
  fi
}

run_amp() {
  (
    cd "$PROJECT_DIR"
    cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1
  ) | tee /dev/stderr
}

run_claude() {
  (
    cd "$PROJECT_DIR"
    claude --dangerously-skip-permissions --print < "$SCRIPT_DIR/CLAUDE.md" 2>&1
  ) | tee /dev/stderr
}

run_codex() {
  local codex_args
  local exec_args

  codex_args=(--ask-for-approval "$CODEX_APPROVAL_POLICY")
  exec_args=(exec --cd "$PROJECT_DIR" --sandbox "$CODEX_SANDBOX_MODE" --color never)

  if [ -n "$CODEX_MODEL" ]; then
    exec_args+=(--model "$CODEX_MODEL")
  fi

  if [ -n "$CODEX_PROFILE" ]; then
    exec_args+=(--profile "$CODEX_PROFILE")
  fi

  env \
    -u CODEX_CI \
    -u CODEX_INTERNAL_ORIGINATOR_OVERRIDE \
    -u CODEX_SANDBOX \
    -u CODEX_SANDBOX_NETWORK_DISABLED \
    -u CODEX_SHELL \
    -u CODEX_THREAD_ID \
    codex "${codex_args[@]}" "${exec_args[@]}" - < "$SCRIPT_DIR/CODEX.md" 2>&1 | tee /dev/stderr
}

run_opencode() {
  local prompt
  prompt="$(<"$SCRIPT_DIR/OPENCODE.md")"

  env -u OPENCODE -u OPENCODE_CLIENT -u OPENCODE_PID -u AGENT -u OPENCODE_SERVER_USERNAME -u OPENCODE_SERVER_PASSWORD \
  opencode run \
    --dir "$PROJECT_DIR" \
    --agent "$OPENCODE_AGENT" \
    --model "$OPENCODE_MODEL" \
    --format json \
    "$prompt" 2>&1 | tee /dev/stderr
}

extract_opencode_text() {
  printf '%s\n' "$1" | jq -r 'select(.type == "text") | .part.text' 2>/dev/null || true
}

extract_codex_text() {
  awk '
    /^assistant$/ { capture=1; next }
    capture { print }
  ' "$1"
}

iteration_has_auth_error() {
  grep -Eiq '401 Unauthorized|authentication required|无效的令牌|Unauthorized' "$1"
}

archive_previous_run
track_current_branch
ensure_progress_file

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  OUTPUT=""
  ITERATION_LOG=$(mktemp)
  DIFF_BEFORE=$(mktemp)
  DIFF_AFTER=$(mktemp)
  git -C "$PROJECT_DIR" status --short > "$DIFF_BEFORE" 2>/dev/null || true

  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT="$(run_amp | tee "$ITERATION_LOG")" || true
  elif [[ "$TOOL" == "claude" ]]; then
    OUTPUT="$(run_claude | tee "$ITERATION_LOG")" || true
  elif [[ "$TOOL" == "codex" ]]; then
    OUTPUT="$(run_codex | tee "$ITERATION_LOG")" || true
  else
    OUTPUT="$(run_opencode | tee "$ITERATION_LOG")" || true
  fi

  git -C "$PROJECT_DIR" status --short > "$DIFF_AFTER" 2>/dev/null || true
  if ! cmp -s "$DIFF_BEFORE" "$DIFF_AFTER"; then
    echo ""
    echo "[ralph] git status changed during iteration $i:"
    cat "$DIFF_AFTER"
  fi

  COMPLETION_SOURCE="$OUTPUT"
  if [[ "$TOOL" == "opencode" ]]; then
    COMPLETION_SOURCE="$(extract_opencode_text "$OUTPUT")"
  elif [[ "$TOOL" == "codex" ]]; then
    COMPLETION_SOURCE="$(extract_codex_text "$ITERATION_LOG")"
  fi

  if iteration_has_auth_error "$ITERATION_LOG"; then
    echo ""
    echo "Ralph stopped: tool authentication failed."
    echo "Check your provider token / API credentials, then retry."
    rm -f "$ITERATION_LOG" "$DIFF_BEFORE" "$DIFF_AFTER"
    exit 1
  fi

  if printf '%s' "$COMPLETION_SOURCE" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    rm -f "$ITERATION_LOG" "$DIFF_BEFORE" "$DIFF_AFTER"
    exit 0
  fi

  rm -f "$ITERATION_LOG" "$DIFF_BEFORE" "$DIFF_AFTER"

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
