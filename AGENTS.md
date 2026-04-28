# Agent Development Protocol

## 1. Branch and Workspace Rule
All project development must happen directly in the local `main` workspace.
- **No Worktrees**: Do not create or use git worktrees for this project.
- **No New Branches**: Do not create feature branches or switch away from `main` for development.
- **Main-Only Workflow**: Before editing, verify the current branch is `main`; if it is not, stop and ask the user how to proceed.

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
