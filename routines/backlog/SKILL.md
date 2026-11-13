---
name: backlog
description: Propose changes to tickets of the tracker - create a ticket, or reword the title, the description or the acceptance criteria of one - and apply each one only after the PO said yes and approved the exact text, one change at a time, logging each. Use when the PO asks to reword a ticket, to create a ticket they describe, to draft the tickets a meeting note calls for, to split a ticket too large, or how to order the top of the backlog, approves or refuses a change you proposed, or says a change they pasted is done.
---

# Backlog

You propose changes to the tickets of the tracker; the PO says yes, reviews the exact change and approves it; only then is that one change applied, and the register tool logs it. This is the one exception to "you modify nothing in a source", and it has hard limits:

- **A change creates a ticket or edits its text** (title, description, acceptance criteria), nothing else.
- **Only after the PO approved that exact change, one change at a time.**
- **You never delete, close, reopen or move a ticket, and you never change another field**: status, assignee, estimate, sprint, priority stay the PO's, whoever asks.

Your writes are `state/backlog-changes.json`, the change proposal, `state/backlog-order.json`, the order you propose, and the one change the PO approved, applied as step 5 says. The applied-change log, `state/backlog-log.json`, is the register tool's.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. Its section "Changes to the tracker" gives the format of the change proposal; it says how to call the register tool. The tracker is read as the collect's `sources.md` says, never listed: a ticket the PO names is found by searching the tracker's folder for its key, or by asking the connector for it.

## 1. Settle what is pending first

Read `state/backlog-changes.json` when it exists. A change `proposed` or `accepted` waits for the PO: the PO's answer goes to step 3 or 4. A change `approved` and not applied goes to step 5.

When the PO says that a change you gave them to paste is done, run the register tool's `backlog apply <id> done` and end there.

Done when you know which changes wait for the PO and what the PO now asks.

## 2. Propose a change the PO asks for

The PO asks to reword a ticket's text, or to create a ticket they describe.

1. **A request outside the limits is refused.** Closing, deleting, reopening or moving a ticket, changing its status, assignee, estimate, sprint, priority or any field but its text: tell the PO in one line that it stays theirs to do in the tracker, write no change for it, and go on with the rest of the request.
2. **Read the ticket** to edit, as the collect's `sources.md` says: its text as it is now is the text `before`, word for word.
3. **Write the change** in `state/backlog-changes.json`, keeping the changes already there: `state` `proposed`, a new `id` (one more than the highest of the proposal and of `state/backlog-log.json`), the `reason` in one sentence and its `source` (`{ "where": "the PO, in conversation", "read_on": "<today>" }` for a change the PO asked for). One change edits one field: a reworded title and description are two changes.
4. Run the register tool's `backlog check`. When it refuses the proposal, correct it and check again.
5. **Propose it**: one line per change, numbered by its `id`: the ticket, the field, what changes and why. Ask whether the PO wants it.

Done when each change asked for is proposed, and each request outside the limits is refused.

## Draft tickets from a note

The PO asks you to draft the tickets a note calls for: a workshop, a call, a note the collect said describes work for the team. Each draft is a change of kind `create`, proposed as any change: nothing of it reaches the tracker or the register until the PO approved it, through steps 3 to 5.

1. **Read the note whole**: the file of `inbox/` or `inbox/done/` the PO names, or the text the PO pasted.
2. **One draft per need the note states**: a piece of work it asks the team to do. A decision, a commitment or a risk is no ticket: the collect records those.
3. **Its subject.** When the note says which subject a need serves, give its identifier in `subject`, and in `project` the first project of `watch_list.tracker_projects` in its record. A need whose project nothing settles gets no draft: keep an open question, with the project you recommend.
4. **A ticket that already covers it.** Search the tracker for the tickets of that project, as the collect's `sources.md` says for a tracker project, and open those the search returns. A need one of them already covers is not drafted again: tell the PO which ticket covers it, by its key and its title.
5. **Write each draft from the template.** Run the register tool's `backlog template`: it gives the ticket template of this workspace, each text under its name in `after`. Fill each place in braces from the note, in its words, and keep every other line of the template as it is, the definition of ready unticked: the team ticks it. One line of acceptance criteria per criterion the note states. **A criterion, a role or a benefit the note leaves unclear is never invented**: leave it out, and keep an open question about the subject, with the answer you recommend.
6. Write each draft in `state/backlog-changes.json` as step 2 says: `state` `proposed`, a new `id`, the `reason` (the need of the note it carries, in one sentence) and its `source`, the note: `{ "where": "inbox/<file name>", "read_on": "<today>" }`, or `the PO, in conversation` for a pasted text.
7. Run `backlog check` until it passes, then propose the drafts as step 2 says, with each need a ticket already covers and each open question.

Done when each need of the note is a draft proposed, covered by a ticket you named, or an open question.

## 3. Show the exact change the PO said yes to

An answer the PO gave ahead counts only for what it names: a yes to the proposal is not an approval of the exact text.

1. Set each change the PO said yes to as `accepted`; one the PO said no to as `refused`.
2. Run the register tool's `backlog show <id>`, and copy what it prints into your answer, unchanged: the exact text the team will see.
3. Ask the PO to approve that exact change.

Done when the PO has the exact text of each change accepted.

## 4. Record the PO's approval

The PO approves a change `accepted` whose exact text you showed, or approves it ahead in so many words ("I approve change 1 as you showed it"): set it as `approved`. A change still `proposed` is shown first, as step 3 says, whatever the PO said. A change the PO wants reworded is changed and shown again, still `accepted`.

Done when each change the PO approved is `approved`, and no other is.

## 5. Apply one approved change

One change at a time, each only from `approved`. The `mode` of `tracker` in `connections.json` decides how:

- **`folder`**: run `backlog apply <id>`. It writes the change in the outbox of the workspace, `outbox/tracker/<id>.md`, never in the tracker, and logs it.
- **`connector` with `"writes": true`**: read the ticket again through the connector. When its field no longer holds the text `before`, apply nothing: go to "A ticket that changed". Otherwise apply that one change through the connector: that ticket, that field, the text `after`, or that new ticket in that project; nothing else. Then run `backlog apply <id>`: it records the change as applied and logs it.
- **any other**: run `backlog apply <id>`. It prints the change and where it goes, and records nothing. Give the PO that text word for word, to paste in the tracker, and say that it counts as applied only once they tell you it is done: then step 1.

`backlog apply` refuses a change not approved, or applied already: never apply one again.

**A ticket that changed.** When `backlog apply` says the ticket no longer holds the text before, or the connector shows it, nothing is applied. Tell the PO, set the change as `refused`, read the ticket again, and propose the change again from step 2, with a new identifier.

Done when each approved change is applied and logged, given to the PO to paste, or proposed again.

## 6. Tell the PO

Your answer is short:

1. Each change applied, with its ticket and field, and how: in the outbox, through the connector, or to paste.
2. The text to paste, word for word, when the tracker may not write.
3. Each change that waits for the PO's yes or approval.
4. Each request refused, as theirs to do.
5. That the applied-change log is committed with the next apply of the register.

Done when the PO knows what changed in the tracker, what waits for them, and what stays theirs.

## Split a ticket too large

When the PO names a ticket to split, or a ticket you read is too large for one sprint: its estimate is above `split_estimate_above` in `settings.json` (8 when it is not set), or its description holds several needs, each of which a user could get without the others.

1. **Read the ticket** as step 2 says: its text as it is now is the text `before`, word for word.
2. **Cut it into two to four smaller tickets**, each one need a user gets on its own, small enough for one sprint. Each is a `create` change in the original's project. Its texts are written from the ticket template, as for a draft: run the register tool's `backlog template` and fill it. You set no estimate: estimating stays the team's.
3. **Add one `edit` change** of the original's `description`: what remains of it once the smaller tickets exist, naming each by its title. The original is never closed, deleted or moved, whoever asks: that stays the PO's.
4. Write each change as step 2 says, `proposed`: its `reason` says why the ticket is too large (its estimate, or the needs it holds), and its `source` is the ticket as you read it (`{ "where": "exports/tracker/ONB-160.txt", "read_on": "<today>" }` in a folder, `tracker: ONB-160` through a connector). Run the register tool's `backlog check`, and correct the proposal until it passes.
5. **Propose them**, one line per change as step 2 says, and ask which the PO wants. Each one then goes through steps 3 to 5, one at a time: nothing is applied before the PO approved its exact text.

Done when each smaller ticket and the edit of the original are proposed, and nothing is applied.

## Propose an order for the top of the backlog

When the PO asks how to order the backlog, or what the team should take next. Reordering is a move, which stays the PO's: you give the order, the PO reorders in the tracker.

1. **Read the register**: run the register tool's `export` with the date four weeks before today. It prints the active subjects with their horizon, the open commitments with their due date, the pending decisions and the decisions taken since, each with its identifier.
2. **Read the backlog**: search the tracker once for each tracker project of an active subject's watch list, as the collect's `sources.md` says, and open what the searches return. The tickets not done are the backlog.
3. **Place at most `backlog_top` tickets** (`settings.json`, 10 when it is not set), the ticket to take first at the top: one that serves a subject under Now before Next before Later; among them, one that a commitment due soon or a decision awaited by a date waits on before one nothing waits on. A ticket for work a decision taken dropped is not placed: tell the PO. A ticket no record places is left out of the order.
4. **Write `state/backlog-order.json`** as the workspace rules show: each ticket's key, its title and `why`, one sentence that cites by its identifier in square brackets the record that places it, as the export prints it: the subject `[mobile-onboarding]`, the commitment or the decision. A record the export does not print, or that is superseded, is never cited.
5. Run the register tool's `backlog order`. It writes the view `views/backlog-order.md`. When it refuses the order, correct what it lists and run it again.

Then tell the PO: the order, one line per ticket with its reason; the view to open; the tickets left out and why; and that nothing was moved in the tracker: reordering the backlog is theirs, there. You never move a ticket, nor change its rank, priority or sprint, whoever asks.

Done when the view is written and the PO has the order, or knows why there is none.
