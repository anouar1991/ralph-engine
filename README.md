# Ralph Engine

Autonomous task executor for Claude Code. Ralph reads a PRD (Product Requirements Document), picks tasks, executes them with Claude, and commits the results - all automatically.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                      RALPH LOOP                              │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│   │ Read PRD │───▶│  Claude  │───▶│  Commit  │             │
│   │  (JSON)  │    │ executes │    │   work   │             │
│   └──────────┘    └──────────┘    └──────────┘             │
│        │                                │                   │
│        │         ┌──────────┐          │                   │
│        └─────────│  Verify  │◀─────────┘                   │
│                  │ (Claude) │                               │
│                  └──────────┘                               │
│                       │                                      │
│                       ▼                                      │
│              ┌────────────────┐                             │
│              │ All complete?  │──No──▶ Next iteration       │
│              └────────────────┘                             │
│                       │                                      │
│                      Yes                                     │
│                       ▼                                      │
│                    EXIT                                      │
└─────────────────────────────────────────────────────────────┘
```

**Key Features:**
- **PRD-driven**: Define tasks in JSON, Ralph executes them in dependency order
- **Auto-generate PRD**: Create tasks from a simple goal description
- **Git as memory**: Each task completion is committed, creating a clear history
- **Self-verifying**: After each task, a verification step ensures proper completion
- **Auto-expansion**: Complex tasks automatically break down into sub-PRDs
- **Live dashboard**: Real-time visualization of task progress
- **Resilient**: Timeouts, stuck detection, and auto-recovery keep things moving

## Installation

```bash
# Clone the repository
git clone https://github.com/anouar1991/ralph-engine.git
cd ralph-engine

# Install (to ~/.local by default)
./install.sh

# Or install to custom location
./install.sh --prefix /usr/local
```

### Dependencies

- **claude**: Claude Code CLI ([install](https://claude.ai/code))
- **jq**: JSON processor (`apt install jq` or `brew install jq`)
- **git**: Version control

## Quick Start

```bash
# 1. Generate a PRD from your goal
ralph init "Build a REST API for user management with authentication"

# 2. Review the generated tasks
cat prd.json | jq '.tasks[] | {id, name, complexity}'

# 3. Run Ralph to execute all tasks
ralph
```

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
```

**Options:**
| Option | Description |
|--------|-------------|
| `-f, --file FILE` | Read goal from file |
| `-d, --dir DIR` | Output directory (default: current) |
| `-p, --prd FILE` | Output filename (default: prd.json) |
| `--complexity NUM` | Target number of tasks |
| `--dry-run` | Preview without writing |

### `ralph run` - Execute Task Loop

Run the main Ralph loop to execute tasks.

```bash
# Run in current directory
ralph

# Run in specific project
ralph ~/my-project

# With options
ralph -n 100 -t 1800    # 100 iterations, 30min timeout
ralph --no-verify       # Skip verification step
ralph --dry-run         # Preview only
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
| `--dry-run` | Preview only | false |

### `ralph status` - Show Progress

Display current project status and progress.

```bash
ralph status              # Current directory
ralph status ~/my-project # Specific project
```

Shows:
- Project name and location
- Completion percentage
- Completed vs pending tasks
- Next available task (based on dependencies)

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

### `ralph watch` - Live Dashboard

Real-time task visualization dashboard.

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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `RALPH_MAX_ITERATIONS` | Override default max iterations |
| `RALPH_TIMEOUT` | Override default timeout |
| `RALPH_OUTPUT_DIR` | Override default output directory |
| `RALPH_NO_EXPAND` | Disable automatic expansion (true/false) |
| `RALPH_EXPANSION_THRESHOLD` | Complexity threshold for expansion |
| `RALPH_MAX_STACK_DEPTH` | Maximum nested sub-PRD depth |
| `NO_COLOR` | Disable colored output |

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
| `dependencies` | No | Array of task IDs that must complete first |
| `complexity` | No | Difficulty rating 1-5 (Ralph prefers lower first) |
| `actions` | No | Steps to complete the task |
| `guarantees` | No | What must be true when complete |
| `validation` | No | Command or check to verify completion |

### Task ID Conventions

- **T-100s**: Setup tasks (project structure, dependencies)
- **T-200s**: Core functionality
- **T-300s**: Features and enhancements
- **T-400s**: Integration tasks
- **T-500s**: Polish (error handling, edge cases)
- **T-600s**: Testing and documentation

### Expandable Tasks

Mark complex tasks for automatic expansion into sub-PRDs:

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

**Expansion Fields:**
| Field | Description |
|-------|-------------|
| `expand` | Set to `true` to force expansion |
| `expandGoal` | Goal description for the sub-PRD |
| `complexity` | Tasks with complexity ≥ 4 and ≥ 5 actions auto-expand |

When expanded, Ralph creates `prd-T-200.json` with sub-tasks like `T-200-100`, `T-200-200`, etc.

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

### 5. Expansion (if needed)
For complex tasks (marked with `expand: true` or high complexity):
- Ralph generates a sub-PRD (e.g., `prd-T-200.json`)
- Pushes current state onto the stack
- Works on sub-PRD until all sub-tasks complete
- Pops stack and marks parent task complete

```
Main PRD → detect complex task → push stack → generate sub-PRD → iterate
    ↑                                                              ↓
    └──────── pop stack ← mark parent done ← sub-PRD complete ←───┘
```

### 6. Loop or Exit
- If tasks remain: continue to next iteration
- If all complete: show success and exit

## AGENTS.md

Ralph encourages Claude to create `AGENTS.md` files in project directories. These capture:
- Directory purpose
- Patterns and conventions
- Lessons learned from tasks
- Gotchas and warnings

This builds a knowledge base that helps in future iterations.

## Troubleshooting

### PRD generation fails
- Ensure Claude Code is installed and working: `claude --help`
- Check your goal is clear and specific
- Try `--dry-run` to see what would be generated

### Ralph exits immediately
- Check that `prd.json` exists and is valid JSON
- Ensure `tasks` array exists with at least one task
- Verify dependencies are satisfiable

### Claude keeps timing out
- Increase timeout: `ralph -t 1800`
- Break large tasks into smaller ones
- Check Claude Code is working: `claude --help`

### Stuck in loop
- Check `/tmp/ralph/` for output logs
- Review `prd.json` for circular dependencies
- Ensure validation commands are correct

### Not committing
- Verify git is initialized in project
- Check file permissions
- Review output for error messages

## Uninstall

```bash
./install.sh --uninstall
```

## License

MIT License - See [LICENSE](LICENSE) for details.

## Author

Noreddine Belhadj Cheikh
