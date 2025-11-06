Generate a comprehensive test status report with metrics.

1. Identify the test command for this project:
   - Chalk: Use `./prove`
   - Others: Check for `make test`, `npm test`, `pytest`, `cargo test`, etc.

2. Run the full test suite with appropriate verbosity

3. Analyze the output and extract:
   - Total number of tests
   - Number of passing tests
   - Number of failing tests
   - Which test files are failing (if any)
   - Any TODO or skipped tests

4. Group failures by category if possible:
   - Parsing errors
   - Unimplemented features
   - Regression issues
   - Configuration problems

5. Calculate and report:
   - Pass rate percentage
   - Progress since last report (if applicable)
   - Which areas need attention

6. Generate a concise summary suitable for:
   - Commit messages
   - PR descriptions
   - Issue updates
   - Status reports

7. If all tests pass, celebrate and confirm 100% pass rate
