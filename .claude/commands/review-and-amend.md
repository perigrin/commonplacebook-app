Amend the most recent commit based on review feedback.

1. Check the last commit to understand what was committed:
   - Use `git log -1 --format='%H %an %ae %s'` to see commit hash, author, and message
   - Use `git show` to see the changes

2. SAFETY CHECK - Verify it's safe to amend:
   - Check authorship: Only amend if you (perigrin) are the author
   - Check if pushed: Use `git status` to see if branch is ahead/behind
   - If commit is from another author, STOP and create a NEW commit instead
   - If uncertain, ask before proceeding

3. Make the requested changes from the conversation context:
   - Edit files as needed based on review feedback
   - Ensure changes address all feedback points

4. Run tests if appropriate:
   - For chalk: `./prove` for quick validation
   - For other projects: Run relevant test suite
   - Only run tests if changes could affect functionality

5. Stage the changes:
   - Use `git add` for modified files
   - Review what will be amended with `git diff --staged`

6. Amend the previous commit:
   - Use `git commit --amend --no-edit` (keeps same message)
   - Or use `git commit --amend` to edit message if requested

7. Show the updated commit:
   - Use `git show` to display the amended commit

8. Ask if the user wants to force push:
   - If on a PR branch: Ask "Should I force push to update the PR?"
   - If confirmed: Use `git push --force-with-lease`
   - Never force push to main/master/pu without explicit permission
