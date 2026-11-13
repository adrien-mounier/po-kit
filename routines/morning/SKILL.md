---
name: morning
description: Start the PO's day. Run a collect that records the plain facts at once and leaves the interpreted lines waiting, read the calendar into the calendar snapshot, note what matters in today's meetings, have the register tool write the morning page, views/morning.html, then tell the PO in two lines what the page holds. Also gives the brief of any meeting on request. Use when the PO says "morning", asks for the morning page, or asks "brief me for the 14:00".
---

# Morning

You collect what arrived since the last collect without stopping to ask, read the calendar, then the register tool writes the page the PO reads to start the day. Your writes are those of the collect, the calendar snapshot and your notes on the meetings; the page is the register tool's, and you never edit it.

**The calendar is read-only.** You never create, change or cancel a calendar event, and you send no invitation, even when the PO's day does not fit.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool.

## 1. Collect, without asking

When `state/proposal.json` exists, a proposal is pending: do not collect. The page lists it under "To sort", and the PO settles it when they choose. Go to step 2.

Otherwise follow the collect routine: `SKILL.md` in the folder `collect`, beside the folder of this routine. Follow it from its step 2 to point 2 of its step 6, with these differences:

- The PO is asked nothing while the morning runs: they read the page first.
- In step 6, do what point 2 says for the validation mode, then go to step 2 of this routine instead of showing a table and waiting for an answer. Under `Validation mode: interpreted.` that is `apply plain`: the plain facts are recorded, and the interpreted lines stay pending. Under `Validation mode: all.` every line stays pending, and nothing is applied.
- When the collect finds nothing new, it applies its empty proposal as it says, and the morning goes on.
- A question the notes cannot settle is said in your answer of step 5.

Done when the plain facts are recorded under `interpreted`, every other line of the collect is pending, and every note read is filed or still in a pending proposal.

## 2. Read the calendar

`connections.json` declares the source `calendar`. When its mode is `off`, skip this step: the page says the calendar was not read.

Otherwise read today and the next ten working days, Monday to Friday, and write what you read in `state/calendar.json`, the calendar snapshot, in the format `AGENTS.md` gives, replacing the last one. Read as the mode says:

- `folder`: exported files, one per event, under the folder the entry names. Open each of them: an event's file gives its title, its start and end, its attendees, and the PO's answer. Keep the events of the days to read.
- `connector`: ask the connector the entry names for the PO's events of those days, for reading only. A connector not yet verified is verified as for mail, with one harmless read, and its result written in the entry.

An event the PO declined is left out. An all-day event that marks the PO's absence is an entry of `absences`, one per day; another all-day event is left out. A calendar that cannot be read leaves no snapshot: tell the PO why, and go on.

Done when the snapshot holds every meeting and absence of the days read, with `read_at` the time you read them, or the calendar is off or could not be read.

## 3. Note what matters in today's meetings

Run the register tool's `brief`: it prints the brief of each meeting of today, with the subjects the meeting concerns, their open commitments and the decisions awaited.

For each meeting that concerns a subject, write a note in `state/morning.json`, in the format `AGENTS.md` gives: `key`, one sentence on what matters in it for the PO, and, under `lacks`, what each decision awaited still lacks to be taken. Take them from the register and what the collect read. Cite a record as `[identifier]`, and only records that `brief` printed or that the register holds and are not superseded. Leave out a meeting that concerns no subject.

Done when every meeting of today that concerns a subject has its note, or the calendar was not read.

## 4. Write the page

Run the register tool's `morning`. It writes `views/morning.html`, replacing the page of the day before, and prints one line per block of the page: its heading, then its counts. When it prints `Not verified: state\morning.json`, your notes cite a record that is missing or superseded: correct them and run `morning` again.

Done when it ends without error and prints no `Not verified`.

## 5. Tell the PO

Your answer is short:

1. What the collect did, in one sentence: each record written with its identifier, the notes filed, how many lines wait for the PO, what went to unclassified, what the check found. When no collect ran because a proposal is pending, say so.
2. Then what the page holds, in two lines, from the counts that `morning` printed: first what is late or due today; then the rest, ending with where the page is, `views/morning.html`, to open in a browser.
3. Then each question on a real effort that the collect kept, one line each, as step 4 of the collect writes it: `Real effort of C-2026-004, "Build the steering pack": how many days did it take you? My guess: 2 d.` A real effort the collect could infer is in its line, and asks nothing.

Copy no table: the lines that wait are on the page, under "To sort", and the PO answers them when they choose.

Done when the PO knows what the collect recorded, what waits for them, what the page holds, and each real effort the agent asks.

## A brief on request

When the PO asks for the brief of a meeting ("brief me for the 14:00", "prepare my meeting with Harbour Bank on Thursday"), at any time of the day:

1. Find the meeting in the calendar snapshot. When there is no snapshot of today, read the calendar first, as step 2 says.
2. Run `brief` with its time, and its date when it is not today: `brief 14:00`, `brief 2026-03-05 10:00`.
3. When the meeting concerns a subject and has no note yet, write its note as step 3 says and run `brief` again.
4. Give the PO in the chat what `brief` printed, as it printed it: the subjects, the open commitments, the decisions awaited and what each still lacks. Add nothing that cites another record.

Done when the PO has the brief of the meeting asked for, or knows that no meeting of the snapshot matches.
