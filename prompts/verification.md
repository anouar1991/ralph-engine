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

## Checklist

1. Was a commit made with format "Complete T-XXX: Task Name"?
2. Does prd.json have pass: true for the completed task?
3. Is ralph.currentTaskId updated?
4. Is ralph.history updated?

## Actions

- If uncommitted work exists: commit it with proper format
- If prd.json not updated: update pass: true and commit
- If all good: do nothing

## Response

Respond with exactly one of:
- VERIFIED (all checks passed)
- FIXED (issues found and resolved)
- FAILED (could not fix)
