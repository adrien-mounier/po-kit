---
name: collect
description: Turn the notes of the PO's inbox, any text the PO pastes, and the mail, tracker tickets and chat messages within the watch lists into a proposal of commitments, decisions, risks and subject updates, shown to the PO before anything is recorded. Use when the PO says "collect", has dropped notes in the inbox, or pastes notes to record.
---

# Collect

You read the PO's notes, and the mail, the tickets and the chat messages within the watch lists, and say what they change in the register, the PO decides, and the register tool writes. Your only writes are a pasted text saved as a note in `inbox/`, the verification of a connector in `connections.json`, and `state/proposal.json`.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool.

**Mail, the tracker and chat are read only as `sources.md` says, never listed.** No `ls`, `ls -R`, `find`, `tree`, `dir` or `Get-ChildItem` on `exports` or on any folder `connections.json` names, not even for a first look: to look around the workspace, list `register`, `state`, `views` and `inbox` only.

## 1. Settle a pending proposal first

When `state/proposal.json` exists, a proposal is pending and this collect waits for it. Run the register tool's `preview`, show the PO its table, ask whether to apply it, change it or delete it, and end there.

Done when no proposal is pending.

## 2. Gather the notes

1. Read the clock of the machine, once:

       powershell -NoProfile -Command "Get-Date -Format yyyy-MM-ddTHH:mm:sszzz"

   It prints the time of this collect, as `2026-03-02T08:30:00+01:00`. Its first ten characters are today's date.
2. Text the PO pasted into the conversation becomes a note first. Save it unchanged as `inbox/pasted-<today's date>.md`, as `inbox/pasted-2026-03-02.md`, written as UTF-8 without a byte order mark. When `inbox/` or `inbox/done/<this month>/` already holds that name, end it with `-2`, then `-3`.
3. The notes are the files directly in `inbox/`. Read each one whole. `inbox/done/` holds the notes already processed.
4. `connections.json` declares the other sources, `mail`, `tracker` and `chat`. A source whose `mode` is `off` is not read: it is not covered. To read one in any other mode, follow `sources.md`, in the folder of this routine, before you look into the source, and never list its folder: it gives you the mails, the tickets and the chat messages to treat as notes. `connections.json` may also declare `calendar`: it is no source of the collect, which neither reads it nor names it among the sources read or not covered.

A file you cannot read as text is not processed: it stays in the inbox, and you tell the PO.

When there is no note, and no mail, ticket or chat message to treat as one, there is nothing new to collect, and the register tool must still learn that the sources were read. Write the proposal of step 5 with no operation, `"operations": []`, and run the register tool's `apply` at once, without asking the PO: there is nothing to validate. Then tell the PO that nothing new was found, and which sources are not covered: the routine ends here.

Done when you have read every note of the inbox, and every source of `connections.json` but the calendar is read or not covered.

## 3. Read what the register holds

Run the register tool's `export` with today's date, as `export 2026-03-02`. It lists the active subjects, the open commitments, the pending decisions and the open risks: one line per record, its identifier in brackets.

The record of a subject is `register/subjects/<identifier>.json`. Read the record of each subject a note is about: it gives the next step and the gates that the note may change. A watch list tells which subject a note is about when the note does not name it.

Done when you know the subject each note is about, and the records of the register that a note changes or replaces.

## 4. Turn each note into operations

Take each note from top to bottom: the operations follow the order in which the notes state things.

| The note states | Operation |
|---|---|
| Someone is to do something: an action, a promise, a deliverable | create a `commitment`: `owner` who does it, `owed_to` who it is for, `due_date` |
| A choice that was made | create a `decision`: `status` `taken`, and `decided_by` who made it |
| A choice that is awaited | create a `decision`: `status` `pending`, `needed_from` who must make it, `needed_by` the date it is needed |
| A threat to a subject or to a commitment: a danger, a blocking decision that cannot wait, a person who stands against the plan | create a `risk`: `severity` `urgent` when the note says it cannot wait, `watch` otherwise |
| A change of a subject itself: its horizon, its clearance, a gate, its next step | update the subject |
| A change of a commitment, a decision or a risk of the register: done, dropped, closed, a new due date | update that record |
| A sign that the PO has started a commitment the PO owns: a ticket of it moved to in progress, a mail or a document the PO wrote about it | update that commitment: see "A start" below |
| Someone asks for an AI use case: to build one, to study one | create a `subject`: see "A request for an AI use case" below |

A person or a date that the note does not give is left out: an action without a due date is a commitment all the same, and the check will list it. What fits no row is not recorded.

**An owner is one person the note names.** Never two people as alternatives ("the tech lead or the architect"), never a person you guess. When the note names no single owner, leave `owner` out and keep the question, as "A question you cannot settle" below says, with the owner you recommend. The register tool refuses an owner that joins two people with "or".

Every created record also gives:

- `title`: one short sentence that reads alone, in the language of the note.
- `subject`: the identifier of the subject the note is about.
- `date_of_fact`: the day the note gives for it (the meeting, the call, the decision), or today when it gives none.
- `evidence_level`: see below.
- `source`: `{ "where": "inbox/<file name of the note>", "read_on": "<today's date>" }`. For a mail, a ticket or a chat message, `where` is as step 4 of `sources.md` says: read from a folder, the path of its file.

When the note says which of the PO's objectives a record serves, the record gives `objectives` too: their numbers as `settings.json` lists them, as `[1]`. A note that names no objective leaves it out, even when the record seems to serve one: that objective is yours to recommend in step 6, and the PO's to attach.

Name a person as the register already does (`the tech lead`), otherwise as the note does. "I" in a note is the PO: `the PO`.

**Evidence level.** How the note knows what it states:

- `fact`: it happened or was agreed, and the note says so plainly: an action taken on, a decision made, a review that did or did not take place.
- `reported`: a person said it, and the note relays it: their position, their opinion, their intention.
- `hypothesis`: the note guesses: at a person's motives, at a cause, at what will happen.

A person's position and a guess at their motives are two records, in that order: the position is `reported`, the guess is `hypothesis`, and neither is ever `fact`. Each is a `risk` when it stands against the plan. Record the guesses the note makes; add none of your own.

**Interpreted or plain fact.** Every operation states `"interpreted"`:

- `true` when it holds your reading of the note: every decision, every change of a status, a clearance, a gate or a horizon, every record that supersedes another, every date or person you had to work out (`by Friday`, `the team`).
- `false` when it says only what the note says in so many words: an action with the owner and the date the note gives.

In doubt, `true`.

**A record that replaces another.** When a note makes a commitment, a decision or a risk of the register obsolete (a plan suspended or abandoned, a decision reversed), the record you create names it in `supersedes`. The register tool then marks the old record `superseded` and links the two: write no update for it.

**A next step that no longer holds.** When a note cancels, suspends or completes what a subject gives as its `next_step`, update the subject too: `next_step` becomes what the note says comes next, or an empty text when it says nothing.

**A gate that did not take place.** When a note says that a gate of a subject never took place, update the subject: `gates` given whole, with that gate `missing`, and `clearance` `out of frame`.

**The effort of what the PO owes.** Each commitment you create whose `owner` is `the PO` is followed, on the next line, by one update that proposes its effort. It names the commitment by its line, `"id": "line 3"` for the commitment that line 3 creates, is `"interpreted": true`, carries the source of the commitment, and gives:

- `estimated_effort`: the days of work you expect the task to take the PO, as `2` or `0.5`;
- `task_kind`: the kind of task, one of `task_kinds` in `settings.json`, word for word;
- `estimate_reason`: your one reason, in one short sentence.

```json
{ "op": "update", "id": "line 3", "interpreted": true,
  "source": { "where": "inbox/steering follow-up.md", "read_on": "2026-03-02" },
  "fields": { "estimated_effort": 2, "task_kind": "steering pack", "estimate_reason": "A steering pack takes about two days." } }
```

When no kind of `task_kinds` fits, leave `task_kind` out, and tell the PO the kind you would add: the PO adds it to the settings. Never propose an effort for what another person owes: the register tool refuses it.

**A start.** A commitment of the PO that is open and not started, without `started` in the export, is started when a source within the watch lists shows it: a ticket of it moved to in progress, a mail or a document the PO wrote about it. Update it, `"interpreted": true`: `started_on` the date of the sign, `started_sign` the sign in a few words, as `ticket ONB-12 moved to in progress`. What the PO says overrides every sign: when the PO says they started, `started_on` is the day they say and `started_sign` is `the PO said so`; when the PO says they have not started, both are given as an empty text. A start the PO stated is never changed by a sign.

**An optional task.** When the PO says that a commitment of theirs is optional, that it could be dropped or handed over, update it with `"optional": true`, plain fact, the PO as its source. Only the PO marks a task optional: never infer it.

**The real effort of what the PO has done.** When you update a commitment of the PO to `done`, give in that same update, never in a line of its own, `real_effort`, the days the task really took the PO, as `"fields": { "status": "done", "real_effort": 3 }`, when it is clear: a note, a mail or the PO says how long it took, or the calendar, when this workspace reads one, shows the time the PO blocked for that task. The days between its start and its end are not its effort: a task shares them with others. When it is not clear, leave `real_effort` out and keep one question for the PO, with your guess, its estimate when it has one: `Real effort of C-2026-004, "Build the steering pack": how many days did it take you? My guess: 2 d.` The PO's answer is an update of that record that gives `real_effort`, with the source `{ "where": "the PO, in conversation", "read_on": "<today's date>" }`.

**A request for an AI use case.** Whoever asks, and even when it is about no subject of the register, the request becomes a new subject, never an unclassified item. Create a `subject`, `"interpreted": true`, that gives:

- `title`: the name the request gives the use case, word for word, else a short name of what it does;
- `kind` `product` unless the request says otherwise, `horizon` `later`, `clearance` `pending`;
- the intake parts the request gives, in its words: `problem` (what goes wrong today), `banks` (the client bank it is for, as `settings.json` lists it), `requested_by` (who asks, named as above), `data_needed` and `expected_gain`;
- `work_changes` when the request says plainly whether the way people work changes (`yes`) or only a tool is added (`no`), with that in one sentence in `work_changes_reason`;
- `evidence_level` `reported` and `source`; a subject gives no `subject` and no `date_of_fact`.

A part the request does not give is left out: keep one question for it, with the answer you recommend. **Every new subject gets the work changes question**: when the source does not settle it, keep the question `Does <title> change the way people work, or only add a tool?`, with your recommended answer and why, as `No: the analysts keep their work and gain a search tool.` While the line waits for the PO, ask these questions in the same answer as the table; once the subject is recorded, those not answered go to your open questions, about the subject. Then run the register tool's `view intake <identifier of the subject>`, and tell the PO where the intake card is: a draft, to review before using it.

**What fits no subject.** A passage that matters to the PO's work and is about no subject of the register becomes no record. It goes to `unclassified`, with the note as its source, and you tell the PO.

**A question you cannot settle.** When a note leaves unclear something a record needs (who of two people owns it, a date "to be confirmed", which subject a passage is about), record what the note does say and keep the question. Once the proposal is applied or waits for the PO, add it to your open questions, as `AGENTS.md` says: about the record once it is recorded, its subject otherwise, with the answer you recommend. A real effort you keep a question for goes there too. The briefing asks them when the PO does not answer first.

Done when every statement of every note is an operation, an unclassified item, or left out because it fits no row.

## 5. Write the proposal

Write `state/proposal.json` as UTF-8 without a byte order mark:

```json
{
  "collected_at": "2026-03-02T08:30:00+01:00",
  "sources_read": [ { "source": "notes", "cutoff": "2026-03-02T08:30:00+01:00", "items": 1 } ],
  "sources_not_covered": [ "mail", "tracker" ],
  "notes_processed": [ "call with the lending analyst.md" ],
  "unclassified": [ { "source": "inbox/call with the lending analyst.md", "text": "The branch network asks who owns the queue screens." } ],
  "operations": [
    { "op": "create", "type": "commitment", "interpreted": false,
      "fields": {
        "title": "Send the rate table to the PO",
        "subject": "loan-calculator", "date_of_fact": "2026-02-27",
        "owner": "the lending analyst", "owed_to": "the PO", "due_date": "2026-03-13",
        "evidence_level": "fact",
        "source": { "where": "inbox/call with the lending analyst.md", "read_on": "2026-03-02" } } },
    { "op": "create", "type": "decision", "interpreted": true,
      "fields": {
        "title": "Drop early repayment from the first version",
        "subject": "loan-calculator", "date_of_fact": "2026-02-27",
        "status": "taken", "decided_by": "the head of lending",
        "supersedes": "C-2026-004",
        "evidence_level": "fact",
        "source": { "where": "inbox/call with the lending analyst.md", "read_on": "2026-03-02" } } },
    { "op": "update", "id": "loan-calculator", "interpreted": true,
      "source": { "where": "inbox/call with the lending analyst.md", "read_on": "2026-03-02" },
      "fields": {
        "clearance": "out of frame",
        "gates": [ { "name": "architecture review", "state": "missing" }, { "name": "security review", "state": "not required" } ] } }
  ]
}
```

- `collected_at` is the time read from the clock.
- `sources_read` holds one entry per source read, in the order of `connections.json`. For `notes`, `cutoff` is the time read from the clock and `items` the number of notes read, 0 included. For `mail`, `tracker` and `chat`, `sources.md` says what the entry holds.
- `sources_not_covered` names every source of `connections.json` but the calendar that was not read, in the same order.
- `notes_processed` holds the file name of every note read, without `inbox/`. The register tool files them under `inbox/done/` when the proposal is applied.
- `fields` of an update holds only the fields that change, each with its whole new value, and the update carries its own `source`.
- The register tool sets the identifiers, the dates recorded and the history.

Done when the proposal holds one operation per change found in step 4, and every note read is in `notes_processed`.

## 6. Preview, then apply once the PO accepts

1. Run the register tool's `preview`. When it refuses the proposal, it lists its reasons: correct the proposal and preview again. A reason the notes cannot settle is a question for the PO.
2. An answer the PO gave ahead, with the request, counts: go to 4. Otherwise the last line of `preview` states the validation mode the PO chose in the settings:
   - `Validation mode: all.` Every line waits for the PO, and the table to show is the one `preview` printed.
   - `Validation mode: interpreted.` The PO accepted the plain facts ahead: run `apply plain`. It records them, files the notes, and prints under `Waiting for the PO` the table of the lines that still wait, numbered again from 1: that table is the one to show. Tell the PO first what was recorded without asking: each record with its identifier, the notes filed, what went to unclassified, what the check found. When it prints no such table, no line waits.
3. Copy the table into your answer, unchanged, every line and every column: the PO reads there the evidence level and the interpreted mark of each line, and names lines by their number. Say that these lines wait for the PO, then wait for the answer.
4. Do as the PO says:
   - The PO accepts: run `apply`.
   - The PO drops lines: run `apply` with the numbers of the lines kept. `apply 1 3` keeps lines 1 and 3; the others are dropped for good.
   - The PO drops every line: run `apply none`. Nothing more is recorded, the notes not yet filed are filed, and no proposal stays pending.
   - The PO wants a line changed: correct the proposal and preview again.

**Recommend an objective the note did not name.** The export of step 3 lists the PO's objectives under `Records per objective`, each with its number and its title. When a line seems to serve one of them and its note does not name it, tell the PO in one line, in the same answer as the table or as what was recorded: the number of the line, or the identifier of the record once it is recorded, the objective by its number and its title, word for word, and why. As: `Line 2 seems to serve objective 2, "Answer every loan request within two days": the rate table is what the answer waits for. Shall I attach it?` A recommendation changes nothing and holds nothing back: the line is shown, applied or left waiting as it is, without the objective. Attach the objective only once the PO says yes: to a line still pending, by adding `objectives` to it in the proposal and previewing again; to a record already recorded, by proposing an update of that record that gives `objectives`.

**Ask the real effort you could not infer.** Each question on a real effort that you kept in step 4 goes in the same answer, one line each, as step 4 writes it. When the PO answers, propose the update it gives and preview it as any proposal.

Done when every line is recorded, dropped, or shown to the PO as waiting for them, you have told the PO each record written with its identifier, the notes filed, what went to unclassified, what the check found, each objective you recommend and each real effort you ask, each subject a request created has its intake card, and each question you could not settle is in your open questions.
