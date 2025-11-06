Systematically migrate test files to a new pattern:

1. **Identify scope:**
   - Ask user for the pattern to find: "${1:old_pattern}"
   - Search for matching files
   - Show count and list

2. **Create migration plan:**
   - Use TodoWrite to create task list
   - One task per file or per logical batch
   - Mark first batch as in_progress

3. **Show example conversion:**
   - Pick one representative file
   - Show old vs new pattern
   - Ask user to confirm approach

4. **Execute in batches:**
   - Migrate ${BATCH_SIZE:=5} files at a time
   - Run tests after each batch
   - Commit after each successful batch
   - Mark todos as completed

5. **Handle failures:**
   - If tests fail, stop and show errors
   - Don't proceed to next batch until fixed
   - Ask user how to proceed

6. **Final commit:**
   - Descriptive message about migration
   - Include count of files migrated
   - Reference any related issues
