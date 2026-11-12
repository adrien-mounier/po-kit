# PO Kit

An installable kit that turns a coding agent into a Product Owner's assistant: it keeps one reliable register of the PO's subjects and derives every deliverable from it. The kit holds no real data; real data lives in a workspace on the machine where the PO works.

## Language

### Where things live

**Kit**:
The installable package of rules, routines, register tool, templates and tests. It never contains real names, real subjects or real documents.
_Avoid_: framework, harness, template repo

**Workspace**:
The folder on one machine that holds one PO's real data: the register, the views and that machine's connections.
_Avoid_: project, wiki, repo

**Connections**:
The per-machine description of which sources are reachable and how. (French: fiche de branchements.)
_Avoid_: integrations, config, plugins

### The register

**Register**:
The single set of records stating what is true about the PO's subjects. Every view is derived from it.
_Avoid_: backlog, database, wiki, tracker

**Record**:
One entry of the register, of exactly one type: subject, commitment, decision or risk. (French: fiche.)
_Avoid_: card, item, entry, note, ticket

**Subject**:
A stream of work the PO follows: a product the PO steers, a contribution to someone else's product, or a service rendered to the organisation.
_Avoid_: project, workstream, initiative, epic

**Commitment**:
Something one named person owes another, with or without a due date. Actions are commitments.
_Avoid_: task, action item, todo

**Decision**:
A choice that has been taken, or that is awaited from a named person.
_Avoid_: resolution, agreement

**Risk**:
A threat to a commitment, a blocking decision that cannot wait, or a significant stakeholder misalignment.
_Avoid_: issue, blocker, alert

**Objective**:
One of the PO's numbered goals for a review period. Records can be attached to objectives.
_Avoid_: goal, KPI, target

**Sponsor**:
The person the PO reports to, and the recipient of the weekly synthesis.
_Avoid_: manager, boss, stakeholder

### What a record says about itself

**Horizon**:
Where a subject sits in time: now, next or later.
_Avoid_: phase, priority, status

**Clearance**:
Whether someone with authority has approved work on a subject: cleared, pending or out of frame. It is independent of the horizon. (French: pastille « feu vert ».)
_Avoid_: approval status, validation, sign-off

**Out of frame**:
The clearance of a subject whose work exists while a mandatory gate is missing.
_Avoid_: non-compliant, blocked, unapproved

**Gate**:
A mandatory approval step defined by the organisation's governance, such as an architecture review before development.
_Avoid_: checkpoint, control, milestone

**Evidence level**:
How the content of a record is known: fact, reported or hypothesis.
_Avoid_: confidence, certainty

**Source**:
Where the content of a record came from, and when it was read.
_Avoid_: origin, reference

**Supersede**:
To replace a record by a newer one while keeping both, linked to each other.
_Avoid_: delete, overwrite, archive

**Stale**:
Said of a record or a source that has not been updated within its allowed delay. A commitment, decision or risk recorded or updated for a subject counts as an update of that subject.
_Avoid_: outdated, old, expired

### How the register changes

**Routine**:
A named procedure the agent follows on request, such as collect or weekly synthesis.
_Avoid_: workflow, command, agent

**Register tool**:
The only program allowed to write the register. It runs without any model.
_Avoid_: script, CLI, engine

**Collect**:
The routine that reads the inbox and the connected sources, and produces a proposal.
_Avoid_: sync, import, capture, refresh

**Inbox**:
The folder where the PO drops raw notes for the next collect.
_Avoid_: drop zone, staging

**Watch list**:
The people, keywords and tracker projects attached to a subject. It bounds what a collect may read.
_Avoid_: filter, scope, query

**Unclassified**:
Collected material that looks relevant but matches no subject, held for the PO to sort.
_Avoid_: misc, backlog, pending

**Proposal**:
The list of register changes a routine has prepared and that awaits validation. Nothing reaches the register except through an applied proposal.
_Avoid_: draft, patch, changeset

**Check**:
The verification of the whole register and of its staleness, run by the register tool.
_Avoid_: lint, audit, validation

### What comes out

**View**:
A document generated from the register for reading. It is never edited and always carries a stamp.
_Avoid_: report, page, dashboard

**Stamp**:
The header of a view stating when it was generated, which register state it reflects and which sources were not covered.
_Avoid_: header, metadata, footer

**Portfolio view**:
The view listing every active subject by horizon, with its clearance.
_Avoid_: roadmap, board, portfolio overview

**Weekly synthesis**:
The view written each week for the sponsor.
_Avoid_: weekly report, weekly brief, status report
