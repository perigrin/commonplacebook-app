Fix GitHub Issue $ARGUMENTS using TDD workflow in a feature branch.

1. Fetch and review the issue from GitHub using `gh issue view $ARGUMENTS`

2. Create a feature branch for this work:
   - Use a descriptive name based on the issue (e.g., `fix-issue-42` or `feature/add-heredoc-support`)
   - Create from the default branch (pu, main, master, etc.)

3. Follow TDD workflow:
   - Write a failing test that demonstrates the issue or defines the feature
   - Run tests to confirm the test fails as expected
   - Implement the fix/feature
   - Run tests to confirm they now pass
   - Refactor if needed while keeping tests green

4. Run the full test suite:
   - Ensure ALL tests pass (100% pass rate required)
   - If tests fail, fix them before proceeding
   - For chalk: use `./prove`
   - For other projects: use appropriate test command

5. Commit your changes:
   - Write a clear commit message explaining what was fixed/added
   - Reference the issue number in the commit

6. Create a PR ONLY if all tests pass:
   - Use `gh pr create` with descriptive title and body
   - Reference the issue being fixed
   - Include test results summary
   - DO NOT create PR if tests are failing

7. Return the PR URL and issue status
