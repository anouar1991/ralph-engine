#!/usr/bin/env bash
#
# ralph-core.sh - Core functions for ralph engine
#

# Color setup (respects NO_COLOR environment variable)
setup_colors() {
    if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
        RED=""
        GREEN=""
        YELLOW=""
        BLUE=""
        CYAN=""
        MAGENTA=""
        BOLD=""
        NC=""
    else
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        MAGENTA='\033[0;35m'
        BOLD='\033[1m'
        NC='\033[0m'
    fi
}

# Logging functions
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

banner() {
    local text="$1"
    local width=65
    local padding=$(( (width - ${#text} - 2) / 2 ))

    echo -e "${CYAN}"
    printf '╔%s╗\n' "$(printf '═%.0s' $(seq 1 $width))"
    printf '║%*s%s%*s║\n' $padding "" "$text" $((width - padding - ${#text})) ""
    printf '╚%s╝\n' "$(printf '═%.0s' $(seq 1 $width))"
    echo -e "${NC}"
}

# Get completed tasks from git history
get_completed_tasks() {
    git log --oneline --grep="Complete T-" --format="%s" 2>/dev/null | \
        grep -oP 'T-\d+' | sort -u || echo ""
}

# Check if all tasks are complete
check_all_tasks_complete() {
    local total completed
    total=$(jq '.tasks | length' "$PRD_FILE" 2>/dev/null || echo 0)
    completed=$(jq '[.tasks[] | select(.pass == true)] | length' "$PRD_FILE" 2>/dev/null || echo 0)

    [[ "$total" -gt 0 ]] && [[ "$total" -eq "$completed" ]]
}

# Show progress
show_progress() {
    local completed_list completed total pct
    completed_list=$(get_completed_tasks)
    completed=0

    if [[ -n "$completed_list" ]]; then
        completed=$(echo "$completed_list" | wc -l)
    fi

    total=$(jq '.tasks | length' "$PRD_FILE" 2>/dev/null || echo 0)
    pct=0

    if [[ "$total" -gt 0 ]] && [[ "$completed" -gt 0 ]]; then
        pct=$((completed * 100 / total))
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Progress: $completed/$total tasks ($pct%)${NC}"

    if [[ -n "$completed_list" ]]; then
        echo -e "${BLUE}Completed:${NC} $(echo "$completed_list" | tr '\n' ' ')"
    else
        echo -e "${BLUE}Completed:${NC} (none yet)"
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get file state for progress detection
get_file_state() {
    find . -type f \
        -not -path '*/\.*' \
        -not -path './node_modules/*' \
        -not -path './target/*' \
        -not -path './.git/*' \
        -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
}

# Build prompt for Claude
build_prompt() {
    local iteration="$1"
    local completed_tasks
    completed_tasks=$(get_completed_tasks | tr '\n' ',' | sed 's/,$//')

    local git_log
    git_log=$(git log --oneline -10 2>/dev/null || echo "No commits yet")

    local agents_files
    agents_files=$(find . -name "AGENTS.md" -type f 2>/dev/null | head -5)

    local dir_structure
    dir_structure=$(find . -type d \
        -not -path '*/\.*' \
        -not -path './node_modules/*' \
        -not -path './target/*' 2>/dev/null | head -20)

    cat <<EOF
# Ralph Loop - Iteration $iteration

## Context from Git Memory

### Recent Commits (your previous work):
\`\`\`
$git_log
\`\`\`

### Completed Tasks: [$completed_tasks]

### Existing AGENTS.md files:
$agents_files

## Your Task This Iteration

1. **Read prd.json** to see all tasks and their dependencies
2. **Find ONE task** where:
   - \`pass: false\`
   - All \`dependencies\` are in completed list above OR have \`pass: true\`
   - Prefer lower complexity for momentum
3. **Execute that task completely**:
   - Follow all \`actions\`
   - Verify all \`guarantees\`
   - Run \`validation\` checks
4. **Update prd.json**: Set \`pass: true\` for the completed task
5. **Create/Update AGENTS.md** in the relevant directory with lessons learned
6. **Commit your work**:
   \`\`\`bash
   git add -A
   git commit -m "Complete T-XXX: Task Name

   - What was done
   - Key decisions made
   - Lessons learned"
   \`\`\`

## AGENTS.md Format

Create in each coherent directory (src/, src/components/, src-tauri/, etc.):

\`\`\`markdown
# Agents Knowledge Base

## Directory Purpose
Brief description of what this directory contains.

## Patterns & Conventions
- Pattern 1: Description
- Pattern 2: Description

## Lessons Learned
- [T-XXX] Lesson from task
- [T-YYY] Another lesson

## Gotchas & Warnings
- Warning about something tricky

## Dependencies & Relationships
- Depends on: ../other-dir
- Used by: ../consumer-dir
\`\`\`

## Rules

1. **ONE task per iteration** - Complete fully before stopping
2. **Git is your memory** - Commit after each task with detailed message
3. **AGENTS.md is your knowledge base** - Document lessons in relevant directories
4. **Follow dependencies strictly** - Never skip ahead
5. **Validate before marking done** - Run all validation checks

## Completion

When ALL tasks have \`pass: true\`, output exactly:

\`\`\`
<promise>PROJECT COMPLETE</promise>
\`\`\`

## Current Directory Structure

\`\`\`
$dir_structure
\`\`\`

## Start Now

Read prd.json, pick ONE task, complete it, commit, and stop.
EOF
}

# Activity monitor (background process)
monitor_activity() {
    local start_time last_file_state current_time elapsed current_file_state
    start_time=$(date +%s)
    last_file_state=$(get_file_state)

    while true; do
        sleep 30
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        current_file_state=$(get_file_state)

        if [[ "$current_file_state" != "$last_file_state" ]]; then
            echo -e "${MAGENTA}  [${elapsed}s] Activity: $current_file_state${NC}"
            last_file_state="$current_file_state"
        else
            echo -e "${BLUE}  [${elapsed}s] Waiting...${NC}"
        fi
    done
}

# Run single Claude iteration
run_claude_iteration() {
    local iteration="$1"
    local prompt="$2"
    local output_file="$OUTPUT_DIR/output-$iteration.txt"
    local prompt_file="$OUTPUT_DIR/prompt-$iteration.md"

    # Save prompt for debugging
    echo "$prompt" > "$prompt_file"

    # Clear output file
    : > "$output_file"

    # Start activity monitor in background
    monitor_activity "$output_file" &
    local monitor_pid=$!

    # Cleanup on exit
    trap "kill $monitor_pid 2>/dev/null || true" RETURN

    info "Invoking Claude Code (timeout: ${ITERATION_TIMEOUT}s)..."
    echo -e "${BLUE}Output: $output_file${NC}"
    echo ""

    # Run Claude with timeout
    local exit_code=0
    timeout --foreground "$ITERATION_TIMEOUT" bash -c '
        claude --print --dangerously-skip-permissions < "$1" 2>&1
    ' -- "$prompt_file" > "$output_file" || exit_code=$?

    # Kill monitor
    kill $monitor_pid 2>/dev/null || true

    # Show output summary
    if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
        local lines
        lines=$(wc -l < "$output_file")
        success "Claude response: $lines lines"
        echo -e "${BLUE}--- Response preview ---${NC}"
        head -30 "$output_file"
        echo -e "${BLUE}--- End preview ---${NC}"
    else
        warn "No text response captured (tools may have executed)"
    fi

    # Handle timeout
    if [[ $exit_code -eq 124 ]]; then
        echo ""
        warn "TIMEOUT: Claude exceeded ${ITERATION_TIMEOUT}s limit"
    fi

    return $exit_code
}

# Check for progress
check_progress() {
    local commit_before="$1"
    local file_state_before="$2"
    local commit_after file_state_after

    commit_after=$(git rev-parse HEAD 2>/dev/null || echo "none")
    file_state_after=$(get_file_state)

    if [[ "$commit_before" != "$commit_after" ]]; then
        success "New commit detected"
        return 0
    fi

    if [[ "$file_state_before" != "$file_state_after" ]]; then
        info "Files changed (no commit yet)"
        return 0
    fi

    if git diff --name-only 2>/dev/null | grep -q "prd.json"; then
        info "prd.json modified (no commit yet)"
        return 0
    fi

    return 1
}

# Verification with Claude
verify_with_claude() {
    local iteration="$1"
    local verify_prompt_file="$OUTPUT_DIR/verify-prompt-$iteration.md"
    local verify_output_file="$OUTPUT_DIR/verify-output-$iteration.txt"

    # Gather context
    local git_status last_commit ralph_section
    git_status=$(git status --short 2>/dev/null)
    last_commit=$(git log -1 --oneline 2>/dev/null)
    ralph_section=$(jq '.ralph' "$PRD_FILE" 2>/dev/null)

    cat > "$verify_prompt_file" <<EOF
# Verification Task

Check if the last iteration completed properly. Fix any issues.

## Current State

Git status:
\`\`\`
$git_status
\`\`\`

Last commit:
\`\`\`
$last_commit
\`\`\`

prd.json ralph section:
\`\`\`json
$ralph_section
\`\`\`

## Checklist

1. Was a commit made with format "Complete T-XXX: Task Name"?
2. Does prd.json have pass: true for the completed task?
3. Is ralph.currentTaskId updated?
4. Is ralph.history updated?

## Actions

- If uncommitted work exists: commit it with proper format
- If prd.json not updated: update pass: true and commit
- If all good: do nothing

Respond with exactly one of:
- VERIFIED (all checks passed)
- FIXED (issues found and resolved)
- FAILED (could not fix)
EOF

    info "Running verification..."
    timeout 60 claude --print --dangerously-skip-permissions < "$verify_prompt_file" > "$verify_output_file" 2>&1 || true

    # Check result
    if grep -q "VERIFIED\|FIXED" "$verify_output_file"; then
        success "Verification passed"
        return 0
    else
        warn "Verification inconclusive - continuing anyway"
        return 0
    fi
}

# Show completion banner
show_completion() {
    local iterations="$1"
    local started="$2"

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                     PROJECT COMPLETE!                         ║${NC}"
    echo -e "${GREEN}║           All tasks in prd.json have pass: true               ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    printf "${GREEN}║  Total Iterations: %-43s ║${NC}\n" "$iterations"
    printf "${GREEN}║  Started:          %-43s ║${NC}\n" "$started"
    printf "${GREEN}║  Finished:         %-43s ║${NC}\n" "$(date -Iseconds)"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    info "Final Git History:"
    git log --oneline -20
}

# Main loop
run_loop() {
    local iteration=0
    local stuck_count=0
    local started_at
    started_at=$(date -Iseconds)

    info "Starting Ralph Loop..."
    echo ""

    while [[ $iteration -lt $MAX_ITERATIONS ]]; do
        iteration=$((iteration + 1))

        echo ""
        echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
        printf "${CYAN}│  ITERATION %-3s / %-3s                                          │${NC}\n" "$iteration" "$MAX_ITERATIONS"
        echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
        echo ""

        show_progress

        # Check if all tasks are already complete
        if check_all_tasks_complete; then
            show_completion "$((iteration - 1))" "$started_at"
            exit 0
        fi

        # Capture state before running Claude
        local commit_before file_state_before
        commit_before=$(git rev-parse HEAD 2>/dev/null || echo "none")
        file_state_before=$(get_file_state)

        # Build and run
        local prompt output_file
        prompt=$(build_prompt "$iteration")
        output_file="$OUTPUT_DIR/output-$iteration.txt"

        local claude_exit=0
        run_claude_iteration "$iteration" "$prompt" || claude_exit=$?

        echo ""

        # Verification step (unless disabled)
        if [[ "$NO_VERIFY" != true ]]; then
            verify_with_claude "$iteration" || true
        fi

        # Check for completion via promise
        if [[ -f "$output_file" ]] && grep -q "<promise>PROJECT COMPLETE</promise>" "$output_file"; then
            show_completion "$iteration" "$started_at"
            exit 0
        fi

        # Check for activity
        local has_activity=false

        if check_progress "$commit_before" "$file_state_before"; then
            has_activity=true
        fi

        if [[ "$(git rev-parse HEAD 2>/dev/null)" != "$commit_before" ]]; then
            has_activity=true
            success "Commit detected after verification"
        fi

        if [[ -s "$output_file" ]]; then
            has_activity=true
        fi

        # Update stuck counter
        if [[ "$has_activity" == true ]]; then
            stuck_count=0
        else
            stuck_count=$((stuck_count + 1))
            warn "No activity (stuck: $stuck_count/5)"
            echo -e "${YELLOW}  Output: $output_file${NC}"

            if [[ $claude_exit -eq 124 ]]; then
                echo -e "${RED}  (Timed out)${NC}"
            fi
        fi

        # Warn but don't exit on stuck
        if [[ $stuck_count -ge 5 ]]; then
            warn "5 iterations without activity - resetting counter"
            stuck_count=0
        fi

        echo ""
        info "Waiting 2 seconds..."
        sleep 2
    done

    echo ""
    warn "Max iterations ($MAX_ITERATIONS) reached."
    show_progress
    exit 1
}

# Generate PRD from goal description
generate_prd() {
    local goal="$1"
    local target_complexity="${RALPH_TARGET_COMPLEXITY:-}"
    local prompt_file="/tmp/ralph-init-prompt.md"
    local output_file="/tmp/ralph-init-output.txt"

    # Build complexity guidance
    local complexity_hint=""
    if [[ -n "$target_complexity" ]]; then
        complexity_hint="Target approximately $target_complexity tasks."
    else
        complexity_hint="Choose an appropriate number of tasks based on project scope (typically 10-50)."
    fi

    # Create the prompt
    cat > "$prompt_file" <<EOF
# Generate PRD for Ralph Engine

You are a technical product manager creating a PRD (Product Requirements Document) for an autonomous AI coding agent.

## Goal

$goal

## Requirements

$complexity_hint

Create a prd.json file with this EXACT structure:

\`\`\`json
{
  "name": "Project Name",
  "description": "Brief project description",
  "tasks": [
    {
      "id": "T-100",
      "name": "Task name",
      "description": "Detailed task description",
      "pass": false,
      "dependencies": [],
      "complexity": 1,
      "actions": ["Step 1", "Step 2"],
      "guarantees": ["What must be true when done"],
      "validation": "How to verify completion"
    }
  ],
  "ralph": {
    "currentTaskId": null,
    "history": [],
    "startedAt": null
  }
}
\`\`\`

## Task Design Rules

1. **IDs**: Use T-100, T-110, T-120... (increment by 10 for flexibility)
2. **Dependencies**: List task IDs that must complete first (e.g., ["T-100", "T-110"])
3. **Complexity**: Rate 1-5 (1=trivial, 3=medium, 5=complex)
4. **Order**: Start with setup/foundation, end with integration/polish
5. **Granularity**: Each task should be completable in one iteration (15-30 min)
6. **Validation**: Include concrete ways to verify completion

## Task Categories (in order)

1. **Setup** (T-100s): Project structure, dependencies, configuration
2. **Core** (T-200s): Main functionality, core features
3. **Features** (T-300s): Additional features, enhancements
4. **Integration** (T-400s): Connect components, API endpoints
5. **Polish** (T-500s): Error handling, edge cases, cleanup
6. **Testing** (T-600s): Tests, validation, documentation

## Output

Return ONLY the JSON object. No markdown code blocks, no explanation, just valid JSON.
Start with { and end with }
EOF

    # Call Claude
    info "Calling Claude to generate PRD..."

    local exit_code=0
    timeout 300 claude --print --dangerously-skip-permissions < "$prompt_file" > "$output_file" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        error "Timeout generating PRD"
        return 1
    fi

    # Extract JSON from output (handle potential wrapper text)
    local content
    content=$(cat "$output_file")

    # Try to extract JSON if it's wrapped in markdown or other text
    if [[ "$content" == *"{"* ]]; then
        # Find the first { and last }
        content=$(echo "$content" | sed -n '/^{/,/^}/p' | head -1)

        # If that didn't work, try a more aggressive extraction
        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | grep -Pzo '(?s)\{.*\}' | tr '\0' '\n' | head -1)
        fi

        # Still not valid? Try to find JSON between code blocks
        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | sed -n '/```json/,/```/p' | sed '1d;$d')
        fi

        # Last resort: just take everything between first { and last }
        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | tr '\n' ' ' | grep -oP '\{.*\}')
        fi
    fi

    # Output the content
    echo "$content"
}

# Export functions
export -f setup_colors info success warn error banner
export -f get_completed_tasks check_all_tasks_complete show_progress
export -f get_file_state build_prompt monitor_activity
export -f run_claude_iteration check_progress verify_with_claude
export -f show_completion run_loop generate_prd
