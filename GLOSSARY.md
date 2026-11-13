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
One entry of the register, of exactly one type: subject, commitment, decision, risk or benefit. (French: fiche.)
_Avoid_: card, item, entry, note, ticket

**Subject**:
A stream of work the PO follows: a product the PO steers, a contribution to someone else's product, or a service rendered to the organisation.
_Avoid_: project, workstream, initiative, epic

**Client bank**:
A bank of the group that the PO's subjects may concern, listed in the settings. A subject names the client banks it concerns; one that names none concerns them all.
_Avoid_: affiliate, subsidiary, customer bank

**Commitment**:
Something one named person owes another, with or without a due date. Actions are commitments.
_Avoid_: task, action item, todo

**Effort**:
The days of work a commitment of the PO takes: estimated when it is recorded, real once it is done. Only the PO's own commitments carry one.
_Avoid_: workload (except the workload view), time spent, charge

**Kind of task**:
One of the short list of kinds in the settings that a commitment of the PO names, such as steering pack. The register tool learns, per kind, the ratio of real to estimated effort, and adjusts each estimate by it.
_Avoid_: category, task type, label

**Latest start**:
The day a commitment of the PO must be begun to be done in time: its due date minus its adjusted effort in working days, minus a margin. It enters "Start soon" on the morning page once it falls within the lead; both are settings, in working days.
_Avoid_: deadline, start date, kick-off

**Usable share**:
The share of the free time the meetings leave that the PO really spends on their tasks: 70% to start with, then learned by the register tool from the real efforts of the PO's done tasks.
_Avoid_: capacity, availability, focus factor

**Decision**:
A choice that has been taken, or that is awaited from a named person.
_Avoid_: resolution, agreement

**Risk**:
A threat to a commitment, a blocking decision that cannot wait, or a significant stakeholder misalignment.
_Avoid_: issue, blocker (except in the heading "Blockers and decisions expected from the sponsor" of the weekly synthesis), alert

**Benefit**:
A gain a subject promises: a metric with its unit, its baseline, its target and the one person who measures it, and the values measured over time, each stated by a person with its source and the date it was measured. A subject may hold several. (French: bénéfice.)
_Avoid_: KPI, outcome, value (except a measured value of a benefit)

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

**Work changes**:
Whether a subject changes the way people work, or only adds a tool: yes, no or unknown, with one sentence. The agent asks it for every new subject.
_Avoid_: transformation, impact, change management

**Score**:
The agent's rating of a subject from 1 to 5, with one reason: its value, its feasibility or its risk. Proposed as an interpreted operation, it counts once the PO says yes.
_Avoid_: rating, grade, priority

**AI Act mark**:
Whether a subject would be a high-risk use case under the EU AI Act, true or false, with its reason. A mark to check, never legal advice; shown beside the score, never in it.
_Avoid_: compliance status, AI Act classification, risk score

**Clearance**:
Whether someone with authority has approved work on a subject: cleared, pending, out of frame, or none, which is what a subject carries until a clearance is stated. It is independent of the horizon. (French: pastille « feu vert ».)
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
Said of a record or a source that has not been updated within its allowed delay. A commitment, decision, risk or benefit recorded or updated for a subject counts as an update of that subject. An open benefit is stale when no value was measured within the delay of a subject.
_Avoid_: outdated, old (except "older than" its delay for an inbox note or an unclassified item), expired

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
The people, keywords, tracker projects and chat channels attached to a subject. It bounds what a collect may read. A chat channel is a channel or a group chat. A one-to-one chat is read whole with a person of a watch list; in any other, only the messages that hold a keyword of a watch list are read, and the rest is never read. No routine lists a source's folder as a whole: it opens only what the watch lists match, by its path.
_Avoid_: filter, scope, query

**Unclassified**:
Collected material that looks relevant but matches no subject, held for the PO to sort.
_Avoid_: misc, backlog, pending

**Cutoff**:
How far a collect has read a source: the next collect reads that source since its last cutoff.
_Avoid_: checkpoint, cursor, watermark

**Cap**:
The most items a collect reads per source, set in the settings.
_Avoid_: limit, quota, batch size

**Collect state**:
What the workspace remembers of the collects: for each source, how far it was read and how many items were read, and which sources were not covered.
_Avoid_: sync state, cursor file, collect log

**Calendar snapshot**:
What the morning routine read of the PO's calendar, the working day before today, today and the next ten working days: each meeting with its start, end, title, attendees and status, and the all-day absences. The calendar is only ever read, never written.
_Avoid_: agenda, schedule, calendar sync

**Backlog alert**:
A ticket of a watched project the agent flags, kept in the workspace state and counted on the morning page: open for work a recorded decision dropped (citing that decision), describing the same need as another ticket, not ready for a refinement session near (no acceptance criteria, no estimate, a dependency not cleared), or stale. It is about the ticket, never about who works on it; the PO decides what to do, and the agent never closes or merges a ticket.
_Avoid_: backlog issue, ticket warning, hygiene report

**Refinement session**:
A meeting of the calendar snapshot whose title holds one of the words of the setting `refinement_words`. From five working days before it, the agent lists the tickets not ready for it.
_Avoid_: grooming (except as a word of the setting), backlog review

**Proposal**:
The list of register changes a routine has prepared and that awaits validation. Nothing reaches the register except through an applied proposal.
_Avoid_: draft, patch, changeset

**Change proposal**:
The changes to the tracker the agent prepares, kept in the workspace state apart from the proposal: each creates a ticket or edits one of its texts (title, description, acceptance criteria), with the exact text before and after, its reason and its source. Each is applied only after the PO said yes, reviewed the exact change and approved it, one at a time; a change that would delete, close, reopen or move a ticket, or touch another field, is refused.
_Avoid_: ticket update, tracker sync, changeset

**Ticket draft**:
A change of the change proposal that creates a ticket, written from the ticket template from a note that describes work for the team: a title, a user story with a definition of ready, and acceptance criteria as a checklist. A need a ticket already covers is not drafted; a need the note leaves unclear is an open question. The template of the organisation, in the workspace, replaces the kit's there only.
_Avoid_: story, generated ticket, backlog item

**Applied-change log**:
The register tool's list, in the workspace state, of every change to the tracker applied: the date, the change, the ticket, the field, the text before and after, who approved it and how it was applied. It is committed with the next apply.
_Avoid_: audit trail, history (which is a record's), journal

**Open question**:
A question a routine could not settle, kept in the workspace state with the record or subject it concerns, the agent's recommended answer and the day it was added, until the PO answers it. The agent asks it when its moment comes: when the PO talks about its subject, or at the briefing.
_Avoid_: todo, pending question, query

**Briefing**:
The conversation the agent offers once the morning page is written: it walks the page block by block, one round of numbered questions per block, each with a recommended answer, and turns the answers into one proposal.
_Avoid_: stand-up, review, meeting brief (which is about one meeting)

**Plain fact**:
An operation of a proposal that is quoted from a source, as opposed to an interpreted one: a decision, a status change, a deadline inferred.
_Avoid_: raw fact, literal, quote

**Validation mode**:
The setting, all or interpreted, that says whether a routine waits for the PO before applying anything, or applies plain facts at once and waits only for interpreted operations.
_Avoid_: approval mode, auto-apply, trust level

**Check**:
The verification of the whole register and of its staleness, run by the register tool.
_Avoid_: lint, audit, validation

### What comes out

**View**:
A document generated from the register for reading. It is never edited and always carries a stamp.
_Avoid_: report (except the check report), page (except the morning page), dashboard

**Stamp**:
The header of a view stating when it was generated, which register state it reflects and which sources were not covered.
_Avoid_: header, metadata, footer

**Portfolio view**:
The view listing every active subject by horizon, with its clearance and its client banks. Asked for one client bank, it keeps to that bank's subjects and those that name no bank.
_Avoid_: roadmap, board, portfolio overview

**Ranked portfolio**:
The view ranking the active subjects by value times feasibility, highest first, with risk, the AI Act mark and whether the work changes beside the score; the subjects without both scores follow, not scored. Asked for one client bank, it keeps to that bank's subjects and those that name no bank.
_Avoid_: priority list, leaderboard, scoring board

**Proposed order**:
The view of the order the agent proposes for the top of the backlog, the ticket to take first at the top, each with why it stands there, citing a subject's horizon, a commitment's due date or a decision. Nothing is moved in the tracker: reordering is the PO's.
_Avoid_: backlog ranking, prioritisation, ranked portfolio (which ranks subjects)

**Split**:
The agent's proposal to cut a ticket too large for one sprint into two to four smaller tickets: a `create` change for each, and an `edit` of the original's text saying what remains, each in the change proposal and approved one at a time. The original is never closed.
_Avoid_: breakdown, decomposition, sub-tasks

**Intake card**:
The view of a subject taken in from a request for an AI use case, written from a template: the problem, the client bank, who asks, the data needed and the expected gain, whether the work changes, and the clearance. A part not given is shown as such. A request taken in is a subject under Later, pending; a refused one is closed with its reason. (French: demande de cas d'usage.)
_Avoid_: intake form, request form, use case sheet

**Check report**:
The view the check writes, errors first, then warnings grouped by rule: the one view named a report.
_Avoid_: check results, audit report, lint output

**Morning page**:
The view the register tool writes each morning for the PO to read in a browser, from the register, the calendar snapshot and the agent's notes: Do first, today's meetings, Start soon with the workload, what the PO owes and is owed, decisions, messages awaiting a reply, backlog alerts and To sort. The one view named a page.
_Avoid_: dashboard, daily report, morning view

**Weekly synthesis**:
The view written each week for the sponsor.
_Avoid_: weekly report, weekly brief, status report

**Steering pack**:
The view the register tool writes for a steering committee of the calendar snapshot, from the register and the agent's commentary: one HTML deck of six slides in a fixed order, one landscape page each, a long list going on over the slides after its own, verified like the weekly synthesis. The morning page offers it from five working days before the committee until it exists. The PO presents it and shares it as a PDF; it counts for nothing until the PO uses it. (French: dossier du comité.)
_Avoid_: board pack, presentation, slides

**Meeting brief**:
For one meeting of the calendar snapshot: the subjects whose watch lists its title and attendees match (kept to a client bank's subjects when the meeting names that bank), their open commitments, the decisions awaited and what each still lacks.
_Avoid_: meeting prep, briefing (which is the morning conversation with the PO), agenda

**Do first**:
The three actions the agent recommends the PO start the day with, at the top of the morning page, each with one line of why. A commitment of the PO whose latest start is today or past and that is not started is always among them.
_Avoid_: top priorities, focus list, today's tasks

**Backlog alert**:
A ticket of a watched project that the morning page points out: one that contradicts a recorded decision, one not ready for the next refinement, or one that is stale.
_Avoid_: ticket warning, backlog issue

**Reminder**:
A draft the agent offers to chase a commitment owed to the PO that is late. The PO sends it; the agent never does.
_Avoid_: chaser, follow-up

**Nudge**:
A draft the agent offers for a commitment owed to the PO that is due within three working days with no sign of progress, before it slips. The PO sends it; the agent never does.
_Avoid_: ping, reminder (which is for one already late)

**Export**:
The digest of the register for a period that the register tool prints: the material the weekly synthesis is written from.
_Avoid_: dump, extract, report

**Verify**:
To check a stored view against the register: its stamp is present, and every record identifier it cites exists and is current.
_Avoid_: validate, review, proofread
