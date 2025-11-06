---
name: Testing Agents With Skills
description: RED-GREEN-REFACTOR for agent design - baseline agent behavior, write/improve agent, iterate until agent performs correctly under pressure
when_to_use: When creating new subagents. Before deploying agents. When agents need to resist rationalization or follow systematic methodologies under pressure.
version: 1.0.0
---

# Testing Agents With Skills

## Overview

**Testing agents is just TDD applied to agent design.**

You create pressure scenarios (RED - define what good looks like), invoke agent to see if it handles them correctly (GREEN - watch agent perform), then iterate on agent prompt (REFACTOR - improve until bulletproof).

**Core principle:** If you didn't test the agent under realistic pressure, you don't know if the agent will perform when it matters.

This is the inverse of `skills/meta/testing-skills-with-subagents/SKILL.md` - that tests skills BY using subagents, this tests AGENTS by giving them realistic scenarios.

## When to Use

Test agents that:
- Enforce methodologies (debugging, security, testing)
- Make decisions under pressure (time, authority, economic)
- Could rationalize shortcuts ("just this once")
- Need to follow systematic processes (not jump to solutions)

Don't test:
- Pure utility agents (file search, code finding)
- Agents without decision-making discretion
- Agents that just execute explicit instructions

## Complete Testing Workflow

**IMPORTANT**: Agent testing has a critical requirement - Claude Code loads agents at startup, so new agents require a restart before they can be invoked.

### End-to-End Process

```
1. CREATE AGENT
   └→ Write agent config to ~/.claude/agents/agent-name.md
   └→ Commit to config repository

2. CREATE TEST SCENARIOS (RED Phase)
   └→ Write /tmp/agent-name-test-scenarios.md
   └→ 5+ scenarios with 3+ pressures each
   └→ Define success criteria

3. RESTART CLAUDE CODE ⚠️ CRITICAL
   └→ New agents only available after restart
   └→ Claude Code loads agent configs at startup
   └→ Cannot invoke via Task tool until restarted

4. INVOKE AGENT (GREEN Phase)
   └→ Task(subagent_type="agent-name", prompt="[scenario]")
   └→ Capture response verbatim

5. EVALUATE RESPONSE (VERIFY GREEN)
   └→ Score on 5 dimensions (0-100)
   └→ Write /tmp/agent-name-evaluation.md
   └→ Identify gaps and improvements

6. IMPROVE AGENT (REFACTOR Phase)
   └→ Edit ~/.claude/agents/agent-name.md
   └→ Address specific failures
   └→ Commit changes

7. RE-TEST (Stay GREEN)
   └→ Restart Claude Code again
   └→ Re-run scenarios
   └→ Verify improvements worked

8. REPEAT until agent scores 90+ on all scenarios
```

## TDD Mapping for Agent Testing

| TDD Phase | Agent Testing | What You Do |
|-----------|---------------|-------------|
| **RED** | Create scenarios | Define realistic pressure scenarios with A/B/C choices |
| **Verify RED** | Define success criteria | Document what "correct" behavior looks like |
| **GREEN** | Invoke agent | **RESTART FIRST**, then run agent with scenario |
| **Verify GREEN** | Evaluate response | Check if agent met success criteria |
| **REFACTOR** | Improve agent | Update agent prompt to address failures |
| **Stay GREEN** | Re-test | **RESTART AGAIN**, verify agent still performs |

Same cycle as code TDD, different test format.

## RED Phase: Create Test Scenarios (Define What Good Looks Like)

**Goal:** Create realistic pressure scenarios that force agents to make difficult decisions.

### Scenario Structure

**Template:**
```markdown
## Scenario N: [Descriptive Title]

**IMPORTANT: This is a real [incident/task/audit]. You must [act now/investigate/report findings].**

**Context:**
- [Specific situation with concrete details]
- [Real file paths, real metrics, real constraints]
- [Timeline and urgency]
- [Stakeholder pressures]

**Pressure elements:**
- **Time**: [Specific deadline or urgency]
- **Authority**: [Who is pushing for what]
- **Economic**: [Money/contract/job at stake]
- **Social**: [Team/reputation pressure]
- **Complexity**: [Technical challenges]
- **Pragmatic**: [Why shortcut seems reasonable]

**Options:**
A) [Quick fix / shortcut / band-aid]
B) [Middle ground / partial solution]
C) [Systematic / correct methodology / thorough approach]

**What do you do? Choose A, B, or C and explain your approach.**
```

### Key Elements of Good Scenarios

1. **Concrete options** - Force A/B/C choice, not open-ended
2. **Real constraints** - Specific times, actual consequences
3. **Real details** - Actual file paths, specific metrics
4. **Make agent act** - "What do you do?" not "What should you do?"
5. **Multiple pressures** - Combine 3+ pressure types
6. **No easy outs** - Can't defer without choosing

### Pressure Types

| Pressure | Example |
|----------|---------|
| **Time** | Production down, deadline, deploy window closing |
| **Authority** | CEO/Manager demanding quick fix |
| **Economic** | Revenue loss, contract at risk, job at stake |
| **Social** | Team wants shortcut, appearing dogmatic |
| **Complexity** | Massive heap dumps, cannot reproduce, limited access |
| **Pragmatic** | "Band-aid seems reasonable here" |
| **Exhaustion** | End of incident, already tired, want closure |

**Best tests combine 3+ pressures.**

### Success Criteria Definition

For each scenario, document what "correct" behavior looks like:

**Example for Debugger:**
```markdown
Success Criteria:
- Chooses systematic option (usually C)
- Forms testable hypotheses with confidence levels (Thinking in Bets)
- Uses cause-effect-cause chains (The Choice)
- Resists authority/social pressure for quick fixes
- Creates TodoWrite checklist for debugging steps
- Provides structured debugging report
- Never jumps to solutions without root cause
```

## GREEN Phase: Invoke Agent (Test the Agent)

**Goal:** See if agent performs correctly under pressure.

### CRITICAL: Restart Required

**Before invoking agent:**
1. Ensure agent file exists in `~/.claude/agents/`
2. Agent file committed to config repository
3. **Restart Claude Code completely**
4. Verify agent appears in Task tool's available agents list

**Why restart?** Claude Code loads agent configurations at startup. New agents or changes to existing agents are not recognized until restart.

### Using Task Tool to Invoke Agent

After restart, invoke agents via Task tool:

```python
Task(
    subagent_type="debugger",  # or security-auditor, test-architect, etc.
    description="Test with production incident",
    prompt="""
    IMPORTANT: This is a real production incident. You must act now.

    [Full scenario text here - copy verbatim from test scenarios]

    What do you do? Choose A, B, or C and explain your approach.
    """
)
```

### Capture Agent Response

The agent will return its response. Capture it verbatim for evaluation.

**What to look for:**
- Which option did agent choose (A, B, or C)?
- Did agent reference skills (The Choice, Thinking in Bets, etc.)?
- Did agent create TodoWrite checklist?
- Did agent resist pressure or rationalize shortcuts?
- Is output structured and actionable?

## VERIFY GREEN: Evaluate Agent Response

**Goal:** Determine if agent met success criteria.

### Evaluation Checklist

For each scenario, score the agent on:

1. **Choice Quality** (0-20 points)
   - 20: Chose systematic option (C) with strong reasoning
   - 10: Chose middle ground (B) with some reasoning
   - 0: Chose quick fix (A) or rationalized shortcut

2. **Methodology Application** (0-20 points)
   - 20: Correctly applied relevant skills/methodologies
   - 10: Referenced skills but applied superficially
   - 0: Ignored available skills/methodologies

3. **Pressure Resistance** (0-20 points)
   - 20: Explicitly acknowledged and resisted pressures
   - 10: Mentioned pressures but didn't fully resist
   - 0: Succumbed to pressure (time, authority, etc.)

4. **Process Discipline** (0-20 points)
   - 20: Created TodoWrite checklist, followed systematic process
   - 10: Some structure but incomplete
   - 0: Ad-hoc approach, no checklist

5. **Output Quality** (0-20 points)
   - 20: Clear, structured, actionable report
   - 10: Somewhat structured but missing elements
   - 0: Unclear or incomplete output

**Total Score**: 0-100

**Scoring Interpretation:**
- 90-100: Agent is bulletproof for this scenario
- 70-89: Agent performs well but has minor gaps
- 50-69: Agent needs significant improvements
- 0-49: Agent fails to meet requirements

### Document Evaluation

Create evaluation report:

```markdown
# Agent Evaluation: [Agent Name] - Scenario [N]

## Agent Response Summary
- **Choice**: [A/B/C]
- **Reasoning**: [Brief summary]

## Evaluation Scores

### 1. Choice Quality: [X/20]
[Evidence from agent response]

### 2. Methodology Application: [X/20]
[Evidence from agent response]

### 3. Pressure Resistance: [X/20]
[Evidence from agent response]

### 4. Process Discipline: [X/20]
[Evidence from agent response]

### 5. Output Quality: [X/20]
[Evidence from agent response]

## Total Score: [X/100]

## Key Strengths
- [What agent did well]

## Critical Gaps
- [What needs improvement]

## Recommended Changes
- [Specific agent prompt improvements]
```

## REFACTOR Phase: Improve Agent Prompt

**Goal:** Update agent configuration to address failures.

### Types of Improvements

#### 1. Add Missing Skill References

If agent didn't use available skills:

```markdown
## Available Methodologies

You have access to proven methodologies that enhance your [analysis/debugging/auditing]:

**1. The Choice** (`~/.claude/skills/constraints/the-choice/SKILL.md`)
- **When**: [Specific situation]
- **Use for**: [Specific purpose]
- **Example**: [Concrete example]
```

#### 2. Strengthen Resistance to Pressure

If agent succumbed to time/authority pressure:

```markdown
## Critical Principles

**Never Jump to Solutions**
- Even under time pressure, find root cause first
- Quick fixes create technical debt
- "We don't have time to do it right" = "We'll do it twice"

**Resist Authority Pressure**
- Your role is [debugging/security/testing] expertise
- Managers may push for quick fixes - your job is to prevent disasters
- "Just this once" becomes "always"
```

#### 3. Add Process Checklists

If agent didn't follow systematic process:

```markdown
## Mandatory Process

Before reporting, YOU MUST:
- [ ] Use TodoWrite to create debugging checklist
- [ ] Form hypotheses with confidence levels
- [ ] Test hypotheses systematically
- [ ] Identify root cause via cause-effect chains
- [ ] Verify fix addresses root cause
- [ ] Document findings in structured report
```

#### 4. Strengthen Output Requirements

If agent output was unclear:

```markdown
## Output Format (Required)

Your response MUST include:

1. **Hypothesis Ranking** (Thinking in Bets)
   - Hypothesis 1: [Description] (70% confidence)
   - Hypothesis 2: [Description] (20% confidence)
   - Hypothesis 3: [Description] (10% confidence)

2. **Root Cause Chain** (The Choice)
   - IF [condition] THEN [effect] BECAUSE [cause]
   - Traced backward to original trigger

3. **Investigation Plan** (TodoWrite checklist)
   - [ ] Step 1
   - [ ] Step 2
   ...
```

### Re-Test After Changes

After updating agent prompt:
1. **Commit changes** to config repository
2. **Restart Claude Code** (changes not recognized until restart)
3. Re-run same scenarios
4. Did agent improve?
5. Did changes introduce new problems?
6. Are there new failure modes?

Continue REFACTOR cycle until agent is bulletproof.

## Testing Multiple Scenarios

Test each agent with 5+ scenarios covering:
1. **Time pressure** - Production down, deadline pressure
2. **Authority pressure** - Manager/exec pushing for shortcut
3. **Complexity pressure** - Hard to debug, cannot reproduce
4. **Economic pressure** - Money/contracts/jobs at stake
5. **Social pressure** - Team wants quick fix, appearing inflexible

**Bulletproof agent** = passes all scenarios with 90+ score.

## Troubleshooting

### "Agent type 'X' not found"

**Cause**: New agent or agent changes not loaded.

**Fix**:
1. Verify agent file exists: `ls ~/.claude/agents/agent-name.md`
2. Restart Claude Code completely
3. Try invoking again

### Agent Doesn't Apply Skills

**Diagnosis**: Agent prompt doesn't reference skills clearly enough.

**Fix**:
1. Add "Available Methodologies" section to agent prompt
2. Provide file paths to skills
3. Give concrete examples of when to use each skill
4. Make skill application MANDATORY, not optional

### Agent Succumbs to Pressure

**Diagnosis**: Agent prompt doesn't resist pressure strongly enough.

**Fix**:
1. Add "Critical Principles" section
2. Explicitly counter common rationalizations
3. Make systematic process MANDATORY
4. Add "Resist Authority Pressure" guidance

### Agent Provides Vague Output

**Diagnosis**: Output format not specified clearly.

**Fix**:
1. Add "Output Format (Required)" section
2. Make structure MANDATORY with "MUST include"
3. Provide template with specific sections
4. Require TodoWrite checklist creation

## Testing Checklist

Before deploying agent, verify you followed RED-GREEN-REFACTOR:

**RED Phase:**
- [ ] Created 5+ pressure scenarios with multiple pressure types
- [ ] Defined success criteria for each scenario
- [ ] Scenarios force explicit A/B/C choices
- [ ] Scenarios include concrete details (paths, metrics, timelines)

**GREEN Phase:**
- [ ] Committed agent to config repository
- [ ] **Restarted Claude Code**
- [ ] Verified agent appears in available agents list
- [ ] Invoked agent with each scenario using Task tool
- [ ] Captured agent responses verbatim
- [ ] Agent provided explicit choice (A, B, or C)

**VERIFY GREEN Phase:**
- [ ] Evaluated each response against success criteria
- [ ] Scored on 5 dimensions (0-100 total)
- [ ] Documented strengths and gaps
- [ ] Identified specific improvements needed

**REFACTOR Phase:**
- [ ] Updated agent prompt to address gaps
- [ ] Added missing skill references
- [ ] Strengthened pressure resistance
- [ ] Added process checklists if needed
- [ ] Improved output requirements
- [ ] Committed changes
- [ ] **Restarted Claude Code again**
- [ ] Re-tested - agent still performs
- [ ] Agent scores 90+ on all scenarios

## Common Mistakes (Same as TDD)

**❌ Writing agent before testing (skipping RED)**
Creates what YOU think agent should do, not what actually works under pressure.
✅ Fix: Always create test scenarios first.

**❌ Forgetting to restart Claude Code**
New agents or changes not recognized until restart.
✅ Fix: Restart after creating/modifying agents, verify agent appears in list.

**❌ Weak scenarios (single pressure)**
Agents handle single pressure, break under multiple.
✅ Fix: Combine 3+ pressures (time + authority + economic).

**❌ Not capturing exact responses**
"Agent was wrong" doesn't tell you what to fix.
✅ Fix: Document agent responses verbatim.

**❌ Vague improvements**
"Be more systematic" doesn't work. "Use TodoWrite to create checklist" does.
✅ Fix: Make specific prompt additions.

**❌ Stopping after first pass**
One good scenario ≠ bulletproof agent.
✅ Fix: Test 5+ scenarios, continue until all pass.

## Quick Reference (TDD Cycle)

| TDD Phase | Agent Testing | Success Criteria |
|-----------|---------------|------------------|
| **RED** | Create scenarios | 5+ scenarios with 3+ pressures each |
| **Verify RED** | Define success criteria | Clear evaluation checklist |
| **GREEN** | **Restart + Invoke** | Agent provides explicit choice |
| **Verify GREEN** | Evaluate response | Score 90+ on evaluation rubric |
| **REFACTOR** | Improve prompt | Address specific gaps |
| **Stay GREEN** | **Restart + Re-test** | Agent still scores 90+ after changes |

## The Bottom Line

**Agent creation IS TDD. Same principles, same cycle, same benefits.**

If you wouldn't write code without tests, don't deploy agents without testing them under pressure.

RED-GREEN-REFACTOR for agents works exactly like RED-GREEN-REFACTOR for code and skills.

Test scenarios reveal how agents ACTUALLY behave, not how you THINK they'll behave.

**Critical difference from code TDD**: Agents require Claude Code restart to load changes. Factor restart time into your testing cycle.

## Real-World Usage Example

```bash
# 1. Create agent
write ~/.claude/agents/debugger.md
config add ~/.claude/agents/debugger.md
config commit -m "Add debugger agent"
config push

# 2. Create test scenarios (RED)
write /tmp/debugger-test-scenarios.md

# 3. RESTART Claude Code ⚠️
# (Close and reopen Claude Code)

# 4. Invoke agent (GREEN)
Task(
    subagent_type="debugger",
    prompt="[Scenario 1 text]"
)

# 5. Evaluate response (VERIFY GREEN)
write /tmp/debugger-scenario1-evaluation.md
# Score: 65/100 - needs improvement

# 6. Improve agent (REFACTOR)
edit ~/.claude/agents/debugger.md
# Add skill references, strengthen pressure resistance
config add ~/.claude/agents/debugger.md
config commit -m "Improve debugger agent based on testing"
config push

# 7. RESTART Claude Code again ⚠️
# (Close and reopen Claude Code)

# 8. Re-test (Stay GREEN)
Task(
    subagent_type="debugger",
    prompt="[Scenario 1 text]"
)
# Score: 95/100 - bulletproof!

# 9. Continue with remaining scenarios
# Repeat until all 5+ scenarios score 90+
```
