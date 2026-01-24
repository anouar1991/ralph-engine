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

# Load prompt template from file
# Usage: load_prompt "prompt-name" [VAR1=value1] [VAR2=value2] ...
load_prompt() {
    local prompt_name="$1"
    shift

    # Determine prompts directory
    local prompts_dir="${RALPH_PROMPTS_DIR:-${RALPH_ROOT}/prompts}"
    local prompt_file="$prompts_dir/${prompt_name}.md"

    # Check if prompt file exists
    if [[ ! -f "$prompt_file" ]]; then
        error "Prompt file not found: $prompt_file"
        return 1
    fi

    # Read the template
    local content
    content=$(cat "$prompt_file")

    # Substitute variables passed as arguments (VAR=value format)
    # Use bash parameter expansion instead of sed to handle special chars
    for arg in "$@"; do
        local var_name="${arg%%=*}"
        local var_value="${arg#*=}"
        # Use bash string replacement (handles special chars safely)
        content="${content//\{\{${var_name}\}\}/${var_value}}"
    done

    echo "$content"
}

# Get custom prompts directory (user can override)
get_prompts_dir() {
    echo "${RALPH_PROMPTS_DIR:-${RALPH_ROOT}/prompts}"
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
    [[ -z "$agents_files" ]] && agents_files="(none yet)"

    local dir_structure
    dir_structure=$(find . -type d \
        -not -path '*/\.*' \
        -not -path './node_modules/*' \
        -not -path './target/*' 2>/dev/null | head -20)

    # Use external template
    load_prompt "iteration" \
        "ITERATION=$iteration" \
        "GIT_LOG=$git_log" \
        "COMPLETED_TASKS=$completed_tasks" \
        "AGENTS_FILES=$agents_files" \
        "DIR_STRUCTURE=$dir_structure"
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

    # Use external template
    load_prompt "verification" \
        "GIT_STATUS=$git_status" \
        "LAST_COMMIT=$last_commit" \
        "RALPH_SECTION=$ralph_section" > "$verify_prompt_file"

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

    # Create the prompt using external template
    load_prompt "prd-generation" \
        "GOAL=$goal" \
        "COMPLEXITY_HINT=$complexity_hint" > "$prompt_file"

    # Call Claude with no tools (prevents file writes, forces JSON output)
    info "Calling Claude to generate PRD..." >&2

    local exit_code=0
    timeout 300 claude --print --tools "" < "$prompt_file" > "$output_file" 2>&1 || exit_code=$?

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
export -f load_prompt get_prompts_dir
export -f get_completed_tasks check_all_tasks_complete show_progress
export -f get_file_state build_prompt monitor_activity
export -f run_claude_iteration check_progress verify_with_claude
export -f show_completion run_loop generate_prd
