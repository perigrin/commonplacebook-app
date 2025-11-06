Review GitHub issue #${1:issue_number} and update it to reflect current state:

1. **Fetch and analyze the issue:**
   - Use `gh issue view ${1}` to read current description
   - Check implementation status in codebase
   - Review related PRs and commits

2. **Update issue description with:**
   - **Current State** section with checkboxes (✅ done, ❓ unknown, ❌ not done)
   - Remove outdated "phase" or "prerequisite" references
   - Update task list to reflect actual work done
   - Add **Related Issues** section linking to dependencies/successors
   - Add **Related PRs** section linking to implementation

3. **Cleanup:**
   - Remove obsolete information
   - Update success criteria
   - Clarify any ambiguous requirements

4. **Before posting:**
   - Show the updated description to user
   - Ask for approval before running `gh issue edit`

**Focus on**: Making the issue reflect reality, not theory.
