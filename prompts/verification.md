# Verification Task

Check if the last iteration completed properly. Fix any issues.

## Current State

Git status:
```
{{GIT_STATUS}}
```

Last commit:
```
{{LAST_COMMIT}}
```

prd.json ralph section:
```json
{{RALPH_SECTION}}
```

## Verification Checklist

### 1. Commit Format
- Was a commit made with format "Complete T-XXX: Task Name"?
- Does the commit message mention guarantees verified?

### 2. PRD Updates
- Does the completed task have `pass: true`?
- Is `ralph.currentTaskId` set to null?
- Is the task ID added to `ralph.history`?

### 3. Contract Fulfillment
- Read the completed task's `guarantees` array
- Verify each guarantee is actually true in the codebase
- If any guarantee is NOT met, the task is not truly complete

### 4. No Broken Contracts
- Check if any dependent tasks now have their `requires` satisfied
- Ensure no uncommitted changes break existing guarantees

## Actions

- If uncommitted work exists: commit it with proper format
- If prd.json not updated: set `pass: true` and update ralph section
- If guarantees not met: DO NOT mark pass, fix the issue first
- If all good: do nothing

## Response

After verification, respond with exactly one of:
- **VERIFIED** - All checks passed, contracts fulfilled
- **FIXED** - Issues found and resolved
- **FAILED** - Could not fix (explain why)
