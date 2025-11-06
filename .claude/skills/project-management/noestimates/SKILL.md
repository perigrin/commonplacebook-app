---
name: "#NoEstimates: Forecasting Without Estimation"
description: A methodology for delivering software predictably without upfront estimation, using historical data, throughput metrics, and probabilistic forecasting instead of story points or time estimates
when_to_use: |
  SYMPTOMS that indicate #NoEstimates is needed:
  - Estimates consistently wrong (projects running 50-100% over)
  - Teams spending hours in estimation meetings
  - Stakeholders demanding more accurate estimates
  - "When will this be done?" causing analysis paralysis
  - Story point inflation or velocity gaming
  - False confidence from detailed estimation
  - Teams delivering less while estimating more
  - Estimation becoming a blocker to starting work
version: 1.0.0
---

# #NoEstimates: Forecasting Without Estimation

A systematic approach to software delivery that replaces upfront estimation with historical data, throughput measurement, and probabilistic forecasting. This provides MORE accurate predictions than estimation while eliminating the waste of estimation ceremonies.

**What it is:** A complete methodology using Running Tested Stories (RTS), cycle time data, and throughput metrics to forecast delivery without estimating individual items.

**What it is NOT:** Chaos, lack of planning, refusing to answer "when will this be done?", or eliminating all predictability.

## The Core Principle: Historical Data Beats Guessing

**The fundamental shift**: Stop guessing how long things will take. Instead, measure how long things actually take, then use that data to forecast.

**Why this works better**: Estimates are based on imagination about the future. Historical data is based on actual performance. Reality beats imagination.

## The Research: Why Estimation Fails

### The 62% Average Delay

**Research finding**: Projects take an average of **62% longer than estimated** (approximately 1.6x the estimated time).

This isn't about "bad estimators" - it's about the fundamental unpredictability of software development. Even experienced teams with good estimation practices hit this average delay.

**Implication**: If your estimate says 6 weeks, the research suggests it will actually take ~10 weeks. The estimate provides FALSE predictability.

### The Three Laws

#NoEstimates is built on understanding three fundamental laws that make estimation unreliable:

#### 1. Hofstadter's Law
**"It always takes longer than you expect, even when you take into account Hofstadter's Law."**

No matter how much buffer you add, you'll underestimate. This is recursive - accounting for the law doesn't fix it.

#### 2. Parkinson's Law
**"Work expands to fill the time available for its completion."**

Give a 2-day task 5 days, it takes 5 days. Give a 5-day task 2 days, it might take 3. Estimates become self-fulfilling prophecies in the wrong direction.

#### 3. Law of Accidental Complication
**"Every estimate becomes a commitment, creates pressure, leads to shortcuts, which creates technical debt, which slows future work."**

The estimate itself damages your ability to deliver. The pressure to meet the estimate causes shortcuts that create future problems. This is why velocity degrades over time.

### The Waste of Estimation

Even if estimates were accurate (they're not), the process has costs:

1. **Time waste**: Hours in planning poker, estimation workshops, re-estimation
2. **False precision**: Arguing whether something is a 5 or 8 point story
3. **False confidence**: "We estimated it, so we know when it will be done" (we don't)
4. **Delayed value**: Can't start until estimation is complete
5. **Focus on output**: Counting story points instead of outcomes
6. **Gaming**: Teams learn to inflate estimates to hit targets

**The #NoEstimates argument**: This time could be spent delivering instead.

---

## Alternative Metrics: What to Measure Instead

### Running Tested Stories (RTS)

**Definition**: The count of stories that are DONE - coded, tested, and deployed to production.

**Why "Running Tested Stories"**:
- **Running**: In production, available to users
- **Tested**: Verified to work
- **Stories**: User-valuable increments

**NOT included in RTS**:
- Stories "done except for testing"
- Stories "90% complete"
- Stories deployed but not tested
- Technical tasks with no user value

**How to count**:
1. Define "DONE" clearly: coded + tested + deployed
2. Count only stories that meet DONE
3. Track per time period (per week is common)
4. No sizing or pointing needed - just counting

**Example**: Team completes 4 stories in week 1, 6 in week 2, 3 in week 3, 5 in week 4. RTS = 4, 6, 3, 5.

### Throughput

**Definition**: The number of completed items per time period.

**Calculation**: RTS over time = throughput

**Example**: 18 stories completed in 4 weeks = 4.5 stories/week average throughput

**Why it matters**: Throughput is your actual delivery rate. This is reality, not a guess.

**Using throughput to forecast**:
```
Stories remaining: 20
Average throughput: 4 stories/week
Forecast: 20 ÷ 4 = 5 weeks
```

This is based on what the team ACTUALLY delivers, not what they think they can deliver.

### Cycle Time

**Definition**: The time from when work starts on a story until it's DONE (coded, tested, deployed).

**Measurement**: Track the date started and date completed for each story.

**Example data**:
- Story A: 2 days
- Story B: 5 days
- Story C: 3 days
- Story D: 10 days
- Story E: 3 days

**Why track individual cycle times**: Reveals variability and helps with probabilistic forecasting.

### Cycle Time Distribution

Instead of averaging, look at the distribution:

**Example from 30 stories**:
- 15 stories: 1-3 days (50%)
- 10 stories: 4-7 days (33%)
- 5 stories: 8-14 days (17%)

**Using this for forecasting**:
- **50th percentile (median)**: 3 days - half of stories complete faster
- **85th percentile**: 7 days - 85% of stories complete within this
- **95th percentile**: 12 days - 95% of stories complete within this

This gives you probabilistic forecasts without estimating.

---

## Forecasting Without Estimates: Step-by-Step

### Method 1: Throughput-Based Forecasting

**When to use**: When stories are relatively similar in size

**Steps**:
1. Measure historical throughput (stories per week)
2. Count remaining stories
3. Calculate: Remaining stories ÷ Throughput = Forecast

**Example**:
- Historical data: 4, 6, 3, 5, 4, 5 stories/week over 6 weeks
- Average throughput: 4.5 stories/week
- Remaining stories: 36
- Forecast: 36 ÷ 4.5 = 8 weeks

**Confidence levels**:
- Use minimum throughput for pessimistic: 36 ÷ 3 = 12 weeks (worst case)
- Use average for typical: 36 ÷ 4.5 = 8 weeks (expected)
- Use maximum throughput for optimistic: 36 ÷ 6 = 6 weeks (best case)

### Method 2: Cycle Time Distribution Forecasting

**When to use**: When stories vary significantly in size

**Steps**:
1. Gather cycle time data for past stories (minimum 20-30 stories)
2. Sort by duration and find percentiles
3. Use percentiles to create probabilistic forecasts

**Example calculation**:
- 30 stories with cycle times ranging from 1 to 14 days
- 50th percentile (median): 3 days
- 85th percentile: 8 days
- 95th percentile: 13 days

**For 20 remaining stories**:
- **50% confidence**: 20 stories × 3 days = 60 days (~12 weeks)
- **85% confidence**: 20 stories × 8 days = 160 days (~32 weeks)
- **95% confidence**: 20 stories × 13 days = 260 days (~52 weeks)

**Refinement**: As stories complete, update the forecast with actual data.

### Method 3: Monte Carlo Simulation

**When to use**: For more sophisticated probabilistic forecasting

**How it works**:
1. Collect historical cycle time data
2. Run thousands of simulations randomly selecting from actual cycle times
3. Generate probability distribution of completion dates

**Tools**: Many available (ActionableAgile, Nave, spreadsheet templates)

**Output**: "50% chance of completing by June 1, 85% chance by July 15, 95% chance by August 30"

### Communicating Forecasts

**Instead of**: "We'll be done in 8 weeks" (false precision)

**Say**:
- "Based on our actual delivery rate of 4-5 stories/week, we expect 8-10 weeks"
- "We're 50% confident we'll complete by June 1, 85% confident by July 15"
- "We completed 18 stories in the last 4 weeks; there are 36 remaining, suggesting 8 weeks"

**Key principle**: Show your work. Make the forecast transparent and based on visible data.

---

## The 7-Step Fast Track Adoption Process

A systematic approach to transition from estimation to #NoEstimates:

### Step 1: Slice Stories to Similar Size
**Goal**: Make stories roughly comparable (not exact)

**How**:
- Target: 1-5 days of work per story
- If larger, split it
- Don't estimate the size - just split anything that feels big
- "Feels like more than a week? Split it."

**Why**: Reduces variability enough that counting works well

### Step 2: Count Completed Stories (RTS)
**Goal**: Establish your baseline metric

**How**:
- Define "DONE": coded + tested + deployed
- Count stories meeting DONE each week
- Track for at least 4-6 weeks to establish baseline

**Data to collect**:
```
Week 1: 4 stories
Week 2: 6 stories
Week 3: 3 stories
Week 4: 5 stories
Week 5: 4 stories
Week 6: 5 stories
```

### Step 3: Track Cycle Time for Each Story
**Goal**: Understand variability and flow

**How**:
- Record start date (when development begins)
- Record completion date (when deployed)
- Calculate days between
- Build a dataset of actual cycle times

**Data format**:
```
Story A: Started Jan 5, Completed Jan 7 = 2 days
Story B: Started Jan 6, Completed Jan 12 = 6 days
Story C: Started Jan 8, Completed Jan 10 = 2 days
```

### Step 4: Calculate Average Throughput
**Goal**: Know your delivery rate

**How**:
- Sum stories completed over time period
- Divide by number of time periods
- Use recent data (4-6 weeks) for current capability

**Example**:
- 6 weeks of data: 4, 6, 3, 5, 4, 5 stories/week
- Total: 27 stories in 6 weeks
- Average throughput: 4.5 stories/week

### Step 5: Use Historical Data to Forecast
**Goal**: Answer "when will this be done?" with data

**How**:
- Count remaining stories
- Divide by average throughput
- Apply: Remaining ÷ Throughput = Forecast

**Example**:
- 36 stories remaining
- 4.5 stories/week throughput
- Forecast: 8 weeks

### Step 6: Communicate with Probabilistic Ranges
**Goal**: Provide useful predictions without false precision

**How**:
- Use minimum, average, maximum throughput for range
- Express as confidence levels
- Show the data behind the forecast

**Example communication**:
"Based on our delivery rate of 3-6 stories per week (average 4.5), we forecast:
- Best case (6/week): 6 weeks
- Expected (4.5/week): 8 weeks
- Worst case (3/week): 12 weeks

We're 85% confident we'll complete within 10 weeks based on historical variance."

### Step 7: Adjust Based on Actual Progress
**Goal**: Keep forecasts current with reality

**How**:
- Update forecast weekly as stories complete
- Don't re-estimate - just count what's done
- Adjust for trends (improving/degrading throughput)
- Communicate changes transparently

**Example**:
```
Week 0: 36 stories remaining, forecast 8 weeks
Week 1: Completed 4 stories, 32 remaining, forecast 7 weeks
Week 2: Completed 3 stories, 29 remaining, forecast 6 weeks
Week 3: Completed 5 stories, 24 remaining, forecast 5 weeks
```

**Key**: Forecast improves over time because it's based on what's actually happening, not old guesses.

---

## Handling Common Objections

### "We Need Predictability!"

**The objection**: "Without estimates, how can we be predictable? Stakeholders need commitments!"

**The response**:

**Estimates provide FALSE predictability**:
- Research shows 62% average delay
- Estimates are guesses about the future
- They create false confidence

**Real predictability comes from**:

1. **Historical data**: What we actually deliver, not what we think we can deliver
2. **Probabilistic forecasting**: Honest ranges, not fake precision
3. **Frequent delivery**: Smaller batches, continuous deployment, faster feedback
4. **Transparency**: Show actual progress, not % complete estimates

**This is MORE predictable** because it's based on reality, not imagination.

**Action**: Show the data. "We delivered 18 stories in 4 weeks. There are 36 remaining. That suggests 8 weeks. What would you like to prioritize in case we have less time?"

### "Story Points Aren't Estimates!"

**The objection**: "Story points are relative sizing, not estimates. They're different from time estimates. #NoEstimates doesn't apply."

**The response**:

**Story points ARE estimates** - you're estimating complexity instead of time.

**All the same problems apply**:
1. **Time waste**: Planning poker sessions, pointing debates
2. **False precision**: "Is this a 5 or an 8?" discussions
3. **Converted to time anyway**: "Our velocity is 20 points = 2 weeks"
4. **Gaming**: Teams learn to inflate points
5. **Still wrong**: Complexity is as unpredictable as time

**The alternative**: Slice stories small enough that sizing doesn't matter.

**Threshold**: If stories are 1-3 days, you don't need to distinguish between 2 and 8 points. Just count them.

**Counter-question**: "How much time do you spend pointing stories? What if you spent that time delivering instead?"

### "How Do We Handle Variable Team Capacity?"

**The objection**: "People take vacation, get sick, we add new hires. Historical throughput doesn't account for changing capacity. Don't we need estimates to adjust for this?"

**The response**:

**Historical throughput ALREADY includes this variation**:
- Past data includes vacations, sick days, interruptions
- You're measuring actual delivery under real conditions
- This is more realistic than estimated capacity

**For current trends**:
- Use recent data (last 4-6 weeks) to reflect current team
- Acknowledge uncertainty with wider confidence ranges
- Update forecasts as actual data emerges

**For major changes** (new hire, team restructure):
- Acknowledge the uncertainty honestly
- Use wider confidence ranges
- Let new data emerge before forecasting

**The key point**: Estimating doesn't make capacity changes predictable either.

**Estimates fail worse**: "We estimated based on 5 people, but someone left, so now we need to re-estimate" - you're guessing twice.

**#NoEstimates adapts**: "Our throughput was 5 stories/week with 5 people. Now it's 4 stories/week with 4 people. Here's the updated forecast based on actual delivery."

### "This Only Works for Similar-Sized Stories"

**The objection**: "Our stories vary wildly. Some are 2 days, some are 2 weeks. We need estimates to account for this."

**The response**:

**Use cycle time distribution, not just throughput**:
- Track how long stories actually take
- Use percentiles for probabilistic forecasting
- 50th percentile = typical, 85th = likely, 95th = confident

**Split large stories when discovered**:
- Don't estimate up front
- When a story feels large, split it
- "This feels like more than a week" → split now, don't estimate

**Historical data handles variability**:
- Your past 30 stories show the real distribution
- Some were quick, some slow - that's in the data
- Use that actual variance for forecasting

**This is MORE accurate than estimation**:
- Estimates guess at variance
- Historical data measures actual variance
- Reality beats guessing

### "What If We Have a Hard Deadline?"

**The objection**: "Our CEO says this feature must be ready for the conference in 6 weeks. We need estimates to know if we can make it."

**The response**:

**This IS one scenario where you need to estimate** - but differently.

**Don't estimate: "How long will this take?"**
**Instead: "What can we deliver by the deadline?"**

**The #NoEstimates approach to deadlines**:

1. **Fixed deadline → Variable scope** (NOT fixed scope → variable deadline)
2. **Use historical throughput**: "We deliver 5 stories/week, we have 6 weeks = 30 stories"
3. **Scope to fit**: "Which 30 stories create the MVP for the conference?"
4. **Ruthlessly prioritize**: What's the minimum viable version?
5. **Track and adjust**: Update scope as you deliver

**Communication**:
- "In 6 weeks at our throughput, we can deliver ~30 stories. Let's prioritize which 30 matter most."
- "We're delivering toward the deadline. Here's what we've completed, here's what's likely to make it."

**Still no individual estimates**: You're not guessing how long each story takes. You're using actual throughput to determine achievable scope.

---

## When Estimates Might Be Useful (The Exceptions)

#NoEstimates recognizes there ARE scenarios where estimation has value:

### Deadline-Driven Projects

**Scenario**: Fixed external deadline (conference, regulatory, contract)

**Approach**:
- Use throughput to determine scope that fits
- Estimate minimum viable version
- Fixed deadline → variable scope

**Example**: "6-week deadline, 5 stories/week throughput = scope to 30 most important stories"

### Build vs. Buy Decisions

**Scenario**: Comparing building internally vs. purchasing solution

**Approach**:
- Rough order of magnitude estimate (weeks? months? years?)
- Compare against purchase cost and timeline
- Decision clarity, not precision

**Example**: "Building this is likely 6-12 months. Vendor delivers in 2 months for $50K. Buy it."

### Exploration and Spikes

**Scenario**: Completely unknown territory, feasibility unclear

**Approach**:
- Timebox the exploration (1 day, 1 week)
- Learn what's possible
- Then use #NoEstimates for delivery

**Example**: "Spend 2 days investigating if this API integration is feasible. Then we'll count stories to deliver it."

### Resource Allocation

**Scenario**: Choosing between multiple large initiatives

**Approach**:
- T-shirt sizing (S, M, L, XL) for relative comparison
- Use for portfolio prioritization only
- Don't convert to time commitments

**Example**: "Feature A is Small, Feature B is Large. Given strategic value, start with B."

**Key principle**: Even in these cases, keep estimates rough, avoid false precision, and switch to data-driven forecasting as soon as possible.

---

## Integration with Other Methodologies

### Works With

**Kanban**:
- WIP limits + throughput = natural fit
- Cycle time distribution = core Kanban metric
- Continuous flow supports #NoEstimates

**Scrum**:
- Replace story pointing with story slicing
- Track RTS instead of velocity
- Keep sprints for rhythm, drop estimation ceremonies

**Lean**:
- Eliminate waste (estimation waste)
- Continuous improvement (adapt based on data)
- Value stream focus (outcomes, not outputs)

**XP (Extreme Programming)**:
- Small stories = estimation unnecessary
- Continuous integration/deployment = frequent RTS
- Sustainable pace = realistic throughput

### Conflicts With

**SAFe (when rigidly applied)**:
- Heavy upfront planning and estimation
- Program Increment (PI) planning with story points
- Can adapt by using throughput in PI planning

**Traditional Waterfall**:
- Requires detailed upfront estimates
- Fixed scope, estimated timeline
- #NoEstimates fundamentally incompatible

---

## Practical Tips for Success

### Start Small
- One team, one project
- Prove it works before expanding
- Bring data to show the improvement

### Define DONE Clearly
- Coded + Tested + Deployed = objective criteria
- No "90% complete"
- Binary: DONE or not DONE

### Keep Stories Small
- 1-5 days target
- Split anything larger
- Makes counting effective

### Track Consistently
- Same definition of DONE every time
- Same time periods (weekly is common)
- Clean, reliable data

### Visualize Progress
- Cumulative flow diagrams
- Burn-up charts (not burn-down)
- Show actual completion, not estimates

### Be Transparent
- Show the data behind forecasts
- Explain how forecasts are calculated
- Update stakeholders on actual progress

### Adjust Based on Reality
- Update forecasts as stories complete
- Don't defend old forecasts
- Follow the data, not the plan

### Focus on Outcomes
- Deliver value, not story points
- Measure impact, not output
- Commit to outcomes, not feature-by-date promises

---

## Measuring Success

**You know #NoEstimates is working when**:

✅ **Less time estimating**: Estimation meetings eliminated or drastically reduced
✅ **More accurate forecasts**: Forecasts within 20% of actual (vs 62% delay with estimates)
✅ **Faster feedback**: Smaller stories, more frequent deployment
✅ **Less re-planning**: Adjust based on data, not re-estimate
✅ **Better conversations**: "What should we prioritize?" vs "Why was the estimate wrong?"
✅ **Improved morale**: Less pressure from false commitments
✅ **Higher throughput**: Time saved from estimation spent delivering
✅ **Greater transparency**: Stakeholders see actual progress, not % complete guesses

**You know you're doing it wrong when**:

❌ Stakeholders say "We have no idea when anything will be done"
❌ Team is still spending hours debating story sizes
❌ Forecasts are consistently wrong (not using real data)
❌ Stories are large and variable (not splitting)
❌ Still using story points or time estimates (not truly #NoEstimates)
❌ Treating #NoEstimates as "no planning" or "no predictability"

---

## Announcing Usage

When using this skill, announce:

"I'm applying the #NoEstimates methodology to provide forecasts based on historical throughput and cycle time data rather than upfront estimation. This approach uses Running Tested Stories (RTS), probabilistic forecasting, and actual delivery data for more accurate predictions."

---

## CSO Keywords

NoEstimates, #NoEstimates, no estimates, Running Tested Stories, RTS, throughput, cycle time, cycle time distribution, probabilistic forecasting, historical data, empirical forecasting, story slicing, 62% average delay, Hofstadter's Law, Parkinson's Law, Law of Accidental Complication, estimation waste, false precision, false confidence, velocity, story points alternative, Monte Carlo simulation, percentile forecasting, confidence intervals, deadline-driven scope, fixed deadline variable scope, forecast without estimates, predictability without estimates, agile metrics, lean metrics, flow metrics, cumulative flow, burn-up charts, empirical process control, data-driven forecasting, when will this be done, software estimation, estimation alternatives, throughput-based planning, capacity planning

---

**Remember**: #NoEstimates isn't about refusing to answer "when will this be done?" It's about answering with REAL data instead of IMAGINED estimates. Historical throughput and cycle time provide more accurate forecasts than estimation because they're based on what actually happens, not what we hope will happen.
