1. Reproduce the issue with minimal test case
   - Create the smallest possible example that demonstrates the problem
   - Isolate the issue from surrounding complexity
   - Document exact steps to reproduce consistently
2. Identify the exact failure point and error messages
   - Capture complete error output, stack traces, and logs
   - Note the specific line, function, or component where failure occurs
   - Record any relevant environment or configuration details
3. Check recent changes that might have introduced the issue
   - Review git history for related modifications
   - Identify commits that touched relevant code paths
   - Consider dependency updates or configuration changes
4. Trace the code path leading to the failure
   - Follow the execution flow from input to failure point
   - Identify key decision points and data transformations
   - Note any assumptions or preconditions that might be violated
5. Create focused test that isolates the problem
   - Write a failing test that captures the specific issue
   - Ensure test is independent of other functionality
   - Verify test fails consistently before attempting fix
6. Apply the smallest possible fix
   - Make minimal changes to address the root cause
   - Avoid refactoring or improvements unrelated to the issue
   - Preserve existing behavior for all other cases
7. Verify fix doesn't break related functionality
   - Run comprehensive test suite to check for regressions
   - Test edge cases and boundary conditions
   - Verify fix works across different environments if applicable
8. Document the root cause and solution for future reference
   - Record what caused the issue and why the fix works
   - Add comments or documentation to prevent similar issues
   - Update any relevant troubleshooting guides or knowledge base