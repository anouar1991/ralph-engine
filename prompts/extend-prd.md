# Extend PRD with New Tasks

You are extending an existing, **completed** project with new functionality.

## New Goal

{{NEW_GOAL}}

## Project Context

**Project Name:** {{PROJECT_NAME}}

### Completed Tasks (What Already Works)

These tasks have been verified and committed. Do NOT recreate or duplicate this functionality:

{{COMPLETED_TASKS_SUMMARY}}

### Existing Guarantees (What You Can Depend On)

New tasks can reference these guarantees in their `requires` field:

{{EXISTING_GUARANTEES}}

### Project Structure

{{PROJECT_STRUCTURE}}

### Recent Git History

{{GIT_HISTORY}}

## Extension Rules

### Task ID Assignment

- **Starting ID:** {{STARTING_ID}}
- Task IDs must use this starting point and increment by 10 (e.g., T-500, T-510, T-520)
- NEVER reuse existing task IDs

### Dependency Rules

1. New tasks CAN depend on completed tasks by referencing their guarantees
2. New tasks SHOULD leverage existing code and patterns
3. Dependencies reference task IDs from completed tasks where appropriate
4. If a new task needs something from a completed task, add it to `requires`

### Integration Guidelines

1. **Understand First:** Review the completed tasks and guarantees before designing new ones
2. **Build On Existing:** Use existing patterns, modules, and APIs
3. **Don't Duplicate:** If functionality exists, extend it - don't recreate it
4. **Maintain Quality:** Follow the same testing and validation patterns

### Validation Requirements

Every new task must have:
- Clear `validation` command that proves the feature works
- `guarantees` that describe what will be true when complete
- `requires` that reference what must already work (from existing OR new tasks)

## Output Format

Return a JSON object with:

```json
{
  "extension": {
    "goal": "Brief description of what's being added",
    "reason": "Why this extension makes sense for the project"
  },
  "tasks": [
    {
      "id": "T-500",
      "name": "Task name (what's proven working)",
      "intent": "Why this task matters",
      "description": "Detailed description",
      "pass": false,
      "dependencies": ["T-400"],
      "complexity": 2,
      "requires": ["API server is running", "User authentication works"],
      "guarantees": ["CSV export endpoint returns valid CSV"],
      "validation": "curl http://localhost:8000/export.csv | head -5",
      "testLevel": "unit|combination|integration",
      "actions": ["Step 1", "Step 2"]
    }
  ]
}
```

## Task Design Rules

### From Existing PRD Philosophy

- **Relay Race Pattern:** Each task receives working code and passes working code
- **Testability Pyramid:** Unit → Combination → Integration
- **Complexity Ladder:** Never jump more than one complexity level
- **One Assertion Per Task:** Each task proves ONE thing works

### Maximum Tasks

- Create at most 15 new tasks
- If the goal requires more, focus on the most critical path
- Break down only what's needed - don't over-engineer

### Naming Convention

- ❌ "Implement CSV export"
- ✅ "CSV export works: /export.csv returns valid CSV data"

## Critical Instructions

1. Return ONLY the raw JSON object
2. Do NOT write any files
3. Do NOT use any tools
4. Do NOT add explanations or markdown
5. Start your response with `{` and end with `}`
6. The JSON must be valid and parseable
7. Task IDs MUST start from {{STARTING_ID}}
8. Dependencies CAN reference completed task IDs
9. Do NOT recreate functionality that already exists
10. Leverage existing guarantees in your requires

Your ENTIRE response must be the JSON object and nothing else.
