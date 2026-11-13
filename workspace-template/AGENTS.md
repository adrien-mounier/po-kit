# PO workspace

This folder is the workspace of a Product Owner (PO): one register of the PO's subjects, and the views generated from it. The PO Kit owns this file, `CLAUDE.md` and `tools/`, and replaces them at every update: a change made there is lost.

## Rules

1. **The register tool is the only writer of `register/` and `views/`.** To change the register, leave a proposal in `state/proposal.json` and have the register tool apply it. The weekly synthesis, `views/weekly/<date>.md`, is the one view you draft: from what `export` prints, and it counts once `verify` passes on it.
2. **A record is updated, superseded or closed, never deleted.**
3. **Every outward action is the PO's.** You send nothing and modify nothing in any source: mail, the tracker, chat and the calendar are read-only. You never create, change or cancel a calendar event, nor send an invitation. A mail draft is the only thing you write outside this workspace.
4. **Notes about a person's performance or career stay out of this workspace.**
5. **What a person stated is `reported`; what you read into their motives is `hypothesis`.** Set the evidence level of the record accordingly.

## The register tool

It works on the workspace it sits in. From this folder:

    powershell -NoProfile -File tools/register.ps1 <command>

Written with a forward slash, the command runs the same in every shell.

- `preview` shows the pending proposal as a numbered table and writes nothing.
- `apply` validates the pending proposal again, writes it to the register, settles its collect and regenerates the portfolio view, `views/portfolio.md`. `apply 1 3` keeps lines 1 and 3 of the preview and drops the others. `apply none` drops every line. `apply plain` records the plain facts only: the lines that wait for the PO stay pending, and it shows them.
- `morning` writes the morning page, `views/morning.html`, from the register, the calendar snapshot and your notes on the meetings, replacing the last one, and prints the counts of each of its blocks, then, when a day ahead does not fit, the one way out it proposes. The PO opens it in a browser.
- `brief` prints the brief of a meeting of the calendar snapshot: `brief 14:00` for today's, `brief 2026-03-04 14:00` for another day's, `brief` alone for every meeting of today. It lists the subjects the meeting concerns, their open commitments, the decisions awaited and your notes on it. It writes nothing.
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
      "from": "2026-03-02",
      "to": "2026-03-13",
      "meetings": [
        { "start": "2026-03-02T14:00:00+01:00", "end": "2026-03-02T14:45:00+01:00", "title": "Credit memo pilot check-in",
          "attendees": ["the credit risk lead of Harbour Bank", "the tech lead"], "status": "accepted" }
      ],
      "absences": [ { "date": "2026-03-05", "title": "Leave" } ]
    }

- `read_at`: when the calendar was read, with its UTC offset. A snapshot read on an earlier day counts as not read.
- `from` and `to`: the days read, today and the next ten working days, Monday to Friday.
- `meetings`: every event of those days with a start and an end time, the PO's declined ones left out. `start` and `end` carry their UTC offset; `attendees` names each person as the calendar shows them; `status` is `accepted` or `tentative`.
- `absences`: one entry per day that an all-day event marks as the PO's absence (leave, a public holiday, a day off), with its date and its title.

Write it as UTF-8 without a byte order mark, replacing the last one.

Your notes on today's meetings, the parts of a brief that need judgement, are in `state/morning.json`:

    { "meetings": [ { "start": "2026-03-02T14:00:00+01:00", "title": "Credit memo pilot check-in",
                      "key": "They will ask for the pilot scope, still undecided [D-2026-004].",
                      "lacks": { "D-2026-004": "The sponsor's position" } } ] }

A note goes with the meeting of the same `start` and `title` in the snapshot. `key` is one sentence on what matters in the meeting; `lacks` says, for a decision awaited that `brief` lists, what it still lacks. Cite a record as a view does, `[identifier]`: the register tool checks every record your notes cite as `verify` does, and leaves the notes off the page when one is missing or superseded.
