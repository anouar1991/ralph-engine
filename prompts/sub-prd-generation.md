# Generate Sub-PRD for Expanded Task

You are generating a **sub-PRD** to break down a complex task into smaller, manageable deliverables.

## Parent Task Context

**Parent Task ID:** {{PARENT_TASK_ID}}
**Parent Task Name:** {{PARENT_TASK_NAME}}
**Parent PRD File:** {{PARENT_PRD_FILE}}

### Expansion Goal

{{EXPAND_GOAL}}

### Parent Task Requirements (must be satisfied before sub-PRD starts)

{{PARENT_REQUIRES}}

### Parent Task Guarantees (sub-PRD must collectively satisfy these)

{{PARENT_GUARANTEES}}

---

## Sub-PRD Requirements

### 1. Task ID Format

All tasks in this sub-PRD **MUST** use the format: `{{PARENT_TASK_ID}}-XXX`

Examples:
- `{{PARENT_TASK_ID}}-100`: First foundation task
- `{{PARENT_TASK_ID}}-200`: Core functionality tasks
- `{{PARENT_TASK_ID}}-300`: Integration/combination tasks
- `{{PARENT_TASK_ID}}-400`: Final verification task

### 2. Satisfy Parent Guarantees

The sub-PRD tasks, when all complete, **MUST** collectively satisfy all the parent task's `guarantees`. The final task in the sub-PRD should verify all parent guarantees are met.

### 3. Maximum 15 Tasks

Keep the sub-PRD focused. Maximum 15 tasks. If more decomposition is needed, individual sub-PRD tasks can themselves be marked for expansion.

### 4. Self-Contained

The sub-PRD should be executable independently, assuming the parent's `requires` are already satisfied.

---

## Complexity Guidelines

Since this is a sub-PRD for an already-complex task:

- **Start simple**: First task should be foundation/setup with complexity 1
- **Build incrementally**: Each task adds one layer of complexity
- **End with verification**: Final task proves all parent guarantees are met
- **Mark complex sub-tasks**: If any task is still too complex (complexity >= 4, actions >= 5), set `"expand": true`

---

## Output JSON Format

```json
{
  "name": "Sub-PRD: {{PARENT_TASK_ID}} - {{PARENT_TASK_NAME}}",
  "description": "Sub-PRD breaking down {{PARENT_TASK_ID}} into manageable tasks",
  "parentTaskId": "{{PARENT_TASK_ID}}",
  "parentPrdFile": "{{PARENT_PRD_FILE}}",
  "parentGuarantees": {{PARENT_GUARANTEES}},
  "tasks": [
    {
      "id": "{{PARENT_TASK_ID}}-100",
      "name": "Deliverable name (what's proven working)",
      "intent": "Why this deliverable matters",
      "description": "What this task delivers",
      "pass": false,
      "dependencies": [],
      "complexity": 1,
      "requires": ["What must be working before this starts"],
      "guarantees": ["What will be proven working after this completes"],
      "validation": "Command that DEMONSTRATES it works",
      "actions": ["Implementation steps"]
    }
  ],
  "ralph": {
    "currentTaskId": null,
    "recommendedNextStepId": "{{PARENT_TASK_ID}}-100",
    "history": []
  }
}
```

---

## Task Design for Sub-PRDs

### Foundation Task (XXX-100)
- Complexity: 1
- Sets up the environment/structure needed
- No dependencies (within sub-PRD)
- Enables all other tasks

### Core Tasks (XXX-200, XXX-300)
- Complexity: 2-3
- Implement the main functionality
- Build on foundation and each other
- Each has clear, testable guarantees

### Final Verification Task (XXX-400 or highest)
- Complexity: 2-3
- Depends on all other tasks
- Validates ALL parent guarantees are met
- Its guarantees should match/satisfy the parent task's guarantees

---

## Example Sub-PRD Structure

For a parent task `T-320` with guarantees `["JWT tokens are generated", "Tokens can be validated"]`:

```
T-320-100: Token configuration exists
   └── Setup: token secret, expiry, algorithms configured

T-320-200: JWT token generation works
   └── Core: generate_token(user_id) returns valid JWT

T-320-210: JWT token validation works
   └── Core: validate_token(token) returns user_id or error

T-320-300: Token lifecycle is complete
   └── Integration: generate → validate → refresh cycle works

T-320-400: All parent guarantees verified
   └── Final: Demonstrates both parent guarantees are met
```

---

## Critical Instructions

1. Return ONLY the raw JSON object
2. Do NOT write any files
3. Do NOT use any tools
4. Do NOT add explanations or markdown
5. Start your response with `{` and end with `}`
6. The JSON must be valid and parseable
7. All task IDs MUST start with `{{PARENT_TASK_ID}}-`
8. Maximum 15 tasks
9. Final task MUST verify parent guarantees
10. Include `parentTaskId` and `parentPrdFile` fields

Your ENTIRE response must be the JSON object and nothing else.
