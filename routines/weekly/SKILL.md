---
name: weekly
description: Write the weekly synthesis for the sponsor from the PO's register, in the sponsor's language, have the register tool verify it, and leave it as a mail draft when the mail connection can create one. Use when the PO says "weekly" or asks for the weekly synthesis.
---

# Weekly synthesis

You write the weekly synthesis for the sponsor from what the register tool exports, and from nothing else. It is the one view you draft: its stamp and its portfolio view are the register tool's, copied unchanged, and it counts once the register tool has verified it. Your only writes are the synthesis, `views/weekly/<today's date>.md`, and one mail draft when the connections allow it. You send nothing.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool.

## 1. Run the check

Run the register tool's `check`. Its last line counts what it found, as `Check: 0 error(s), 2 warning(s).`

An error means the register cannot be trusted for a synthesis. When the check counts one or more: read `views/check-report.md`, show the PO each error it lists under `## Errors`, with its rule, and end there. Nothing is written, and the errors are the PO's to settle.

Done when the check counts 0 error. Warnings let the synthesis go on.

## 2. Get the period and the team capacity

1. Read today's date from the clock of the machine:

       powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"

2. **The period** starts at the previous synthesis. Each synthesis is stored under its date, as `views/weekly/2026-03-03.md`: list the names of the files of `views/weekly/`, and take the latest date before today. Their names are all you take from them. When no synthesis is stored before today, the PO gives the date the period starts on.
3. **Team capacity** is one sentence that only the PO can give: the register holds nothing on it. The PO may also say there is nothing to say.

What the PO said ahead, with the request, counts. For what is still missing, ask the PO in one message and end there: you write nothing on a date or a sentence of your own.

Done when you hold the date the period starts on, and either the PO's sentence on team capacity or the PO's word that there is none.

## 3. Export the period

Run the register tool's `export` with the date the period starts on, as `export 2026-03-03`. It prints everything the synthesis may say: the stamp, the records and what changed in the period, how each source is covered, and last the portfolio view. The stamp and the portfolio view come in the sponsor's language.

Done when you hold the export.

## 4. Write the synthesis

`settings.json` gives the sponsor's language in `languages.sponsor`. The template of that language is beside this routine, in its folder: `template-en.md` for `en`, `template-fr.md` for `fr`. It gives the six blocks in their order, with their headings and their set phrases. A passage between angle brackets tells you what to write in its place.

Write the template, filled, to `views/weekly/<today's date>.md`, as UTF-8 without a byte order mark. A synthesis already stored today is replaced.

- **Copy the stamp and the portfolio view** from the export line for line and character for character: every space, every bar and every dash of the tables as printed, and the words of the records as they are.
- **Write the other blocks in the sponsor's language, from the lines of the export.** Each statement says what one line of the export says and ends with the identifier of that record in square brackets, as the export prints it: `[C-2026-004]`, or `[C-2026-004, D-2026-002]` for two. A text taken from the export may hold square brackets of its own, as a ticket reference in a title, `[REQ#4521]`: copy it as it is.
- **Keep to the export.** A fact, a date or a name is in the synthesis because a line of the export gives it. The only other sources are the PO's sentence on team capacity and the date the period starts on.
- **Keep the evidence level.** Each line of the export gives one: `fact` is stated plainly, `reported` as what a person said, `hypothesis` as a guess.
- **Keep the headings and the set phrases** of the template word for word.

Done when the file holds the six blocks of the template in their order, no angle bracket is left, and every line of blocks 2 to 4 that speaks of a record cites it.

## 5. Have the register tool verify it

Run the register tool's `verify` with the path of the synthesis, as `verify views/weekly/2026-03-10.md`.

`Verified` means the synthesis counts. `Not verified` comes with what failed: the stamp, or each identifier that is not in the register or is superseded. Then correct the synthesis from the export, where a superseded record no longer appears, and verify once more. When it fails again: delete the file, tell the PO each identifier that failed, and end there, with no mail draft.

Done when `verify` answers `Verified`.

## 6. Leave a mail draft, when the connections allow it

`connections.json` allows a draft when its `mail` entry has the mode `connector` and holds `"drafts": true`.

- **It does**: create one mail draft through that connector, and leave it in the PO's drafts for the PO to review and send.
  - To: `sponsor.email` of `settings.json`. When it is empty, create no draft and tell the PO to fill it in.
  - Subject: in the sponsor's language, that this is the weekly synthesis, and today's date.
  - Body: the synthesis as stored, with its identifiers taken out: each pair of square brackets that cites records, with what it holds and the space before it. A pair cites records when all it holds is identifiers as the export prints them. Any other pair is text of a record, as `[REQ#4521]`, and stays.
- **It does not**, or the draft cannot be created: the stored synthesis is the output.

The stored synthesis keeps what was generated: it stays as verified, whatever the PO changes in the draft before sending it.

Done when you have told the PO where the synthesis is stored, whether a draft waits in the mailbox and for whom or why none was created, what the block on what is not covered lists, and the warnings the check counted.
