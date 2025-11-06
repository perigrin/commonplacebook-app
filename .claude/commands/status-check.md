1. Check git status for uncommitted changes or untracked files
2. Run the project's primary test suite (make test, npm test, pytest, cargo test, etc.)
3. Run linting/static analysis if available (golangci-lint, eslint, flake8, clippy, etc.)
4. Check for any build artifacts that need cleaning
5. Verify all dependencies are properly installed and up to date
6. Check for any configuration files that might need attention
7. Document current state and any issues found
8. If issues exist, categorize them by type:
   - **Critical**: Blocking development (build failures, test failures)
   - **Important**: Quality issues (linting errors, outdated dependencies)
   - **Minor**: Housekeeping (untracked files, build artifacts)
9. Create action plan for addressing issues in priority order
10. Update any project documentation or plans to reflect current status