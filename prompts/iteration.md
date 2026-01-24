# Ralph Loop - Iteration {{ITERATION}}

{{SUB_PRD_CONTEXT}}

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

## The Relay Race: Baton Passing

**You are a runner in a relay race. Each task passes a working baton to the next.**

```
T-300 (Your predecessor)         YOU (T-400)              T-500 (Next runner)
├── guarantees: ─────────────► ├── requires:     ├── requires:
│   "add(2,3)=5" ✓ PROVEN     │   "add works"   │   "all ops verified"
│                              │                  │
│                              ├── guarantees: ──►│
│                              │   "all 4 ops     │
│                              │    demo'd"       │
```

**The Rules:**
1. **Receive the baton**: Verify your `requires` are proven (run the predecessor's validation)
2. **Run your leg**: Implement and DEMONSTRATE your deliverable works
3. **Pass the baton**: Your `guarantees` must be PROVEN so the next runner can proceed

**DEMONSTRATE, Don't Just Test:**
- ❌ "Tests pass" (silent, invisible)
- ✅ "Demo: add(2,3) outputs 5, subtract(5,2) outputs 3" (visible proof)

**Every validation should SHOW output the user could see.**

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

## Task Expansion

If you encounter a task that is too complex to complete in a single iteration (complexity >= 4 with many actions), you can signal that it needs expansion into a sub-PRD.

**When to signal expansion:**
- Task has 5+ distinct actions that each require significant work
- Task spans multiple concerns (e.g., "implement full auth system")
- You realize mid-task that breaking it down would be more effective

**How to signal expansion:**

```
<expansion-needed>
Task T-XXX requires expansion.
Goal: "Brief description of what needs to be achieved"
</expansion-needed>
```

After outputting this signal, stop working on the task. Ralph will automatically:
1. Generate a sub-PRD for this task
2. Execute the sub-PRD tasks
3. Mark the original task complete when the sub-PRD finishes

**Note:** Don't signal expansion for simple tasks or tasks you can complete. Only use this when genuine decomposition would help.

---

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
