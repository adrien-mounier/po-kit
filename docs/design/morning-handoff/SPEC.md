# Morning page that follows a day plan: specification

Date: 25 November 2026. Audience: the agent that builds the new morning page, on the machine where the kit runs. Read it with `HANDOFF.md` and the three example pages beside this file (`morning-example.html`, `morning-example-proposed.html`, `morning-example-cases.html`): they give the look, which is to be reproduced as it is; this gives the behaviour.

**It is built on the work machine, not in the kit's repository.** This text was written against the kit as its repository stood on 24 November 2026. The kit installed on the work machine was hardened there and may differ: check each fact below against what is installed before building on it, and say what you found different.

The parts "Decided" are requirements: changing one is a product decision, to take back to the PO. The part "Yours to decide" is yours. Routine technical choices need no approval; say afterwards what you chose and why.

## Problem Statement

The PO opens the morning page to know what to do, and the page gives two answers. "Do first" ranks three actions by importance; "Today's meetings" ranks the day by hour; the free time between the meetings is a third line. The PO merges the three in their head.

The same thing is said up to three times: a deck that must start today is under "Do first", under "Start soon" and under "What you owe", tied together by pointers. Nine blocks have the same weight, about twenty-five buttons have the same weight, and red is on so many lines that it no longer says "look here".

The PO said it on 24 November 2026: the page is not clear or fast enough to read, and it feels messy. They want one thread to follow from the first hour of the day to the last, each stretch of the day holding what was planned for it, with the details of a block one click away and everything that is pending kept behind it.

## Solution

The morning page follows a **day plan**. The day is one thread of blocks, in the order of the clock: the meetings of the calendar snapshot, and between them the work the agent proposes for the free time. A click on a block shows its details beside the day. Everything pending sits in a second view of the same page.

The agent proposes the plan when it writes its notes for the page, before the PO is up. The page then says the plan is proposed. The briefing ends with one round on the plan; once the PO agrees, the page says so. During the day the page follows the clock: the past fades, the running block is marked.

The PO chose the look and the organisation among three prototypes. The choice, with its example page and the list of what the PO decided, is this folder (`HANDOFF.md` and the three example pages). **That folder is the reference for everything this specification does not spell out about the look.**

## User Stories

The day

1. As a PO, I want the day shown as one thread from the first block to the end of my working hours, so that I read what to do in the order of the clock.
2. As a PO, I want my meetings and my planned work in the same thread, told apart at a glance, so that I no longer merge two lists in my head.
3. As a PO, I want a block to be as tall as it is long, so that I see where the long stretches of work are.
4. As a PO, I want a block of work to last what the work needs, two hours for a deck, a quarter of an hour for a reminder, so that the plan is one I can keep.
5. As a PO, I want short things bundled in one block that lists them, so that three five-minute replies do not take three lines of my day.
6. As a PO, I want the pause in my working hours and the gaps left empty, so that the plan does not pretend every minute is filled.
7. As a PO, I want a meeting outside my working hours to stretch the day, so that the early stand-up is on the thread.
8. As a PO, I want what found no room listed under the day as "Not today", with why, so that nothing the agent thought of disappears silently.
9. As a PO, I want up to three blocks to carry a priority number, so that I know what matters most if the day goes wrong.
10. As a PO, I want a block to carry a flag when what it names is late, due today or at its latest start, so that red and amber appear once per block and mean something.
11. As a PO, I want one sentence at the top that says what is late, what must start today and whether the week fits, so that I know the day's headline before reading the thread.

The details

12. As a PO, I want a click on a block to show its details beside the day, so that I keep my place in the thread.
13. As a PO, I want the details of a meeting to be its meeting brief, so that I prepare it from the page.
14. As a PO, I want the details of a block of work to say why it is planned today, for whom, its due date and its record, so that I can decide to do it or move it.
15. As a PO, I want each thing of a bundle to have its own button, so that I draft each reply in one click.
16. As a PO, I want to walk the day with the arrow keys and come back to the running block in one click, so that I review the day quickly.

Proposed, then agreed

17. As a PO, I want the page written before the briefing to show the plan the agent proposes, marked as proposed, so that I open a full day and react to it.
18. As a PO, I want the briefing to end with one round on the plan, so that the plan I follow is one I agreed.
19. As a PO, I want to change the plan in my own words at that round, so that I move, drop or add a block without a form.
20. As a PO, I want the page to say when the plan was agreed, so that I know which plan I am reading.
21. As a PO who put the briefing off, I want the page to keep saying the plan is proposed, so that I never take a proposal for an agreement.
22. As a PO, I want yesterday's "Not today" considered first in today's plan, so that what I pushed back does not get lost.

The clock

23. As a PO who keeps the page open all day, I want past blocks to fade and the running one to be marked, so that I find my place at each return.
24. As a PO, I want the line of the thread to darken as the day goes, so that I see how much of the day is left.
25. As a PO who left the page open overnight, I want it to say that it is yesterday's and to stop following the clock, so that I do not follow an old plan.
26. As a PO, I want nothing on the page to be ticked, so that the page never says "done" while the register says "open".
27. As a PO, I want a "Done, tell the agent" button on a block of work, so that I report it in one paste.
28. As a PO, I want a "Not today" button on a block of work, so that I ask the agent to find it another place.
29. As a PO, I want a block whose record is done to show as done once the page is written again, so that my report has an effect I can see.

What is pending

30. As a PO, I want everything pending in a second view of the page, whose tab says how many lines it holds, so that the day stays clean and the rest is one click away.
31. As a PO, I want what waits on me in one group: what I owe, the decisions awaited from me and the messages awaiting my reply, so that I see my side in one place.
32. As a PO, I want what I wait for in one group: what others owe me and the decisions I wait for, so that I see whom to chase.
33. As a PO, I want the load of the week, with what must start soon, as a third group, so that I see whether the week fits.
34. As a PO, I want backlog alerts, then To sort last, so that the least pressing is at the end.
35. As a PO, I want a pending line that today's plan already covers to say "Planned 12:00" and lead to its block, so that a thing is said once and has one button.
36. As a PO, I want a source that was not read said in the bar and in the group it hides lines from, so that I know what the page may be missing.

When something is missing

37. As a PO whose calendar could not be read, I want the planned work shown with a warning that the meetings are missing, so that I still have a day.
38. As a PO whose agent wrote no plan, or a plan the tool refused, I want the meetings and the free time shown and the page to say that no plan is proposed, so that I am not shown a broken day.
39. As a PO on a day off, I want the page to say so instead of a thread.
40. As a PO who reads the page in French, I want every new word of the page in French.
41. As a PO whose browser blocks scripts, I want the page whole without them: every block's details and the pending view under the day.

The agent and the tool

42. As the agent, I want a documented place in my notes for the day plan, so that I write it once and the register tool draws it.
43. As the agent, I want the tool to refuse a plan that overlaps a meeting, leaves the day or names a record the register does not hold, and to tell me why, so that I correct it before the PO sees it.
44. As the agent, I want the tool to tell me when a commitment that must start today is in no block, so that I plan it or say why not.
45. As an organisation, I want every colour of the page named once, so that the page is restyled by replacing one block.

## Decided

**Vocabulary.** Three terms enter the kit's vocabulary and one leaves.

- **Day plan**: for one day, the blocks of work the agent proposes for the PO's free time and the list of what waits, proposed in the agent's notes for the page and agreed by the PO at the briefing. It is not a record of the register. _Avoid_: schedule, agenda, timetable.
- **Block**: one stretch of the day on the morning page: a meeting of the calendar snapshot, a block of work of the day plan, or a bundle, a block of work that lists several short things. _Avoid_: slot, task, event.
- **Not today**: the part of the day plan that lists what found no room, each with why.
- **Do first** leaves the vocabulary. Its three actions become blocks that carry a priority, 1 to 3. Its rule stays: a commitment of the PO whose latest start is today or past and that is not started is planned today, unless the PO says otherwise at the briefing.
- The **Morning page** now holds: the day with its blocks, Not today, then Waiting on you, You are waiting on, This week's load, Backlog alerts and To sort.
- The kit keeps "task" out of its words: on the page a block of work is "Work".

**The day plan is part of the agent's notes for the page.** It replaces the list of actions to do first, which leaves the notes. The meetings are never in it: they come from the calendar snapshot. This shape comes from the prototype's data, trimmed to what the decisions need. It is a suggestion: the fields may be named and arranged otherwise, as long as the rules below hold.

```json
"plan": {
  "proposed_at": "2026-03-02T07:12:00+01:00",
  "agreed_at": null,
  "blocks": [
    { "start": "10:00", "end": "10:15", "priority": 1, "record": "C-2026-011",
      "title": "Chase the head of payments for the test dataset",
      "why": "The pilot is blocked without it." },
    { "start": "12:00", "end": "12:30", "title": "Replies and nudges",
      "items": [ { "record": "C-2026-008", "title": "Send the go-live checklist" },
                 { "title": "Classify the mail on pilot pricing", "button": "Classify", "ask": "Help me classify ..." } ] },
    { "start": "13:30", "end": "14:00", "title": "Prepare the 14:00 with Harbour Bank",
      "meeting": "14:00", "why": "They will ask for the pilot scope.", "button": "Brief me", "ask": "Brief me for the 14:00 ...", "done": false }
  ],
  "not_today": [ { "record": "D-2026-007", "title": "Draft the classification proposal", "why": "About 1 h, due Wednesday. Proposed for tomorrow." } ]
}
```

- A block or a thing of a bundle names its record, or gives its button and the request the button copies, as an action to do first does today.
- `agreed_at` is empty until the PO agrees. `done` is for a block that names no record.
- Times are hours of the day in the PO's time zone.

**What the register tool verifies.** The plan is verified with the rest of the notes, and refused as they are today, each problem on its line under `Not verified`. A plan is refused when a block:

- does not start and end on a quarter of an hour, or ends before it starts;
- starts before the day or ends after it. The day runs from the earlier of the start of the working hours and the first meeting, to the later of their ends;
- overlaps a meeting of the calendar snapshot, tentative or not, or another block. With no snapshot of today, the overlap with meetings is not checked;
- names a record the register does not hold or that is superseded;
- names no record and gives no button and request;
- carries a priority that is not 1, 2 or 3, or one another block carries.

A refused plan leaves the page with the meetings, the free time and the words that no plan could be written, and never a part of a plan.

**What the tool computes, never the agent.**

- Where each block is drawn and how long it is. A meeting that does not start on a quarter of an hour is drawn from the nearest one and keeps its true time in words. Two meetings that overlap share their rows side by side.
- The pause between two ranges of the working hours, named "Break": the tool cannot know what the PO does in it.
- The flag of a block, from its record: late and by how many days, due today, latest start today or past for a commitment not started. A bundle says how many of its things are late. A meeting is flagged when its meeting brief lists a commitment of the PO that is late.
- That a block is done: its record is done, taken or closed, or the notes say so for a block with no record.
- The details of a block that names a record: who owes whom, the due date, the effort for a commitment of the PO, the subject, the client bank. The agent adds only the one sentence of why.
- The sentence at the top, from what the tool already counts: how many things are late, on either side; each commitment that must start today, by its title; by how many days the week does not fit. With nothing of the three, it says that nothing is late and the week fits.
- "Planned 12:00" on a pending line: the block of today that names its record. A pending line with such a block gets no button of its own.
- The count on the tab of the pending view: the lines of Waiting on you, You are waiting on, Backlog alerts and To sort.

Which work goes in which free time, what is bundled, what waits, the priorities and the sentence of a block are judgement: the agent's proposal, then the PO's agreement.

**The page.** One view, one self-contained file, written from the kit's template as today: no network, no font to download, fonts installed with Windows. It holds:

- The bar: the date; the state of the plan (none, proposed at an hour, agreed at an hour), with a button that copies the request to start the briefing while the plan is proposed; the sources read and not read; the two tabs.
- The sentence at the top.
- The view "Today": the day drawn to scale, a quarter of an hour per row, a row growing when the words of a block need it; "Not today" under it; beside it the panel with the details of the selected block. A block shorter than 45 minutes holds one line: title, flag, client bank, length. A longer one adds its sentence.
- The view "Pending": Waiting on you; You are waiting on; This week's load, which holds the lines of "Start soon", this week drawn in half-days, the next week in one sentence and the suggestion; Backlog alerts; To sort. Lines, folding, reminders, nudges, signs of progress and warnings of a source not read keep today's rules.
- The stamp and the sentence that the page changes nothing.

The script of the page marks the past, the running block and the place of the clock on the line, from the times the tool wrote and the date of the page. The panel shows the running block, or the next one, marked "Next", when none runs, until the PO selects another. On another day than its own, the page shows no clock and says in the bar which day it is of. The script also selects a block, switches views and copies requests, as the example does. Without script, every block's details and both views show.

Light only, as the example. Every colour is named once, in the palette block.

**The console lines of the tool.** One line per heading of the page with its counts, as today, under the new headings. One more line says the state of the plan and how many blocks and "Not today" lines it holds. Each "Start today" line says when no block names its commitment. The other lines keep their words.

**The morning routine.** Its step on the notes ends with the day plan in place of the actions to do first:

- The agent reads the meetings of today in the calendar snapshot and the free time within the working hours, and places work in it: what is late, what must start today, what a meeting of today needs prepared, the decisions awaited from the PO, then what is due soonest.
- It proposes in free time within the working hours only. It plans around the pause, never in it.
- It reads the "Not today" of the last notes before replacing them, and considers those first.
- A commitment that must start today is in a block. Only the PO moves it to "Not today".
- What found no room goes to "Not today" with why, and with the day it is proposed for when the agent can say.
- It tells the PO, in its short answer, that the plan is proposed and how many blocks it holds, and offers the briefing as today.

**The briefing.** Its rounds follow the new order of the page: the day, Waiting on you, You are waiting on, This week's load, Backlog alerts, To sort. A last round is the plan: the blocks of work numbered with their hours and "Not today", the recommended answer being to agree. The PO agrees with `ok`, or changes it in their words. The round comes last because the answers before it change the plan. At the end the agent writes the agreed plan with its hour and the page is written again. `skip`, `later` or `stop` before that round leave the plan proposed. The plan is no record: it goes through no proposal and no preview.

**Requests from the page, during the day.** "Done, tell the agent" on a block that names a record is a status answer as the PO gives one today: it becomes a proposal, applied on the PO's yes, and the page is written again. On a block with no record, the agent marks it done in its notes and writes the page again. "Not today" moves the block to "Not today" with the PO's reason, proposes another day, and writes the page again; the plan stays agreed.

**Languages.** Every new word of the page and of the console lines exists in English and in French.

**What leaves.** The "Do first" block and the pointers to it; the separate blocks "What you owe", "What others owe you", "Decisions" and "Messages awaiting your reply", whose lines move into the two groups; the line "Free for work", which the empty time of the day replaces; the dark colours.

**Documents.** The installed routine and the workspace rules say it: the place of the plan in the notes, its rules, the new last round of the briefing.

## Yours to decide

- The names and the arrangement of the plan in the notes, and how the tool reads and verifies it.
- How the page is written: the template, its placeholders, its script. The example is an output to reproduce, not a template to fill.
- How the change survives a reinstall or an update of the kit on the work machine, whose own files an update replaces.
- How it is tested there, beyond the scenarios below.
- Anything the three example pages do not show: `HANDOFF.md` says what the page was checked to hold and what was never drawn.

## Proving it

A routine is proven by its scenario passing. These are the results to observe, whatever tests you write. Use fictional or anonymised material for them.

| Scenario | What must be seen |
|---|---|
| An ordinary morning | The page shows the meetings and a proposed plan, marked proposed; a commitment that must start today is in a block; what found no room is under "Not today". |
| The briefing, to its end | Its last round is the plan; after `ok` the page is written again and says agreed, with the hour. |
| The briefing put off | The page still says proposed. |
| A change at the plan round | A block moved or dropped in the PO's words is moved or dropped on the page written again. |
| A plan the tool must refuse | A block over a meeting, outside the day, off the quarter hour, or naming a record the register does not hold: each is refused with its reason, and the page shows the meetings and no part of a plan. |
| "Done, tell the agent" | The request becomes a proposal; once applied, the page written again shows the block done. |
| "Not today" | The block leaves the day for "Not today" with its reason; the plan stays agreed. |
| A pending line that the plan covers | It says "Planned" with the hour, leads to its block, and has no second button. |
| The calendar not read | The planned work is shown with the warning that the meetings are missing. |
| No plan in the notes | The meetings and the free time are shown, and the page says no plan is proposed. |
| A meeting off the quarter hour, two meetings that overlap | Both are drawn, with their true hours in words. |
| A day off | The page says so in place of the thread. |
| French | Every new word of the page is in French. |
| The clock, by eye, in Edge | On the day of the page, the past is faded and the running block marked; on another day the page shows no clock and says which day it is of. |
| Scripts blocked | Every block's details and the pending view show under the day. |
| After a reinstall of the kit | The new page, the routine's plan and the briefing's last round are still there, and the PO's data is untouched. |

What stays true from the page it replaces is checked too: the counts, the folding of long lists, reminders and nudges, the sources not read, source text shown as text and never as markup, a file with no byte order mark that loads nothing from elsewhere.

## Out of Scope

- Writing to the calendar. The plan never becomes calendar events: the calendar stays read-only.
- Ticking a block on the page, or any way for the page to save something.
- A dark mode. The page it replaces has one; the PO chose a light example and has not asked to keep it.
- A phone layout.
- A template of the organisation for the morning page, as the steering pack has.
- Planning other days than today. "Not today" may name a day; nothing is planned on it.
- Learning how long a block of work really took. Efforts stay in days and keep their own rules.
- The two prototypes not chosen.
- Bringing the change back into the kit's repository. It is done afterwards, restated with fictional material, as the work machine's earlier hardening was.

## Further Notes

- `HANDOFF.md` lists what the examples were checked for. The special states are drawn in `morning-example-cases.html`.
- At 768 pixels of height the last hour and a half of the example's day is below the fold, and the panel stays in view. The PO knows.
- Decided by the agent that wrote this specification, for the PO to overrule: the plan round comes last in the briefing; the pause is named "Break"; the sentence at the top is composed by the tool; a block of work is called "Work"; a page of another day says so; a block shows as done.
- This specification is also issue 43 of the kit's repository.
