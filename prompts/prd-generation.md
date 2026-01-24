# Generate Deliverable Goals for Ralph Engine

You are generating a **relay race of deliverable goals** by reasoning backwards from the final outcome.

## Goal

{{GOAL}}

## Requirements

{{COMPLEXITY_HINT}}

## Core Philosophy: The Relay Race Pattern

**Every task is a runner in a relay race:**

1. **Each runner must receive a working baton** - A task can only start when its predecessor has proven their piece works
2. **Each runner must prove they ran their leg** - A task must demonstrate its deliverable works before passing the baton
3. **The final runner crosses the finish line** - The last task delivers something the user can actually USE

**This means:**
- Tasks are NOT "implement X" - they are "deliver working X and prove it"
- Each task's validation DEMONSTRATES the deliverable (not just runs tests silently)
- The final task gives the user something interactive/usable

## Process: Backward Goal Decomposition

**Think backwards from what the user will SEE and USE:**

1. **Start with the User Experience**: What will the user actually DO with the final product? Create the goal task that delivers this.

2. **What must work before the user can use it?**: Decompose into sub-deliverables, each provably working.

3. **Each Deliverable Proves Itself**: Every task must have a visible validation - something that shows it works, not just "test passes".

4. **Continue Until Base**: Keep asking "what must be working before this?" until you reach tasks that can start immediately.

## Example: Calculator (Relay Race Pattern)

```
🏁 FINISH LINE: "User can perform calculations" (T-600)
   └── requires: All operations work, CLI/REPL available
       └── proves: Interactive session with user doing real calculations

🏃 LEG 5: "Interactive calculator REPL" (T-500)
   └── requires: All 4 operations verified working
   └── proves: Demo session showing actual user input/output

🏃 LEG 4: "All operations verified" (T-400)
   └── requires: add, subtract, multiply, divide all work
   └── proves: Test run output showing all operations with results

🏃 LEG 3: "Division with error handling" (T-330)
   └── requires: module importable, multiply works
   └── proves: Demo of 10/2=5.0, 7/2=3.5, 5/0→error message

🏃 LEG 2b: "Multiplication works" (T-320)
   └── requires: module importable
   └── proves: Demo of 4*3=12, 2.5*4=10.0

🏃 LEG 2a: "Subtraction works" (T-310)
   └── requires: module importable
   └── proves: Demo of 5-3=2, 1.5-0.5=1.0

🏃 LEG 1: "Addition works" (T-300)
   └── requires: module importable
   └── proves: Demo of 2+3=5, 1.5+2.5=4.0

🏁 START: "Calculator module exists" (T-100) ← BASE TASK
   └── proves: python -c "import calculator" succeeds
```

**Key insight**: Each task PROVES its deliverable works before the next can start.

## Output JSON Format

```json
{
  "name": "Project Name",
  "description": "Brief project description",
  "goal": "What the USER will be able to DO (not what code does)",
  "tasks": [
    {
      "id": "T-100",
      "name": "Deliverable name (what's proven working)",
      "intent": "Why this deliverable matters to the final goal",
      "description": "What this task delivers and how it proves itself",
      "pass": false,
      "dependencies": [],
      "complexity": 1,
      "requires": ["What must be working before this starts"],
      "guarantees": ["What will be proven working after this completes"],
      "validation": "DEMONSTRATION command/output that PROVES it works",
      "actions": ["Implementation steps"]
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

### Naming: Deliverables, Not Actions
- ❌ "Implement add function"
- ✅ "Addition works: add(a,b) returns correct sums"

- ❌ "Write tests for calculator"
- ✅ "All operations verified: test suite proves each operation works"

- ❌ "Create CLI interface"
- ✅ "Interactive calculator: user can perform calculations via REPL"

### Validation: Demonstration, Not Silent Tests
- ❌ `"validation": "pytest test_add.py"`
- ✅ `"validation": "python -c 'from calc import add; print(add(2,3))' outputs 5"`

- ❌ `"validation": "Run test suite"`
- ✅ `"validation": "Demo: 2+3=5, 10-4=6, 3*4=12, 8/2=4.0, 5/0→'Error: division by zero'"`

### Guarantees: Observable Outcomes
- ❌ `"guarantees": ["Function is implemented"]`
- ✅ `"guarantees": ["add(2,3) returns 5", "add(1.5, 2.5) returns 4.0"]`

- ❌ `"guarantees": ["Tests pass"]`
- ✅ `"guarantees": ["Demo output shows all 4 operations with correct results"]`

### Final Task: User-Facing Deliverable
The highest-numbered task should deliver something the USER interacts with:
- A CLI they can run
- A REPL they can type into
- A web page they can open
- An API they can call
- A script they can execute

Example:
```json
{
  "id": "T-600",
  "name": "Working calculator: user can perform calculations",
  "intent": "Deliver the final usable product to the user",
  "validation": "Interactive demo: start REPL, user enters '2+3', sees '5', enters '10/0', sees error message",
  "guarantees": [
    "User can start calculator with 'python -m calculator'",
    "User can enter expressions and see results",
    "Invalid operations show helpful error messages"
  ]
}
```

## The Baton: Contracts That Enable Progress

**A task's guarantees ARE the baton it passes:**

```
T-300 (Addition)                    T-400 (Verification)
├── guarantees: ─────────────────► ├── requires:
│   "add(2,3) returns 5"          │   "Addition operation works"
│   "add(1.5,2.5) returns 4.0"    │
```

**The contract must be PROVEN, not assumed:**
- T-300's validation DEMONSTRATES add works
- Only then can T-400 trust the baton and proceed

## Task Categories (by dependency depth)

- **T-100s**: Starting line - foundation tasks (no dependencies)
- **T-200s**: Infrastructure - setup and configuration
- **T-300s**: Core deliverables - main functionality proven working
- **T-400s**: Integration - multiple pieces working together
- **T-500s**: User-facing - interface/interaction layer
- **T-600s**: Finish line - final deliverable user can USE

## Critical Instructions

1. Return ONLY the raw JSON object
2. Do NOT write any files
3. Do NOT use any tools
4. Do NOT add explanations or markdown
5. Start your response with `{` and end with `}`
6. The JSON must be valid and parseable
7. `recommendedNextStepId` must be a base task (no dependencies)
8. Final task MUST deliver something the user can USE/interact with
9. Every validation must DEMONSTRATE (show output), not just test silently

Your ENTIRE response must be the JSON object and nothing else.
