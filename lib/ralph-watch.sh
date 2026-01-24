#!/usr/bin/env bash
#
# ralph-watch.sh - Real-time task visualization for Ralph Engine
#
# Provides a beautiful terminal UI showing task progress in real-time
#

# Terminal control sequences
CLEAR_SCREEN="\033[2J"
MOVE_HOME="\033[H"
HIDE_CURSOR="\033[?25l"
SHOW_CURSOR="\033[?25h"
SAVE_CURSOR="\033[s"
RESTORE_CURSOR="\033[u"
CLEAR_LINE="\033[K"
CLEAR_TO_END="\033[J"

# Box drawing characters (Unicode)
BOX_TL="╭"
BOX_TR="╮"
BOX_BL="╰"
BOX_BR="╯"
BOX_H="─"
BOX_V="│"
BOX_LT="├"
BOX_RT="┤"

# Progress bar characters
PROG_FULL="█"
PROG_PARTIAL="▓"
PROG_EMPTY="░"

# Task status icons
ICON_DONE="✓"
ICON_WORKING="◉"
ICON_PENDING="○"
ICON_BLOCKED="◌"
ICON_EXPANDING="↳"

# Get terminal dimensions
get_term_size() {
    TERM_COLS=$(tput cols 2>/dev/null || echo 80)
    TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
}

# Draw a horizontal line
draw_hline() {
    local width="${1:-$TERM_COLS}"
    local char="${2:-$BOX_H}"
    printf "%${width}s" | tr ' ' "$char"
}

# Draw a box around text
draw_box() {
    local title="$1"
    local width="${2:-60}"
    local inner=$((width - 2))

    # Top border with title
    local title_len=${#title}
    local padding_left=$(( (inner - title_len - 2) / 2 ))
    local padding_right=$(( inner - title_len - 2 - padding_left ))

    echo -n "$BOX_TL"
    draw_hline $padding_left
    echo -n " $title "
    draw_hline $padding_right
    echo "$BOX_TR"
}

# Close a box
close_box() {
    local width="${1:-60}"
    echo -n "$BOX_BL"
    draw_hline $((width - 2))
    echo "$BOX_BR"
}

# Draw progress bar
draw_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    local pct=0

    if [[ "$total" -gt 0 ]]; then
        pct=$((current * 100 / total))
    fi

    local filled=$((current * width / total))
    [[ "$total" -eq 0 ]] && filled=0
    local empty=$((width - filled))

    echo -n "["
    printf "%${filled}s" | tr ' ' "$PROG_FULL"
    printf "%${empty}s" | tr ' ' "$PROG_EMPTY"
    echo -n "] ${pct}%"
}

# Format timestamp
format_time() {
    local seconds="$1"
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))

    if [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" $hours $minutes $secs
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# Get task status info from PRD
get_task_status() {
    local prd_file="$1"

    if [[ ! -f "$prd_file" ]]; then
        echo "ERROR: PRD file not found"
        return 1
    fi

    jq -r '
        .tasks as $all |
        {
            total: (.tasks | length),
            completed: [.tasks[] | select(.pass == true)] | length,
            expanding: [.tasks[] | select(.expanding == true)] | length,
            in_progress: (.ralph.currentTaskId // "none"),
            goal: (.name // "Project"),
            tasks: [
                .tasks[] | {
                    id: .id,
                    name: (.name | if length > 40 then .[:37] + "..." else . end),
                    pass: .pass,
                    expanding: (.expanding // false),
                    complexity: (.complexity // 1),
                    dependencies: (.dependencies // []),
                    blocked: (
                        if .dependencies then
                            (.dependencies | length) > (
                                [.dependencies[] | . as $d | $all[] | select(.id == $d and .pass == true)] | length
                            )
                        else false end
                    )
                }
            ]
        }
    ' "$prd_file" 2>/dev/null
}

# Build dependency flow visualization
build_dependency_flow() {
    local status_json="$1"
    local max_width="${2:-35}"

    # Flow drawing characters
    local FLOW_DOWN="│"
    local FLOW_RIGHT="──▶"
    local FLOW_BRANCH="├"
    local FLOW_END="└"
    local FLOW_START="◆"

    local flow_output=""

    # Get goal name
    local goal
    goal=$(echo "$status_json" | jq -r '.goal // "Goal"')
    goal="${goal:0:$((max_width - 4))}"

    # Start with goal
    flow_output+="${MAGENTA}${FLOW_START} ${BOLD}${goal}${NC}\n"
    flow_output+="${MAGENTA}${FLOW_DOWN}${NC}\n"

    # Get tasks organized by dependency level
    # Level 0: no dependencies, Level 1: depends on level 0, etc.

    # First, get all tasks with no dependencies (roots)
    local roots
    roots=$(echo "$status_json" | jq -r '.tasks[] | select(.dependencies | length == 0) | .id' | sort)

    # Build the tree for each root
    local root_count=0
    local total_roots
    total_roots=$(echo "$roots" | grep -c . || echo 0)

    while IFS= read -r root_id; do
        [[ -z "$root_id" ]] && continue
        ((root_count++))

        local is_last_root=false
        [[ "$root_count" -eq "$total_roots" ]] && is_last_root=true

        # Get root task info
        local root_info
        root_info=$(echo "$status_json" | jq -r --arg id "$root_id" '.tasks[] | select(.id == $id) | "\(.pass)|\(.blocked)|\(.id)"')

        IFS='|' read -r pass blocked id <<< "$root_info"

        # Determine icon and color
        local icon color
        if [[ "$pass" == "true" ]]; then
            icon="$ICON_DONE"
            color="${GREEN}"
        elif [[ "$blocked" == "true" ]]; then
            icon="$ICON_BLOCKED"
            color="${BLUE}"
        else
            icon="$ICON_PENDING"
            color="${YELLOW}"
        fi

        # Draw root task
        local prefix
        if [[ "$is_last_root" == true ]]; then
            prefix="${FLOW_END}${FLOW_RIGHT}"
        else
            prefix="${FLOW_BRANCH}${FLOW_RIGHT}"
        fi

        flow_output+="${MAGENTA}${prefix}${NC} ${color}${icon} ${id}${NC}\n"

        # Find children (tasks that depend on this root)
        local children
        children=$(echo "$status_json" | jq -r --arg id "$root_id" '.tasks[] | select(.dependencies | contains([$id])) | .id' | sort)

        if [[ -n "$children" ]]; then
            local child_count=0
            local total_children
            total_children=$(echo "$children" | grep -c . || echo 0)

            local indent_prefix
            if [[ "$is_last_root" == true ]]; then
                indent_prefix="    "
            else
                indent_prefix="${MAGENTA}${FLOW_DOWN}${NC}   "
            fi

            while IFS= read -r child_id; do
                [[ -z "$child_id" ]] && continue
                ((child_count++))

                local is_last_child=false
                [[ "$child_count" -eq "$total_children" ]] && is_last_child=true

                # Get child task info
                local child_info
                child_info=$(echo "$status_json" | jq -r --arg id "$child_id" '.tasks[] | select(.id == $id) | "\(.pass)|\(.blocked)|\(.id)"')

                IFS='|' read -r cpass cblocked cid <<< "$child_info"

                # Determine icon and color for child
                if [[ "$cpass" == "true" ]]; then
                    icon="$ICON_DONE"
                    color="${GREEN}"
                elif [[ "$cblocked" == "true" ]]; then
                    icon="$ICON_BLOCKED"
                    color="${BLUE}"
                else
                    icon="$ICON_PENDING"
                    color="${YELLOW}"
                fi

                local child_prefix
                if [[ "$is_last_child" == true ]]; then
                    child_prefix="${FLOW_END}${FLOW_RIGHT}"
                else
                    child_prefix="${FLOW_BRANCH}${FLOW_RIGHT}"
                fi

                flow_output+="${indent_prefix}${MAGENTA}${child_prefix}${NC} ${color}${icon} ${cid}${NC}\n"

                # Show grandchildren (one more level)
                local grandchildren
                grandchildren=$(echo "$status_json" | jq -r --arg id "$child_id" '.tasks[] | select(.dependencies | contains([$id])) | .id' | head -3)

                if [[ -n "$grandchildren" ]]; then
                    local gc_indent
                    if [[ "$is_last_root" == true ]]; then
                        if [[ "$is_last_child" == true ]]; then
                            gc_indent="        "
                        else
                            gc_indent="    ${MAGENTA}${FLOW_DOWN}${NC}   "
                        fi
                    else
                        if [[ "$is_last_child" == true ]]; then
                            gc_indent="${MAGENTA}${FLOW_DOWN}${NC}       "
                        else
                            gc_indent="${MAGENTA}${FLOW_DOWN}${NC}   ${MAGENTA}${FLOW_DOWN}${NC}   "
                        fi
                    fi

                    local gc_count=0
                    while IFS= read -r gc_id; do
                        [[ -z "$gc_id" ]] && continue
                        ((gc_count++))
                        [[ $gc_count -gt 2 ]] && { flow_output+="${gc_indent}${BLUE}...${NC}\n"; break; }

                        local gc_info
                        gc_info=$(echo "$status_json" | jq -r --arg id "$gc_id" '.tasks[] | select(.id == $id) | "\(.pass)|\(.blocked)|\(.id)"')

                        IFS='|' read -r gpass gblocked gid <<< "$gc_info"

                        if [[ "$gpass" == "true" ]]; then
                            icon="$ICON_DONE"
                            color="${GREEN}"
                        elif [[ "$gblocked" == "true" ]]; then
                            icon="$ICON_BLOCKED"
                            color="${BLUE}"
                        else
                            icon="$ICON_PENDING"
                            color="${YELLOW}"
                        fi

                        flow_output+="${gc_indent}${MAGENTA}${FLOW_END}${FLOW_RIGHT}${NC} ${color}${icon} ${gid}${NC}\n"
                    done <<< "$grandchildren"
                fi
            done <<< "$children"
        fi
    done <<< "$roots"

    echo -e "$flow_output"
}

# Print a line and clear to end (smooth update)
print_line() {
    echo -e "${1}${CLEAR_LINE}"
}

# Render the watch display (smooth, flicker-free)
render_display() {
    local prd_file="$1"
    local project_dir="$2"
    local start_time="$3"
    local refresh_interval="$4"

    get_term_size
    local width=$((TERM_COLS > 80 ? 80 : TERM_COLS))

    # Build output in a buffer for atomic update
    local output=""

    # Move to top without clearing
    output+="$MOVE_HOME"

    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))

    # Get status from active PRD
    local active_sub
    active_sub=$(jq -r '.ralph.activeSubPrdFile // empty' "$prd_file" 2>/dev/null)
    local stack_depth
    stack_depth=$(jq '.ralph.prdStack | length // 0' "$prd_file" 2>/dev/null || echo 0)

    local active_prd="$prd_file"
    if [[ -n "$active_sub" ]] && [[ -f "$(dirname "$prd_file")/$active_sub" ]]; then
        active_prd="$(dirname "$prd_file")/$active_sub"
    fi

    local status_json
    status_json=$(get_task_status "$active_prd")

    # Header
    output+="${CYAN}$(draw_box "RALPH WATCH" $width)${NC}${CLEAR_LINE}\n"

    # Project info
    output+="${BOX_V} ${BOLD}Project:${NC} $(basename "$project_dir")${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}PRD:${NC} $(basename "$prd_file")${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}Elapsed:${NC} $(format_time $elapsed)${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}Updated:${NC} $(date '+%H:%M:%S')${CLEAR_LINE}\n"

    # Sub-PRD info if active
    if [[ -n "$active_sub" ]]; then
        output+="${BOX_V}${CLEAR_LINE}\n"
        output+="${BOX_V} ${YELLOW}${BOLD}⚡ Active Sub-PRD:${NC} ${YELLOW}$active_sub${NC}${CLEAR_LINE}\n"
        output+="${BOX_V} ${YELLOW}   Stack Depth: $stack_depth${NC}${CLEAR_LINE}\n"
    fi

    output+="${CYAN}${BOX_LT}$(draw_hline $((width - 2)))${BOX_RT}${NC}${CLEAR_LINE}\n"

    if [[ "$status_json" == "ERROR:"* ]]; then
        output+="${BOX_V} ${RED}$status_json${NC}${CLEAR_LINE}\n"
        output+="$(close_box $width)${CLEAR_LINE}\n"
        echo -en "$output"
        return
    fi

    local total completed
    total=$(echo "$status_json" | jq -r '.total')
    completed=$(echo "$status_json" | jq -r '.completed')

    # Progress section
    output+="${BOX_V}${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}Progress${NC}${CLEAR_LINE}\n"
    output+="${BOX_V}   $(draw_progress_bar $completed $total 50) ${GREEN}$completed${NC}/${total} tasks${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"

    output+="${CYAN}${BOX_LT}$(draw_hline $((width - 2)))${BOX_RT}${NC}${CLEAR_LINE}\n"

    # Tasks section
    output+="${BOX_V}${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}Tasks${NC}${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"

    # Show tasks with status icons
    while IFS='|' read -r pass expanding blocked id name complexity; do
        local icon color status_text

        if [[ "$pass" == "true" ]]; then
            icon="$ICON_DONE"
            color="${GREEN}"
            status_text=""
        elif [[ "$expanding" == "true" ]]; then
            icon="$ICON_EXPANDING"
            color="${MAGENTA}"
            status_text=" [expanding]"
        elif [[ "$blocked" == "true" ]]; then
            icon="$ICON_BLOCKED"
            color="${BLUE}"
            status_text=" [blocked]"
        else
            icon="$ICON_PENDING"
            color="${YELLOW}"
            status_text=" [ready]"
        fi

        # Complexity indicator (inline)
        local complexity_dots=""
        for ((i=0; i<complexity && i<5; i++)); do
            complexity_dots+="●"
        done
        for ((i=complexity; i<5; i++)); do
            complexity_dots+="○"
        done

        output+="${BOX_V}   ${color}${icon}${NC} ${BOLD}${id}${NC} ${BLUE}[${complexity_dots}]${NC} ${name}${color}${status_text}${NC}${CLEAR_LINE}\n"
    done < <(echo "$status_json" | jq -r '.tasks[] | "\(.pass)|\(.expanding)|\(.blocked)|\(.id)|\(.name)|\(.complexity)"')

    output+="${BOX_V}${CLEAR_LINE}\n"

    # Git activity
    output+="${CYAN}${BOX_LT}$(draw_hline $((width - 2)))${BOX_RT}${NC}${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}Recent Git Activity${NC}${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"

    while read -r line; do
        local short_line="${line:0:$((width - 6))}"
        output+="${BOX_V}   ${CYAN}$short_line${NC}${CLEAR_LINE}\n"
    done < <(cd "$project_dir" 2>/dev/null && git log --oneline -5 2>/dev/null)

    output+="${BOX_V}${CLEAR_LINE}\n"

    # Footer
    output+="${CYAN}$(close_box $width)${NC}${CLEAR_LINE}\n"
    output+="${CLEAR_LINE}\n"
    output+="${BLUE}Press Ctrl+C to exit | Refresh: ${refresh_interval}s | Legend: ${GREEN}✓${NC}done ${YELLOW}○${NC}ready ${BLUE}◌${NC}blocked${NC}${CLEAR_LINE}\n"

    # Clear any remaining lines from previous render
    output+="${CLEAR_TO_END}"

    # Print entire buffer at once (atomic update)
    echo -en "$output"
}

# Main watch loop
run_watch() {
    local prd_file="$1"
    local project_dir="$2"
    local refresh_interval="${3:-2}"

    local start_time
    start_time=$(date +%s)

    # Hide cursor, clear screen once, and setup cleanup
    echo -en "$HIDE_CURSOR$CLEAR_SCREEN"
    trap 'echo -en "$SHOW_CURSOR$CLEAR_SCREEN$MOVE_HOME"; exit 0' INT TERM EXIT

    while true; do
        render_display "$prd_file" "$project_dir" "$start_time" "$refresh_interval"
        sleep "$refresh_interval"
    done
}

# Render the flow display (dependency visualization)
render_flow() {
    local prd_file="$1"
    local project_dir="$2"
    local start_time="$3"
    local refresh_interval="$4"

    get_term_size
    local width=$((TERM_COLS > 80 ? 80 : TERM_COLS))

    # Build output in a buffer for atomic update
    local output=""

    # Move to top without clearing
    output+="$MOVE_HOME"

    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - start_time))

    # Get status from active PRD
    local active_sub
    active_sub=$(jq -r '.ralph.activeSubPrdFile // empty' "$prd_file" 2>/dev/null)

    local active_prd="$prd_file"
    if [[ -n "$active_sub" ]] && [[ -f "$(dirname "$prd_file")/$active_sub" ]]; then
        active_prd="$(dirname "$prd_file")/$active_sub"
    fi

    local status_json
    status_json=$(get_task_status "$active_prd")

    # Header
    output+="${CYAN}$(draw_box "TASK FLOW" $width)${NC}${CLEAR_LINE}\n"

    # Project info
    output+="${BOX_V} ${BOLD}Project:${NC} $(basename "$project_dir")${CLEAR_LINE}\n"
    output+="${BOX_V} ${BOLD}Elapsed:${NC} $(format_time $elapsed)${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"

    if [[ "$status_json" == "ERROR:"* ]]; then
        output+="${BOX_V} ${RED}$status_json${NC}${CLEAR_LINE}\n"
        output+="$(close_box $width)${CLEAR_LINE}\n"
        echo -en "$output"
        return
    fi

    local total completed
    total=$(echo "$status_json" | jq -r '.total')
    completed=$(echo "$status_json" | jq -r '.completed')

    # Progress line
    output+="${BOX_V} $(draw_progress_bar $completed $total 40) ${GREEN}$completed${NC}/${total} tasks${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"

    output+="${CYAN}${BOX_LT}$(draw_hline $((width - 2)))${BOX_RT}${NC}${CLEAR_LINE}\n"
    output+="${BOX_V}${CLEAR_LINE}\n"

    # Build and display flow
    local flow_content
    flow_content=$(build_dependency_flow "$status_json" $((width - 6)))

    while IFS= read -r flow_line; do
        output+="${BOX_V}   ${flow_line}${CLEAR_LINE}\n"
    done <<< "$flow_content"

    output+="${BOX_V}${CLEAR_LINE}\n"

    # Footer
    output+="${CYAN}$(close_box $width)${NC}${CLEAR_LINE}\n"
    output+="${CLEAR_LINE}\n"
    output+="${BLUE}Press Ctrl+C to exit | Refresh: ${refresh_interval}s${NC}${CLEAR_LINE}\n"
    output+="${CLEAR_LINE}\n"
    output+="${BOLD}Legend:${NC} ${GREEN}✓${NC} done  ${YELLOW}○${NC} ready  ${BLUE}◌${NC} blocked  ${MAGENTA}◆${NC} goal${CLEAR_LINE}\n"

    # Clear any remaining lines from previous render
    output+="${CLEAR_TO_END}"

    # Print entire buffer at once (atomic update)
    echo -en "$output"
}

# Main flow loop
run_flow() {
    local prd_file="$1"
    local project_dir="$2"
    local refresh_interval="${3:-2}"

    local start_time
    start_time=$(date +%s)

    # Hide cursor, clear screen once, and setup cleanup
    echo -en "$HIDE_CURSOR$CLEAR_SCREEN"
    trap 'echo -en "$SHOW_CURSOR$CLEAR_SCREEN$MOVE_HOME"; exit 0' INT TERM EXIT

    while true; do
        render_flow "$prd_file" "$project_dir" "$start_time" "$refresh_interval"
        sleep "$refresh_interval"
    done
}

# Export functions
export -f get_term_size draw_hline draw_box close_box draw_progress_bar
export -f format_time get_task_status build_dependency_flow
export -f render_display run_watch render_flow run_flow
