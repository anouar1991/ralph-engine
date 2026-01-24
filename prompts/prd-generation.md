# Generate Task Dependency Graph for Ralph Engine

You are generating a task dependency graph by **reasoning backwards from a goal**.

## Goal

{{GOAL}}

## Requirements

{{COMPLEXITY_HINT}}

## Process: Backward Goal Decomposition

**Think backwards from the goal to discover dependencies:**

1. **Start with the Goal**: What is the final deliverable? Create a task node for it.

2. **Ask "What must be true before this can start?"**: For each task, identify its preconditions (requires). Each precondition that isn't trivially true becomes a dependency task.

3. **Recursively Decompose**: Continue asking "what must be true?" for each new task until you reach **base tasks** - tasks with no dependencies that can start immediately.

4. **Define Contracts**: For each task, specify:
   - `requires`: What must be true BEFORE this task can begin (preconditions)
   - `guarantees`: What will be true AFTER this task completes (postconditions)
   - The guarantees of dependency tasks should satisfy the requires of dependent tasks

5. **Identify Starting Point**: Find the task with no dependencies and lowest complexity - this is the `recommendedNextStepId`.

## Example Reasoning (for "Build a REST API")

```
Goal: "Working REST API with tests" (T-500)
  └── requires: API endpoints exist, tests exist
      ├── "Write API tests" (T-400)
      │   └── requires: endpoints to test exist
      │       └── "Implement API endpoints" (T-300)
      │           └── requires: data models exist, framework setup
      │               ├── "Create data models" (T-200)
      │               │   └── requires: project structure exists
      │               └── "Setup framework" (T-110)
      │                   └── requires: project structure exists
      └── "Project structure" (T-100) ← BASE TASK (no requires)
```

## Output JSON Format

```json
{
  "name": "Project Name",
  "description": "Brief project description",
  "goal": "The main goal/deliverable",
  "tasks": [
    {
      "id": "T-100",
      "name": "Task name",
      "intent": "Why this task exists (what goal it serves)",
      "description": "Detailed description",
      "pass": false,
      "dependencies": [],
      "complexity": 1,
      "requires": ["Precondition 1", "Precondition 2"],
      "guarantees": ["Postcondition 1", "Postcondition 2"],
      "validation": "How to verify guarantees are met",
      "actions": ["Step 1", "Step 2"]
    }
  ],
  "ralph": {
    "currentTaskId": null,
    "recommendedNextStepId": "T-100",
    "history": [],
    "startedAt": null
  }
}
```

## Task Design Rules

1. **IDs**: Use T-100, T-110, T-120... (increment by 10 for gaps)
2. **Dependencies**: List task IDs whose `guarantees` satisfy this task's `requires`
3. **Complexity**: Rate 1-5 (1=trivial, 5=complex)
4. **Base Tasks**: Have empty `dependencies` and minimal `requires`
5. **Goal Task**: Has highest ID, most dependencies, represents final deliverable
6. **Contract Consistency**: A task's `requires` must be covered by its dependencies' `guarantees`
7. **Granularity**: Each task should be completable in 15-30 minutes

## Task Categories (IDs reflect dependency order, not sequence)

- **T-100s**: Base/Foundation tasks (no dependencies)
- **T-200s**: Core building blocks
- **T-300s**: Feature implementation
- **T-400s**: Integration tasks
- **T-500s**: Goal tasks (final deliverables)
- **T-600s**: Verification/Polish (depend on goal tasks)

## Contract Examples

**Base Task (no requires):**
```json
{
  "id": "T-100",
  "name": "Create project structure",
  "requires": [],
  "guarantees": ["Project directory exists", "Main file is valid Python"],
  "dependencies": []
}
```

**Dependent Task:**
```json
{
  "id": "T-200",
  "name": "Implement add function",
  "requires": ["Main module exists and is importable"],
  "guarantees": ["add(a,b) returns sum", "Function handles int and float"],
  "dependencies": ["T-100"]
}
```

## Critical Instructions

1. Return ONLY the raw JSON object
2. Do NOT write any files
3. Do NOT use any tools
4. Do NOT add explanations or markdown
5. Start your response with `{` and end with `}`
6. The JSON must be valid and parseable
7. `recommendedNextStepId` must be a base task (no dependencies)

Your ENTIRE response must be the JSON object and nothing else.
