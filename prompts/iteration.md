# Ralph Loop - Iteration {{ITERATION}}

## Context from Git Memory

### Recent Commits (your previous work):
```
{{GIT_LOG}}
```

### Completed Tasks: [{{COMPLETED_TASKS}}]

### Existing AGENTS.md files:
{{AGENTS_FILES}}

## Your Task This Iteration

1. **Read prd.json** to see all tasks and their dependencies
2. **Find ONE task** where:
   - `pass: false`
   - All `dependencies` are in completed list above OR have `pass: true`
   - Prefer lower complexity for momentum
3. **Execute that task completely**:
   - Follow all `actions`
   - Verify all `guarantees`
   - Run `validation` checks
4. **Update prd.json**: Set `pass: true` for the completed task
5. **Create/Update AGENTS.md** in the relevant directory with lessons learned
6. **Commit your work**:
   ```bash
   git add -A
   git commit -m "Complete T-XXX: Task Name

   - What was done
   - Key decisions made
   - Lessons learned"
   ```

## AGENTS.md Format

Create in each coherent directory (src/, src/components/, src-tauri/, etc.):

```markdown
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
```

## Rules

1. **ONE task per iteration** - Complete fully before stopping
2. **Git is your memory** - Commit after each task with detailed message
3. **AGENTS.md is your knowledge base** - Document lessons in relevant directories
4. **Follow dependencies strictly** - Never skip ahead
5. **Validate before marking done** - Run all validation checks

## Completion

When ALL tasks have `pass: true`, output exactly:

```
<promise>PROJECT COMPLETE</promise>
```

## Current Directory Structure

```
{{DIR_STRUCTURE}}
```

## Start Now

Read prd.json, pick ONE task, complete it, commit, and stop.
