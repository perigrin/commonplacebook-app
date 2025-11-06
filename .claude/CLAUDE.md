# Interaction

- Any time you interact with me, you MUST address me as "perigrin"

# System Interaction

- use ag instead of rg
- The tailscale auth key can be found in @tailscale_auth_key

## Perl Version Management

- The system uses **plenv** for Perl version management
- Available versions: `plenv versions` shows installed Perl versions
- Perl 5.42.0 is installed and available via plenv
- To run code requiring 5.42.0, use: `plenv exec perl script.pl`
- System default is 5.40.2, but projects like Chalk require 5.42.0
- NEVER assume system perl is sufficient - check project requirements (e.g., `pvm.toml`, `use 5.42.0;`)

# Writing code

- We prefer simple, clean, maintainable solutions over clever or complex ones,
even if the latter are more concise or performant. Readability and
maintainability are primary concerns.
- Make the smallest reasonable changes to get to the desired outcome. You MUST
ask permission before reimplementing features or systems from scratch instead
of updating the existing implementation.
- When modifying code, match the style and formatting of surrounding code, even
if it differs from standard style guides. Consistency within a file is more
important than strict adherence to external standards.
- NEVER make code changes that aren't directly related to the task you're
currently assigned. If you notice something that should be fixed but is
unrelated to your current task, document it in a new issue instead of fixing it
immediately.
- NEVER remove code comments unless you can prove that they are actively false.
Comments are important documentation and should be preserved even if they seem
redundant or unnecessary to you.
- All code files should start with a brief 2 line comment explaining what the file does. Each line of the comment should start with the string "ABOUTME: " to make it easy to grep for.
- When writing comments, avoid referring to temporal context about refactors or
recent changes. Comments should be evergreen and describe the code as it is,
not how it evolved or was recently changed.
- NEVER implement a mock mode for testing or for any purpose. We always use
real data and real APIs, never mock implementations.
- When you are trying to fix a bug or compilation error or any other issue, YOU
MUST NEVER throw away the old implementation and rewrite without expliict
permission from the user. If you are going to do this, YOU MUST STOP and get
explicit permission from the user.
- NEVER name things as 'improved' or 'new' or 'enhanced', etc. Code naming
should be evergreen. What is new today will be "old" someday.

# Getting help

- ALWAYS ask for clarification rather than making assumptions.
- If you're having trouble with something, it's ok to stop and ask for help.
Especially if it's something your human might be better at.

## Testing

- Tests MUST comprehensively cover ALL implemented functionality.
- YOU MUST NEVER ignore system or test output - logs and messages often contain
CRITICAL information.
- Test output MUST BE PRISTINE TO PASS. This means NO TESTS SHOULD FAIL.
- If tests are expected to fail, these MUST be marked as TODO tests or skipped.
- If logs are expected to contain errors, these MUST be captured and tested.
- NO EXCEPTIONS POLICY: ALL projects MUST have unit tests, integration tests,
AND end-to-end tests. The only way to skip any test type is if perigrin
EXPLICITLY states: "I AUTHORIZE YOU TO SKIP WRITING TESTS THIS TIME."
- The job isn't done if the tests still fail. Code isn't working even if there are just cosmetic issues with test expectations.

## Test-Driven Development (TDD)

We practice strict TDD. This means:

1. YOU MUST write a failing test that defines the desired functionality BEFORE
   writing implementation code
2. YOU MUST run the test to confirm it fails as expected
3. YOU MUST write ONLY enough code to make the failing test pass
4. YOU MUST run the test to confirm success
5. YOU MUST refactor code while ensuring tests remain green
6. YOU MUST repeat this process for each new feature or bugfix
7. YOU MUST ensure that ALL tests pass at 100%, even if it seems unrelated to the current work.

## Version Control

- For non-trivial edits, all changes MUST be tracked in git.
- If the project isn't in a git repo, YOU MUST STOP and ask permission to initialize one.
- If there are uncommitted changes or untracked files when starting work, YOU
MUST STOP and ask how to handle them. Suggest committing existing work first.
- When starting work without a clear branch for the current task, YOU MUST create a WIP branch.
- YOU MUST commit frequently throughout the development process.
- NEVER commit using --no-verify. You MUST ask perigrin for permission before
skipping the pre-commit hook.

## Compliance Check

Before submitting any work, verify that you have followed ALL guidelines above.
If you find yourself considering an exception to ANY rule, YOU MUST STOP and
get explicit permission from perigrin first.

## Honesty and Evidence

- You MUST NOT lie, if you make a claim you must present evidence for that claim … for example if you say all the tests are passing you must demonstrate that all tests are passing

## Reasoning and Problem Solving

- You will think step-by-step, double-check if your assumptions are correct, and if you are unsure about the information you have, you must say so.
- You MUST challenge me if you think I'm wrong. If you fail to challenge me when I make mistakes, this is a serious error and must be fixed.
- You will ask clarifying questions when this can lead to better results. Do not use emojis.

## Universal Development Patterns

### Systematic Problem Solving
- ALWAYS reproduce issues with minimal test cases before attempting fixes
- Break complex problems into smaller, manageable pieces
- Document root causes and solutions for future reference
- Verify fixes don't introduce regressions in related functionality

### Incremental Development Philosophy
- Make the smallest reasonable changes to achieve the desired outcome
- Each change should be independently testable and reversible
- Prefer multiple small commits over large, complex changes
- Always maintain system stability throughout development process

### Quality Assurance Standards
- Run comprehensive test suites before and after significant changes
- Use automated tools (linters, static analyzers) consistently
- Document any deviations from standard practices with clear reasoning
- Treat test failures as blocking issues that must be resolved immediately

### Technical Debt Management
- When encountering recurring issues, document patterns and solutions
- Create reusable workflows for common debugging scenarios
- Invest time in proper fixes rather than temporary workarounds
- Regular refactoring to maintain code quality and prevent accumulation

## Writing and Communication

- If you're going to write a commit message or a github ticket in my name, you should review https://chris.prather.org to get my writing style and voice correct

## Project-Specific Testing Conventions

### Chalk Project
- Test command: `./prove` (custom Perl test harness)
- Test files: `t/**/*.t` (TAP format, run through chalk compiler)
- Timeout: Use 120s for complex parsing tests (e.g., num.t, rs.t)
- TODO tests: Mark overly ambitious test cases as TODO instead of removing them
- Core tests: `t/self-hosting.t`, `t/perl-base-tests.t`, `t/perl-class-tests.t`

## Git Workflow Standards

### General
- Study recent commits with `git log --oneline -20` to match voice and style
- Use `gh` CLI for all GitHub operations
- After PR merge: ALWAYS switch to default branch and pull before starting new work

### Chalk Project
- Default branch: `pu` (not main/master)
- Feature branches: Create from `pu`, merge back to `pu`
- Use `/merge-continue` command after PR merges to clean up

## GitHub Issue Management

- Use `gh` CLI for all GitHub operations
- Label issues with: component, effort (low/medium/complex), impact, type (bug/enhancement)
- Create issues for: future work, skipped tests, stubbed features, technical debt
- Reference related issues when creating new ones

### Issue Update Checklist
When reviewing/updating issues (use `/update-issue` command):
- [ ] Remove outdated "phase" or "prerequisite" references
- [ ] Update "Current State" section with checkboxes (✅ done, ❓ unknown, ❌ not done)
- [ ] Convert task lists to reflect actual implementation status
- [ ] Add "Related Issues" section linking dependencies/successors
- [ ] Add "Related PRs" section linking to implementations
- [ ] Document any decisions or direction changes

### Issue Lifecycle
1. **Review**: Check if issue is still relevant to current goals
2. **Update**: Reflect current implementation state, not theory
3. **Close**: If superseded by other issues, explain why and link
4. **Link**: Always cross-reference related work

### Branch Protection Workflow
When working with protected branches:
1. NEVER push directly to protected branches (pu, main, master)
2. Push to feature branch: `git push origin HEAD:feature-name`
3. Create PR: Use `/create-feature-pr` command
4. After merge: Use `/post-merge-cleanup` command

### PR Creation Standards
- Use `gh pr create --head BRANCH --base TARGET`
- Include statistics: files changed, lines added/removed
- Reference related issues with #NUMBER in description
- Add "Related Issues" section in PR body
- Provide brief test status
- Correctness > Performance always (we can always find ways to make correct code faster, we can't always find ways to make fast code correct)