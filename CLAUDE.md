# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ralph Engine is an autonomous task executor for Claude Code. It implements a PRD-driven development loop: read PRD → select next task → execute with Claude → commit → verify → repeat. Git serves as the memory of completed work. Version 1.3.0.

## Architecture

Three main components form the execution pipeline:

- **bin/ralph** — CLI entry point and command dispatcher. Parses arguments, routes to subcommands (`run`, `init`, `extend`, `status`, `stack`, `watch`, `flow`).
- **lib/ralph-core.sh** — Core engine. Contains the main loop (`run_loop`), prompt building, Claude execution with timeout/activity monitoring, task selection respecting dependencies, sub-PRD stack management, PRD generation, and verification.
- **lib/ralph-watch.sh** — Terminal UI dashboard with progress bars, task status icons, dependency flow visualization.

Prompt templates in `prompts/` use `{{VAR}}` substitution and are loaded by `load_prompt()` in ralph-core.sh.

### Execution Flow

```
get_active_prd → check_completion → get_next_task → should_expand_task?
  ├─ yes → push_prd_stack → generate_sub_prd → continue on sub-PRD
  └─ no  → generate_task_briefing → build_prompt → run_claude_iteration → verify_with_claude → check_progress
```

The pre-flight optimizer (`generate_task_briefing`) calls Haiku to produce routing rules for each task. The output is written to `briefing-{N}.md` and injected via `--append-system-prompt-file`, giving it system-level authority over the executor's behavior. It covers stack discovery, AGENTS.md reading directives, agent/skill routing, tool strategy, and delegation rules.

Sub-PRDs form a stack: complex tasks (complexity ≥ 4 with 5+ actions) get decomposed into `prd-T-XXX.json` files. When a sub-PRD completes, the stack pops and the parent task is marked done.

### PRD Format

Tasks in `prd.json` have: `id`, `name`, `pass` (completion boolean), `dependencies` (task IDs), `complexity` (1-5), `actions`, `guarantees`, `requires`, `validation`, and optional `expand`/`expandGoal` fields. The `ralph` section tracks `currentTaskId`, `history`, `prdStack`, and `activeSubPrdFile`.

Task ID convention: T-100s (setup), T-200s (core), T-300s (features), T-400s (integration), T-500s (polish), T-600s (testing/docs).

## Commands

```bash
# Install
./install.sh                         # Install to ~/.local
./install.sh --prefix /usr           # Custom prefix
./install.sh --check                 # Verify installation

# Generate PRD from a goal
ralph init "Build a REST API"

# Run the autonomous loop
ralph [project-dir]

# Extend a completed project with new tasks
ralph extend "Add authentication"

# View status, expansion stack, live dashboard, dependency flow
ralph status [project-dir]
ralph stack [project-dir]
ralph watch [project-dir]
ralph flow [project-dir]

# Pass arguments through to Claude CLI
ralph -- --chrome --debug
```

## Key Defaults

| Setting | Default | Env Override |
|---------|---------|-------------|
| Max iterations | 50 | `RALPH_MAX_ITERATIONS` |
| Iteration timeout | 900s | `RALPH_TIMEOUT` |
| Output directory | /tmp/ralph | `RALPH_OUTPUT_DIR` |
| Expansion threshold | complexity ≥ 4 | `RALPH_EXPANSION_THRESHOLD` |
| Max stack depth | 3 | `RALPH_MAX_STACK_DEPTH` |
| Stuck threshold | 5 iterations | hardcoded |

## Testing & Debugging

No automated test suite. Manual testing via execution. Debug artifacts are written to the output directory:

- `prompt-{N}.md` — full prompt sent to Claude each iteration
- `briefing-{N}.md` — pre-flight routing rules injected as system prompt extension
- `output-{N}.txt` — Claude's response and activity log
- `verify-prompt-{N}.md` / `verify-output-{N}.txt` — verification step

Use `shellcheck bin/ralph lib/ralph-core.sh lib/ralph-watch.sh` for static analysis (not configured but recommended).

## Dependencies

Runtime: `bash` 4.0+, `jq`, `git`, `claude` (Claude Code CLI). No package managers or containers required.

## Development Notes

- Prompt templates use `{{VARNAME}}` syntax — `load_prompt()` does sed-based substitution. Special characters in values are handled via `sed_escape()`.
- Activity monitoring polls every 30s during Claude execution, tracking the latest modified file as a heartbeat.
- The `get_next_task()` function filters for `pass != true` and `expanding != true`, checks all dependencies are met, and sorts by complexity ascending.
- `generate_prd()` and `extend_prd()` try multiple JSON extraction strategies (markdown code blocks, raw JSON, regex) since Claude output format varies.
