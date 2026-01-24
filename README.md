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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `RALPH_MAX_ITERATIONS` | Override default max iterations |
| `RALPH_TIMEOUT` | Override default timeout |
| `RALPH_OUTPUT_DIR` | Override default output directory |
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
