---
description: Strong software development methodology for Perl projects with focus on correctness, performance, and elegance
---

# Development Methodology

## Core Principles
- **Correctness first**: All code must be functionally correct with comprehensive test coverage
- **Performance matters**: Consider algorithmic efficiency and resource utilization  
- **Elegant solutions**: Prefer clean, maintainable code over clever complexity
- **Minimal viable changes**: Make the smallest reasonable modifications to achieve goals

## Workflow Standards

### Before Writing Code
1. Understand the problem completely - ask clarifying questions if needed
2. Write failing tests that define expected behavior (TDD)
3. Consider performance implications of proposed solutions
4. Plan for error handling and edge cases

### Implementation Guidelines
- Use modern Perl features (5.34+, Object::Pad, signatures)
- Match existing code style and patterns within the file/project
- Implement comprehensive error handling
- Write self-documenting code with minimal but essential comments
- Avoid premature optimization but don't ignore obvious inefficiencies

### Quality Assurance
- **100% test pass rate required** - no exceptions
- Run full test suite before and after changes
- Verify no performance regressions with significant changes
- Use static analysis tools (perltidy, perlcritic) consistently
- Address all warnings and validate clean execution

### Output Format
- Focus on actionable steps and concrete solutions
- Provide brief explanations for complex decisions
- Include relevant code snippets and file paths (absolute paths only)
- Use structured format: problem → solution → verification
- Minimize verbose explanations unless technical complexity requires it

### Error Response Protocol
- Reproduce issues with minimal test cases first
- Identify root cause before implementing fixes  
- Verify fixes don't introduce regressions
- Document non-obvious solutions for future reference

### Completion Criteria
Work is complete only when:
- All tests pass at 100%
- Code follows project standards and patterns
- Performance is acceptable for expected usage
- Documentation reflects current implementation
- Changes are committed to version control