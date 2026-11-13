# PO workspace

This folder is the workspace of a Product Owner (PO): one register of the PO's subjects, and the views generated from it. The PO Kit owns this file, `CLAUDE.md` and `tools/`, and replaces them at every update: a change made there is lost.

## Rules

1. **The register tool is the only writer of `register/` and `views/`.** To change the register, leave a proposal in `state/proposal.json` and have the register tool apply it. The weekly synthesis, `views/weekly/<date>.md`, is the one view you draft: from what `export` prints, and it counts once `verify` passes on it.
2. **A record is updated, superseded or closed, never deleted.**
3. **Every outward action is the PO's.** You send nothing and modify nothing in any source: mail, the tracker and chat are read-only. A mail draft is the only thing you write outside this workspace.
4. **Notes about a person's performance or career stay out of this workspace.**
5. **What a person stated is `reported`; what you read into their motives is `hypothesis`.** Set the evidence level of the record accordingly.

## The register tool

It works on the workspace it sits in. From this folder:

    powershell -NoProfile -File tools/register.ps1 <command>

Written with a forward slash, the command runs the same in every shell.

- `preview` shows the pending proposal as a numbered table and writes nothing.
- `apply` validates the pending proposal again, writes it to the register, settles its collect and regenerates the portfolio view, `views/portfolio.md`. `apply 1 3` keeps lines 1 and 3 of the preview and drops the others. `apply none` drops every line. `apply plain` records the plain facts only: the lines that wait for the PO stay pending, and it shows them.
- `check` verifies the whole register and what has gone stale, and writes the check report, `views/check-report.md`. It fails on an error, not on a warning. `apply` runs it after every write and prints its summary, `Check: 0 error(s), 2 warning(s).`: when it counts anything, read the check report and tell the PO what it lists.

A refused proposal lists its reasons and writes nothing: correct the proposal and preview again.

Each command is one file under `tools/commands`; its first line says what it does.

## The settings

`settings.json` is the PO's, edited by hand. Two of its lists bound what a record may say:

- `gates`: the names of the organisation's gates, as `["architecture review", "security review"]`. A subject states a gate under one of these names.
- `objectives`: the PO's objectives, each as `{ "number": 1, "title": "Halve the time to open an account" }`. A record names an objective by its number.

When the PO names a gate or an objective that is not listed, the PO adds it there first.

`validation_mode` says what a collect records without asking the PO: `all`, nothing; `interpreted`, the plain facts, while the interpreted lines wait for the PO.

Two settings shape the weekly synthesis:

- `sponsor`: who it is written for, as `{ "name": "The sponsor", "email": "sponsor@example.com" }`.
- `languages`: as `{ "default": "en", "sponsor": "fr" }`, the weekly synthesis is in French and every other view in English.

## The connections

`connections.json` is the PO's too: it says how each source is read on this machine. A source goes by the name it is declared under there (`notes`, `mail`, `tracker`, `chat`), in one of three modes:

- `{ "mode": "off" }`: the source is not read.
- `{ "mode": "folder", "folder": "exports/mail" }`: the source is read from the files of that folder, named from this folder or by its full path. `notes` names no folder: its folder is always `inbox/`.
- `{ "mode": "connector", "connector": "<name>" }`: the source is read through the connector that the agent of this machine knows under that name, for reading only. The collect verifies a connector once, with a harmless read, and writes in the entry what it gave and when: `"verified": { "result": "ok", "on": "2026-03-02" }`, or `"result": "failed"` with the reason in `"detail"`. Whoever writes `connections.json` writes it as UTF-8 without a byte order mark.

The entry of `mail` also says whether its connector can create mail drafts: `{ "mode": "connector", "connector": "<name>", "drafts": true }`. The weekly synthesis is then left as a draft in the PO's mailbox. Without `"drafts": true`, no draft is created.

A routine names a source as the connections do, and reads it as its mode says.
