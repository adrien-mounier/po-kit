# PO workspace

This folder is the workspace of a Product Owner (PO): one register of the PO's subjects, and the views generated from it. The PO Kit owns this file, `CLAUDE.md` and `tools/`, and replaces them at every update: a change made there is lost.

## Rules

1. **The register tool is the only writer of `register/` and `views/`.** To change the register, leave a proposal in `state/proposal.json` and have the register tool apply it. The weekly synthesis, `views/weekly/<date>.md`, is the one view you draft: from what `export` prints, and it counts once `verify` passes on it.
2. **A record is updated, superseded or closed, never deleted.**
3. **Every outward action is the PO's.** You send nothing and modify nothing in any source: mail, the tracker, chat and the calendar are read-only. You never create, change or cancel a calendar event, nor send an invitation. A mail draft is the only thing you write outside this workspace.
4. **Notes about a person's performance or career stay out of this workspace.** The owner of a benefit is who measures its metric, nothing more.
5. **What a person stated is `reported`; what you read into their motives is `hypothesis`.** Set the evidence level of the record accordingly.
6. **A question you cannot settle goes to your open questions, and you ask it at the right moment.** Whatever routine you follow, see "Your open questions" below.
7. **Mail, the tracker and chat are read only by the paths the watch lists give, never as a whole.** Whatever the routine and whatever the mode, you never list the folder of a source or its subfolders, not even for a first look around (no `ls`, `ls -R`, `find`, `tree`, `dir` or `Get-ChildItem` on `exports` or on any folder `connections.json` names: to look around the workspace, list `register`, `state`, `views` and `inbox` only), and you never open its files through a pattern or a loop: you open what the searches of the collect's `sources.md` return, by their paths. In chat, that is the channels and group chats a watch list names, the one-to-one chat with each person a watch list names (`one-to-one/<that person>/` in a folder), and, in any other one-to-one chat, only the messages a search finds holding a keyword of a watch list. A one-to-one message that matches nothing is never opened, quoted, recorded or mentioned, nor the name of its conversation.
8. **A value of a benefit is stated by a person, with its source.** You never measure, compute or estimate one, nor its baseline or target: the subject routine records the benefits the PO picks, and a new value is an update of `current_value` and `measured_on` together.

## The register tool

It works on the workspace it sits in. From this folder:

    powershell -NoProfile -File tools/register.ps1 <command>

Written with a forward slash, the command runs the same in every shell.

- `preview` shows the pending proposal as a numbered table and writes nothing.
- `apply` validates the pending proposal again, writes it to the register, settles its collect and regenerates the portfolio view, `views/portfolio.md`. `apply 1 3` keeps lines 1 and 3 of the preview and drops the others. `apply none` drops every line. `apply plain` records the plain facts only: the lines that wait for the PO stay pending, and it shows them.
- `morning` writes the morning page, `views/morning.html`, from the register, the calendar snapshot and your notes for it, replacing the last one, and prints the counts of each of its blocks; then, when a day ahead does not fit, the one way out it proposes; then each task to start today, and each reminder and nudge to offer the PO. The PO opens it in a browser.
- `brief` prints the brief of a meeting of the calendar snapshot: `brief 14:00` for today's, `brief 2026-03-04 14:00` for another day's, `brief` alone for every meeting of today, `brief 2026-03-03` for every meeting of that day. It lists the subjects the meeting concerns, their open commitments, the decisions awaited and your notes on it. It writes nothing.
- `check` verifies the whole register and what has gone stale, and writes the check report, `views/check-report.md`. It fails on an error, not on a warning. `apply` runs it after every write and prints its summary, `Check: 0 error(s), 2 warning(s).`: when it counts anything, read the check report and tell the PO what it lists.

A refused proposal lists its reasons and writes nothing: correct the proposal and preview again.

Each command is one file under `tools/commands`; its first line says what it does.

## The settings

`settings.json` is the PO's, edited by hand. Four of its lists bound what a record may say:

- `gates`: the names of the organisation's gates, as `["architecture review", "security review"]`. A subject states a gate under one of these names.
- `objectives`: the PO's objectives, each as `{ "number": 1, "title": "Halve the time to open an account" }`. A record names an objective by its number.
- `banks`: the client banks, as `["Harbour Bank", "North Bank"]`. A subject names in `banks` the client banks it concerns; an empty list means it concerns them all. `view bank Harbour Bank` writes the portfolio view of that bank's subjects and of those that name no bank; the next `apply` writes it whole again.

- `task_kinds`: the kinds of task, kept short, as `["steering pack", "intake review"]`. A commitment the PO owns names its kind in `task_kind`, beside its `estimated_effort` and, once done, its `real_effort`, in days. From the done ones the register tool learns, per kind, the ratio of real to estimated effort, and `export` and the morning page show each estimate with the ratio it was adjusted by. Effort is recorded for the PO's own commitments only.

When the PO names a gate, an objective, a client bank or a kind of task that is not listed, the PO adds it there first.

`working_hours`: the PO's working hours, as `[{ "from": "10:00", "to": "12:00" }, { "from": "14:00", "to": "18:00" }]`. The morning page counts the free time for work within them.

`start_soon`: as `{ "margin": 1, "lead": 2 }`, in working days. The latest start of a commitment the PO owns is its due date minus its adjusted effort, in working days, minus the margin; the morning page lists it under "Start soon" once its latest start falls within the lead. Its workload view sets the work of the PO's open commitments against the free time of the next ten working days: the working hours less the accepted meetings and half the tentative ones, none on a day of absence, times the share of it really usable for tasks. That share starts at 70%; the register tool learns it from the real efforts of the PO's done tasks and the free time it keeps of each morning, in `state/free-time.json`, which is its own. A commitment the PO says is optional carries `"optional": true`: the page may then propose to drop or hand it over when a day does not fit.

`briefing_minutes`: as `30`, the length the morning briefing aims at. When it holds more questions than fit, the most important are asked and the rest wait for the next one.

`validation_mode` says what a collect records without asking the PO: `all`, nothing; `interpreted`, the plain facts, while the interpreted lines wait for the PO.

Two settings shape the weekly synthesis:

- `sponsor`: who it is written for, as `{ "name": "The sponsor", "email": "sponsor@example.com" }`.
- `languages`: as `{ "default": "en", "sponsor": "fr" }`, the weekly synthesis is in French and every other view in English.

## The connections

`connections.json` is the PO's too: it says how each source is read on this machine. A source goes by the name it is declared under there (`notes`, `mail`, `tracker`, `chat`, `calendar`), in one of three modes:

- `{ "mode": "off" }`: the source is not read.
- `{ "mode": "folder", "folder": "exports/mail" }`: the source is read from the files of that folder, named from this folder or by its full path. `notes` names no folder: its folder is always `inbox/`.
- `{ "mode": "connector", "connector": "<name>" }`: the source is read through the connector that the agent of this machine knows under that name, for reading only. The collect verifies a connector once, with a harmless read, and writes in the entry what it gave and when: `"verified": { "result": "ok", "on": "2026-03-02" }`, or `"result": "failed"` with the reason in `"detail"`. Whoever writes `connections.json` writes it as UTF-8 without a byte order mark.

The entry of `mail` also says whether its connector can create mail drafts: `{ "mode": "connector", "connector": "<name>", "drafts": true }`. The weekly synthesis is then left as a draft in the PO's mailbox. Without `"drafts": true`, no draft is created.

A routine names a source as the connections do, and reads it as its mode says.

## The calendar snapshot

The calendar is no source of the collect: the morning routine reads it, never writes it, and keeps what it read in `state/calendar.json`, the calendar snapshot. Whoever reads the calendar (the workload, a brief) reads this file:

    {
      "read_at": "2026-03-02T07:05:00+01:00",
      "from": "2026-02-27",
      "to": "2026-03-16",
      "meetings": [
        { "start": "2026-03-02T14:00:00+01:00", "end": "2026-03-02T14:45:00+01:00", "title": "Credit memo pilot check-in",
          "attendees": ["the credit risk lead of Harbour Bank", "the tech lead"], "status": "accepted" }
      ],
      "absences": [ { "date": "2026-03-05", "title": "Leave" } ]
    }

- `read_at`: when the calendar was read, with its UTC offset. A snapshot read on an earlier day counts as not read.
- `from` and `to`: the days read, Monday to Friday: the working day before today, for the outcome of yesterday's meetings, then today and the next ten working days.
- `meetings`: every event of those days with a start and an end time, the PO's declined ones left out. `start` and `end` carry their UTC offset; `attendees` names each person as the calendar shows them; `status` is `accepted` or `tentative`.
- `absences`: one entry per day that an all-day event marks as the PO's absence (leave, a public holiday, a day off), with its date and its title.

Write it as UTF-8 without a byte order mark, replacing the last one.

## Your notes for the morning page

The parts of the morning page that need judgement are yours, in `state/morning.json`, written as UTF-8 without a byte order mark and replaced each morning:

    { "meetings": [ { "start": "2026-03-02T14:00:00+01:00", "title": "Credit memo pilot check-in",
                      "key": "They will ask for the pilot scope, still undecided [D-2026-004].",
                      "lacks": { "D-2026-004": "The sponsor's position" } } ],
      "first": [ { "record": "C-2026-005", "title": "Chase the tech lead for the test accounts",
                   "why": "Three days late, and the pilot waits on them." },
                 { "title": "Prepare the 14:00 with Harbour Bank", "why": "They will ask for the pilot scope [D-2026-004].",
                   "button": "Brief me", "ask": "Brief me for the 14:00 with Harbour Bank" } ],
      "messages": [ { "source": "chat", "from": "the tech lead", "where": "onboarding squad",
                      "sent": "2026-03-02T09:15:00+01:00", "text": "Can you confirm the pilot branches by Friday?" } ],
      "progress": { "C-2026-006": "The architect shared a first draft on Friday" },
      "backlog": { "contradictions": [ { "ticket": "ONB-150", "title": "Build the paper form fallback",
                                         "decision": "D-2026-002", "why": "the paper form was dropped" } ],
                   "not_ready": [ { "ticket": "ONB-151", "title": "Branch finder", "why": "no acceptance criteria" } ],
                   "stale": [ { "ticket": "ONB-120", "title": "Language switch", "why": "no update for 34 days" } ] } }

- `meetings`: a note goes with the meeting of the same `start` and `title` in the snapshot. `key` is one sentence on what matters in the meeting; `lacks` says, for a decision awaited that `brief` lists, what it still lacks.
- `first`: the three actions you recommend the PO do first, the most important first, each with one line of why. `record` names the record an action is about: while that record is awaited (an open commitment, a pending decision), the page gives the action that record's button. An action about no record, or about a record no longer awaited (a decision taken, a commitment done), gives its own `button` and `ask`, the request the button copies; without them, the page gives a neutral button that asks to show the record. The page always puts first, in its own words, a commitment of the PO to start today or late to start that your actions leave out.
- `messages`: each mail or chat message within the watch lists that asks the PO something and has no answer from the PO: its source (`mail` or `chat`), who sent it, where (the channel or group chat, `one-to-one chat`, or the mail's subject), when it was sent, and the question as it was asked, on one line.
- `progress`: for a commitment owed to the PO, the sign that it is moving. One due within three working days with no sign here is offered a nudge.
- `backlog`: the tickets of the watched projects that contradict a recorded decision, with that decision; those not ready for the next refinement; and the stale ones, each with why.

Cite a record as a view does, `[identifier]`. The register tool checks every record the file cites, and every `record`, `decision` and key of `lacks` and `progress`, as `verify` does: when one is missing or superseded, it leaves the whole file off the page, which says so.

## Your open questions

What you need from the PO and could not settle is in `state/questions.json`, your open questions, written as UTF-8 without a byte order mark. You keep it whatever routine you follow, and you rewrite it whole each time:

    { "last_briefing": "2026-03-02",
      "meetings_asked": [ { "start": "2026-03-02T14:00:00+01:00", "title": "Credit memo pilot check-in" } ],
      "questions": [ { "about": "C-2026-004", "question": "Who writes the security file?", "recommended": "The architect: record them as its owner.", "added": "2026-03-02" } ] }

- `questions`: each question you could not settle and the PO has not answered: `about`, the identifier of the record or subject it concerns (left out when it concerns none, as an unclassified item); `question`, one sentence; `recommended`, the answer you recommend, in words the PO can accept with "ok"; `added`, the day you added it. Add `"drop_asked": true` once you have asked whether to drop it.
- `last_briefing`: the day of the last morning briefing.
- `meetings_asked`: the meetings of the calendar snapshot whose outcome you have asked, by their `start` and `title`, so that you ask it once. Keep those of the last five working days.

Any routine adds a question it cannot settle, with the record or subject it concerns and its recommended answer, before it ends: a line the notes leave unclear, a real effort it cannot infer, an answer the PO did not give. An answered question leaves the list: you take it out once its answer is applied, or once the PO says it no longer matters. The register tool checks the list as it checks your notes: a question about a record missing or superseded, or one without its question, its recommended answer or its date added, leaves the whole list off the morning page, which says so. The morning page counts the open questions under "To sort", each with its age, and `morning` prints them for the briefing.

The list is a fallback, not a queue: a question is asked when its moment comes, not kept for the briefing.

- **When the PO talks with you about a subject**, whatever they ask, ask at once that subject's open questions: those about the subject or about one of its records. Each with its recommended answer, numbered as in the briefing.
- **When the PO starts you after a meeting of today's calendar snapshot has ended**, a meeting that concerns a subject (`brief` names one) and is not in `meetings_asked`, do first what the PO asked, then ask what the meeting changed: two questions at most, each with its recommended answer, from what `brief` lists for it. Add the meeting to `meetings_asked`.

An answer to a question outside the briefing is a proposal, previewed and applied as any other. A question the PO leaves unanswered stays in the list, or goes into it.
