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

### 1. Select a Task

Read `prd.json` and find ONE task where:
- `pass: false` (not yet complete)
- All `dependencies` have `pass: true` (their guarantees are satisfied)
- All `requires` preconditions are met (verify before starting!)
- If first iteration, prefer `ralph.recommendedNextStepId`
- Otherwise, prefer lower `complexity` for momentum

### 2. Verify Preconditions (requires)

Before starting, confirm each item in the task's `requires` array is true:
- If a precondition is NOT met, the task cannot proceed
- Check that dependency tasks' `guarantees` satisfy this task's `requires`
- If preconditions fail, pick a different task or fix the issue

### 3. Execute the Task

Follow the task's `intent` (why it exists) and complete it:
- Execute each item in `actions`
- Ensure each item in `guarantees` will be true when done
- Run `validation` to verify guarantees are met

### 4. Update prd.json

After successful validation:
- Set `pass: true` for the completed task
- Update `ralph.currentTaskId` to null
- Add task ID to `ralph.history`

### 5. Document & Commit

Create/Update AGENTS.md with lessons learned, then commit:
```bash
git add -A
git commit -m "Complete T-XXX: Task Name

- What was done
- Key decisions made
- Guarantees verified: [list what was validated]"
```

## Contract System

The PRD uses a contract system to ensure correctness:

```
Task A (dependency)          Task B (dependent)
├── guarantees: ──────────► ├── requires:
│   "X exists"              │   "X exists"  ✓ satisfied
│   "Y works"               │   "Y works"   ✓ satisfied
```

**Before starting a task**: Verify all `requires` are satisfied
**After completing a task**: Verify all `guarantees` are true

## AGENTS.md Format

Create in each coherent directory:

```markdown
# Agents Knowledge Base

## Directory Purpose
Brief description of what this directory contains.

## Patterns & Conventions
- Pattern 1: Description

## Lessons Learned
- [T-XXX] Lesson from task

## Gotchas & Warnings
- Warning about something tricky
```

## Rules

1. **ONE task per iteration** - Complete fully before stopping
2. **Verify contracts** - Check requires before, guarantees after
3. **Git is your memory** - Commit after each task with detailed message
4. **Follow dependencies strictly** - Never skip ahead
5. **Validate before marking done** - Run validation checks

## Completion

When ALL tasks have `pass: true`, output exactly:

```
<promise>PROJECT COMPLETE</promise>
```

## Current Directory Structure

```
{{DIR_STRUCTURE}}
```
{{SUDO_INSTRUCTIONS}}
## Start Now

1. Read prd.json
2. Check `ralph.recommendedNextStepId` if first iteration
3. Pick ONE task with satisfied requires
4. Verify preconditions → Execute → Verify guarantees
5. Update prd.json, commit, and stop
