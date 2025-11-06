Create a descriptive progress checkpoint commit.

Arguments: Optional description for the commit message

1. Check current git status to see what files have changed

2. Review all changes with `git diff` to understand what was accomplished

3. Stage all relevant files (exclude build artifacts, temporary files, etc.)
   - Use `git add` for specific files if needed
   - Be careful not to commit generated files or artifacts

4. Create a commit message:
   - If arguments provided: Use "$ARGUMENTS" as the commit message
   - Otherwise: Generate a descriptive message based on the changes
   - Follow the project's commit message style (check `git log --oneline -20`)
   - Focus on what was accomplished, not just what changed
   - Keep it concise but meaningful (1-2 lines)

5. Create the commit with the message

6. Confirm the commit was created successfully with `git log -1 --oneline`

7. Ask if the user wants to push the commit (if on a feature branch)

Note: This is for progress checkpoints and WIP commits. For final commits before PRs,
ensure all tests pass and follow stricter commit message conventions.
