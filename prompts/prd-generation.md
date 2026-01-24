# Generate PRD for Ralph Engine

You are a technical product manager creating a PRD (Product Requirements Document) for an autonomous AI coding agent.

## Goal

{{GOAL}}

## Requirements

{{COMPLEXITY_HINT}}

Create a prd.json file with this EXACT structure:

```json
{
  "name": "Project Name",
  "description": "Brief project description",
  "tasks": [
    {
      "id": "T-100",
      "name": "Task name",
      "description": "Detailed task description",
      "pass": false,
      "dependencies": [],
      "complexity": 1,
      "actions": ["Step 1", "Step 2"],
      "guarantees": ["What must be true when done"],
      "validation": "How to verify completion"
    }
  ],
  "ralph": {
    "currentTaskId": null,
    "history": [],
    "startedAt": null
  }
}
```

## Task Design Rules

1. **IDs**: Use T-100, T-110, T-120... (increment by 10 for flexibility)
2. **Dependencies**: List task IDs that must complete first (e.g., ["T-100", "T-110"])
3. **Complexity**: Rate 1-5 (1=trivial, 3=medium, 5=complex)
4. **Order**: Start with setup/foundation, end with integration/polish
5. **Granularity**: Each task should be completable in one iteration (15-30 min)
6. **Validation**: Include concrete ways to verify completion

## Task Categories (in order)

1. **Setup** (T-100s): Project structure, dependencies, configuration
2. **Core** (T-200s): Main functionality, core features
3. **Features** (T-300s): Additional features, enhancements
4. **Integration** (T-400s): Connect components, API endpoints
5. **Polish** (T-500s): Error handling, edge cases, cleanup
6. **Testing** (T-600s): Tests, validation, documentation

## Output

CRITICAL INSTRUCTIONS:
1. Return ONLY the raw JSON object
2. Do NOT write any files
3. Do NOT use any tools
4. Do NOT add explanations, commentary, or markdown
5. Start your response with { and end with }
6. The JSON must be valid and parseable

Your ENTIRE response must be the JSON object and nothing else.
