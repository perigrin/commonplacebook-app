Create a GitHub issue to track work described in the arguments.

Arguments: Brief description of the issue (required)

1. Analyze the description provided in $ARGUMENTS

2. Determine the issue type:
   - bug: Something is broken or incorrect
   - enhancement: New feature or improvement
   - grammar: Grammar rule addition/fix (chalk project)
   - parser: Parser implementation issue (chalk project)
   - documentation: Documentation needs
   - technical-debt: Refactoring or cleanup needed

3. Infer appropriate labels based on:
   - Issue type (from step 2)
   - Component affected (if clear from description)
   - Estimated effort: low, medium, or complex
   - Impact: high, medium, or low

4. Check for related open issues:
   - Use `gh issue list` to see current issues
   - Note any that should be referenced

5. Format the issue description in markdown:
   - Clear problem statement or feature request
   - Current behavior (if it's a bug)
   - Expected behavior
   - Relevant code references if applicable from conversation
   - References to related issues (if any)

6. Create the issue using `gh issue create`:
   - Include title derived from $ARGUMENTS
   - Include formatted body
   - Add appropriate labels

7. Return the issue number and URL

8. Confirm the issue was created successfully
