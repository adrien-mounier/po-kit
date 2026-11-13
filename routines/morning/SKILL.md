---
name: morning
description: Start the PO's day. Run a collect that records the plain facts at once and leaves the interpreted lines waiting, read the calendar into the calendar snapshot, write its notes for the page (today's meetings, the actions to do first, the messages awaiting the PO's reply) and the backlog alerts, have the register tool write the morning page, views/morning.html, then tell the PO in two lines what the page holds and offer the briefing: a walk through the page in rounds of numbered questions, each with a recommended answer, whose answers become one proposal. Also gives the brief of any meeting on request. Use when the PO says "morning", asks for the morning page, or asks "brief me for the 14:00".
---

# Morning

You collect what arrived since the last collect without stopping to ask, read the calendar, then the register tool writes the page the PO reads to start the day. Your writes are those of the collect, the calendar snapshot and your notes for the page; the page is the register tool's, and you never edit it.

**The calendar is read-only.** You never create, change or cancel a calendar event, and you send no invitation, even when the PO's day does not fit.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool.

**Mail, the tracker and chat are read through the collect only.** You open of them only what the collect's searches return, as its `sources.md` says. You never list the folder of a source to look around, at the start or for the messages: no `ls`, `ls -R`, `find`, `tree`, `dir` or `Get-ChildItem` on `exports` or on any folder `connections.json` names; to look around the workspace, list `register`, `state`, `views` and `inbox` only. You never open a one-to-one message that the collect's searches did not find: one from a person of no watch list that holds no keyword.

## 1. Collect, without asking

The morning always collects, so that the page shows what arrived overnight, even when lines of an earlier proposal still wait for the PO. Follow the collect routine: `SKILL.md` in the folder `collect`, beside the folder of this routine. Follow it from its step 2 to point 2 of its step 6, with these differences:

- The PO is asked nothing while the morning runs: they read the page first.
- **Lines that still wait are carried over.** When `state/proposal.json` exists, its lines still wait for the PO, and your proposal keeps every one of them. In step 5, its operations are the first operations of yours, in their order, each as it is but with `"interpreted": true`, so that it keeps waiting; your own operations follow them. Your "line N" counts the lines carried over: with two of them, the record your first operation creates is "line 3". The lines carried over may name each other as "line 1", "line 2": leave them as they are.
- In step 6, do what point 2 says for the validation mode, then go to step 2 of this routine instead of showing a table and waiting for an answer. Under `Validation mode: interpreted.` that is `apply plain`: the plain facts are recorded, and the interpreted lines, those carried over among them, stay pending. Under `Validation mode: all.` every line stays pending, and nothing is applied.
- When the collect finds nothing new and no line is carried over, it applies its empty proposal as it says, and the morning goes on. With lines carried over, its proposal holds them and no line of its own: go through step 6 as for any proposal.
- A question the notes cannot settle, a real effort you could not infer among them, goes to your open questions, as `AGENTS.md` says: the briefing asks it, and you do not ask it in the chat.

Done when the plain facts are recorded under `interpreted`, every other line of the collect is pending, every line that waited before still waits, and every note read is filed or still in a pending proposal.

## 2. Read the calendar

`connections.json` declares the source `calendar`. When its mode is `off`, skip this step: the page says the calendar was not read.

Otherwise read the working day before today, today and the next ten working days, Monday to Friday, and write what you read in `state/calendar.json`, the calendar snapshot, in the format `AGENTS.md` gives, replacing the last one. Read as the mode says:

- `folder`: exported files, one per event, under the folder the entry names. Open each of them: an event's file gives its title, its start and end, its attendees, and the PO's answer. Keep the events of the days to read.
- `connector`: ask the connector the entry names for the PO's events of those days, for reading only. A connector not yet verified is verified as for mail, with one harmless read, and its result written in the entry.

An event the PO declined is left out. An all-day event that marks the PO's absence is an entry of `absences`, one per day; another all-day event is left out. A calendar that cannot be read leaves no snapshot: tell the PO why, and go on.

Done when the snapshot holds every meeting and absence of the days read, with `read_at` the time you read them, or the calendar is off or could not be read.

## 3. Write your notes for the page

You write `state/morning.json` in the format `AGENTS.md` gives, replacing the last one: one file with every part below but the backlog alerts, which have their own file, each part present even when it holds nothing (`[]`, `{}`). Cite a record as `[identifier]`, and only records the register holds and are not superseded.

1. **Meetings.** Run the register tool's `brief`: it prints the brief of each meeting of today, with the subjects the meeting concerns, their open commitments and the decisions awaited. For each meeting that concerns a subject, write under `meetings` its `key`, one sentence on what matters in it for the PO, and, under `lacks`, what each decision awaited still lacks to be taken. Leave out a meeting that concerns no subject.
2. **Messages awaiting the PO's reply.** Under `messages`, each mail and chat message that asks the PO something and has no answer from the PO in the mail or chat read: from the messages the collect of step 1 opened (in chat, those of the watched channels and group chats, of the one-to-one chats with the people of the watch lists, and the one-to-one messages that hold a keyword), and those the last `state/morning.json` listed. A message the PO answered leaves the list. You open nothing more for this part: no folder of a source is listed, and no other one-to-one message is opened.
3. **Signs of progress.** Under `progress`, for each open commitment owed to the PO due within three working days, the sign that it is moving, when what the collect read shows one: a mail, a message or a ticket of its owner about it. Write nothing for one without a sign: the page then offers a nudge.
4. **Backlog alerts.** When `connections.json` reads `tracker`, follow steps 1 to 4 of "Backlog health" in the backlog routine: `SKILL.md` in the folder `backlog`, beside the folder of this routine. It writes your backlog alerts in their own file, `state/backlog-alerts.json`, with the tickets not ready for a refinement session near when `backlog alerts` names one. With the tracker off, skip this part.
5. **Do first.** Under `first`, the three actions you recommend the PO do first today, the most important first, chosen from what is late, what must start today (the commitments of the PO whose latest start is today or past and not started), today's meetings and the decisions awaited from the PO. Each has a `title`, the action in a few words, and `why`, one line. Name its record in `record` when it is about one; otherwise give its `button` and its `ask`, the request for you the button copies.

6. **Yesterday's meetings.** Run `brief` with the date of the working day before today, as `brief 2026-02-27`. For each meeting it lists that concerns a subject and is not in `meetings_asked` of `state/questions.json`, add to your open questions, as `AGENTS.md` says, one question on what it decided or changed, about its subject: what became of the decisions awaited and the commitments `brief` lists for it, with the answer you recommend from what the meeting's title, its description and the register say. Add the meeting to `meetings_asked`.

Done when `state/morning.json` holds the four parts, the backlog alerts are written or the tracker is off, and each of yesterday's meetings on a subject has its question.

## 4. Write the page

Run the register tool's `morning`. It writes `views/morning.html`, replacing the page of the day before, and prints one line per block of the page: its heading, then its counts; then each task to start today, each reminder and nudge to offer, and each open question with its age. When it prints `Not verified: state\morning.json`, your notes cite a record that is missing or superseded, or an action lacks its button: correct them and run `morning` again. `Not verified: state\questions.json` is the same for your open questions, and `Not verified: state\backlog-alerts.json` for your backlog alerts.

Done when it ends without error and prints no `Not verified`.

## 5. Tell the PO

Your answer is short:

1. What the collect did, in one sentence: each record written with its identifier, the notes filed, how many lines wait for the PO, what went to unclassified, what the check found.
2. Then what the page holds, in two lines, from the counts that `morning` printed: first what is late, due today, and each task to start today by its title as `morning` printed it, and a day that does not fit with the suggestion `morning` printed; then the rest, ending with where the page is, `views/morning.html`, to open in a browser.
3. Then each reminder and nudge `morning` printed to offer, one line each, as a question: `Shall I draft the reminder to the tech lead for C-2026-005, "Deliver the test accounts", 3 days late?` You draft one only once the PO says yes, as a mail draft when the connections allow it or in the chat otherwise, and you never send it. Then each steering pack `morning` printed to offer, one line each: `Shall I draft the steering pack for the Retail steering committee of 2026-03-09?` On yes, follow the steering routine: `SKILL.md` in the folder `steering`, beside the folder of this routine.
4. Last, offer the briefing, in one line: how many questions it holds and how long it should take, as `Shall we do the briefing now? 9 questions, about 20 minutes.` Count the questions of step 6 that you would ask, at about two minutes each; when they take longer than `briefing_minutes` in `settings.json`, count those that fit and say how many wait for the next briefing. The PO says yes, or later: then the page and the open questions wait for them.

Copy no table: the lines that wait are on the page, under "To sort", and the PO answers them when they choose.

Done when the PO knows what the collect recorded, what waits for them, what the page holds, each reminder and nudge offered, and has been offered the briefing. A question on a real effort the collect could not infer is not asked here: it is in your open questions, asked at the briefing or as soon as the PO talks about its subject.

## 6. The briefing

When the PO says yes, you walk the page with them, block after block, to get from them what keeps the register current. It is your daily chance to come to the PO for what you need.

**What you stop on.** Follow the blocks of the page in their order: Do first, today's meetings, Start soon, what you owe, what others owe you, decisions, messages awaiting your reply, backlog alerts, To sort. In each block, stop only on a point that is new since the last briefing (a record recorded or updated after `last_briefing` in `state/questions.json`, or a line of the page it did not have), that needs an answer, or that needs attention (late, due today, a day that does not fit). Give the other points of the block one summary sentence. A block with nothing to stop on is that one sentence, or nothing when it is empty.

**What you may ask.** Each question is one of these, about the block where its record stands:

- the outcome of yesterday's meetings: your open questions on them, in the meetings block;
- a status: is it done, started, still due on its date;
- a real effort you could not infer;
- missing information: an owner, a due date, an estimate, an objective;
- your readings waiting for the PO: each line of the pending proposal that `preview` shows, in To sort;
- sorting unclassified material, in To sort;
- your recommendations: a reminder or a nudge to draft, a way out of a day that does not fit, an objective to attach.

Each open question that `morning` printed is asked in the block of the record or subject it concerns, or in To sort when it concerns none, with its age: `(open 3 working days)`. When `morning` prints `Ask once whether to drop it.`, ask it as a question of its own, `Drop it?`, recommended answer `Drop it`, and set `"drop_asked": true` on it whatever the answer.

**What fits.** Aim at `briefing_minutes`, about two minutes a question. When there is more than fits, ask the most important first (late or due today, then what blocks a decision or a commitment of another person, then the rest) and leave the rest for the next briefing: a question that is not in your open questions goes into it.

**The words.** Open the briefing with this line, once:

`At any pause: ok or next, more, skip, later, stop. Anything else is an answer.`

- `ok` or `next`: every recommended answer of the round is accepted, and you go to the next block.
- `more`: say more about the round, or about one question with `2: more`, then ask again.
- `skip`: go to the next block; nothing of this round is recorded, and its open questions stay as they were.
- `later`: the questions of the round, or one with `2: later`, go to your open questions, to be asked at the next briefing with their age.
- `stop`: end the briefing now, with the recap below.

**A round.** Each block you stop on is one round: one message, then you wait for the PO. Write it this way, the block's name, its context in one or two sentences, then its questions numbered from 1, each with its title, the question, and on the next line the answer you recommend:

```
**Today's meetings.** Yesterday's onboarding pilot review [mobile-onboarding] was to settle the pilot branches; the screens are due Thursday.

❓ Q1 - Pilot branches: Did the sponsor choose the pilot branches [D-2026-004]?
➡️ Yes, Harbour Street and Market Square: I record the decision as taken by the sponsor.

❓ Q2 - Onboarding screens: Is the tech lead still delivering the screens [C-2026-007] on Thursday?
➡️ Yes: no change.
```

The PO answers the round in one reply. `ok` accepts every recommendation. `2: ...` answers question 2 in the PO's words, and the others keep their recommended answer when the reply ends with `ok`, as `2: they now come on Monday, ok`; without it, ask once for those left. A reply that says neither is an answer to the round: read it against the questions, and ask again only what it leaves open.

A recommendation the PO accepts is the PO's answer, worded as you recommended it: record it as said, with the PO as its source. Do not weigh it again against the notes, mail or calendar. A source that does not say it is the reason you asked, and the PO's answer settles it. If a recommendation needs a fact you do not have, write the fact into the recommended answer, as Q1 above does, so that "ok" confirms the fact.

**One proposal.** The answers build one proposal: the pending one when there is one, `state/proposal.json`, with its lines kept or dropped as the PO said, and each answer that changes the register added to it as an operation, as the collect writes them, with the source `{ "where": "the PO, at the morning briefing", "read_on": "<today's date>" }`. An answer that changes nothing (still due, no change) adds no line. Write the proposal as you go, and apply nothing before the end.

**The end.** After the last block, or at `stop`:

1. Recap in a few lines what was answered, question by question, and what waits for the next briefing.
2. Run the register tool's `preview` and copy its table, unchanged. Ask for one yes.
3. On yes, run `apply`. When the PO corrects a line, correct the proposal and preview again. On no, apply nothing: the proposal waits under "To sort".
4. Rewrite `state/questions.json`: an answered question leaves it, a question put off with `later` or left for the next briefing stays or goes into it, and `last_briefing` is today.
5. Correct your notes in `state/morning.json` that the answers made untrue: an action of Do first about a record now done, taken, dropped or closed leaves `first`, and a note that says "pending" or "still open" of one is rewritten. Then run `morning` again, as step 4 says: the page shows what the briefing changed. Tell the PO in one line.

Done when every answer given is applied or dropped by the PO, the open questions hold what is still unanswered, and the page is written again.

## A brief on request

When the PO asks for the brief of a meeting ("brief me for the 14:00", "prepare my meeting with Harbour Bank on Thursday"), at any time of the day:

1. Find the meeting in the calendar snapshot. When there is no snapshot of today, read the calendar first, as step 2 says.
2. Run `brief` with its time, and its date when it is not today: `brief 14:00`, `brief 2026-03-05 10:00`.
3. When the meeting concerns a subject and has no note yet, add its note to `state/morning.json` as point 1 of step 3 says, leaving the rest of the file as it is, and run `brief` again.
4. Give the PO in the chat what `brief` printed, as it printed it: the subjects, the open commitments, the decisions awaited and what each still lacks. Add nothing that cites another record.

Done when the PO has the brief of the meeting asked for, or knows that no meeting of the snapshot matches.
