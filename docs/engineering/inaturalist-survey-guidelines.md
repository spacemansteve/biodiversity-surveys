# Engineering Guidelines for Extending iNaturalist with Survey Support

## Purpose

We are extending the existing iNaturalist software to support structured biodiversity **Surveys**.

The objective is **not to build a separate biodiversity platform or replace existing iNaturalist functionality**. The objective is to add the smallest coherent set of capabilities needed to represent surveys while preserving compatibility with iNaturalist's existing architecture, observations, taxonomy, users, places, projects, APIs, and community processes.

The implementation should be designed with the possibility that useful portions could eventually be contributed upstream to iNaturalist.

When choosing between:

1. modifying an existing iNaturalist mechanism,
2. extending an existing mechanism,
3. creating a parallel subsystem,

prefer them in that order unless there is a compelling architectural reason not to.

---

# 1. Core Design Principle

**Make the smallest possible change to iNaturalist that provides genuine Survey functionality.**

Do not redesign iNaturalist simply because a different design might look cleaner in isolation.

iNaturalist is a mature production system with many implicit relationships and behaviors. Existing conventions have substantial value.

Prefer:

> extend → compose → reference

over:

> replace → duplicate → fork

The Survey system should feel like an additional capability of iNaturalist, not another biodiversity application embedded inside it.

---

# 2. Begin with Existing iNaturalist Concepts

Before adding a new model, table, API endpoint, controller, service, or interface, search the existing codebase for functionality that already addresses some or all of the requirement.

In particular investigate existing:

- Trips
- Observations
- Projects
- ProjectObservations
- Places
- Taxa
- Users
- Lists and Checklists
- Observation Fields
- Controlled Terms / Annotations
- Taxon Frameworks
- Taxon Changes

The existing **Trip** functionality is particularly important.

Our working direction, based partly on communication with iNaturalist leadership, is to investigate whether Survey support can be implemented by making relatively small extensions to the existing Trip concept rather than introducing an entirely independent top-level system.

Do not assume Trips are sufficient, but investigate them first.

---

# 3. Preserve Observations as Observations

A Survey should normally **contain or reference iNaturalist observations**, not replace them with a new representation of organisms.

Do not create something like:

`SurveySpeciesObservation`

if an ordinary iNaturalist `Observation` can represent the occurrence correctly.

The Survey system should add information that an ordinary observation does not contain, for example:

- the sampling event,
- protocol,
- observer effort,
- survey duration,
- route,
- survey area,
- target taxa,
- completeness,
- environmental conditions,
- sampling method,
- repeated sampling structure.

Think approximately:

    Survey / Trip
        |
        +-- Survey Event
        |      |
        |      +-- Observation
        |      +-- Observation
        |      +-- Observation
        |
        +-- protocol / effort / location / targets

Do not commit to this exact schema without studying the existing application.

---

# 4. Treat Taxonomy as an iNaturalist-Owned Resource

**Do not create an independent taxonomy system.**

iNaturalist's curated taxonomy should remain authoritative for anything represented as an iNaturalist taxon.

Survey records should reference existing iNaturalist `taxon_id` values whenever possible.

Do not:

- create competing taxon identifiers,
- silently replace iNaturalist taxonomy with GBIF taxonomy,
- maintain a separate taxonomic hierarchy,
- independently resolve taxonomic changes,
- assume scientific names are stable identifiers.

Use `taxon_id`, not scientific-name strings, as the principal taxonomic reference.

Scientific names change.

Taxon concepts change.

Taxa can become inactive.

Identifiers provide continuity.

---

# 5. Local Taxonomy Is a Cache / Replica, Not a Fork

Development environments and Survey applications may need local taxonomic information.

That local information should be treated as a **synchronized representation of iNaturalist taxonomy**, not as a separately curated taxonomy.

iNaturalist currently provides monthly Open Dataset metadata including a taxa snapshot with:

- `taxon_id`
- ancestry
- rank
- rank level
- scientific name
- active/inactive status

The Open Dataset is appropriate for bulk synchronization. The API should not be used to scrape the complete taxonomy; iNaturalist specifically recommends bulk data mechanisms rather than API scraping.

Use the API for current application interactions and relatively small queries.

Use appropriate bulk sources for bulk synchronization.

Expect that additional taxonomic information—such as common names or some curatorial structures—may require other mechanisms.

Do not assume that the Open Dataset taxonomy snapshot represents every piece of taxonomy-related information in the production iNaturalist database.

---

# 6. Preserve Historical Taxonomic References

Taxonomy changes over time.

A survey conducted today must remain interpretable ten years from now even if the taxonomic concept has changed.

Do not destructively rewrite historical survey information merely because a taxon has subsequently changed.

Where appropriate retain information sufficient to distinguish:

- what taxon was selected when the survey occurred,
- what its current active taxonomic interpretation is.

iNaturalist generally retains obsolete taxa as inactive taxa rather than simply deleting them, which is useful for this purpose.

---

# 7. Separate Survey Definition from Survey Event

Avoid treating these as the same thing.

A **Survey Definition / Protocol** describes how surveying should be performed.

A **Survey Event** records one occurrence of that activity.

For example:

    Protocol:
      Butterfly transect
      Walk route for 20 minutes
      Record all butterflies detected

versus:

    Survey Event:
      October 14, 2026
      Menotomy Rocks Park
      10:03–10:24
      Steve + Rob
      720 meters
      13 taxa detected

A protocol may be reused thousands of times.

A survey event is historical and should generally become increasingly immutable after completion.

Keep this distinction visible during schema design.

---

# 8. Represent Effort Explicitly

One of the principal scientific differences between an observation collection and a survey is **effort**.

Survey design should therefore be able to represent relevant effort information without forcing every survey protocol to use every field.

Potential effort information includes:

- start time,
- end time,
- duration,
- distance,
- area searched,
- number of observers,
- number of sampling units,
- route,
- stationary vs traveling,
- equipment,
- sampling method,
- environmental conditions.

Do not assume all protocols require the same effort metrics.

Support structured protocol-specific metadata rather than adding dozens of globally mandatory columns.

---

# 9. Treat Completeness as Important Scientific Data

For many surveys:

> “I observed these species”

is fundamentally different from:

> “I attempted to record every species in this target group and these were all the species I detected.”

The second statement contains information about potential non-detection.

Survey design should allow an observer to state whether the submitted list is complete with respect to the survey protocol or target taxonomic group.

Do not infer completeness merely because a Survey contains observations.

Completeness should be explicitly recorded.

This idea is analogous to the scientific value of complete eBird checklists.

---

# 10. Do Not Manufacture Absence Records

Failure to observe a species is not automatically evidence that the species was absent.

The system should distinguish:

- observed,
- specifically searched for but not detected,
- included in a complete target checklist but not detected,
- outside the target scope,
- unknown.

Do not generate thousands of false zero-observation records by simply subtracting observed species from a regional species list.

Absence/non-detection must be interpreted in the context of protocol and effort.

---

# 11. Keep Protocols Extensible

We eventually want Surveys to support very different kinds of biodiversity work.

Examples might include:

- bird checklists,
- point counts,
- butterfly transects,
- timed searches,
- vegetation plots,
- vernal pool surveys,
- acoustic monitoring,
- camera traps,
- phenology observations,
- bio-blitzes,
- repeated site inventories.

Do not design the initial database around one taxonomic group or one sampling method.

At the same time, **do not prematurely build a universal scientific workflow engine**.

Implement the smallest general abstraction demonstrated by actual use cases.

Add complexity only when a concrete protocol requires it.

---

# 12. Prefer Structured Data over Free Text

Information used for searching, filtering, comparison, analysis, or validation should generally be stored in structured form.

For example, prefer:

    duration_seconds = 1200

over:

    notes = "surveyed for about twenty minutes"

Free-text notes can supplement structured information but should not replace scientifically important fields.

---

# 13. Use Established Biodiversity Standards Where Practical

Design Survey data so that eventual interoperability with major biodiversity-data standards is possible.

GBIF / Darwin Core compatibility is an important project goal.

However:

**Do not force the internal iNaturalist database schema to imitate Darwin Core literally.**

Internal application models should make sense within iNaturalist.

Create standards-compatible import/export mappings at appropriate system boundaries.

Where sampling-event concepts are involved, investigate relevant Darwin Core event and sampling terms rather than inventing incompatible terminology unnecessarily.

---

# 14. Preserve Backward Compatibility

Existing iNaturalist behavior must continue working when Survey functionality is not being used.

Survey functionality should not require every existing Observation, Trip, Project, User, or Taxon to acquire new mandatory data.

Prefer nullable or optional relationships where appropriate.

An ordinary iNaturalist observation should remain an ordinary iNaturalist observation.

A user who never creates a Survey should experience as little change as possible.

---

# 15. Database Changes Should Be Conservative

Before creating a migration:

1. inspect related existing tables,
2. inspect associated models,
3. inspect indexes,
4. inspect validations,
5. inspect callbacks,
6. inspect deletion behavior,
7. inspect API serialization,
8. inspect tests.

Prefer additive migrations.

Avoid destructive changes to existing production columns.

Use explicit foreign keys where consistent with the existing application.

Index fields that will actually be queried or joined frequently.

Consider the consequences of millions of records.

Never assume that a migration that is trivial on a development database will be trivial on production iNaturalist.

---

# 16. Avoid Heavy Logic in Database Migrations

Schema migrations should primarily change schema.

Large backfills or expensive transformations should be designed so they can be performed safely and separately when appropriate.

Do not write a migration that assumes it can synchronously update millions of production records without examining operational consequences.

---

# 17. Follow Existing Rails Conventions

The main iNaturalist application is an existing Rails application with established conventions.

Before introducing:

- a new service layer,
- a new state-management system,
- a new serialization pattern,
- a new JavaScript framework,
- a new job framework,
- a new dependency,

determine how equivalent work is already performed by iNaturalist.

Consistency with the existing application is normally more valuable than introducing a theoretically cleaner new pattern.

---

# 18. Do Not Add Dependencies Casually

Every new library creates:

- maintenance burden,
- upgrade burden,
- security exposure,
- deployment complexity,
- possible incompatibility with upstream iNaturalist.

Use existing dependencies whenever reasonable.

Adding a dependency requires a clear explanation of why existing capabilities are insufficient.

---

# 19. API Changes Must Be Intentional

iNaturalist maintains a separate API codebase in addition to the main Rails application.

Do not assume that adding database tables automatically creates an appropriate public API.

First determine:

- whether Survey functionality requires API access,
- whether existing endpoints can support it,
- whether the Rails application alone is sufficient during early prototyping.

Only modify `iNaturalistAPI` when there is a demonstrated requirement.

If API changes are added:

- follow existing API conventions,
- add tests,
- update OpenAPI/Swagger documentation,
- preserve existing responses,
- avoid breaking clients.

The current API repository explicitly requires tests and linting to pass before contributions are merged.

---

# 20. Never Use the API as a Bulk Data Extraction Mechanism

The iNaturalist API is intended for application functionality and small-to-medium data retrieval, not bulk database replication.

Respect current published API guidance and rate limits.

For bulk data, investigate:

- iNaturalist Open Dataset,
- exports,
- approved data dumps,
- direct arrangements with iNaturalist where necessary.

Current iNaturalist guidance recommends roughly one request per second and around 10,000 requests per day and specifically warns against using the API for bulk downloading.

---

# 21. Preserve User Identity

If Survey functionality ultimately submits observations to iNaturalist, observations should normally belong to the actual observer's iNaturalist account.

Do not implement a shared “Survey Project” user account that submits observations on behalf of many people.

Current iNaturalist API guidance explicitly recommends OAuth so users submit as themselves rather than through group accounts.

---

# 22. Respect Privacy, Sensitive Species, and Existing Geoprivacy

Do not design a parallel location-privacy mechanism without first understanding iNaturalist's existing geoprivacy behavior.

Survey functionality may create additional privacy problems because routes, sites, sampling areas, and repeated visits can reveal information that an obscured individual observation does not.

Before exposing Survey coordinates publicly, consider:

- observation geoprivacy,
- threatened species,
- private land,
- nesting sites,
- den sites,
- researcher-sensitive sites,
- observer privacy,
- aggregation attacks.

Survey-level location visibility may need to be at least as restrictive as the most sensitive information it contains.

Never accidentally undo iNaturalist's existing sensitive-species protections.

---

# 23. Separate Scientific Metadata from User Interface

Do not encode scientific meaning purely in UI behavior.

If a checkbox means “complete checklist,” store that meaning explicitly.

If a protocol specifies “10-minute stationary count,” represent the protocol in data rather than only displaying instructions on the page.

A different client—web, mobile, external application, API—should be capable of interpreting the same Survey.

---

# 24. Design for Offline Field Work, but Do Not Build It First

Many biodiversity surveys happen with poor connectivity.

The data model should not make offline collection impossible.

Useful characteristics include:

- stable local identifiers,
- client-generated UUIDs where appropriate,
- explicit synchronization state,
- deterministic relationships,
- timestamps representing observation time separately from upload time.

However, do not build an elaborate synchronization engine until the core Survey model has been proven.

Model first.

Simple web implementation second.

Offline/mobile complexity later.

---

# 25. Use Stable Identifiers

Do not use display names as relationships.

Prefer persistent IDs for:

- taxa,
- users,
- places,
- protocols,
- surveys,
- observations.

Names and labels are attributes.

Identifiers establish relationships.

---

# 26. Make Survey Provenance Explicit

A scientifically useful Survey should eventually make it possible to determine:

- who performed it,
- when it occurred,
- where it occurred,
- what protocol was used,
- which version of the protocol was used,
- what organisms were targeted,
- what effort was expended,
- whether reporting was complete,
- what observations resulted.

Avoid architectures where this information can only be reconstructed indirectly from logs or timestamps.

---

# 27. Protocol Versioning Matters

Protocols evolve.

Changing a protocol must not silently rewrite the interpretation of historical surveys.

Prefer something conceptually like:

    Protocol
      version 1
      version 2

or another mechanism that preserves historical meaning.

A Survey Event should be associated with the protocol definition that actually governed that event.

Do not overwrite the past when editing a protocol.

---

# 28. Avoid Premature Generalization

Do not attempt to solve every conceivable biodiversity survey before implementing one.

Use concrete reference protocols to test the architecture.

Good early examples might include:

1. an eBird-like complete taxonomic checklist,
2. a timed search,
3. a route/transect,
4. a stationary point count.

If the same core representation handles those cleanly, the abstraction is probably useful.

If it requires dozens of special cases, revisit the design.

---

# 29. Build Vertical Slices

Prefer implementing a complete thin capability:

    create Survey
        ↓
    perform Survey
        ↓
    attach observations
        ↓
    record effort
        ↓
    save
        ↓
    view completed Survey

rather than implementing twenty database tables before any end-to-end workflow works.

Early vertical slices reveal incorrect assumptions quickly.

---

# 30. Tests Are Part of the Feature

Every meaningful change should include appropriate tests.

At minimum consider:

- model tests,
- validation tests,
- relationship tests,
- permissions tests,
- API tests if relevant,
- controller/request tests,
- regression tests for existing behavior.

When fixing a bug, first create or identify a test demonstrating the bug whenever practical.

Do not disable existing tests simply to make Survey functionality pass.

---

# 31. Keep Commits Small and Explainable

Prefer commits such as:

    Add survey protocol model

    Associate trips with survey protocols

    Record survey completeness

over:

    Implement surveys

Each commit should have one understandable purpose.

Avoid mixing:

- formatting,
- unrelated refactoring,
- dependency upgrades,
- Survey functionality

in the same commit.

This makes review, debugging, upstream integration, and rollback substantially easier.

---

# 32. Avoid Opportunistic Refactoring

While working on Surveys, we will encounter old or awkward iNaturalist code.

Do not rewrite unrelated code merely because it could be improved.

If unrelated refactoring is truly necessary:

- explain why,
- isolate it,
- preferably make it a separate commit.

Our goal is Survey functionality, not modernization of the entire iNaturalist application.

---

# 33. Optimize for Potential Upstream Acceptance

Whenever two solutions work, prefer the one that:

- changes fewer existing files,
- changes fewer existing tables,
- creates fewer dependencies,
- preserves existing behavior,
- follows existing naming conventions,
- can be disabled or ignored by existing users,
- has clear tests,
- has a narrowly understandable purpose.

iNaturalist explicitly encourages developers considering substantial forks to communicate with them and look for ways needs can fit into the existing infrastructure rather than fragmenting the community.

Therefore, keep the difference between our branch and upstream iNaturalist as small and intelligible as practical.

---

# 34. Keep an Architectural Decision Log

For consequential design decisions, record:

- problem,
- alternatives considered,
- decision,
- rationale,
- consequences.

Examples:

    ADR-001: Extend Trip vs introduce Survey model
    ADR-002: Survey–Observation relationship
    ADR-003: Protocol representation
    ADR-004: Taxonomy synchronization
    ADR-005: Completeness representation

Do not rely on chat history as the sole record of important architectural decisions.

---

# 35. Distinguish Prototype Decisions from Permanent Architecture

During experimentation it is acceptable to build something provisional.

Mark provisional decisions explicitly.

For example:

    PROTOTYPE ONLY:
    SurveyProtocol stored as JSON while requirements are being explored.

Do not allow experimental shortcuts to quietly become permanent architecture.

---

# 36. Questions Codex Should Ask Before Making a Major Change

Before a major implementation decision, investigate:

1. Does iNaturalist already have something similar?
2. Can Trips support this?
3. Does this require modifying Observations?
4. Does this duplicate Projects?
5. Does this duplicate taxonomy functionality?
6. Does this change existing API behavior?
7. Does this introduce a migration that would be expensive at iNaturalist scale?
8. Does this create a new dependency?
9. Does this affect sensitive-location handling?
10. Could this make future upstream integration harder?
11. Is the feature required by a concrete Survey use case?
12. Is there a smaller implementation?

When uncertainty is substantial, stop and present the alternatives before making a large architectural change.

---

# 37. Things Codex Should NOT Do Without Explicit Approval

Do not:

- replace iNaturalist taxonomy,
- substantially rewrite Observation,
- substantially rewrite Trip,
- substantially rewrite Project,
- change existing identifiers,
- modify existing data destructively,
- create a parallel authentication system,
- create group accounts for survey observations,
- bypass geoprivacy,
- remove or weaken existing validations,
- introduce major dependencies,
- redesign unrelated interfaces,
- perform large refactors,
- change API response semantics,
- implement bulk API scraping,
- create a new taxonomic authority,
- create a large generalized protocol language,
- change production deployment architecture.

If one of these appears necessary, explain the reason and alternatives first.

---

# 38. Preferred Development Sequence

Unless evidence suggests otherwise, proceed approximately in this order:

### Phase 1 — Understand

Study:

- Trip schema and models,
- Trip UI,
- Trip–Observation relationships,
- relevant controllers,
- tests,
- API representation,
- Projects,
- taxonomy relationships.

Document what exists before modifying it.

### Phase 2 — Define the Minimum Survey Concept

Determine the minimum additional information needed to turn a Trip or similar structure into a scientifically meaningful Survey.

Likely candidates:

- protocol,
- target taxa,
- completeness,
- effort,
- survey status.

Do not implement everything yet.

### Phase 3 — Implement One Minimal Survey

Implement one end-to-end survey protocol with minimal schema changes.

Demonstrate:

- creation,
- data collection,
- observations,
- completion,
- retrieval.

### Phase 4 — Test Generality

Try representing several substantially different survey methods.

Identify which fields are universal and which belong to individual protocols.

### Phase 5 — Stabilize the Data Model

Only after the concepts work should we expand:

- protocol configuration,
- repeat surveys,
- sophisticated effort models,
- mobile/offline support,
- external exports,
- broader API support.

---

# 39. Definition of Success

Success is **not** measured by how much code we write.

A successful first Survey implementation would:

- reuse existing iNaturalist concepts,
- preserve ordinary observations,
- preserve iNaturalist taxonomy,
- add scientifically meaningful sampling-event information,
- capture effort,
- capture completeness when appropriate,
- support repeated surveys,
- remain understandable to existing iNaturalist developers,
- require relatively few changes to core iNaturalist,
- remain compatible with future upstream development,
- establish a foundation that other taxonomic groups and protocols can reuse.

The ideal result should prompt the reaction:

> “This seems like a natural extension of iNaturalist.”

rather than:

> “This is another biodiversity platform living inside the iNaturalist repository.”

---

# 40. Standing Instruction to Codex

When implementing Survey functionality:

**Study before changing. Reuse before creating. Extend before replacing. Preserve before refactoring.**

When an architectural decision could substantially increase divergence from upstream iNaturalist, stop and explain:

- the requirement,
- the existing iNaturalist mechanism,
- the smallest-change option,
- alternative designs,
- expected schema impact,
- expected API impact,
- migration implications,
- testing implications,
- implications for eventual upstream contribution.

Do not optimize merely for getting a prototype working.

Optimize for a Survey capability that fits naturally within iNaturalist and can remain maintainable as iNaturalist itself evolves.