Clean up after a PR has been merged:

1. **Identify the default branch:**
   - Check git config or use `pu` for chalk project
   - Verify with `git remote show origin`

2. **Switch and update:**
   ```bash
   git checkout ${DEFAULT_BRANCH}
   git pull
   ```

3. **Optional cleanup:**
   - Delete local feature branch if user confirms
   - Delete remote feature branch (usually auto-deleted by GitHub)

4. **Show status:**
   - Recent commits: `git log --oneline -5`
   - Current branch state
   - Any uncommitted changes

5. **Ask user:**
   - "Should I update any related GitHub issues?"
   - If yes, list issues that should be marked complete or updated
