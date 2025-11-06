---
name: Escape Velocity - Beyond Story Points and Velocity
description: Systematic critique of velocity as a metric, explaining why it fails (lagging indicator of complex system, Goodhart's Law, no baseline), and providing actionable alternatives using lead time with probability distributions, Cumulative Flow Diagrams, throughput-based forecasting, and the actionable vs. vanity metrics framework
when_to_use:
  - SYMPTOM - Team tracking velocity but it varies wildly (23, 31, 19, 28, 22, 35 points)
  - SYMPTOM - Management wants to compare velocity across teams or use it as performance target
  - SYMPTOM - Velocity going up but actual output going down (gaming the metric)
  - SYMPTOM - Team needs to forecast completion but velocity is unreliable
  - SYMPTOM - Work piling up in columns but no visibility until retrospective
  - SYMPTOM - Dashboard shows vanity metrics (velocity, code coverage, happiness scores) but unclear what action to take
  - SYMPTOM - Asked "when will we finish 50 stories?" and defaulting to story point estimation
  - SYMPTOM - Debates about whether 5 points means the same thing to different teams
version: 1.0.0
---

# Escape Velocity: Why Velocity Fails and What to Use Instead

**Core Insight**: Velocity is a lagging indicator of a complex system with irreducible variation. Using it to predict the future is like driving by looking in the rearview mirror. The solution isn't better velocity—it's different metrics entirely: lead time with probability distributions, throughput, and Cumulative Flow Diagrams.

---

## THE FUNDAMENTAL PROBLEM: WHY VELOCITY DOESN'T WORK

### Velocity Is a Lagging Indicator of a Complex System

**The Metaphor**: Using velocity to predict is like driving by looking only in the rearview mirror.

**Why This Fails**:

Software development is a **complex system** with multiple interacting variables:
- Story point estimation inconsistency (what's a 5? what's an 8?)
- Different team members with different skills and interpretations
- Scope changes mid-sprint
- Dependencies on external teams
- Production issues and interruptions
- Learning during implementation
- Technical debt discoveries
- Integration complexity that emerges

**Complex systems have irreducible variation**. You cannot eliminate it by averaging, "stabilizing," or "better estimating." The variation is inherent to the nature of the work.

**Velocity measures the past**. It tells you what happened after all these variables interacted. By the time you measure it, the information is historical. Using historical output in a complex system to predict future output assumes:
1. The same variables will interact the same way
2. No new variables will emerge
3. The system is stable and linear

**None of these are true in software development.**

**Real Example**:
Team's velocity over 6 sprints: 23, 31, 19, 28, 22, 35 points.
- Average: 26.3 points
- Standard deviation: ~5.8 points
- Coefficient of variation: 22%

What will next sprint be? **Unknown.** Why?
- 23-point sprint: Two people on vacation, production incident
- 31-point sprint: No interruptions, stories better understood than estimated
- 19-point sprint: Discovered technical debt, complete rewrite needed
- 35-point sprint: Three small stories inflated to 13 points each (Goodhart's Law)

**Each number is the OUTPUT of a complex system, not an INPUT you can control.**

---

## GOODHART'S LAW: WHEN THE MEASURE BECOMES THE TARGET

**Goodhart's Law**: "When a measure becomes a target, it ceases to be a good measure."

### The Predictable Pattern

**Scenario**: Management sets goal: "Increase velocity 20% this quarter."

**What happens** (this is inevitable, not a team failure):

1. **Estimate Inflation**:
   - Stories previously estimated at 5 points → now estimated at 8 points
   - Same work, different number
   - Velocity goes up, output stays same (or decreases)

2. **Cherry-Picking Stories**:
   - Team focuses on high-point stories
   - Ignores small but important work (bug fixes, refactoring, tech debt)
   - Metrics look good, product quality degrades

3. **Gaming Retrospective Calculations**:
   - Stories not quite done → "close enough, mark it complete"
   - Split stories retroactively to boost points
   - Redefine "done" to exclude testing or documentation

4. **The Ratchet Effect**:
   - Higher velocity becomes new baseline
   - Next quarter: "Increase another 20%"
   - Infinite inflation spiral

**This isn't a moral failure**. When you measure people on a number they can manipulate, they will manipulate it. The problem is using velocity as a performance target, not the people responding to incentives.

**The Solution**: Use metrics that can't be gamed because they're based on observable reality, not relative estimates. (See: Actionable vs. Vanity Metrics below.)

---

## THE NO BASELINE PROBLEM: STORY POINTS ARE RELATIVE

**The Core Issue**: Story points have **no baseline across teams** (or even within the same team over time).

### Why This Matters

**Team A**: 5 points = "I can finish this in a day with moderate effort"
**Team B**: 5 points = "This is complex enough we should discuss it"
**Team C**: 5 points = "This is medium complexity compared to our other work"

**These are NOT the same**. You cannot compare them.

**The Fibonacci Illusion**: Using Fibonacci numbers (1, 2, 3, 5, 8, 13) creates the illusion of precision and standardization. But:
- Team A's 5 might be Team B's 13
- Team A's 8 might be Team C's 3
- Same team's 5 in January ≠ same team's 5 in July (learning, turnover, codebase changes)

**Real Comparison Problem**:
- Team A velocity: 40 points/sprint
- Team B velocity: 25 points/sprint
- Manager conclusion: "Team A is more productive"

**Actual reality**:
- Team A delivers 6 features per sprint
- Team B delivers 8 features per sprint
- Team B is more productive, but has lower "velocity"

**Why?** Team B estimates conservatively (inflation factor ~0.5). Team A estimates generously (inflation factor ~1.8). The numbers are meaningless for comparison.

**The Fundamental Truth**: Story points are self-referential estimation units. They only have meaning within the specific team that created them, and only temporarily.

**Better comparison**: Count actual outcomes delivered (features shipped, value created, user problems solved), not relative effort estimates.

---

## THE ALTERNATIVE: LEAD TIME WITH PROBABILITY DISTRIBUTIONS

This is the **core alternative to velocity** for forecasting and planning.

### Lead Time vs. Cycle Time: Critical Distinction

**Cycle Time**: Time from "work started" to "work completed"
- Measures execution speed
- Starts when someone begins work
- Ends when work is done

**Lead Time**: Time from "work requested" to "work delivered"
- Measures total time including waiting
- Starts when customer/stakeholder makes request
- Ends when customer receives value
- **This is what stakeholders care about**

**Example**:
- Feature requested: Monday
- Started: Thursday (3-day wait)
- Completed: Following Monday (4 days of work)
- **Cycle Time**: 4 days
- **Lead Time**: 8 days

**For forecasting, use Lead Time** (includes all delays, not just execution).

### How to Use Lead Time with Probability Distributions

**Step 1: Track Historical Data**

Track the **last 30-50 items completed**. For each item, record:
- When was it requested?
- When was it delivered?
- Lead time = delivery date - request date

**Example data** (lead times in days):
```
3, 5, 7, 4, 12, 5, 6, 8, 4, 5, 9, 11, 6, 5, 7, 14, 6, 5, 8, 7,
6, 4, 5, 9, 10, 6, 7, 5, 8, 6, 13, 5, 7, 6, 4, 5, 9, 8, 6, 5,
7, 11, 6, 5, 8, 7, 6, 5, 4, 12
```

**Step 2: Create Probability Distribution**

Sort the data and find percentiles:
- **50th percentile (median)**: 6 days (half finish faster, half slower)
- **85th percentile**: 10 days (85% finish by this point)
- **95th percentile**: 13 days (95% finish by this point)

**Step 3: Provide Percentile Forecasts**

When asked "How long will this feature take?", answer:

**"Based on our last 50 items:**
- **50% confidence: 6 days** (as likely to finish earlier as later)
- **85% confidence: 10 days** (only 15% chance it takes longer)
- **95% confidence: 13 days** (high confidence, accounts for outliers)"

### Why This Is Better Than Velocity

**1. Forward-Looking**:
- Based on actual completion data
- Accounts for all sources of variation
- No estimation required

**2. Actionable**:
- Distribution widening → investigate (more variation entering system)
- Lead time trending up → bottleneck somewhere
- Outliers visible → examine root causes

**3. Honest About Uncertainty**:
- Provides range, not false precision
- Stakeholders can choose their risk tolerance
- No pretending we can predict exactly

**4. Based on Reality**:
- Uses actual delivered items
- Can't be gamed (work was delivered or it wasn't)
- Reflects true system behavior

**5. Re-forecasting**:
- Update weekly as new data arrives
- Distribution adjusts automatically
- Self-correcting over time

### Common Questions

**Q: What if the next item is different from past items?**
A: Break it into similar-sized items. If you can't, it's too big to estimate reliably anyway. The law of large numbers works better with more items of similar scope.

**Q: What if our process changed?**
A: Use data from after the change. If you improved process, lead time distribution should improve. The data tells you if the change worked.

**Q: What counts as an "item"?**
A: User story, feature, bug fix, any deliverable unit of value. Track what you deliver.

---

## CUMULATIVE FLOW DIAGRAMS: VISUALIZING SYSTEM HEALTH

**Cumulative Flow Diagrams (CFDs)** make bottlenecks, WIP, throughput, and lead time visible at a glance.

### What Is a CFD?

**Structure**:
- **X-axis**: Time (days, weeks)
- **Y-axis**: Cumulative count of items
- **Colored bands**: Each workflow state (To Do, In Progress, Code Review, Testing, Done)
- **Bands stack**: Each band shows total items that have reached that state

**Visual Appearance**:
Imagine a chart where colored bands flow from bottom to top over time:
```
          ┌─────────────────────────────── Done (dark blue)
          │  ┌──────────────────────────── Testing (green)
          │  │  ┌───────────────────────── Code Review (yellow)
          │  │  │  ┌────────────────────── In Progress (orange)
          │  │  │  │  ┌─────────────────── To Do (light blue)
Time ─────┴──┴──┴──┴──┴─────────────────>
```

### How to Read a CFD

**1. Expanding Band = Bottleneck**

If the "Code Review" band is getting wider over time:
- Items entering Code Review faster than exiting
- Work is accumulating (bottleneck)
- **Action**: Add code review capacity, pair review, automate checks

**2. Parallel Bands = Steady Flow**

If bands maintain consistent width:
- Input rate ≈ Output rate
- System is balanced
- **Action**: Continue monitoring

**3. Vertical Distance Between Bands = Work in Progress (WIP)**

Height of a band = items currently in that state:
- Large band = too much WIP in that state
- **Action**: Implement WIP limits, focus on finishing vs. starting

**4. Horizontal Distance = Lead Time**

Draw horizontal line from "To Do" to "Done":
- Horizontal distance = average lead time
- Increasing distance = lead time growing (bad)
- Decreasing distance = lead time shrinking (good)

**5. Slope of "Done" Band = Throughput**

Steeper slope = more items completed per time unit:
- Flattening = throughput decreasing (investigate)
- Steepening = throughput increasing (system improvement)

### Real-Time Bottleneck Detection

**Traditional Problem**: Work piles up in "Code Review." Team doesn't notice until retrospective 2 weeks later. By then, 15 items are blocked.

**With CFD**: On day 3, you see the "Code Review" band expanding. Immediate visibility:
- Tuesday: Band width = 2 items (normal)
- Wednesday: Band width = 4 items (growing)
- Thursday: Band width = 6 items (clear bottleneck)
- **Action taken Thursday**: Add reviewer, pair on reviews, halt new work until cleared

**Result**: Bottleneck cleared in 2 days instead of festering for 2 weeks.

### What CFDs Reveal Simultaneously

A single CFD shows:
1. **Bottlenecks**: Expanding bands
2. **WIP**: Vertical distance
3. **Throughput**: Slope of Done band
4. **Lead Time**: Horizontal distance across all bands
5. **Flow stability**: Smoothness of bands
6. **System changes**: Slope changes indicate process improvements or degradations

**No other single visualization provides this much system visibility.**

### Implementing CFDs

**Minimum Requirement**:
- Track items by state over time
- Most project management tools can generate CFDs
- Update daily or weekly

**Best Practice**:
- Display prominently (team monitors, dashboards)
- Review in standups: "Any expanding bands?"
- Use to guide WIP limits and capacity allocation

---

## ACTIONABLE VS. VANITY METRICS: THE EVALUATION FRAMEWORK

This framework helps you distinguish metrics that drive action from metrics that just make you feel good.

### Definitions

**Actionable Metric**: Tells you what to do.
- Changes in the metric suggest specific actions
- Identifies problems and their sources
- Connects to controllable factors
- **Example**: Lead time trending up → investigate process, check for bottlenecks, examine recent changes

**Vanity Metric**: Makes you feel good but doesn't guide action.
- Looks impressive on dashboards
- Doesn't suggest what to change
- May hide problems or create false confidence
- **Example**: Velocity = 32 points → so what? What should we do differently?

### The Test: "What Action Does This Metric Suggest?"

**Example Dashboard**:
- Velocity: 32 points
- Code coverage: 78%
- Team happiness: 4.2/5

**Apply the test**:

**Velocity = 32 points**:
- What should we do? Increase it? Decrease it? Keep it the same?
- Is 32 good or bad? No baseline.
- Can we compare to last sprint's 28? Maybe, but why was 28 different?
- **Verdict**: Vanity metric (tells us nothing actionable)

**Code coverage = 78%**:
- Should we increase coverage?
- Does 78% mean tests are good? (No - can have 100% coverage with terrible tests)
- Does it tell us where bugs are? (No)
- Does it identify untested critical paths? (Not necessarily)
- **Verdict**: Vanity metric (high coverage ≠ good tests, low coverage could mean focused testing)

**Team happiness = 4.2/5**:
- Why is it 4.2 and not 4.8?
- What should we change to improve it?
- Does correlation with productivity exist?
- **Verdict**: Vanity metric (symptom without diagnosis, unclear what to change)

### Common Actionable Metrics

**1. Lead Time Trends**:
- **Observation**: Lead time increased from 6 days (median) to 11 days over 4 weeks
- **Action**: Investigate what changed, check CFD for bottlenecks, interview team about obstacles

**2. Lead Time Distribution Width**:
- **Observation**: 85th percentile was 2x median (6→12), now 3x median (7→21)
- **Action**: More variation entering system, investigate outliers, look for new categories of complexity

**3. Deployment Frequency**:
- **Observation**: Deployed 3x/week, now 1x/week
- **Action**: What's blocking deployments? Testing bottleneck? Approval process? Fear of breaking things?

**4. Failed Deployment Rate**:
- **Observation**: 2% of deployments failed last month, 15% this month
- **Action**: What changed? New team members? Skipping steps? Technical debt? Need better testing?

**5. Cycle Time by Stage**:
- **Observation**: "Code Review" cycle time: was 4 hours, now 2 days
- **Action**: Not enough reviewers, need training, too much WIP, pair programming?

**6. Throughput (Items per Week)**:
- **Observation**: Completing 8 items/week, now 4 items/week
- **Action**: Check WIP (too much started?), check lead time (items taking longer?), team capacity issues?

**7. Work Item Age**:
- **Observation**: 5 items have been in progress > 10 days
- **Action**: Are they blocked? Too large? Need help? Should they be paused?

**8. Blocked Items Count**:
- **Observation**: 8 items blocked, was 2 last week
- **Action**: What's blocking them? External dependency? Missing information? Need escalation?

### Common Vanity Metrics

**Avoid these** (or combine with actionable metrics):

1. **Velocity**: No baseline, gameable, lagging, doesn't suggest action
2. **Lines of Code**: More code ≠ better, incentivizes bloat
3. **Code Coverage %**: Coverage ≠ quality, can game with empty tests
4. **Sprint Burndown**: Shows progress toward commitment (which may have been bad commitment)
5. **Number of Commits**: Encourages small meaningless commits
6. **Team Happiness Scores**: Symptom without diagnosis
7. **Number of Features**: Doesn't account for value, size, or quality
8. **Percentage of Sprint Completed**: Based on estimates (see velocity problems)

### Converting Vanity to Actionable

Sometimes you can convert vanity metrics by adding context:

**Vanity**: "Code coverage = 78%"
**Actionable**: "Code coverage decreased from 82% to 78% in critical authentication module, coverage of error paths dropped from 95% to 60%"
- **Action**: Review recent changes, ensure error handling tested

**Vanity**: "Velocity = 32 points"
**Actionable**: "Velocity variance increased from σ=4 to σ=9, coefficient of variation now 28%"
- **Action**: Investigate why variation increased, check for estimation inflation or sandbagging

### The Framework in Practice

When evaluating any metric, ask:

1. **Does this tell me what to do?** (If no → vanity)
2. **Does this connect to controllable factors?** (If no → vanity)
3. **Can this be gamed without improving reality?** (If yes → risky, likely vanity)
4. **Does a change in this metric suggest specific investigation or action?** (If no → vanity)
5. **Am I measuring this because it's easy or because it's useful?** (Easy ≠ useful)

**Remember**: Vanity metrics make stakeholders feel good. Actionable metrics make teams better.

---

## FORECASTING WITHOUT VELOCITY: THROUGHPUT-BASED APPROACH

You can forecast completion without estimating story points or using velocity.

### The Traditional Trap

**Product owner asks**: "We have 50 user stories left. When will we be done?"

**Traditional response**: "Let's estimate all 50 stories, sum the points, divide by average velocity, and forecast completion."

**Problems**:
1. Estimation takes time (waste)
2. Estimates are unreliable for distant work (everything is unknown)
3. Velocity varies (which average to use?)
4. Assumes future = past (complex system, not true)

### The Throughput-Based Alternative

**Definition of Throughput**: Count of items completed per time period.

**Example**: Team completed 6, 7, 4, 5, 6 stories per week over last 5 weeks.
- **Average throughput**: 5.6 items/week
- **Median throughput**: 6 items/week
- **Range**: 4-7 items/week

**Simple Forecast**:
50 stories ÷ 5.6 items/week = **8.9 weeks**

**But don't stop there.** Provide probability distribution:

### Probability-Based Throughput Forecasting

**Step 1: Calculate Throughput Distribution**

From last 10 weeks: 6, 7, 4, 5, 6, 8, 5, 5, 7, 6 items/week

Sorted: 4, 5, 5, 5, 6, 6, 6, 7, 7, 8

Percentiles:
- **50th percentile (median)**: 6 items/week
- **15th percentile (slower)**: 5 items/week
- **5th percentile (much slower)**: 4 items/week

**Step 2: Forecast with Confidence Levels**

**50 stories remaining:**

**50% confidence** (median throughput):
- 50 ÷ 6 items/week = **8.3 weeks**

**85% confidence** (15th percentile throughput):
- 50 ÷ 5 items/week = **10 weeks**

**95% confidence** (5th percentile throughput):
- 50 ÷ 4 items/week = **12.5 weeks**

**Response to product owner**:

"Based on our actual delivery rate over the last 10 weeks:
- **50% chance we finish in 8-9 weeks** (as likely to be faster as slower)
- **85% chance we finish in 10 weeks** (accounts for slower weeks)
- **95% chance we finish in 12-13 weeks** (accounts for bad luck, surprises)"

### Why This Works

**1. Based on Actual Data**:
- Not estimates, not wishes, not commitments
- Historical reality of what this team actually delivers

**2. No Estimation Required**:
- Don't estimate 50 stories
- Count them and divide by throughput
- Saves estimation time

**3. Honest About Uncertainty**:
- Provides range based on historical variation
- Stakeholder chooses their risk tolerance
- No false precision

**4. Self-Correcting**:
- Re-forecast weekly as new data arrives
- If throughput increases, forecast improves
- If throughput decreases, forecast adjusts

**5. Works With Any Item Size** (within reason):
- As long as items are roughly similar sized
- If wildly different, split large items or use lead time distribution instead

### Re-Forecasting as Work Progresses

**Week 1**: 50 stories, forecast 8-10 weeks
**Week 2**: 44 stories (completed 6), forecast 7-9 weeks (tracking median)
**Week 3**: 38 stories (completed 6), forecast 6-8 weeks (tracking median)
**Week 4**: 34 stories (completed 4, slower week), forecast 6-9 weeks (adjusted)

**The forecast adjusts based on reality, not hopes.**

### Combining with Lead Time

**Alternative Approach**: Use lead time distribution instead of throughput.

If median lead time is 6 days and you have 50 stories:
- **Sequential**: 50 × 6 days = 300 days (assumes one at a time, bad)
- **Parallel with WIP limit of 5**:
  - 10 batches of 5 items
  - 10 × 6 days = 60 days
  - Plus variation (use 85th percentile: 10 days)
  - 10 × 10 days = **100 days / 20 weeks**

**Better approach**: Use actual throughput (accounts for parallelism automatically).

### When to Use Which

**Use Throughput** when:
- Items are countable and roughly similar size
- You want simple forecast
- Historical throughput is stable

**Use Lead Time Distribution** when:
- Items vary significantly in size
- You want to forecast individual item completion
- You need to communicate per-item uncertainty

**Use Both** when:
- You want maximum visibility
- Stakeholders need different views
- They should converge (if not, investigate why)

---

## WHEN VELOCITY MIGHT BE OKAY (NUANCED VIEW)

Escape Velocity is not absolutist. Velocity isn't evil—it's **overused and misunderstood**.

### Contexts Where Velocity Might Be Acceptable

**1. Single Team, Internal Planning**:
- **Context**: Stable team, consistent sprint length, planning their own work
- **Use**: "Based on recent sprints, we think we can take on about 25-30 points"
- **Constraints**:
  - NOT compared to other teams
  - NOT used as performance target
  - NOT treated as commitment
  - Team understands it's estimate, not prediction
  - Combined with other metrics (lead time, throughput)

**2. Rough Capacity Check**:
- **Context**: Sprint planning, sanity-checking capacity
- **Use**: "We took 40 points last sprint and struggled. Let's take 30 this sprint."
- **Constraints**:
  - Directional only (more/less, not precise)
  - Based on feeling of load, not mathematics
  - Open to adjustment mid-sprint

**3. Historical Pattern Recognition**:
- **Context**: Team notices "we always take more than we can finish"
- **Use**: Velocity as feedback loop about over-commitment
- **Constraints**:
  - Diagnostic, not prescriptive
  - Leads to process change, not target-setting
  - Combined with qualitative reflection

### Critical Conditions

**Velocity might be okay IF AND ONLY IF**:

1. **Not a target**: No one is measured on it, incentivized by it, or compared by it
2. **Team-specific**: Never compared across teams or time periods
3. **Qualitative supplement**: Used as rough guide, not mathematical input
4. **Combined with better metrics**: Lead time, throughput, CFDs also tracked
5. **Team-owned**: Team decides how to use it, not imposed from above
6. **Disposable**: Team can stop using it without organizational resistance

**Even then, lead time distribution is better.** Velocity at best provides weak signal. Lead time provides strong signal.

### When Velocity Is NEVER Okay

**Reject velocity when**:

1. **Performance target**: "Increase velocity 20% this quarter"
2. **Team comparison**: "Team A has higher velocity than Team B"
3. **External reporting**: "Our velocity is 45" (to stakeholders, executives)
4. **Resource allocation**: "High velocity teams get more budget"
5. **Velocity as THE metric**: Only metric tracked, primary planning input
6. **Commitment treated as promise**: "You committed to 30 points, you only did 25"
7. **Predictive mathematics**: "30 points/sprint × 10 sprints = 300 points = done"

### The Philosophical Stance

**Escape Velocity argues**:
- Velocity is a **weak, gameable, lagging indicator**
- It's **overused** in most organizations
- Better alternatives exist (lead time, throughput, CFDs)
- If you're going to use velocity, use it minimally and carefully
- **But you probably shouldn't use it at all**

**The risk**: Even in "acceptable" contexts, velocity tends to creep toward misuse. Someone eventually asks to compare teams, or set targets, or report to executives. Then it becomes toxic.

**Safer approach**: Start with lead time and throughput from day one. Don't introduce velocity unless you have specific reason and guardrails.

---

## IMPLEMENTATION GUIDE

### Phase 1: Start Tracking Actionable Metrics

**Week 1-2: Data Collection**

1. **Track lead time**:
   - For each item: request date → delivery date
   - Store in spreadsheet or tool
   - Need 30-50 items minimum

2. **Track throughput**:
   - Count items completed per week
   - Track for 8-10 weeks minimum

3. **Implement CFD**:
   - Most tools (Jira, Azure DevOps, etc.) can generate
   - If not, track item counts by state manually
   - Update daily or weekly

**Week 3-4: Analysis**

1. **Calculate lead time distribution**:
   - 50th, 85th, 95th percentiles
   - Create visual histogram

2. **Calculate throughput distribution**:
   - Median, 15th percentile
   - Note variation

3. **Review CFD**:
   - Identify any expanding bands
   - Measure WIP, lead time, throughput from chart

### Phase 2: Use Metrics for Decisions

**Sprint/Week Planning**:
- **Replace**: "How many points can we take?"
- **With**: "Based on throughput, we complete ~6 items/week. Let's plan 6-7 items and see."

**Forecasting**:
- **Replace**: "Sum story points, divide by velocity"
- **With**: "50 items, throughput is 6/week, forecast 8-10 weeks at 85% confidence"

**Bottleneck Detection**:
- **Replace**: Waiting for retrospective
- **With**: Check CFD daily, act on expanding bands immediately

**Progress Reporting**:
- **Replace**: "Velocity this sprint was 32 points"
- **With**: "Completed 7 items, median lead time 5 days, no bottlenecks on CFD"

### Phase 3: Stop Using Velocity

**Gradual Transition**:

1. **Week 1-4**: Track both velocity and lead time/throughput (prove equivalence)
2. **Week 5-8**: Use lead time/throughput for planning, report both
3. **Week 9+**: Stop reporting velocity externally
4. **Week 13+**: Stop calculating velocity at all

**Address Stakeholder Resistance**:

**If stakeholder asks**: "What's our velocity?"

**Respond**: "We've moved to lead time and throughput, which are more accurate. Our median lead time is 6 days with 85% completing in 10 days. We deliver about 6 items per week. This is more reliable than velocity because it's based on actual delivery data, not estimates."

**If they push back**: "Would you rather know we committed to 30 points (velocity planning) or that we have an 85% chance of finishing in 10 weeks (probability forecasting)? Which helps you make business decisions?"

### Phase 4: Embed Actionable Metrics Culture

**Daily Standups**:
- Review CFD: Any expanding bands?
- Check work item age: Anything stale?
- Note blocked items: What can we unblock?

**Weekly Reviews**:
- Update lead time distribution
- Update throughput calculation
- Re-forecast current initiatives
- Share with stakeholders

**Retrospectives**:
- Lead time trending up → why?
- Throughput declining → what changed?
- CFD shows bottleneck → how do we prevent it?
- Use actionable vs vanity framework to evaluate any new metric proposals

---

## COMMON OBJECTIONS AND RESPONSES

### Objection 1: "We need estimates for planning"

**Response**:
You need **forecasts**, not estimates. Forecasts use historical data (lead time, throughput). Estimates use guesses about future work. Historical data is more reliable.

### Objection 2: "Lead time doesn't account for item complexity"

**Response**:
Neither does velocity (5 points to you ≠ 5 points to me). Both assume items are roughly similar. If items vary wildly, split them smaller. The law of large numbers works better with more uniform items.

### Objection 3: "Our stakeholders demand commitments"

**Response**:
Provide probability-based forecasts. "85% confidence we'll finish in 10 weeks" is more honest than "we commit to 30 points." Commitments based on estimates create false confidence. Stakeholders need realistic expectations, not false promises.

### Objection 4: "Story points help us discuss complexity"

**Response**:
Discuss complexity directly. "This is complex because X, Y, Z" is clearer than "this is 8 points." Planning poker conversation is valuable; the number at the end is not. Keep the conversation, discard the points.

### Objection 5: "We've always used velocity"

**Response**:
Has it worked? If your forecasts are accurate and stakeholders are happy, maybe keep it (but still track lead time as validation). If forecasts are wrong and stakeholders frustrated, try something better.

### Objection 6: "This is too much change at once"

**Response**:
Start small. Track lead time for one month alongside velocity. Compare forecast accuracy. Let the data convince you.

### Objection 7: "Management won't understand this"

**Response**:
Management understands probability. "85% chance of finishing in 10 weeks" is clearer than "velocity is 28 points, we have 140 points remaining, so 5 sprints, but velocity might change, and estimates might be wrong, so maybe 4-7 sprints."

### Objection 8: "What if our lead time is inconsistent?"

**Response**:
That's valuable information. Inconsistent lead time means inconsistent process. Investigate why. Use the distribution to account for variation. Provide the 85th or 95th percentile for safer forecasts.

---

## ANNOUNCING USAGE

When using this skill, announce:

"I'm using the Escape Velocity framework to move beyond velocity and story points, focusing instead on actionable metrics: lead time with probability distributions, Cumulative Flow Diagrams, and throughput-based forecasting to provide realistic forecasts and identify system bottlenecks."

---

## CSO KEYWORDS

Escape Velocity, velocity, story points, agile metrics, lead time, cycle time, probability distribution, percentile forecasting, Cumulative Flow Diagram, CFD, throughput, Goodhart's Law, actionable metrics, vanity metrics, lagging indicator, complex system, forecasting without estimates, WIP, work in progress, bottleneck detection, flow metrics, Kanban, delivery metrics, agile antipatterns, metric gaming, story point inflation, no baseline problem, reference class, statistical forecasting, Monte Carlo, burn-up, burn-down, sprint planning, capacity planning, agile planning, software metrics, DevOps metrics, deployment frequency, lead time trends, variance, coefficient of variation, data-driven decisions, evidence-based management

---

**Remember**: Velocity is a lagging indicator of a complex system. You cannot drive forward looking backward. Use lead time with probability distributions, track throughput, visualize with CFDs, and focus on actionable metrics that tell you what to do. The goal isn't better velocity—it's better forecasting, better visibility, and better decisions.
