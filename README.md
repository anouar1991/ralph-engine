# Ralph Engine

<p align="center">
  <strong>Autonomous task executor for Claude Code</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.3.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License">
  <img src="https://img.shields.io/badge/platform-linux%20%7C%20macos-lightgrey.svg" alt="Platform">
</p>

---

Ralph reads a PRD (Product Requirements Document), picks tasks based on dependencies, executes them with Claude Code, and commits the results - all automatically. It's like having an autonomous developer that follows your project specification.

## The Loop

```
┌─────────────────────────────────────────────────────────────────────┐
│                           RALPH LOOP                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│    ┌──────────┐      ┌──────────┐      ┌──────────┐               │
│    │ Read PRD │ ───▶ │  Claude  │ ───▶ │  Commit  │               │
│    │  (JSON)  │      │ executes │      │   work   │               │
│    └──────────┘      └──────────┘      └──────────┘               │
│          │                                   │                     │
│          │          ┌───────────┐           │                     │
│          └───────── │  Verify   │ ◀─────────┘                     │
│                     │ (Claude)  │                                  │
│                     └───────────┘                                  │
│                           │                                        │
│                           ▼                                        │
│                  ┌────────────────┐                               │
│                  │ All complete?  │ ──No──▶ Next iteration        │
│                  └────────────────┘                               │
│                           │                                        │
│                          Yes                                       │
│                           ▼                                        │
│                   ┌───────────────┐                               │
│                   │   SUCCESS!    │                               │
│                   └───────────────┘                               │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Features

| Feature | Description |
|---------|-------------|
| **PRD-driven** | Define tasks in JSON, Ralph executes them in dependency order |
| **Auto-generate PRD** | Create tasks from a simple goal description with `ralph init` |
| **Git as memory** | Each task completion is committed, creating a clear history |
| **Self-verifying** | After each task, a verification step ensures proper completion |
| **Auto-expansion** | Complex tasks automatically break down into sub-PRDs |
| **Live dashboards** | Real-time visualization with `ralph watch` and `ralph flow` |
| **Resilient** | Timeouts, stuck detection, and auto-recovery keep things moving |
| **Claude passthrough** | Pass extra arguments to Claude with `-- ARGS` |

---

## Installation

```bash
# Clone the repository
git clone https://github.com/anouar1991/ralph-engine.git
cd ralph-engine

# Install (to ~/.local by default)
./install.sh

# Or install to custom location
./install.sh --prefix /usr/local

# Verify installation
ralph --version
```

### Dependencies

| Dependency | Description | Install |
|------------|-------------|---------|
| **claude** | Claude Code CLI | [claude.ai/code](https://claude.ai/code) |
| **jq** | JSON processor | `apt install jq` or `brew install jq` |
| **git** | Version control | Usually pre-installed |

---

## Quick Start

```bash
# 1. Generate a PRD from your goal
ralph init "Build a REST API for user management with authentication"

# 2. Review the generated tasks
cat prd.json | jq '.tasks[] | {id, name, complexity}'

# 3. Run Ralph to execute all tasks
ralph

# 4. (Optional) Watch progress in another terminal
ralph watch
```

---

## Commands

### `ralph init` - Generate PRD from Goal

Create a `prd.json` from a natural language goal description.

```bash
# From text argument
ralph init "Build a CLI tool for managing todos with priorities"

# From file
ralph init -f requirements.md

# With target complexity (number of tasks)
ralph init "Create an e-commerce backend" --complexity 30

# Preview without writing
ralph init "Build a blog engine" --dry-run

# Output to specific directory
ralph init "Create a web scraper" -d ~/my-project

# With extra Claude arguments (e.g., enable Chrome for web research)
ralph init "Build a web scraper for news sites" -- --chrome
```

**Options:**

| Option | Description |
|--------|-------------|
| `-f, --file FILE` | Read goal from file |
| `-d, --dir DIR` | Output directory (default: current) |
| `-p, --prd FILE` | Output filename (default: prd.json) |
| `--complexity NUM` | Target number of tasks |
| `--dry-run` | Preview without writing |
| `-- ARGS` | Pass extra arguments to Claude |

---

### `ralph run` - Execute Task Loop

Run the main Ralph loop to execute tasks. This is the default command.

```bash
# Run in current directory
ralph

# Run in specific project
ralph ~/my-project

# With options
ralph -n 100 -t 1800    # 100 iterations, 30min timeout
ralph --no-verify       # Skip verification step
ralph --dry-run         # Preview only

# Pass extra arguments to Claude
ralph -- --chrome       # Enable Chrome access for web tasks
ralph -- --debug        # Run Claude in debug mode
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-n, --max-iterations` | Maximum loop iterations | 50 |
| `-t, --timeout` | Seconds per iteration | 900 |
| `-p, --prd` | PRD filename | prd.json |
| `-o, --output` | Log directory | /tmp/ralph |
| `-q, --quiet` | Minimal output | false |
| `--no-verify` | Skip verification | false |
| `--no-expand` | Disable auto task expansion | false |
| `--expansion-threshold` | Complexity threshold for expansion | 4 |
| `--max-stack-depth` | Maximum nested sub-PRD depth | 3 |
| `--sudo-pass [VAR]` | Enable sudo password piping | RALPH_SUDO_PASS |
| `--dry-run` | Preview only | false |
| `-- ARGS` | Pass extra arguments to Claude | - |

---

### `ralph status` - Show Progress

Display current project status and progress.

```bash
ralph status              # Current directory
ralph status ~/my-project # Specific project
```

Shows:
- Project name and location
- Completion percentage with progress bar
- Completed vs pending tasks
- Next available task (based on dependencies)

---

### `ralph stack` - Show Expansion Stack

Display the PRD expansion stack status when working with sub-PRDs.

```bash
ralph stack              # Current directory
ralph stack ~/my-project # Specific project
```

Shows:
- Current stack depth
- Active PRD file (main or sub-PRD)
- Parent tasks that have been expanded
- When each expansion was started
- Sub-PRD files in the project

---

### `ralph watch` - Live Dashboard

Real-time task visualization dashboard showing overall progress.

```bash
ralph watch              # Watch current project
ralph watch -r 5         # Refresh every 5 seconds
ralph watch & ralph      # Run dashboard alongside ralph
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --refresh` | Refresh interval (seconds) | 2 |
| `-p, --prd` | PRD filename | prd.json |

**Task Status Icons:**

| Icon | Status | Description |
|------|--------|-------------|
| ✓ | Done | Task completed successfully |
| ◉ | Working | Task currently in progress |
| ○ | Ready | Task ready to start (dependencies met) |
| ◌ | Blocked | Waiting on dependencies |
| ↳ | Expanding | Task expanded into sub-PRD |

---

### `ralph flow` - Dependency Flow Visualization

Real-time dependency tree visualization showing task relationships from goal to leaf tasks.

```bash
ralph flow               # View dependency flow
ralph flow -r 5          # Refresh every 5 seconds
ralph flow ~/my-project  # Specific project
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --refresh` | Refresh interval (seconds) | 2 |
| `-p, --prd` | PRD filename | prd.json |

**Example output:**

```
═══════════════════════════════════════════════════
              DEPENDENCY FLOW
═══════════════════════════════════════════════════

  GOAL: Build a REST API

  ═══════════════════════════════════════════════

  [✓] T-100  Setup project structure
   ├── [✓] T-200  Add user model
   │    └── [◉] T-210  User authentication
   └── [○] T-300  Add API endpoints

  ═══════════════════════════════════════════════
```

---

## Passing Arguments to Claude

Ralph supports passing extra arguments to Claude Code using the `--` separator (POSIX convention).

```bash
# Enable Chrome for web-based tasks
ralph init "Scrape product prices from e-commerce sites" -- --chrome
ralph -- --chrome

# Multiple arguments
ralph -- --chrome --verbose

# Via environment variable
export RALPH_CLAUDE_ARGS="--chrome"
ralph  # Will use --chrome automatically
```

This is useful when Claude needs:
- **`--chrome`**: Browser access for web scraping, testing web UIs
- **`--debug`**: Debugging mode
- **Custom MCP servers**: Additional tool integrations

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `RALPH_MAX_ITERATIONS` | Override default max iterations |
| `RALPH_TIMEOUT` | Override default timeout |
| `RALPH_OUTPUT_DIR` | Override default output directory |
| `RALPH_NO_EXPAND` | Disable automatic expansion (true/false) |
| `RALPH_EXPANSION_THRESHOLD` | Complexity threshold for expansion |
| `RALPH_MAX_STACK_DEPTH` | Maximum nested sub-PRD depth |
| `RALPH_CLAUDE_ARGS` | Extra arguments to pass to Claude |
| `RALPH_SUDO_PASS` | Sudo password for privileged commands |
| `NO_COLOR` | Disable colored output |

---

## PRD File Format

Ralph expects a `prd.json` file with a `tasks` array:

```json
{
  "name": "My Project",
  "description": "Brief project description",
  "tasks": [
    {
      "id": "T-100",
      "name": "Setup project structure",
      "description": "Create directories and initialize package.json",
      "pass": false,
      "dependencies": [],
      "complexity": 1,
      "actions": [
        "Create src/, tests/, docs/ directories",
        "Initialize package.json with dependencies"
      ],
      "guarantees": [
        "All directories exist",
        "package.json is valid"
      ],
      "validation": "npm install succeeds"
    },
    {
      "id": "T-110",
      "name": "Add authentication",
      "pass": false,
      "dependencies": ["T-100"],
      "complexity": 3
    }
  ],
  "ralph": {
    "currentTaskId": null,
    "history": [],
    "startedAt": null
  }
}
```

### Task Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique identifier (e.g., "T-100") |
| `name` | Yes | Human-readable name |
| `pass` | Yes | Completion status (true/false) |
| `description` | No | Detailed description |
| `dependencies` | No | Array of task IDs that must complete first |
| `complexity` | No | Difficulty rating 1-5 (Ralph prefers lower first) |
| `actions` | No | Steps to complete the task |
| `guarantees` | No | What must be true when complete |
| `validation` | No | Command or check to verify completion |
| `expand` | No | Force expansion into sub-PRD |
| `expandGoal` | No | Goal description for sub-PRD |

### Task ID Conventions

| Range | Purpose |
|-------|---------|
| **T-100s** | Setup tasks (project structure, dependencies) |
| **T-200s** | Core functionality |
| **T-300s** | Features and enhancements |
| **T-400s** | Integration tasks |
| **T-500s** | Polish (error handling, edge cases) |
| **T-600s** | Testing and documentation |

---

## Task Expansion

Ralph can automatically expand complex tasks into sub-PRDs. This happens when:

1. A task has `expand: true` set explicitly
2. A task has complexity >= 4 AND >= 5 actions
3. Claude signals expansion is needed during execution

### Example Expandable Task

```json
{
  "id": "T-200",
  "name": "Implement authentication system",
  "complexity": 5,
  "expand": true,
  "expandGoal": "Build JWT auth with login, tokens, and password reset",
  "guarantees": [
    "Users can log in",
    "JWT tokens are generated",
    "Password reset works"
  ]
}
```

### Expansion Flow

```
Main PRD → detect complex task → push stack → generate sub-PRD → iterate
    ↑                                                              ↓
    └──────── pop stack ← mark parent done ← sub-PRD complete ←───┘
```

When expanded, Ralph creates `prd-T-200.json` with sub-tasks like `T-200-100`, `T-200-200`, etc.

Use `ralph stack` to view the current expansion state.

---

## How Ralph Works

### 1. Task Selection

Ralph reads `prd.json` and picks ONE task where:
- `pass: false` (not yet complete)
- All `dependencies` are complete (`pass: true`)
- Lower `complexity` preferred (builds momentum)

### 2. Execution

Claude Code executes the task:
- Follows `actions` if specified
- Implements requirements
- Runs `validation` checks

### 3. Commit

Work is committed to git:
```
Complete T-100: Setup project structure

- Created src/, tests/, docs/ directories
- Initialized package.json with dependencies
- Configured TypeScript
```

### 4. Verification

A second Claude call verifies:
- Commit was made with correct format
- `prd.json` updated with `pass: true`
- Any missed steps are fixed

### 5. Loop or Exit

- If tasks remain: continue to next iteration
- If all complete: show success and exit

---

## AGENTS.md

Ralph encourages Claude to create `AGENTS.md` files in project directories. These capture:
- Directory purpose
- Patterns and conventions
- Lessons learned from tasks
- Gotchas and warnings

This builds a knowledge base that helps in future iterations.

---

## Troubleshooting

### PRD generation fails

- Ensure Claude Code is installed: `claude --help`
- Check your goal is clear and specific
- Try `--dry-run` to see what would be generated

### Ralph exits immediately

- Check that `prd.json` exists and is valid JSON: `jq . prd.json`
- Ensure `tasks` array exists with at least one task
- Verify dependencies are satisfiable (no circular dependencies)

### Claude keeps timing out

- Increase timeout: `ralph -t 1800`
- Break large tasks into smaller ones (lower complexity)
- Check Claude Code is working: `claude "hello"`

### Stuck in loop

- Check `/tmp/ralph/` for output logs
- Review `prd.json` for circular dependencies
- Ensure validation commands are correct

### Not committing

- Verify git is initialized: `git status`
- Check file permissions
- Review output for error messages

### Need Chrome access

- Pass `--chrome` to Claude: `ralph -- --chrome`
- Or set environment: `export RALPH_CLAUDE_ARGS="--chrome"`

---

## Shell Completions

Ralph includes shell completions for enhanced CLI experience.

**Bash:**
```bash
# Add to ~/.bashrc
source /path/to/ralph-engine/completions/ralph.bash
```

**Zsh:**
```bash
# Add to ~/.zshrc
source /path/to/ralph-engine/completions/ralph.zsh
```

---

## Uninstall

```bash
./install.sh --uninstall
```

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

## Author

**Noreddine Belhadj Cheikh**

---

<p align="center">
  <i>Let Ralph handle the tasks while you focus on the vision.</i>
</p>
