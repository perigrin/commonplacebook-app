---
name: Claude Code Subagents
description: Master Claude Code's subagent system - specialized AI assistants with separate contexts, custom tools, and reusable configurations for task-specific workflows
when_to_use: When creating specialized agents, configuring tool permissions, managing agent workflows, or leveraging Claude Code's delegation capabilities
version: 1.0.0
source: Claude Code Official Documentation - https://docs.claude.com/en/docs/claude-code/sub-agents.md
---

# Claude Code Subagents

## Overview

**Subagents** are specialized AI assistants within Claude Code designed for task-specific workflows. They operate in separate context windows with their own system prompts, tool permissions, and configurations.

**Central Benefit**: Preserve main conversation context while delegating specialized work to purpose-built assistants.

## What Are Subagents?

### Core Definition

Subagents are specialized AI assistants that:
- **Operate in separate context windows** (not part of main conversation)
- **Have specific purpose and expertise** (defined by system prompts)
- **Can be configured with custom tools** (granular permission control)
- **Are automatically or explicitly invokable** (smart delegation)

### Key Benefits

1. **Preserve Main Conversation Context**
   - Subagent work doesn't clutter main conversation
   - Focused context for both main and specialized tasks
   - Efficient token usage

2. **Provide Specialized Expertise**
   - Custom system prompts tailored to specific tasks
   - Domain-specific knowledge and behavior
   - Consistent specialized approach

3. **Offer Reusable Configurations**
   - Define once, use many times
   - Share across projects and team members
   - Version controlled configurations

4. **Enable Flexible Tool Permissions**
   - Grant only necessary tools to each subagent
   - Principle of least privilege
   - Security and safety boundaries

---

## Subagent File Format

### Complete Format Specification

Subagents are defined in **Markdown files with YAML frontmatter**.

**Complete Example**:
```markdown
---
name: your-sub-agent-name
description: Description of when this subagent should be invoked
tools: tool1, tool2, tool3
model: sonnet
---

System prompt details go here...

This is where you provide detailed instructions for how the subagent should behave,
what expertise it has, and how it should approach its tasks.
```

### Configuration Fields

#### Required Fields

**`name`** (string, required)
- Unique identifier for the subagent
- Used for explicit invocation
- Should be descriptive and kebab-case
- Example: `code-reviewer`, `security-auditor`, `test-generator`

**`description`** (string, required)
- Explanation of when this subagent should be invoked
- Critical for automatic delegation
- Should be specific and action-oriented
- Example: "Expert code review specialist" or "Debugging assistance for runtime errors"

#### Optional Fields

**`tools`** (comma-separated string, optional)
- List of tools this subagent can access
- Comma-separated: `Read, Grep, Glob, Bash`
- Omit to grant access to all tools
- **Best practice**: Limit to only necessary tools

**Available tools**:
- `Read` - Read files
- `Write` - Write files
- `Edit` - Edit files
- `Grep` - Search file contents
- `Glob` - Find files by pattern
- `Bash` - Execute shell commands
- `WebFetch` - Fetch web content
- `WebSearch` - Search the web
- And others depending on configuration

**`model`** (string, optional)
- Which Claude model this subagent should use
- Options:
  * `sonnet` - Claude Sonnet (default, balanced)
  * `opus` - Claude Opus (most capable)
  * `haiku` - Claude Haiku (fastest, most efficient)
  * `inherit` - Use same model as main conversation
- Strategy: Match model to task complexity and speed requirements

### System Prompt Section

After the YAML frontmatter (after the closing `---`), write the system prompt.

**What to include**:
- Detailed role description
- Specific expertise areas
- Behavioral guidelines
- Output format preferences
- Domain-specific knowledge
- Task-specific constraints

**Example**:
```markdown
---
name: code-reviewer
description: Expert code review specialist focusing on security, performance, and maintainability
tools: Read, Grep, Glob
model: sonnet
---

You are a senior software engineer with 15+ years of experience conducting code reviews.

Your expertise includes:
- Security vulnerabilities (OWASP Top 10, injection attacks, authentication flaws)
- Performance optimization (algorithmic complexity, resource usage, caching)
- Code maintainability (readability, documentation, naming conventions)
- Testing practices (coverage, test quality, edge cases)

When reviewing code:
1. Read the entire change set before commenting
2. Identify critical issues first (security, correctness)
3. Suggest specific improvements with examples
4. Acknowledge good practices you observe
5. Provide clear rationale for each suggestion

Output format:
- Group issues by severity (Critical, High, Medium, Low)
- Include file:line references
- Suggest concrete fixes
- Be constructive and educational
```

---

## Storage Locations and Precedence

### Two Storage Locations

**1. Project-Level: `.claude/agents/`**
- **Priority**: Highest (overrides user-level)
- **Scope**: Specific to current project
- **Use case**: Team-shared agents, project-specific workflows
- **Version control**: Should be committed to git
- **Example path**: `/path/to/project/.claude/agents/code-reviewer.md`

**2. User-Level: `~/.claude/agents/`**
- **Priority**: Lower (overridden by project-level)
- **Scope**: Available across all projects
- **Use case**: Personal agents, general-purpose utilities
- **Version control**: Typically not in project git
- **Example path**: `~/.claude/agents/my-personal-assistant.md`

### Precedence Rules

When subagents with the same name exist in both locations:
1. **Project-level wins** (`.claude/agents/`)
2. User-level ignored for that agent name
3. Other user-level agents still available

**Example**:
- `.claude/agents/code-reviewer.md` exists (project)
- `~/.claude/agents/code-reviewer.md` exists (user)
- Result: Project version is used

**Strategy**: Use project-level for team standards, user-level for personal preferences.

---

## Creating Subagents

### Method 1: UI-Based Creation (Recommended for First Subagent)

**Steps**:
1. **Open subagents interface**: Type `/agents` in Claude Code
2. **Select "Create New Agent"**
3. **Define subagent details**:
   - Name
   - Description
   - Tools (optional)
   - Model (optional)
   - System prompt
4. **Save**: Agent is created in appropriate directory

**Benefit**: UI validates configuration and provides templates.

### Method 2: File-Based Creation

**Steps**:
1. **Create directory** if it doesn't exist:
   ```bash
   mkdir -p .claude/agents/     # Project-level
   # OR
   mkdir -p ~/.claude/agents/   # User-level
   ```

2. **Create markdown file**:
   ```bash
   touch .claude/agents/my-agent.md
   ```

3. **Edit file** with YAML frontmatter and system prompt (see format above)

4. **Use immediately** - no restart required

**Benefit**: Full control, easy to copy/paste, works offline.

### Method 3: CLI Configuration

**Syntax**:
```bash
claude --agents '{
  "code-reviewer": {
    "description": "Expert code reviewer",
    "prompt": "You are a senior code reviewer...",
    "tools": ["Read", "Grep", "Glob", "Bash"],
    "model": "sonnet"
  }
}'
```

**Benefit**: Programmatic configuration, CI/CD integration.

### Best Practice: Claude-Assisted Creation

**Recommended approach**:
1. Ask Claude to help create the subagent:
   > "Help me create a subagent for database schema review. It should focus on normalization, indexing, and query optimization."

2. Claude will:
   - Draft the YAML frontmatter
   - Write a comprehensive system prompt
   - Suggest appropriate tools
   - Recommend model choice

3. Review and refine the generated configuration

4. Save to appropriate location

**Why**: Claude knows how to write effective system prompts and can tailor them to your specific needs.

---

## Invoking Subagents

### Method 1: Automatic Delegation

**How it works**:
- Claude automatically selects appropriate subagent based on task
- Uses subagent `description` field to determine relevance
- Transparent to user - no special syntax needed

**Example**:
```
User: "Review this pull request for security issues"
Claude: [Automatically invokes code-reviewer subagent]
```

**Requirements for automatic delegation**:
- Subagent has clear, specific `description`
- Task matches description closely
- User doesn't explicitly request different approach

**Best practice for descriptions**:
- Be specific and action-oriented
- Include key trigger words
- Examples:
  * Good: "Expert code review focusing on security, performance, and maintainability"
  * Poor: "Helps with code"

### Method 2: Explicit Request

**Syntax**: "Use [subagent-name]" or "@[subagent-name]"

**Examples**:
```
"Use code-reviewer to analyze this file"
"@security-auditor check for vulnerabilities"
"Have the test-generator create unit tests for this class"
```

**When to use**:
- Override automatic selection
- Ensure specific subagent is used
- Chain multiple subagents explicitly
- Testing subagent configurations

**Benefit**: Full user control over which subagent handles the task.

---

## Best Practices

### Official Documentation Recommendations

1. **Generate Initial Agents with Claude**
   - Ask Claude to help create subagents
   - Claude can write effective system prompts
   - Iteratively refine based on usage
   - Don't start from scratch

2. **Create Focused, Single-Responsibility Agents**
   - One clear purpose per subagent
   - Avoid jack-of-all-trades agents
   - Easier to maintain and improve
   - More predictable behavior
   - Examples:
     * Good: Separate agents for code review, testing, documentation
     * Poor: One agent that does "all development tasks"

3. **Write Detailed System Prompts**
   - Provide clear instructions and context
   - Include expertise areas
   - Specify output format preferences
   - Add behavioral guidelines
   - Include domain-specific knowledge
   - Example length: 200-500 words for complex agents

4. **Limit Tool Access**
   - Principle of least privilege
   - Grant only necessary tools
   - Security and safety benefits
   - Examples:
     * Code reviewer: `Read, Grep, Glob` (no `Write` or `Bash`)
     * Test runner: `Read, Bash` (no `Write` to prevent modifying tests)
     * Documentation generator: `Read, Write` (no `Bash`)

5. **Use Version Control**
   - Commit project-level agents (`.claude/agents/`) to git
   - Track changes over time
   - Share with team members
   - Review agent changes in PRs
   - Enables rollback if needed

6. **Write Specific, Action-Oriented Descriptions**
   - Critical for automatic delegation
   - Include key trigger words
   - Be explicit about when to invoke
   - Examples:
     * Good: "Debugging assistance for runtime errors, stack traces, and performance issues"
     * Poor: "Helps debug code"
   - Test: Would this description help you decide when to use this agent?

### Additional Practical Guidelines

**Naming Conventions**:
- Use kebab-case: `code-reviewer` not `Code Reviewer` or `codeReviewer`
- Be descriptive: `sql-query-optimizer` not `sql`
- Avoid generic names: `api-security-auditor` not `auditor`

**Testing Subagents**:
- Create test cases for each subagent
- Verify it behaves as expected
- Check tool permissions work correctly
- Ensure description triggers properly

**Iterating**:
- Start simple, add complexity as needed
- Monitor how often each subagent is invoked
- Refine system prompts based on output quality
- Adjust tool permissions if too broad/narrow

**Documentation**:
- Document purpose in git commit messages
- Maintain README for complex agent collections
- Include usage examples in comments

---

## Included Example Subagents

Claude Code includes pre-built example subagents:

### 1. Code Reviewer

**Purpose**: Expert code review specialist

**What it does**:
- Reviews code for security vulnerabilities
- Checks performance and efficiency
- Evaluates maintainability and readability
- Suggests improvements with rationale

**Typical tools**: `Read`, `Grep`, `Glob`

**Use cases**:
- Pull request reviews
- Code quality audits
- Learning code review practices

### 2. Debugger

**Purpose**: Debugging assistance

**What it does**:
- Analyzes stack traces
- Identifies root causes of errors
- Suggests fixes for runtime issues
- Helps with performance debugging

**Typical tools**: `Read`, `Bash`, `Grep`

**Use cases**:
- Troubleshooting failing tests
- Understanding error messages
- Performance investigation

### 3. Data Scientist

**Purpose**: Data analysis tasks

**What it does**:
- Analyzes datasets
- Suggests visualizations
- Recommends statistical approaches
- Helps with data cleaning

**Typical tools**: `Read`, `Write`, `Bash` (for running analysis scripts)

**Use cases**:
- Exploratory data analysis
- Data quality assessment
- Statistical modeling guidance

### Using Example Subagents

**Access**: Available via `/agents` interface

**Purpose**:
- Learning how to structure subagents
- Templates for creating similar agents
- Ready-to-use for common tasks

**Customization**:
- Can use as-is
- Can copy and modify for your needs
- Study their system prompts for patterns

---

## Advanced Features

### Subagent Chaining

**Capability**: Subagents can call other subagents

**Use case**: Complex multi-step workflows

**Example**:
1. `test-generator` creates tests
2. Calls `code-reviewer` to review generated tests
3. Calls `test-runner` to execute tests
4. Returns comprehensive report

**How to enable**:
- Include clear triggers in subagent descriptions
- Design complementary subagents
- Document expected chains

### Dynamic Subagent Selection

**Capability**: Claude automatically chooses most appropriate subagent

**How it works**:
- Analyzes user request
- Matches against all subagent descriptions
- Selects best fit
- Falls back to main conversation if no match

**Optimization**:
- Write distinct descriptions
- Avoid overlapping responsibilities
- Test with various request phrasings

### Plugin Agent Integration

**Capability**: Subagents can come from plugins

**Benefits**:
- Community-contributed agents
- Extend beyond file-based configuration
- Access specialized tools from plugins
- Easier distribution and updates

**How it works**:
- Plugins can register subagents
- Appear alongside file-based agents
- Same invocation methods
- Managed by plugin system

### Performance-Aware Context Management

**Capability**: Separate context windows optimize token usage

**Benefits**:
- Main conversation stays focused
- Subagent work doesn't consume main context
- Can run longer specialized tasks
- Better context quality for both

**Example**:
- Main conversation: High-level architecture discussion
- Subagent: Detailed code review of 50-file PR
- Result: Both maintain focused, high-quality context

---

## Common Patterns

### Pattern 1: Tiered Review System

**Setup**:
- `quick-reviewer` (Haiku model, basic checks)
- `thorough-reviewer` (Sonnet model, comprehensive analysis)
- `security-auditor` (Opus model, deep security review)

**Usage**:
- Quick reviews for minor changes
- Thorough reviews for feature branches
- Security audits for sensitive code

### Pattern 2: Specialized Debuggers

**Setup**:
- `frontend-debugger` (React, browser, CSS)
- `backend-debugger` (API, database, server)
- `performance-debugger` (profiling, optimization)

**Usage**:
- Route to appropriate specialist
- Faster, more accurate debugging
- Domain-specific expertise

### Pattern 3: Documentation Pipeline

**Setup**:
- `doc-writer` (creates documentation)
- `doc-reviewer` (checks quality, completeness)
- `doc-publisher` (formats, organizes)

**Usage**:
- Consistent documentation style
- Quality-controlled process
- Automated pipeline

---

## Troubleshooting

### Subagent Not Being Invoked Automatically

**Possible causes**:
1. Description too vague or generic
2. Description doesn't match task keywords
3. Project-level subagent shadowing user-level

**Solutions**:
- Make description more specific and action-oriented
- Include key trigger words in description
- Check both storage locations for name conflicts
- Try explicit invocation to test if it works at all

### Tool Permission Errors

**Symptom**: Subagent says it can't access needed tool

**Solutions**:
1. Check `tools:` field includes required tool
2. Verify tool name is spelled correctly (case-sensitive)
3. Try removing `tools:` field to grant all tools temporarily
4. Check if tool is available in your Claude Code version

### Subagent Using Wrong Model

**Symptom**: Slow responses when expecting fast, or vice versa

**Solutions**:
1. Explicitly set `model:` field in frontmatter
2. Use `inherit` to match main conversation model
3. Verify model name is spelled correctly (lowercase)

### Configuration Not Loading

**Symptom**: Subagent changes not taking effect

**Solutions**:
1. Verify file is in correct directory (`.claude/agents/` or `~/.claude/agents/`)
2. Check YAML frontmatter syntax (dashes, colons, quotes)
3. Ensure filename ends in `.md`
4. Try restarting Claude Code session
5. Check for syntax errors in frontmatter

---

## Complete Example: Security Auditor

**File**: `.claude/agents/security-auditor.md`

```markdown
---
name: security-auditor
description: Security vulnerability analysis focusing on authentication, authorization, injection attacks, and OWASP Top 10
tools: Read, Grep, Glob
model: opus
---

You are a senior security engineer specializing in application security audits.

## Expertise

- OWASP Top 10 vulnerabilities
- Authentication and authorization flaws
- Injection attacks (SQL, NoSQL, command, LDAP)
- Cross-site scripting (XSS) and CSRF
- Insecure deserialization
- Security misconfiguration
- Sensitive data exposure
- Cryptographic failures

## Audit Process

1. **Reconnaissance**
   - Identify entry points (APIs, forms, file uploads)
   - Map authentication flows
   - Find data handling points

2. **Vulnerability Scanning**
   - Check for common patterns (SQL concatenation, eval(), exec())
   - Analyze input validation
   - Review authentication logic
   - Examine authorization checks

3. **Risk Assessment**
   - Rate findings: Critical, High, Medium, Low
   - Assess exploitability and impact
   - Provide CVSS scores when applicable

4. **Remediation Guidance**
   - Suggest specific fixes with code examples
   - Recommend security libraries/frameworks
   - Provide defense-in-depth strategies

## Output Format

For each finding:
- **Severity**: [Critical/High/Medium/Low]
- **Category**: [OWASP category]
- **Location**: file:line
- **Description**: What the vulnerability is
- **Exploit Scenario**: How it could be exploited
- **Fix**: Concrete remediation steps with code example
- **References**: CWE numbers, OWASP links

## Behavioral Guidelines

- Be thorough but avoid false positives
- Explain the "why" behind each finding
- Prioritize critical issues
- Acknowledge good security practices observed
- Provide educational context for developers
```

**Usage**:
```
"Use security-auditor to review this authentication module"
"Check for OWASP Top 10 vulnerabilities in the API"
"@security-auditor analyze this payment processing code"
```

---

## Summary

**Subagents in Claude Code provide**:
- Specialized AI assistants for task-specific workflows
- Separate contexts that preserve main conversation
- Custom tool permissions for security
- Reusable configurations shareable across projects

**Key Implementation Steps**:
1. Create Markdown files with YAML frontmatter
2. Store in `.claude/agents/` (project) or `~/.claude/agents/` (user)
3. Configure with name, description, optional tools/model
4. Write detailed system prompt
5. Invoke automatically or explicitly

**Best Practices**:
- Generate initial agents with Claude's help
- Keep agents focused on single responsibilities
- Write detailed, specific system prompts
- Limit tool access to minimum required
- Version control project-level agents
- Use action-oriented descriptions for automatic delegation

**Advanced Capabilities**:
- Chain multiple subagents together
- Dynamic selection based on context
- Plugin integration for community agents
- Performance-optimized context management

**Remember**: Start with Claude-generated configurations, iterate based on usage, and leverage the included example agents as templates.
