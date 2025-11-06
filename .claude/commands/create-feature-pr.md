Create a pull request for the current feature branch:

1. **Verify setup:**
   - Check current branch is NOT the default (pu/main/master)
   - Verify there are commits to include
   - Check if remote branch exists

2. **Push to remote:**
   - If no remote branch: `git push -u origin HEAD:BRANCH_NAME`
   - If remote exists: `git push`

3. **Generate PR description:**
   - Summary from recent commit messages
   - Statistics: files changed, lines added/removed (`git diff --stat ${BASE_BRANCH}..HEAD`)
   - Related issues (extract from commit messages or ask user)
   - Brief test status

4. **Create PR:**
   ```bash
   gh pr create --head BRANCH --base ${BASE:-pu} --title "TITLE" --body "DESCRIPTION"
   ```

5. **Return PR URL** for user to review

**Note:** Always ask user to confirm branch name and PR title before creating.
