# Agent Development Protocol

## 1. Core Implementation Principles
*These principles act as the primary directive for all agents when writing or modifying code.*
- **Think Before Coding**: Explicitly state your assumptions before writing code. If requirements are ambiguous, stop and ask for clarification; never guess silently. If multiple implementation paths exist, proactively present tradeoffs to the user.
- **Simplicity First**: Reject overengineering. Write the minimum viable code required to solve the current problem. Do not add unrequested "flexibility", bloated abstractions, or interfaces for hypothetical future use. If 50 lines will do, never write 200.
- **Surgical Changes**: Make precise modifications. **Strictly prohibited** from performing drive-by refactoring, optimizing adjacent unrelated code, or changing existing formatting. Strictly match the existing code style. Clean up only the dead code created by your current changes; do not touch pre-existing dead code.
- **Goal-Driven Execution**: Transform instructions into verifiable goals. Before executing complex multi-step tasks, outline concise steps and verification criteria (e.g., `1. [Step] -> verify: [check]`). Use test-driven approaches whenever possible to ensure logic is correct before and after changes.

## 2. Branch and Workspace Rule
Project development leverages `git worktree` to ensure clean, isolated, and parallel execution of all tasks. The primary repository directory remains strictly on the `main` branch to serve as the source of truth, while active development happens in isolated workspaces.

- **Task Isolation via Worktrees**: Every new task or feature must be executed in a dedicated git worktree on a new branch. **Never** create or checkout feature branches within the primary repository directory.
- **Worktree Structure**: **All worktrees must be located in the `.worktrees/` directory at the project root.** When setting up a new worktree for a task, create a corresponding feature branch (e.g., using a `codex/` prefix) strictly within that specific workspace.
- **Parallel Work & Subagents**: Multiple tasks can and should be processed concurrently when appropriate. You are encouraged to dispatch subagents to operate independently across multiple worktrees and separate branches, allowing for robust parallel development without workspace conflicts.

## 3. Code Review Process
After each completed Godot feature, run code review in two strict stages. 

### Stage 1: Spec Compliance Review
- Verify implementation matches the plan exactly.
- Check scenes, nodes, signals, scripts, resources, input map, and autoloads.
- **GATE**: Do not proceed to the Code Quality Review if any requirements are missing, or if the behavior differs from the spec in any way.

### Stage 2: Code Quality Review
- Check GDScript structure, static typing (typed variables/functions), signal usage, node paths, resource loading, code duplication, testability, and maintainability.
- **Simplicity & Scope Check**: Strictly review for violations of *Simplicity First* (e.g., unnecessary abstractions) or *Surgical Changes* (e.g., modifications to unrelated code).
- Classify all found issues as Critical, Important, or Minor.

## 4. Feedback Handling
When receiving review feedback (from a user or another agent), verify each item against the actual code before applying it. 
- **Do not blindly agree with feedback.** If the code is already correct according to the spec, defend the implementation and point out why the feedback might be incorrect.
- **Manage Confusion**: If you are confused by the feedback or find the instructions ambiguous, explicitly state your confusion and request clarification. **Never** force changes while confused.

## 5. Use Rust Token Killer
@RTK.md