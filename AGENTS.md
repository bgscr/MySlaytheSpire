# Agent Development Protocol

## 1. Branch and Workspace Rule
Project development may use git branches, git worktrees, and subagents when useful.
- **Branches Allowed**: Use feature branches with the `codex/` prefix by default.
- **Worktrees Allowed**: Use the default worktree location selected by the active agent workflow unless the user specifies a path.
- **Subagents Allowed**: Use subagents for implementation and review work when the task benefits from delegation.

## 2. Code Review Process
After each completed Godot feature, run code review in two strict stages. 

### Stage 1: Spec Compliance Review
- Verify implementation matches the plan exactly.
- Check scenes, nodes, signals, scripts, resources, input map, and autoloads.
- **GATE**: Do not proceed to the Code Quality Review if any requirements are missing, or if the behavior differs from the spec in any way.

### Stage 2: Code Quality Review
- Check GDScript structure, static typing (typed variables/functions), signal usage, node paths, resource loading, code duplication, testability, and maintainability.
- Classify all found issues as Critical, Important, or Minor.

## 3. Feedback Handling
When receiving review feedback (from a user or another agent), verify each item against the actual code before applying it. 
- **Do not blindly agree with feedback.** - If the code is already correct according to the spec, defend the implementation and point out why the feedback might be incorrect.

## 4. Use Rust Token Killer
@RTK.md
