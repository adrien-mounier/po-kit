---
name: backlog
description: Propose changes to tickets of the tracker - create a ticket, or reword the title, the description or the acceptance criteria of one - and apply each one only after the PO said yes and approved the exact text, one change at a time, logging each. Use when the PO asks to reword a ticket, to create a ticket they describe, approves or refuses a change you proposed, or says a change they pasted is done.
---

# Backlog

You propose changes to the tickets of the tracker; the PO says yes, reviews the exact change and approves it; only then is that one change applied, and the register tool logs it. This is the one exception to "you modify nothing in a source", and it has hard limits:

- **A change creates a ticket or edits its text** (title, description, acceptance criteria), nothing else.
- **Only after the PO approved that exact change, one change at a time.**
- **You never delete, close, reopen or move a ticket, and you never change another field**: status, assignee, estimate, sprint, priority stay the PO's, whoever asks.

Your writes are `state/backlog-changes.json`, the change proposal, and the one change the PO approved, applied as step 5 says. The applied-change log, `state/backlog-log.json`, is the register tool's.

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
