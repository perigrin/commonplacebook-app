---
name: Domain Storytelling
description: A collaborative modeling method using pictographic language to create shared understanding between domain experts and development teams. Based on Stefan Hofer's book.
when_to_use: When teams misunderstand requirements, documenting domain knowledge, onboarding new team members, exploring business processes, or discovering bounded contexts for domain-driven design
version: 1.0.0
---

# Domain Storytelling

A workshop-based modeling method that uses a specific pictographic language to create shared understanding of business domains between domain experts and development teams.

**What it is:** Domain experts tell stories about their work while a moderator draws them using a simple pictographic language (actors, activities, work objects). The visual story creates shared understanding and reveals domain language.

**What it is NOT:** Technical design notation (UML/BPMN), flowcharts with conditionals, or requirements documentation templates.

## Core Principle: One Story, One Diagram

**Each diagram tells exactly one story** - a single scenario from start to finish with no branches or conditionals.

If you have variations (logged-in user, guest user, admin), create **separate diagrams** for each scenario. This forces clarity about where scenarios truly differ.

**Why no conditionals?** Branches make diagrams unreadable and shift focus from understanding the domain to documenting every edge case. Domain Storytelling is about **learning**, not comprehensive documentation.

## The Pictographic Language

Domain Storytelling uses a specific grammar structure that creates precise, readable stories:

### Elements

1. **Actors** (people, systems, organizations) - Drawn as stick figures or icons
2. **Work Objects** (documents, data, physical items) - Drawn as page icons or relevant symbols
3. **Activities** (verbs) - Written on arrows connecting elements
4. **Sequence Numbers** - Numbers on arrows showing order of events

### Grammar Structure

**Subject (Actor) → Predicate (Activity) → Object (Work Object or Actor)**

Example: `Customer → places → Order` or `Warehouse → ships → Package → to → Customer`

**Read like a sentence:** "Customer places Order" → "Warehouse ships Package to Customer"

### Annotation

Add numbers (1, 2, 3...) to arrows to show sequence. This creates a readable story: "First the customer places an order (1), then the system validates payment (2), then the warehouse ships the package (3)..."

## When to Use Domain Storytelling

✅ **Use Domain Storytelling when:**
- Teams have **cross-functional misunderstandings** (business ↔ development)
- You need to **understand existing processes** (AS-IS scenarios)
- You're **designing new workflows** (TO-BE scenarios)
- **Onboarding** new team members to the domain
- Discovering **bounded contexts** for domain-driven design
- Business and IT speak different languages about the same process

❌ **Do NOT use Domain Storytelling for:**
- **Technical design** (use UML, sequence diagrams, architecture diagrams)
- **Complete system documentation** (too verbose, not the purpose)
- **Real-time collaboration documentation** (not for live system behavior)
- **API contracts** (use OpenAPI, gRPC definitions, etc.)

**Key distinction:** Domain Storytelling is about **understanding the domain**, not designing technical solutions. If you're thinking about databases, APIs, or classes, you're doing technical design, not domain storytelling.

## Workshop Facilitation Process

Domain Storytelling happens in **structured workshops** with specific roles:

### Roles

1. **Domain Expert** - Tells the story (their actual work experience)
2. **Moderator** - Facilitates, asks questions, retells the story
3. **Modeler** - Draws the story using the pictographic language
4. **Participants** - Development team, other stakeholders who listen and learn

### Process

1. **Start with happy path** - Model the simplest, most common scenario first
2. **Domain expert tells story** - Concrete example from their actual work
3. **Modeler draws in real-time** - Using actors, activities, work objects, sequence numbers
4. **Moderator retells while pointing** - "So the customer places an order, then the system validates payment..." (validates understanding)
5. **Participants ask clarifying questions** - Reveal misunderstandings early
6. **Iterate until accurate** - Adjust diagram based on feedback
7. **Model variations separately** - Create new diagrams for different scenarios

**Critical technique:** The moderator **retells the story while pointing at the diagram**. This forces the domain expert to confirm: "Yes, that's exactly what happens" or "No, actually it works differently..."

## Scope and Granularity

Domain stories can operate at different levels:

### Granularity

- **COARSE-GRAINED**: High-level overview (end-to-end process in 5-10 steps)
- **FINE-GRAINED**: Detailed view (zooming into one part with 15-20 steps)

**Start coarse, then drill down** into areas that need clarification.

**Rule of thumb:** 10-20 sentences per diagram. More than that? You're probably mixing scenarios or going too fine-grained.

### Scope Dimensions

1. **Granularity**: COARSE (overview) ↔ FINE (detailed)
2. **Time**: AS-IS (current state) ↔ TO-BE (future state)
3. **Purity**: PURE (domain only) ↔ DIGITALIZED (with systems/automation)

## Common Anti-Patterns to Avoid

### ❌ Request/Response Technical Patterns

**Wrong:** "User requests data → System responds with data → User validates data → System confirms validation"

**Why wrong?** This is technical thinking about system interactions, not domain thinking about business intent.

**Better:** "Customer searches product catalog → selects TV → adds to cart → proceeds to checkout"

**Focus on intent**, not technical request/response loops.

### ❌ Conditionals and Branches

**Wrong:** Creating one diagram with "if logged in, go here; if guest, go there"

**Right:** Create separate diagrams: one for logged-in users, one for guests

### ❌ Using UML/BPMN Notation

Domain Storytelling has its own pictographic language. Don't use UML sequence diagrams, BPMN decision nodes, or flowchart symbols. They're technical notations that create distance between business and IT.

### ❌ Comprehensive Documentation

Domain Storytelling is for **learning and shared understanding**, not comprehensive documentation. Don't try to capture every edge case or exception. Model the happy path and key variations only.

## Integration with Other Practices

Domain Storytelling **pairs naturally with:**
- **Domain-Driven Design**: Reveals bounded contexts, aggregates, domain language
- **Event Storming**: Both are collaborative, visual; Domain Storytelling is more structured
- **User Story Mapping**: Domain stories inform what user stories to write

Domain Storytelling **complements but does NOT replace:**
- **Technical design documents**: Still need UML, architecture diagrams
- **API specifications**: Still need OpenAPI, gRPC definitions
- **Test cases**: Still need comprehensive test scenarios

## Announcing Usage

When using this skill, announce:

"I'm using the Domain Storytelling skill to model the [process/workflow]. I'll create a pictographic diagram showing actors, activities, and work objects in sequence, following the 'one story, one diagram' principle."

## CSO Keywords

Domain Storytelling, pictographic language, collaborative modeling, requirements gathering, domain understanding, shared understanding, business-IT communication, domain language, ubiquitous language, workshop facilitation, AS-IS process, TO-BE process, domain-driven design, bounded contexts, visual modeling, domain knowledge, cross-functional collaboration, requirements misunderstanding, process documentation, domain expert storytelling

---

**Remember:** Domain Storytelling is about creating shared understanding through structured storytelling and visual language, NOT about comprehensive documentation or technical design.
