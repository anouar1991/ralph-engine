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

# ==========================================
# Pre-Iteration Task Optimizer
# ==========================================

# Discover available agents by scanning Claude plugin directories
discover_agents_catalog() {
    local catalog=""
    local claude_dir="${HOME}/.claude"

    # Scan for agent definition files in plugin directories
    if [[ -d "$claude_dir" ]]; then
        while IFS= read -r agent_file; do
            local name="" description="" in_frontmatter=false
            while IFS= read -r line; do
                if [[ "$line" == "---" ]]; then
                    if [[ "$in_frontmatter" == true ]]; then
                        break
                    fi
                    in_frontmatter=true
                    continue
                fi
                if [[ "$in_frontmatter" == true ]]; then
                    if [[ "$line" =~ ^name:\ *(.*) ]]; then
                        name="${BASH_REMATCH[1]}"
                        # Strip quotes
                        name="${name%\"}"
                        name="${name#\"}"
                        name="${name%\'}"
                        name="${name#\'}"
                    elif [[ "$line" =~ ^description:\ *(.*) ]]; then
                        description="${BASH_REMATCH[1]}"
                        description="${description%\"}"
                        description="${description#\"}"
                        description="${description%\'}"
                        description="${description#\'}"
                    fi
                fi
            done < "$agent_file"
            if [[ -n "$name" ]] && [[ -n "$description" ]]; then
                # Truncate description to first sentence for brevity
                local short_desc="${description%%.*}."
                if [[ ${#short_desc} -gt 120 ]]; then
                    short_desc="${short_desc:0:117}..."
                fi
                catalog+="${name}: ${short_desc}"$'\n'
            fi
        done < <(find "$claude_dir" -path "*/agents/*.md" -type f 2>/dev/null | sort)
    fi

    # Fallback to static catalog if discovery found nothing
    if [[ -z "$catalog" ]]; then
        cat "${RALPH_ROOT}/config/agents-catalog.md" 2>/dev/null || echo "(none)"
    else
        echo "$catalog"
    fi
}

# Discover available skills by scanning Claude plugin directories
discover_skills_catalog() {
    local catalog=""
    local claude_dir="${HOME}/.claude"

    # Scan for skill definition files in plugin directories
    if [[ -d "$claude_dir" ]]; then
        while IFS= read -r skill_file; do
            local name="" description="" in_frontmatter=false
            while IFS= read -r line; do
                if [[ "$line" == "---" ]]; then
                    if [[ "$in_frontmatter" == true ]]; then
                        break
                    fi
                    in_frontmatter=true
                    continue
                fi
                if [[ "$in_frontmatter" == true ]]; then
                    if [[ "$line" =~ ^name:\ *(.*) ]]; then
                        name="${BASH_REMATCH[1]}"
                        name="${name%\"}"
                        name="${name#\"}"
                        name="${name%\'}"
                        name="${name#\'}"
                    elif [[ "$line" =~ ^description:\ *(.*) ]]; then
                        description="${BASH_REMATCH[1]}"
                        description="${description%\"}"
                        description="${description#\"}"
                        description="${description%\'}"
                        description="${description#\'}"
                    fi
                fi
            done < "$skill_file"
            if [[ -n "$name" ]] && [[ -n "$description" ]]; then
                local short_desc="${description%%.*}."
                if [[ ${#short_desc} -gt 120 ]]; then
                    short_desc="${short_desc:0:117}..."
                fi
                catalog+="${name}: ${short_desc}"$'\n'
            fi
        done < <(find "$claude_dir" -path "*/skills/*.md" -type f -o -path "*/commands/*.md" -type f 2>/dev/null | sort)
    fi

    # Fallback to static catalog if discovery found nothing
    if [[ -z "$catalog" ]]; then
        cat "${RALPH_ROOT}/config/skills-catalog.md" 2>/dev/null || echo "(none)"
    else
        echo "$catalog"
    fi
}

# Generate a task briefing using a fast haiku pre-call
generate_task_briefing() {
    local task_json="$1"
    local active_prd="$2"

    # Skip if disabled
    if [[ "${RALPH_NO_OPTIMIZER:-false}" == "true" ]]; then
        echo ""
        return 0
    fi

    # Get project context
    local project_name
    project_name=$(jq -r '.name // "Unknown"' "$active_prd" 2>/dev/null)

    local project_context
    project_context="Project: $project_name"$'\n'"Directory: $PROJECT_DIR"
    local dir_listing
    dir_listing=$(find "$PROJECT_DIR" -maxdepth 2 -type d -not -path '*/\.*' -not -path '*/node_modules/*' -not -path '*/target/*' 2>/dev/null | head -10)
    if [[ -n "$dir_listing" ]]; then
        project_context+=$'\n'"$dir_listing"
    fi

    # Discover catalogs at runtime
    local agents_catalog skills_catalog
    agents_catalog=$(discover_agents_catalog)
    skills_catalog=$(discover_skills_catalog)

    # Build optimizer prompt
    local optimizer_prompt
    optimizer_prompt=$(load_prompt "optimizer" \
        "TASK_JSON=$task_json" \
        "AVAILABLE_AGENTS=$agents_catalog" \
        "AVAILABLE_SKILLS=$skills_catalog" \
        "PROJECT_CONTEXT=$project_context")

    if [[ -z "$optimizer_prompt" ]]; then
        warn "Optimizer: failed to load prompt template"
        echo ""
        return 0
    fi

    # Fast haiku call (no tools, short timeout)
    local briefing
    briefing=$(echo "$optimizer_prompt" | timeout 30 claude --print --model haiku 2>/dev/null || echo "")

    if [[ -n "$briefing" ]]; then
        info "Task briefing generated"
        echo "$briefing"
    else
        warn "Optimizer: no briefing generated (continuing without)"
        echo ""
    fi
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
    local active_prd="${1:-$PRD_FILE}"
    local completed_list completed total pct

    # Count from PRD file (source of truth), not git history
    total=$(jq '.tasks | length' "$active_prd" 2>/dev/null || echo 0)
    completed=$(jq '[.tasks[] | select(.pass == true)] | length' "$active_prd" 2>/dev/null || echo 0)
    completed_list=$(jq -r '[.tasks[] | select(.pass == true) | .id] | join(" ")' "$active_prd" 2>/dev/null || echo "")
    pct=0

    if [[ "$total" -gt 0 ]] && [[ "$completed" -gt 0 ]]; then
        pct=$((completed * 100 / total))
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Progress: $completed/$total tasks ($pct%)${NC}"

    if [[ -n "$completed_list" ]]; then
        echo -e "${BLUE}Completed:${NC} $completed_list"
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

# Build sudo instructions if enabled
build_sudo_instructions() {
    local var_name="${SUDO_PASS_VAR:-}"

    if [[ -z "$var_name" ]]; then
        echo ""
        return
    fi

    cat <<EOF

## Sudo Password Configuration

When commands require sudo/root privileges, pipe the password from the environment:

\`\`\`bash
# Pattern for sudo commands:
echo "\$${var_name}" | sudo -S <command>

# Examples:
echo "\$${var_name}" | sudo -S apt-get install -y package-name
echo "\$${var_name}" | sudo -S systemctl restart service-name
echo "\$${var_name}" | sudo -S chmod 755 /path/to/file
\`\`\`

**Important:**
- The password is available in the \`${var_name}\` environment variable
- Always use \`sudo -S\` to read password from stdin
- Never echo or log the password value directly
- This enables fully automated execution of privileged commands

EOF
}

# Build prompt for Claude
build_prompt() {
    local iteration="$1"
    local active_prd="${2:-$PRD_FILE}"
    local task_briefing="${3:-}"

    local completed_tasks
    completed_tasks=$(jq -r '[.tasks[] | select(.pass == true) | .id] | join(",")' "$active_prd" 2>/dev/null || echo "")

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

    local sudo_instructions
    sudo_instructions=$(build_sudo_instructions)

    # Build sub-PRD context if working on a sub-PRD
    local sub_prd_context=""
    local parent_task_id
    parent_task_id=$(jq -r '.parentTaskId // empty' "$active_prd" 2>/dev/null)

    if [[ -n "$parent_task_id" ]]; then
        local parent_name parent_guarantees stack_depth
        parent_name=$(jq -r '.name // "Sub-PRD"' "$active_prd")
        parent_guarantees=$(jq -c '.parentGuarantees // []' "$active_prd")
        stack_depth=$(get_stack_depth)

        sub_prd_context="
## Sub-PRD Context

**You are working on a Sub-PRD** (Stack depth: $stack_depth)

- **Parent Task:** $parent_task_id
- **Sub-PRD:** $(basename "$active_prd")
- **Parent Guarantees to Satisfy:** $parent_guarantees

When this sub-PRD is complete (all tasks pass), the parent task $parent_task_id will automatically be marked complete.

**Important:** Focus on the tasks in this sub-PRD. Read $(basename "$active_prd") instead of prd.json.
"
    fi

    # Use external template
    load_prompt "iteration" \
        "ITERATION=$iteration" \
        "GIT_LOG=$git_log" \
        "COMPLETED_TASKS=$completed_tasks" \
        "AGENTS_FILES=$agents_files" \
        "DIR_STRUCTURE=$dir_structure" \
        "SUDO_INSTRUCTIONS=$sudo_instructions" \
        "SUB_PRD_CONTEXT=$sub_prd_context" \
        "OPTIMIZER_RECOMMENDATIONS=$task_briefing"
}

# Activity monitor with debouncing timeout (background process)
# Writes to a sentinel file when activity is detected so the watchdog can reset
monitor_activity() {
    local sentinel="$OUTPUT_DIR/.activity_sentinel"
    local output_file="${1:-}"
    local start_time last_file_state current_time elapsed current_file_state
    local last_output_size=0
    local last_activity_time
    start_time=$(date +%s)
    last_activity_time=$start_time
    last_file_state=$(get_file_state)

    while true; do
        sleep 10
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        local idle=$((current_time - last_activity_time))
        current_file_state=$(get_file_state)
        local activity=false

        # Check for project file changes
        if [[ "$current_file_state" != "$last_file_state" ]]; then
            echo -e "${MAGENTA}  [${elapsed}s] Activity: $current_file_state${NC}"
            last_file_state="$current_file_state"
            activity=true
        fi

        # Check for output file growth (Claude is producing response)
        if [[ -n "$output_file" ]] && [[ -f "$output_file" ]]; then
            local current_output_size
            current_output_size=$(wc -c < "$output_file" 2>/dev/null || echo 0)
            if [[ "$current_output_size" -gt "$last_output_size" ]]; then
                if [[ "$activity" == false ]]; then
                    echo -e "${MAGENTA}  [${elapsed}s] Claude writing output...${NC}"
                fi
                last_output_size=$current_output_size
                activity=true
            fi
        fi

        if [[ "$activity" == true ]]; then
            last_activity_time=$current_time
            date +%s > "$sentinel"
        else
            echo -e "${BLUE}  [${elapsed}s idle=${idle}s/${ITERATION_TIMEOUT}s] Waiting...${NC}"
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

    info "Invoking Claude Code (timeout: ${ITERATION_TIMEOUT}s, resets on activity)..."
    echo -e "${BLUE}Output: $output_file${NC}"
    echo ""

    # Sentinel file for activity-based timeout reset
    local sentinel="$OUTPUT_DIR/.activity_sentinel"
    rm -f "$sentinel"
    date +%s > "$sentinel"

    # Run Claude in a new process group so we can kill the entire tree
    local claude_pid
    setsid bash -c '
        claude --print --dangerously-skip-permissions '"${CLAUDE_EXTRA_ARGS:-}"' < "$1" 2>&1
    ' -- "$prompt_file" > "$output_file" &
    claude_pid=$!

    # Debouncing watchdog: kill Claude only after ITERATION_TIMEOUT seconds of inactivity
    local exit_code=0
    local timed_out=false
    while kill -0 "$claude_pid" 2>/dev/null; do
        sleep 5
        local now last_activity idle
        now=$(date +%s)
        last_activity=$(cat "$sentinel" 2>/dev/null || echo "$now")
        idle=$((now - last_activity))

        if [[ $idle -ge $ITERATION_TIMEOUT ]]; then
            timed_out=true
            warn "TIMEOUT: idle ${idle}s >= ${ITERATION_TIMEOUT}s, killing process group..."
            # Kill entire process group (setsid made claude_pid the group leader)
            kill -- -"$claude_pid" 2>/dev/null || true
            sleep 2
            kill -9 -- -"$claude_pid" 2>/dev/null || true
            break
        fi
    done

    wait "$claude_pid" 2>/dev/null || exit_code=$?

    # Kill monitor
    kill $monitor_pid 2>/dev/null || true
    rm -f "$sentinel"

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
    if [[ "$timed_out" == true ]]; then
        echo ""
        warn "TIMEOUT: Claude idle for ${ITERATION_TIMEOUT}s (no file activity)"
        exit_code=124
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
    timeout 60 claude --print --dangerously-skip-permissions ${CLAUDE_EXTRA_ARGS:-} < "$verify_prompt_file" > "$verify_output_file" 2>&1 || true

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

# ==========================================
# Sub-PRD Stack Management Functions
# ==========================================

# Configuration for expansion
EXPANSION_THRESHOLD="${RALPH_EXPANSION_THRESHOLD:-4}"
MAX_STACK_DEPTH="${RALPH_MAX_STACK_DEPTH:-3}"
NO_EXPAND="${RALPH_NO_EXPAND:-false}"

# Get the main PRD file path (the original prd.json)
get_main_prd_file() {
    echo "${MAIN_PRD_FILE:-$PRD_FILE}"
}

# Get the currently active PRD file (may be a sub-PRD)
get_active_prd_file() {
    local main_prd
    main_prd=$(get_main_prd_file)

    # Check if there's an active sub-PRD
    local active_sub
    active_sub=$(jq -r '.ralph.activeSubPrdFile // empty' "$main_prd" 2>/dev/null)

    if [[ -n "$active_sub" ]] && [[ -f "$(dirname "$main_prd")/$active_sub" ]]; then
        echo "$(dirname "$main_prd")/$active_sub"
    else
        echo "$main_prd"
    fi
}

# Check if a task should be expanded into a sub-PRD
# Returns 0 (true) if expansion needed, 1 (false) otherwise
should_expand_task() {
    local task_json="$1"

    # Skip if expansion is disabled
    if [[ "$NO_EXPAND" == true ]]; then
        return 1
    fi

    # Check explicit expand flag
    local expand_flag
    expand_flag=$(echo "$task_json" | jq -r '.expand // false')
    if [[ "$expand_flag" == "true" ]]; then
        return 0
    fi

    # Check complexity threshold and action count
    local complexity action_count
    complexity=$(echo "$task_json" | jq -r '.complexity // 1')
    action_count=$(echo "$task_json" | jq -r '.actions | length // 0')

    if [[ "$complexity" -ge "$EXPANSION_THRESHOLD" ]] && [[ "$action_count" -ge 5 ]]; then
        return 0
    fi

    return 1
}

# Get current stack depth
get_stack_depth() {
    local main_prd
    main_prd=$(get_main_prd_file)
    jq '.ralph.prdStack | length // 0' "$main_prd" 2>/dev/null || echo 0
}

# Push current PRD state onto stack and switch to sub-PRD
push_prd_stack() {
    local current_prd="$1"
    local task_id="$2"
    local iteration="${3:-0}"

    local main_prd
    main_prd=$(get_main_prd_file)

    # Check stack depth limit
    local depth
    depth=$(get_stack_depth)
    if [[ "$depth" -ge "$MAX_STACK_DEPTH" ]]; then
        warn "Max stack depth ($MAX_STACK_DEPTH) reached, not expanding task $task_id"
        return 1
    fi

    local prd_basename
    prd_basename=$(basename "$current_prd")
    local sub_prd_file="prd-${task_id}.json"
    local timestamp
    timestamp=$(date -Iseconds)

    info "Pushing PRD stack: $prd_basename -> $sub_prd_file for task $task_id"

    # Build stack entry
    local stack_entry
    stack_entry=$(jq -n \
        --arg prdFile "$prd_basename" \
        --arg taskId "$task_id" \
        --argjson iteration "$iteration" \
        --arg timestamp "$timestamp" \
        '{
            prdFile: $prdFile,
            expandingTaskId: $taskId,
            iterationAtSuspend: $iteration,
            suspendedAt: $timestamp
        }')

    # Update main PRD with stack entry and active sub-PRD
    local tmp_file
    tmp_file=$(mktemp)
    jq --argjson entry "$stack_entry" \
       --arg subPrd "$sub_prd_file" \
       '.ralph.prdStack = ((.ralph.prdStack // []) + [$entry]) |
        .ralph.activeSubPrdFile = $subPrd' \
        "$main_prd" > "$tmp_file" && mv "$tmp_file" "$main_prd"

    # Mark the parent task as "expanding" (in progress but delegated)
    if [[ "$current_prd" != "$main_prd" ]]; then
        # We're in a nested sub-PRD, update that too
        jq --arg taskId "$task_id" \
           '.tasks = [.tasks[] | if .id == $taskId then .expanding = true else . end]' \
           "$current_prd" > "$tmp_file" && mv "$tmp_file" "$current_prd"
    else
        jq --arg taskId "$task_id" \
           '.tasks = [.tasks[] | if .id == $taskId then .expanding = true else . end]' \
           "$main_prd" > "$tmp_file" && mv "$tmp_file" "$main_prd"
    fi

    success "Stack pushed, ready to generate sub-PRD: $sub_prd_file"
    return 0
}

# Pop PRD stack and return to parent PRD
pop_prd_stack() {
    local completed_sub_prd="$1"
    local parent_task_id="$2"

    local main_prd
    main_prd=$(get_main_prd_file)

    local depth
    depth=$(get_stack_depth)
    if [[ "$depth" -eq 0 ]]; then
        warn "Cannot pop: PRD stack is empty"
        return 1
    fi

    info "Popping PRD stack: completing task $parent_task_id"

    # Get the stack entry we're popping
    local stack_entry
    stack_entry=$(jq '.ralph.prdStack[-1]' "$main_prd")
    local parent_prd_file
    parent_prd_file=$(echo "$stack_entry" | jq -r '.prdFile')

    # Pop the stack and determine new active PRD
    local new_depth=$((depth - 1))
    local new_active_sub=""

    if [[ "$new_depth" -gt 0 ]]; then
        # There's still a parent sub-PRD, find it
        new_active_sub=$(jq -r '.ralph.prdStack[-2].prdFile // empty' "$main_prd" 2>/dev/null)
        # If the parent is the main PRD, don't set activeSubPrdFile
        if [[ "$new_active_sub" == "$(basename "$main_prd")" ]]; then
            new_active_sub=""
        fi
    fi

    # Update main PRD: pop stack and update active sub-PRD
    local tmp_file
    tmp_file=$(mktemp)
    jq --arg newActive "$new_active_sub" \
       '.ralph.prdStack = .ralph.prdStack[:-1] |
        if $newActive == "" then del(.ralph.activeSubPrdFile) else .ralph.activeSubPrdFile = $newActive end' \
        "$main_prd" > "$tmp_file" && mv "$tmp_file" "$main_prd"

    # Mark the parent task as complete in its PRD
    local parent_prd_path
    if [[ -z "$new_active_sub" ]]; then
        parent_prd_path="$main_prd"
    else
        parent_prd_path="$(dirname "$main_prd")/$new_active_sub"
    fi

    # If parent_prd_file is not the main PRD and not the new active, use it
    if [[ "$parent_prd_file" != "$(basename "$main_prd")" ]] && [[ -f "$(dirname "$main_prd")/$parent_prd_file" ]]; then
        parent_prd_path="$(dirname "$main_prd")/$parent_prd_file"
    fi

    # Mark parent task as complete
    jq --arg taskId "$parent_task_id" \
       '.tasks = [.tasks[] | if .id == $taskId then .pass = true | del(.expanding) | .subPrdCompleted = true else . end] |
        .ralph.history = ((.ralph.history // []) + [$taskId])' \
        "$parent_prd_path" > "$tmp_file" && mv "$tmp_file" "$parent_prd_path"

    # Optionally archive the completed sub-PRD (keep it for reference)
    local sub_prd_path
    sub_prd_path=$(dirname "$main_prd")/prd-${parent_task_id}.json
    if [[ -f "$sub_prd_path" ]]; then
        jq '.completed = true | .completedAt = now | .completedAt |= todate' "$sub_prd_path" > "$tmp_file" && mv "$tmp_file" "$sub_prd_path"
    fi

    success "Stack popped, task $parent_task_id marked complete"
    return 0
}

# Generate a sub-PRD for a task that needs expansion
generate_sub_prd() {
    local task_json="$1"
    local parent_prd="$2"

    local task_id task_name expand_goal
    task_id=$(echo "$task_json" | jq -r '.id')
    task_name=$(echo "$task_json" | jq -r '.name')
    expand_goal=$(echo "$task_json" | jq -r '.expandGoal // .intent // .name')

    local guarantees requires
    guarantees=$(echo "$task_json" | jq -c '.guarantees // []')
    requires=$(echo "$task_json" | jq -c '.requires // []')

    local sub_prd_file="prd-${task_id}.json"
    local sub_prd_path="$(dirname "$parent_prd")/$sub_prd_file"
    local prompt_file="/tmp/ralph-subprd-prompt.md"
    local output_file="/tmp/ralph-subprd-output.txt"

    info "Generating sub-PRD for task $task_id: $task_name"

    # Use external template
    load_prompt "sub-prd-generation" \
        "PARENT_TASK_ID=$task_id" \
        "PARENT_TASK_NAME=$task_name" \
        "EXPAND_GOAL=$expand_goal" \
        "PARENT_GUARANTEES=$guarantees" \
        "PARENT_REQUIRES=$requires" \
        "PARENT_PRD_FILE=$(basename "$parent_prd")" > "$prompt_file"

    # Call Claude to generate sub-PRD
    local exit_code=0
    timeout 300 claude --print --tools "" ${CLAUDE_EXTRA_ARGS:-} < "$prompt_file" > "$output_file" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        error "Timeout generating sub-PRD for $task_id"
        return 1
    fi

    # Extract JSON from output
    local content
    content=$(cat "$output_file")

    # Try various extraction methods (same as generate_prd)
    if [[ "$content" == *"{"* ]]; then
        content=$(echo "$content" | sed -n '/^{/,/^}/p' | head -1)

        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | grep -Pzo '(?s)\{.*\}' | tr '\0' '\n' | head -1)
        fi

        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | sed -n '/```json/,/```/p' | sed '1d;$d')
        fi

        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | tr '\n' ' ' | grep -oP '\{.*\}')
        fi
    fi

    # Validate JSON
    if ! echo "$content" | jq empty 2>/dev/null; then
        error "Generated sub-PRD is not valid JSON"
        echo "Raw output:"
        cat "$output_file" | head -50
        return 1
    fi

    # Write sub-PRD
    echo "$content" | jq . > "$sub_prd_path"

    local sub_task_count
    sub_task_count=$(echo "$content" | jq '.tasks | length')

    success "Sub-PRD generated: $sub_prd_file with $sub_task_count tasks"
    return 0
}

# Check if all tasks are complete in a specific PRD file
check_prd_complete() {
    local prd_file="$1"

    local total completed
    total=$(jq '.tasks | length' "$prd_file" 2>/dev/null || echo 0)
    completed=$(jq '[.tasks[] | select(.pass == true)] | length' "$prd_file" 2>/dev/null || echo 0)

    [[ "$total" -gt 0 ]] && [[ "$total" -eq "$completed" ]]
}

# Get next available task from a PRD (respects dependencies)
get_next_task() {
    local prd_file="$1"

    jq -c '
        .tasks as $all |
        [.tasks[] | select(.pass != true and .expanding != true)] |
        map(select(
            .dependencies as $deps |
            ($deps == null or $deps == [] or
             ([$deps[] | . as $d | $all[] | select(.id == $d and .pass == true)] | length) == ($deps | length))
        )) |
        sort_by(.complexity // 5) |
        first // empty
    ' "$prd_file"
}

# Show current stack status
show_stack_status() {
    local main_prd
    main_prd=$(get_main_prd_file)

    local depth
    depth=$(get_stack_depth)

    echo ""
    echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│  PRD STACK STATUS                                              │${NC}"
    echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
    echo ""

    if [[ "$depth" -eq 0 ]]; then
        echo -e "${GREEN}Stack: Empty (working on main PRD)${NC}"
        echo "  Active PRD: $(basename "$main_prd")"
    else
        echo -e "${YELLOW}Stack Depth: $depth${NC}"
        echo ""

        # Show stack entries
        local i=0
        while [[ $i -lt $depth ]]; do
            local entry
            entry=$(jq ".ralph.prdStack[$i]" "$main_prd")
            local prd_file task_id suspended_at
            prd_file=$(echo "$entry" | jq -r '.prdFile')
            task_id=$(echo "$entry" | jq -r '.expandingTaskId')
            suspended_at=$(echo "$entry" | jq -r '.suspendedAt')

            local indent=""
            for ((j=0; j<i; j++)); do indent+="  "; done

            echo "${indent}📁 $prd_file"
            echo "${indent}   └─ Expanding: $task_id (suspended: $suspended_at)"

            i=$((i + 1))
        done

        # Show active sub-PRD
        local active_sub
        active_sub=$(jq -r '.ralph.activeSubPrdFile // empty' "$main_prd")
        if [[ -n "$active_sub" ]]; then
            local indent=""
            for ((j=0; j<depth; j++)); do indent+="  "; done
            echo "${indent}📄 $active_sub (ACTIVE)"
        fi
    fi

    echo ""
}

# Main loop
run_loop() {
    local iteration=0
    local stuck_count=0
    local started_at
    started_at=$(date -Iseconds)

    # Store main PRD file for stack operations
    export MAIN_PRD_FILE="$PRD_FILE"

    info "Starting Ralph Loop..."
    echo ""

    while [[ $iteration -lt $MAX_ITERATIONS ]]; do
        iteration=$((iteration + 1))

        # Get active PRD (may be sub-PRD)
        local active_prd
        active_prd=$(get_active_prd_file)
        local is_sub_prd=false
        if [[ "$active_prd" != "$MAIN_PRD_FILE" ]]; then
            is_sub_prd=true
        fi

        echo ""
        echo -e "${CYAN}╭────────────────────────────────────────────────────────────────╮${NC}"
        printf "${CYAN}│  ITERATION %-3s / %-3s                                          │${NC}\n" "$iteration" "$MAX_ITERATIONS"
        if [[ "$is_sub_prd" == true ]]; then
            local sub_prd_name
            sub_prd_name=$(basename "$active_prd")
            printf "${CYAN}│  ${YELLOW}SUB-PRD: %-53s${CYAN}│${NC}\n" "$sub_prd_name"
        fi
        echo -e "${CYAN}╰────────────────────────────────────────────────────────────────╯${NC}"
        echo ""

        # Show stack status if we're in a sub-PRD
        if [[ "$is_sub_prd" == true ]]; then
            local depth
            depth=$(get_stack_depth)
            echo -e "${YELLOW}  Stack depth: $depth${NC}"
        fi

        show_progress "$active_prd"

        # Check if active PRD is complete
        if check_prd_complete "$active_prd"; then
            if [[ "$is_sub_prd" == true ]]; then
                # Sub-PRD complete → pop stack and continue
                local parent_task_id
                parent_task_id=$(jq -r '.parentTaskId // empty' "$active_prd")
                if [[ -n "$parent_task_id" ]]; then
                    success "Sub-PRD complete! Returning to parent..."
                    pop_prd_stack "$active_prd" "$parent_task_id"
                    continue  # Re-check with parent PRD
                fi
            fi

            # Main PRD complete
            show_completion "$((iteration - 1))" "$started_at"
            exit 0
        fi

        # Get next task and check if it needs expansion
        local next_task
        next_task=$(get_next_task "$active_prd")

        if [[ -n "$next_task" ]] && [[ "$NO_EXPAND" != true ]]; then
            if should_expand_task "$next_task"; then
                local task_id
                task_id=$(echo "$next_task" | jq -r '.id')
                info "Task $task_id needs expansion, generating sub-PRD..."

                if push_prd_stack "$active_prd" "$task_id" "$iteration"; then
                    if generate_sub_prd "$next_task" "$active_prd"; then
                        success "Sub-PRD created, continuing with expansion..."
                        continue  # Start working on sub-PRD
                    else
                        error "Failed to generate sub-PRD, continuing with original task"
                        # Rollback stack push
                        local main_prd
                        main_prd=$(get_main_prd_file)
                        local tmp_file
                        tmp_file=$(mktemp)
                        jq '.ralph.prdStack = .ralph.prdStack[:-1] | del(.ralph.activeSubPrdFile)' "$main_prd" > "$tmp_file" && mv "$tmp_file" "$main_prd"
                        jq --arg taskId "$task_id" '.tasks = [.tasks[] | if .id == $taskId then del(.expanding) else . end]' "$active_prd" > "$tmp_file" && mv "$tmp_file" "$active_prd"
                    fi
                fi
            fi
        fi

        # Generate task briefing for this iteration (pre-flight optimizer)
        local task_briefing=""
        if [[ -n "$next_task" ]]; then
            local briefing_task_id
            briefing_task_id=$(echo "$next_task" | jq -r '.id')
            info "Generating task briefing for $briefing_task_id..."
            task_briefing=$(generate_task_briefing "$next_task" "$active_prd")
        fi

        # Capture state before running Claude
        local commit_before file_state_before
        commit_before=$(git rev-parse HEAD 2>/dev/null || echo "none")
        file_state_before=$(get_file_state)

        # Build and run (use active PRD for prompt)
        local prompt output_file
        prompt=$(build_prompt "$iteration" "$active_prd" "$task_briefing")
        output_file="$OUTPUT_DIR/output-$iteration.txt"

        local claude_exit=0
        run_claude_iteration "$iteration" "$prompt" || claude_exit=$?

        echo ""

        # Verification step (unless disabled)
        if [[ "$NO_VERIFY" != true ]]; then
            verify_with_claude "$iteration" || true
        fi

        # Check for expansion signal in output
        if [[ -f "$output_file" ]] && [[ "$NO_EXPAND" != true ]]; then
            if grep -q "<expansion-needed>" "$output_file"; then
                local expansion_task_id expansion_goal
                expansion_task_id=$(grep -oP '(?<=Task )[A-Z]+-\d+(?= requires expansion)' "$output_file" || true)
                expansion_goal=$(sed -n '/<expansion-needed>/,/<\/expansion-needed>/p' "$output_file" | grep -oP '(?<=Goal: ")[^"]*' || true)

                if [[ -n "$expansion_task_id" ]]; then
                    info "Claude signaled expansion needed for task $expansion_task_id"

                    # Get the task JSON
                    local task_json
                    task_json=$(jq -c --arg id "$expansion_task_id" '.tasks[] | select(.id == $id)' "$active_prd")

                    if [[ -n "$task_json" ]]; then
                        # Add expand goal if provided
                        if [[ -n "$expansion_goal" ]]; then
                            task_json=$(echo "$task_json" | jq --arg goal "$expansion_goal" '. + {expandGoal: $goal}')
                        fi

                        if push_prd_stack "$active_prd" "$expansion_task_id" "$iteration"; then
                            if generate_sub_prd "$task_json" "$active_prd"; then
                                success "Sub-PRD created from Claude signal, continuing..."
                                continue
                            fi
                        fi
                    fi
                fi
            fi
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
    show_progress "$active_prd"
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
        complexity_hint="Create as many tasks as needed to make each one atomic and achievable in a single focused iteration. Break down complex goals until every task is clear, testable, and completable without requiring further decomposition. Prefer more granular tasks over fewer complex ones."
    fi

    # Create the prompt using external template
    load_prompt "prd-generation" \
        "GOAL=$goal" \
        "COMPLEXITY_HINT=$complexity_hint" > "$prompt_file"

    # Call Claude with no tools (prevents file writes, forces JSON output)
    info "Calling Claude to generate PRD..." >&2

    local exit_code=0
    timeout 300 claude --print --tools "" ${CLAUDE_EXTRA_ARGS:-} < "$prompt_file" > "$output_file" 2>&1 || exit_code=$?

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

# ==========================================
# PRD Extension Functions
# ==========================================

# Generate extension tasks for a completed project
# Usage: extend_prd "new goal" "/path/to/prd.json"
extend_prd() {
    local new_goal="$1"
    local prd_file="$2"
    local prompt_file="/tmp/ralph-extend-prompt.md"
    local output_file="/tmp/ralph-extend-output.txt"

    # Validate PRD exists
    if [[ ! -f "$prd_file" ]]; then
        error "PRD file not found: $prd_file"
        return 1
    fi

    # Extract project context from existing PRD
    local project_name
    project_name=$(jq -r '.name // "Unnamed Project"' "$prd_file")

    # Get completed tasks summary (id, name, guarantees)
    local completed_tasks_summary
    completed_tasks_summary=$(jq -r '
        [.tasks[] | select(.pass == true)] |
        map("- **\(.id)**: \(.name)\n  Guarantees: \(.guarantees // [] | join(", "))") |
        join("\n\n")
    ' "$prd_file")

    if [[ -z "$completed_tasks_summary" ]] || [[ "$completed_tasks_summary" == "" ]]; then
        error "No completed tasks found. Use 'ralph' to execute existing tasks first."
        return 1
    fi

    # Get existing guarantees (flattened and unique)
    local existing_guarantees
    existing_guarantees=$(jq -r '
        [.tasks[] | select(.pass == true) | .guarantees // []] |
        flatten | unique |
        map("- \(.)") |
        join("\n")
    ' "$prd_file")

    # Calculate starting task ID (next hundred boundary)
    local max_id starting_id
    max_id=$(jq '
        [.tasks[].id | capture("T-(?<n>[0-9]+)").n | tonumber] | max // 0
    ' "$prd_file")
    starting_id=$(( ((max_id / 100) + 1) * 100 ))

    # Get project structure
    local project_structure
    project_structure=$(find "$(dirname "$prd_file")" -type f \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/target/*' \
        -not -path '*/__pycache__/*' \
        -not -name '*.pyc' \
        -not -name 'prd*.json' \
        2>/dev/null | head -30 | sort)

    # Get git history
    local git_history
    git_history=$(cd "$(dirname "$prd_file")" && git log --oneline -10 2>/dev/null || echo "No git history")

    # Create the prompt using external template
    load_prompt "extend-prd" \
        "NEW_GOAL=$new_goal" \
        "PROJECT_NAME=$project_name" \
        "COMPLETED_TASKS_SUMMARY=$completed_tasks_summary" \
        "EXISTING_GUARANTEES=$existing_guarantees" \
        "STARTING_ID=T-$starting_id" \
        "PROJECT_STRUCTURE=$project_structure" \
        "GIT_HISTORY=$git_history" > "$prompt_file"

    # Call Claude with no tools (forces JSON output)
    info "Calling Claude to generate extension tasks..." >&2

    local exit_code=0
    timeout 300 claude --print --tools "" ${CLAUDE_EXTRA_ARGS:-} < "$prompt_file" > "$output_file" 2>&1 || exit_code=$?

    if [[ $exit_code -eq 124 ]]; then
        error "Timeout generating extension tasks"
        return 1
    fi

    # Extract JSON from output (same extraction logic as generate_prd)
    local content
    content=$(cat "$output_file")

    if [[ "$content" == *"{"* ]]; then
        content=$(echo "$content" | sed -n '/^{/,/^}/p' | head -1)

        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | grep -Pzo '(?s)\{.*\}' | tr '\0' '\n' | head -1)
        fi

        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | sed -n '/```json/,/```/p' | sed '1d;$d')
        fi

        if [[ -z "$content" ]] || ! echo "$content" | jq empty 2>/dev/null; then
            content=$(cat "$output_file" | tr '\n' ' ' | grep -oP '\{.*\}')
        fi
    fi

    # Output the content
    echo "$content"
}

# Merge extension tasks into existing PRD
# Usage: merge_extension "/path/to/prd.json" "extension_json_string"
merge_extension() {
    local prd_file="$1"
    local extension_json="$2"

    # Validate extension JSON
    if ! echo "$extension_json" | jq empty 2>/dev/null; then
        error "Invalid extension JSON"
        return 1
    fi

    # Extract new tasks array
    local new_tasks
    new_tasks=$(echo "$extension_json" | jq '.tasks')

    if [[ -z "$new_tasks" ]] || [[ "$new_tasks" == "null" ]]; then
        error "No tasks found in extension JSON"
        return 1
    fi

    local new_task_count
    new_task_count=$(echo "$new_tasks" | jq 'length')

    # Get the first new task ID for recommendedNextStepId
    local first_new_id
    first_new_id=$(echo "$new_tasks" | jq -r '.[0].id // empty')

    # Merge: append new tasks and update ralph metadata
    local tmp_file
    tmp_file=$(mktemp)

    jq --argjson new "$new_tasks" \
       --arg nextId "$first_new_id" '
        .tasks = .tasks + $new |
        .ralph.recommendedNextStepId = $nextId |
        .ralph.extendedAt = (now | todate)
    ' "$prd_file" > "$tmp_file" && mv "$tmp_file" "$prd_file"

    echo "$new_task_count"
}

# Export functions
export -f setup_colors info success warn error banner
export -f load_prompt get_prompts_dir
export -f get_completed_tasks check_all_tasks_complete show_progress
export -f get_file_state build_sudo_instructions build_prompt monitor_activity
export -f run_claude_iteration check_progress verify_with_claude
export -f show_completion run_loop generate_prd
export -f extend_prd merge_extension

# Sub-PRD stack management exports
export -f get_main_prd_file get_active_prd_file should_expand_task
export -f get_stack_depth push_prd_stack pop_prd_stack
export -f generate_sub_prd check_prd_complete get_next_task show_stack_status

# Optimizer exports
export -f discover_agents_catalog discover_skills_catalog generate_task_briefing
