---
name: subject
description: Create, modify or close a subject of the PO's register by asking the PO a few questions. Use when the PO wants to add a subject, change one (horizon, client banks, clearance, gates, watch list, next step) or close one.
---

# Create, modify or close a subject

The PO answers in plain words, you turn the answers into a proposal, and the register tool writes the record. Your only write is `state/proposal.json`.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool and how `settings.json` lists the gates, the objectives and the client banks.

## 1. Know which subject, and what to do with it

For each subject the PO names, one of three:

- **Create** a subject the register does not hold yet.
- **Modify** a subject: any answer of step 2 can change.
- **Close** a subject: its status becomes `closed`, and the record stays in the register with its history.

To modify or close, find the record. Each file under `register/subjects/` is one subject, and its name without `.json` is the identifier. When what the PO said fits no subject, or more than one, ask which one.

Done when each change names a new title or the identifier of one existing subject.

## 2. Get every answer from the PO

Creating a subject takes the eight answers below. Modifying one takes only the answers that change.

| Ask the PO | Fields | Recorded as |
|---|---|---|
| Its title | `title` | text |
| Its kind | `kind` | `product` (a product the PO steers), `contribution` (to someone else's product) or `service` (rendered to the organisation) |
| Its horizon | `horizon` | `now`, `next` or `later` |
| Which client banks it concerns | `banks` | the names of the client banks, as `settings.json` lists them under `banks`; an empty list when the PO says "none" or "all": the subject concerns the whole group, or every bank |
| Its clearance, who gave it and when | `clearance`, `cleared_by`, `cleared_on` | `cleared` (with who and the date), `pending`, `out of frame` (work exists while a mandatory gate is missing) or `none` |
| The state of each gate | `gates` | one `{ "name": ..., "state": ... }` per gate that `settings.json` lists; the state is `unknown`, `not required`, `missing`, `planned` or `done` |
| Its watch list | `watch_list` | three lists: `people`, `keywords`, `tracker_projects` |
| Its next step | `next_step`, `next_date`, `next_date_confirmed` | text; a date when the PO gives one; confirmed is `true` when the PO says the date is confirmed |

Every answer comes from the PO's own words. "None", "not yet" and "nobody knows" are answers: record `none`, `unknown`, an empty list, or leave the field out. An answer the PO has not given is a question: ask for all the missing ones in one message, in the words of the left column, and stop there. The proposal waits for the PO's reply.

Record these too when the PO mentions them: `owning_entity`, `sponsor`, `decider`, `links`, `notes`, `objectives` (the numbers of the objectives the subject serves), and in the watch list `chat_channels` (the chat channels and group chats to read; a one-to-one chat is never read).

Done when each answer needed is one the PO gave.

## 3. Write the proposal

When `state/proposal.json` already exists, a proposal is pending: preview it, show it to the PO and ask what to do with it before writing another.

Write `state/proposal.json` as UTF-8 without a byte order mark, one operation per subject.

To create:

```json
{ "operations": [ {
  "op": "create", "type": "subject", "interpreted": false,
  "fields": {
    "title": "Loan calculator", "kind": "service", "horizon": "later", "banks": ["Harbour Bank"],
    "clearance": "cleared", "cleared_by": "the head of lending", "cleared_on": "2026-01-15",
    "gates": [ { "name": "architecture review", "state": "done" } ],
    "watch_list": { "people": ["the lending analyst"], "keywords": ["loan"], "tracker_projects": ["LOAN"] },
    "next_step": "Review the first mock-up",
    "objectives": [1],
    "evidence_level": "fact",
    "source": { "where": "conversation with the PO", "read_on": "2026-03-02" }
  } } ] }
```

To modify or close:

```json
{ "operations": [ {
  "op": "update", "id": "loan-calculator", "interpreted": false,
  "source": { "where": "conversation with the PO", "read_on": "2026-03-02" },
  "fields": { "horizon": "now" }
} ] }
```

- `fields` of an update holds only the fields that change, each with its whole new value: a list is given whole.
- To close: `"fields": { "status": "closed" }`.
- `read_on` is today's date, read from the machine.
- What the PO tells you is a plain fact: `"interpreted": false` and `"evidence_level": "fact"`.
- The register tool sets the identifier, the dates and the history.

## 4. Preview, then apply once the PO accepts

1. Run the register tool's `preview`. When it refuses the proposal, it lists its reasons. Correct the proposal when the reason is its form. Ask the PO when the reason is an answer: a gate, an objective or a client bank that `settings.json` does not list is the PO's to add there.
2. Show the PO the table that `preview` printed.
3. Run `apply` once the PO accepts. An acceptance given ahead, with the request, counts. When the PO wants a change, correct the proposal and preview again. When the PO wants nothing recorded, delete `state/proposal.json`.

Done when the register tool has answered `Applied and committed`, and you have told the PO which subject was recorded, with its identifier.
