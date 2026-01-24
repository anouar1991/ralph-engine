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

---

## The Testability Pyramid: From Simple to Combined

**Design goals to be tested at three levels:**

```
                    ┌─────────────────────┐
                    │  INTEGRATION TESTS  │  ← T-400+: Multiple goals working together
                    │  "All parts work    │
                    │   as a system"      │
                    └──────────┬──────────┘
                               │
              ┌────────────────┴────────────────┐
              │       COMBINATION TESTS         │  ← T-300+: Two or more goals combined
              │  "A works with B correctly"     │
              └────────────────┬────────────────┘
                               │
    ┌──────────────────────────┴──────────────────────────┐
    │                    UNIT TESTS                        │  ← T-100-200: Single goal isolation
    │  "This one thing works exactly as specified"         │
    └──────────────────────────────────────────────────────┘
```

### Level 1: Unit-Testable Goals (T-100s, T-200s)
- **One thing, one test**: Goal does exactly ONE thing that can be verified with ONE assertion
- **No dependencies**: Can be tested in complete isolation
- **Instant feedback**: Test runs in milliseconds, result is obvious

**Example:**
```json
{
  "id": "T-200",
  "name": "Addition works: add(a,b) returns correct sums",
  "guarantees": ["add(2,3) returns 5"],
  "validation": "python -c \"from calc import add; assert add(2,3) == 5; print('✓ add works')\""
}
```

### Level 2: Combination-Testable Goals (T-300s)
- **Combines 2-3 unit goals**: Tests that earlier pieces work together
- **Inter-testable**: Validation uses outputs from multiple previous goals
- **Catches integration bugs**: Reveals issues that unit tests miss

**Example:**
```json
{
  "id": "T-350",
  "name": "Arithmetic chain works: operations can be combined",
  "requires": ["add works", "multiply works"],
  "guarantees": ["multiply(add(2,3), 4) returns 20"],
  "validation": "python -c \"from calc import add, multiply; result = multiply(add(2,3), 4); assert result == 20; print(f'✓ chain: (2+3)*4 = {result}')\""
}
```

### Level 3: Integration-Testable Goals (T-400s+)
- **Full system test**: Multiple components working as a whole
- **End-to-end validation**: User-like interaction patterns
- **Confidence checkpoint**: Proves the system is ready for the next layer

**Example:**
```json
{
  "id": "T-400",
  "name": "All operations verified: complete arithmetic core works",
  "requires": ["add works", "subtract works", "multiply works", "divide works"],
  "guarantees": ["All 4 operations return correct results", "Error handling works for invalid inputs"],
  "validation": "python -c \"from calc import *; tests = [(add,2,3,5), (subtract,5,3,2), (multiply,4,3,12), (divide,8,2,4.0)]; [print(f'✓ {f.__name__}({a},{b})={f(a,b)}') for f,a,b,expected in tests if f(a,b)==expected]\""
}
```

---

## The Complexity Ladder: Manageable Steps to Complex Goals

**Never jump more than one rung at a time:**

```
COMPLEXITY 5: Full system with error handling, edge cases, UI
     ↑
COMPLEXITY 4: Multiple features integrated together
     ↑
COMPLEXITY 3: Single feature with variations (types, edge cases)
     ↑
COMPLEXITY 2: Single feature, happy path only
     ↑
COMPLEXITY 1: Foundation exists and is reachable
```

### Ladder Rules:

1. **Each task is ONE rung**: Don't combine complexity levels
2. **Test before climbing**: Prove current rung works before adding complexity
3. **Happy path first**: Get the basic case working before edge cases
4. **One variation at a time**: Add complexity incrementally

### Example Ladder: Building a Divide Function

```
T-100 (Complexity 1): Module exists
  └── Test: import succeeds

T-230 (Complexity 2): divide(a,b) works for simple integers
  └── Test: divide(10,2) == 5.0

T-231 (Complexity 3): divide handles floats correctly
  └── Test: divide(7.5, 2.5) == 3.0
  └── Builds on: T-230 already works for integers

T-232 (Complexity 3): divide raises error for zero
  └── Test: divide(5,0) raises ValueError
  └── Builds on: T-230, T-231 already work for valid inputs

T-233 (Complexity 4): divide handles all edge cases
  └── Test: negative numbers, very small numbers, etc.
  └── Builds on: All previous divide tasks
```

---

## Inter-Testability: Designing for Combination Testing

**Create explicit "combination points" where goals merge:**

```
T-200 (add) ─────┐
                 │
T-210 (subtract)─┼──► T-350 (arithmetic chain) ──► T-400 (full verification)
                 │
T-220 (multiply)─┼──► T-360 (expression parser) ──► T-500 (calculator REPL)
                 │
T-230 (divide) ──┘
```

### Inter-Test Design Rules:

1. **Name the combination**: Create explicit tasks that test goals together
2. **Test the seams**: Focus validation on how pieces connect, not just that they exist
3. **Progressive integration**: First combine 2, then 3, then all

### Inter-Test Task Template:
```json
{
  "id": "T-350",
  "name": "Operations combine: arithmetic expressions work",
  "intent": "Prove that individual operations can be chained together",
  "requires": ["add works", "subtract works", "multiply works"],
  "guarantees": [
    "add result can be passed to multiply",
    "subtract result can be passed to divide",
    "chained operations produce correct results"
  ],
  "validation": "Demo: (2+3)*4=20, (10-2)/4=2.0, 2+(3*4)=14",
  "interTests": [
    "add→multiply chain",
    "subtract→divide chain",
    "mixed operations"
  ]
}
```

---

## Reliable Progression: Each Goal Enables the Next

**Design dependency chains that are impossible to break:**

### The Enablement Pattern:

```
T-100 ENABLES T-200:
  T-100.guarantees: ["module is importable"]
  T-200.requires:   ["module is importable"]  ← Exact match

T-200 ENABLES T-300:
  T-200.guarantees: ["add(a,b) returns sum"]
  T-300.requires:   ["addition operation exists"]  ← Semantic match
```

### Reliable Progression Rules:

1. **Guarantees must be testable**: Every guarantee has a corresponding validation
2. **Requires must be satisfiable**: Every require matches some guarantee
3. **No implicit dependencies**: If B needs A, B.dependencies includes A
4. **Fail-fast validation**: If a guarantee isn't met, the task cannot pass

### Progression Checkpoint Task:
Every 3-4 tasks, insert a "checkpoint" that verifies accumulated progress:

```json
{
  "id": "T-250",
  "name": "Core arithmetic checkpoint: foundation is solid",
  "intent": "Verify all basic operations work before building integration layer",
  "requires": ["add works", "subtract works"],
  "guarantees": ["Core arithmetic is reliable", "Ready for multiplication/division"],
  "validation": "Run all unit tests for T-200, T-210; all must pass",
  "isCheckpoint": true
}
```

---

## Process: Backward Goal Decomposition

**Think backwards from what the user will SEE and USE:**

1. **Start with the User Experience**: What will the user actually DO with the final product? Create the goal task that delivers this.

2. **What must work before the user can use it?**: Decompose into sub-deliverables, each provably working.

3. **Each Deliverable Proves Itself**: Every task must have a visible validation - something that shows it works, not just "test passes".

4. **Insert Combination Points**: Where should goals merge for inter-testing?

5. **Add Checkpoints**: Every 3-4 tasks, add a checkpoint that verifies progress.

6. **Continue Until Base**: Keep asking "what must be working before this?" until you reach tasks that can start immediately.

---

## Example: Calculator with Testability Layers

```
🏁 FINISH LINE: T-600 "User can perform calculations"
   └── Integration test: Full interactive session

📊 CHECKPOINT: T-500 "Calculator is feature-complete"
   └── Integration test: All features work together

🔗 COMBINATION: T-400 "All operations verified"
   └── Inter-test: add+subtract+multiply+divide in sequence

🔗 COMBINATION: T-350 "Operations chain correctly"
   └── Inter-test: (2+3)*4, (10-2)/2, etc.

📦 UNIT: T-330 "Division with error handling"
   └── Unit test: divide(10,2)=5, divide(5,0)→error

📦 UNIT: T-320 "Multiplication works"
   └── Unit test: multiply(4,3)=12

📦 UNIT: T-310 "Subtraction works"
   └── Unit test: subtract(5,3)=2

📦 UNIT: T-300 "Addition works"
   └── Unit test: add(2,3)=5

🏁 START: T-100 "Calculator module exists"
   └── Unit test: import succeeds
```

---

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
      "testLevel": "unit|combination|integration",
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

---

## Task Design Rules

### Testability: One Assertion Per Goal
- ❌ "Add function handles integers, floats, and negatives"
- ✅ "Addition works: add(2,3) returns 5" (then separate tasks for floats, negatives)

### Manageability: Maximum Complexity Increment of 1
- ❌ Jump from "module exists" to "full REPL works"
- ✅ "module exists" → "add works" → "operations combine" → "CLI parses" → "REPL works"

### Inter-testability: Explicit Combination Points
- ❌ Assume operations work together without testing
- ✅ Create T-350 "Operations chain correctly" that explicitly tests combinations

### Reliability: Guarantees Match Requires
- ❌ Vague guarantee: "Function works correctly"
- ✅ Specific guarantee: "add(2,3) returns exactly 5"

### Naming: What's Proven, Not What's Done
- ❌ "Implement add function"
- ✅ "Addition works: add(a,b) returns correct sums"

### Validation: Single Clear Assertion
- ❌ `"validation": "Run all tests"`
- ✅ `"validation": "python -c \"assert add(2,3)==5; print('✓')\""`

---

## Task Categories (by test level)

- **T-100s**: Foundation (unit tests) - module exists, imports work
- **T-200s**: Core units (unit tests) - individual functions work
- **T-300s**: Combinations (inter-tests) - functions work together
- **T-400s**: Integration (system tests) - complete features work
- **T-500s**: Interface (acceptance tests) - user can interact
- **T-600s**: Delivery (smoke tests) - final product is usable

---

## Critical Instructions

1. Return ONLY the raw JSON object
2. Do NOT write any files
3. Do NOT use any tools
4. Do NOT add explanations or markdown
5. Start your response with `{` and end with `}`
6. The JSON must be valid and parseable
7. `recommendedNextStepId` must be a base task (no dependencies)
8. Include `testLevel` field: "unit", "combination", or "integration"
9. **Unit goals**: ONE testable thing, ONE assertion
10. **Combination goals**: Test 2-3 units working together
11. **Integration goals**: Test complete features end-to-end
12. **Maximum complexity jump**: 1 level between dependent tasks
13. Final task MUST deliver something the user can USE/interact with

Your ENTIRE response must be the JSON object and nothing else.
