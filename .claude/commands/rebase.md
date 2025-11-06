Rebase the current branch onto the default branch to maintain clean history.

Arguments: Optional target branch name (defaults to auto-detected default branch)

1. Identify the target branch:
   - If $ARGUMENTS provided, use that branch
   - Otherwise, auto-detect default branch:
     - Check `git symbolic-ref refs/remotes/origin/HEAD`
     - Or check common names: pu, main, master
   - Confirm which branch to rebase onto

2. Fetch latest changes from origin:
   - Run `git fetch origin`

3. Rebase current branch onto target:
   - Use `git rebase origin/$TARGET_BRANCH`
   - If conflicts occur, pause and help resolve them
   - After resolving conflicts, continue with `git rebase --continue`

4. After successful rebase, verify tests still pass:
   - For chalk: Run `./prove`
   - For other projects: Run appropriate test command (make test, npm test, etc.)
   - If tests fail, help diagnose what the rebase broke

5. Confirm rebase completed successfully and tests pass

6. Remind user about force-push if branch was already pushed:
   - "This branch will need force-push: `git push --force-with-lease`"
   - Only force-push if user confirms
