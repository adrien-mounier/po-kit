# Weekly presentation as a dashboard of the subjects: specification

Date: 25 November 2026. Audience: the agent that builds the weekly presentation, on the machine where the kit runs. Read it with `HANDOFF.md` and the three example pages beside this file (`weekly-example.html`, `weekly-example-notes.html`, `weekly-example-cases.html`): they give the look, which is to be reproduced as it is; this gives the behaviour.

**It is built on the work machine, not in the kit's repository.** This text was written against the kit as its repository stood on 25 November 2026. The kit installed on the work machine was hardened there and may differ: check each fact below against what is installed before building on it, and say what you found different.

The parts "Decided" are requirements: changing one is a product decision, to take back to the PO. The part "Yours to decide" is yours. Routine technical choices need no approval; say afterwards what you chose and why.

## Problem Statement

Each week the PO meets their sponsor for 30 minutes to an hour. Today the kit gives the PO a text: a synthesis in seven blocks, verified against the register and left as a mail draft. It is a document to read, not a support to talk from. The PO has nothing to put on the screen of the room, nothing to walk through subject by subject, and nothing that reminds them, out of the sponsor's sight, what they came to ask.

A first presentation in five screens was chosen for its look on 23 November 2026. Its content came from the text synthesis, not from how the meeting runs: it opened on figures and highlights, addressed the sponsor in its titles ("expected from the sponsor"), and had no answer when the sponsor asked for more about one subject.

## Solution

When the PO asks for the weekly, the kit writes, beside the synthesis it already writes, a presentation and a page of private notes.

The presentation follows the order of the meeting: what was done, what is needed, what is planned. Its first screen is a dashboard of the subjects, one row each, with how far each is and what changed this week. The PO walks the subjects one by one: a subject takes the screen with its detail, the list reduced to a column. Then come the decisions to take and what blocks, then the plan until the next weekly, then one annex on the value delivered. No title speaks to the sponsor.

The private notes are a separate page the PO keeps on their own screen: what was agreed at the last weekly and what became of it, whom to ask for which decision, what to have validated. They are never shown and never sent.

After the meeting, the PO prints the presentation to PDF and sends it: the list of subjects, the decisions and the plan.

## User Stories

The meeting

1. As a PO, I want a presentation written when I ask for the weekly, so that I do not assemble slides each week.
2. As a PO, I want it readable on the screen of a room and in a video call, so that the same file serves both.
3. As a PO, I want the order of the screens to be the order of my meeting: what was done, what is needed, what is planned.
4. As a PO whose weekly is on a Tuesday, I want the week to run from the last weekly to today and the plan until the next one, so that the dates match the meeting.
5. As a PO, I want no title that speaks to my sponsor or names them, so that the screen states facts and I do the asking.

The dashboard

6. As a PO, I want one screen listing every subject I work on now or next, so that the sponsor sees the whole portfolio at once.
7. As a PO, I want the subjects that changed first and the others after, dimmed, so that the eye goes to what happened.
8. As a PO, I want the subjects planned for later in one closing line, so that they are named without taking rows.
9. As a PO, I want each row to say how far the subject is, as a percentage, so that progress reads at a glance.
10. As a PO, I want one word for the week on each row, tied to a fact, so that nobody wonders what "moved" means.
11. As a PO, I want a sign on a blocked subject and the number of blocked points in the subtitle, so that a blockage is seen without a banner of figures.
12. As a PO, I want no score of what I did against what I had agreed, so that the screen does not grade me.
13. As a PO with more subjects than the screen holds, I want the list to scroll under its title, so that nothing is cut.

One subject at a time

14. As a PO, I want to open a subject with a click or with Enter, so that it takes the screen while I talk about it.
15. As a PO, I want the other subjects to stay in a column on the left, with their word and their sign, so that I keep the whole in view.
16. As a PO, I want to go from one subject to the next with the arrow keys or a click, and back to the list with Escape, so that I walk the portfolio without hunting.
17. As a PO, I want the detail to hold this week, next, what blocks, decisions to take, in progress and value measured, so that I can answer a question without leaving the screen.
18. As a PO, I want a part with nothing left out and a long list folded after its first lines, so that a light subject and a heavy one both read well.
19. As a PO, I want the detail to show the week and what is open today, not the history, so that it does not grow week after week.
20. As a PO, I want what was agreed at the last weekly to appear as ordinary lines of this week, so that its outcome is said without a tally.
21. As a PO, I want the stages of the subject named in its detail, with the one in progress marked, so that the percentage is explained.

Value

22. As a PO, I want a value said as "today" and "objective", each with its unit, so that someone who never followed the project understands it.
23. As a PO, I want a number that is not known left empty and said so, so that nothing is invented.
24. As a PO, I want the annex to list every value of every subject in the same two columns, so that the last screen reads from left to right.

Decisions and plan

25. As a PO, I want each decision to take shown with its date and what happens without it, so that its cost is plain.
26. As a PO, I want each blocked point shown with what is late, by how much and who owes it, so that I can ask for help on it.
27. As a PO, I want the steps until the next weekly, each marked proposed or agreed, so that we validate the plan together.
28. As a PO, I want the dated milestones of the next four weeks, so that the sponsor sees what is coming.
29. As a PO, I want the team capacity and up to three other points in my own words, so that I can raise what the register does not hold.
30. As a PO, I want an empty screen to stay and say that it is empty, so that an absence is never mistaken for an omission.

Private notes

31. As a PO, I want a page of notes written with the presentation, so that I know what to ask before I enter the room.
32. As a PO, I want it to list what was agreed at the last weekly and whether each was done, so that I am not caught out.
33. As a PO, I want it to say, for each decision, whom I must ask, so that the screen can stay neutral.
34. As a PO, I want it to hold my own load when the week does not fit, so that I can choose to raise it.
35. As a PO, I want it in a separate file that the presentation never links to, so that sending the presentation never sends my notes.

Before and after

36. As a PO, I want the morning page of the day of the weekly to lead to the presentation and to the notes, so that I find them where I start my day.
37. As a PO, I want the presentation printed to PDF to be what I send afterwards: the list, the decisions and the plan, without the detail.
38. As a PO, I want the next morning's briefing to ask what the weekly decided, so that what was agreed becomes commitments and opens next week's notes.

The agent and the tool

39. As the agent, I want every line I write for the presentation to cite its record and to be verified, so that the screen says nothing the register does not hold.
40. As an organisation, I want to give my list of stages once, with a weight each if I wish, so that progress is counted my way.
41. As an organisation, I want every colour named once, so that the presentation is restyled by replacing one block.

## Decided

**Vocabulary.** These words enter the kit's vocabulary.

- **Weekly presentation**: the view written for the weekly point with the sponsor, to be shown on a screen: a dashboard of the subjects, the decisions to take and what blocks, the plan, one annex. The weekly synthesis stays what it is.
- **Private notes** (of a weekly): the page written with the presentation for the PO alone.
- **Stage**: a step of a subject's life that the organisation names, such as scoping, design, tests. It is not a gate: a gate is a mandatory approval; a stage measures progress.
- **Word of the week**: the one word that says what happened to a subject in the period.

**What stays.** The weekly synthesis, its seven blocks, its verification and its mail draft are untouched. The presentation and the notes are written at the same request, from the same export of the period and the same state of the register, and carry the same stamp. A correction is made in the register, then both are written again: nothing is edited in the presentation.

**The period.** It starts at the previous weekly, as today. The plan runs from today to the day before the next weekly, seven days later. The examples call them "du mardi 17 au lundi 23" and "jusqu'à mardi prochain"; the days come from the dates, not from a rule on Tuesdays.

**Which subjects.** Every active subject under Now or Next has a row. Those under Later are named in one closing line and have no row. A closed subject has none.

**What the register tool computes, never the agent.**

- The word of the week, the first that applies, in this order: "Nouveau", the subject was created in the period; "Étape franchie", a commitment of the subject was done, a decision of the subject was taken, or the subject passed a stage in the period; "Reporté", a due date or a next date of the subject was pushed back in the period; "En cours", a record of the subject was created or updated in the period; "Sans changement" otherwise.
- "Bloqué": a commitment that another person owes on the subject is late, or a decision awaited on the subject is past its date, or the agent's notes name a record that blocks it. The count in the subtitle is the count of blocked points, not of blocked subjects.
- The percentage: the weights of the stages the subject passed over the weights of all the stages, rounded to a whole number. Without weights, each stage counts the same. With no list of stages in the settings, nothing about progress is drawn: no column, no bar, no figure.
- The order of the rows: the subjects whose word is not "Sans changement" first, in the order of the portfolio view; then the others.
- The date of the next milestone of a subject: the earliest dated thing ahead that its records hold.
- The two numbers of a value: "Aujourd'hui" is the last value measured, or the baseline when none was measured since; "Objectif" is the target. Each is written with the unit of the benefit. One that the register does not hold is left empty and says "Non mesuré" or "Non fixé". Nothing is computed between them.
- The decisions to take: the pending decisions of the subjects shown, the earliest date first, those with no date last. The blocked points: what makes a subject "Bloqué".
- The milestones: the dated things of the next 28 days that the register and the calendar snapshot hold.
- In the private notes: each step that the last weekly marked agreed, and whether its record is done today; for each decision to take, who decides, as its record says.

**What the agent writes, verified by the tool.** For each subject: the line on what changed, the lines of "this week", the next step, and the records that block it. For the plan: the steps it proposes. Each statement says what one line of the export says and cites its record; the evidence level is kept, a reported fact being said as reported ("selon le tech lead"). The tool refuses a line that cites a record the register does not hold or that is superseded, as it does for the synthesis.

**A step of the plan is "agreed" or "proposed".** Agreed: it is a commitment of the register due in the plan's days. Proposed: the agent proposes it and no record holds it yet.

**What only the PO gives.** The team capacity, as today, and up to three other points. Both are asked with the request for the weekly, in one message, and written as the PO said them, marked "selon le PO". The PO may say there is none.

**The presentation.** One self-contained file per weekly, stored under its date beside the synthesis. No network, no font to download. Four screens in this order, each staying when it is empty and saying so:

1. The progress of the week: the dashboard and, on demand, one subject at a time.
2. The decisions to take and the blocked points.
3. The plan until the next weekly, with the milestones, the capacity and the other points.
4. The value delivered, as an annex.

No title and no subtitle names the sponsor or addresses them. A decision does not say who must take it. A person is named where it is a fact of a record.

**One subject at a time.** A row is a link to its subject. With the script: a click or Enter opens the subject in the height of the screen, the list becomes a column, up and down go to the previous and the next subject, Escape or "Tous les sujets" comes back, and an address that names a subject opens it. Without the script: every subject is drawn under the list and a row leads to its own. The script saves nothing and loads nothing.

**The detail of a subject.** Its stages with the one in progress marked and the percentage; then six parts, each left out when it holds nothing: this week, next, what blocks, decisions to take, in progress, value measured. "This week" shows four lines and the other lists three before a fold that opens without script. It holds the period and what is open today, never an older week.

**What was agreed at the last weekly.** The steps the last presentation marked agreed are kept in the workspace state when a weekly is written. In the next presentation their outcome is an ordinary line of "this week" under their subject. They are listed with "done" or "not done" only in the private notes.

**The private notes.** One page, in a file of its own beside the presentation, which never links to it. It holds: what was agreed at the last weekly; the subjects to open first (blocked, with a decision to take, new); for the decisions screen, each decision with who decides it, and each blocked point where the sponsor's support may help; for the plan, the steps still proposed; and, for the PO alone, their own load when the week does not fit, as the morning page counts it. It is written for a laptop screen and prints on one A4 page.

**What is sent.** The presentation printed to PDF gives, one screen per page: the list of subjects, the decisions and blocked points, the plan. The detail of the subjects and the annex are left out by the print rules. Nothing is sent by the kit.

**Before and after.** On the day of the weekly, the morning page's block of that meeting offers to open the presentation and the notes when they exist, and to write them when they do not. The next morning, the question the briefing already asks about yesterday's meetings covers the weekly: what it decided becomes a proposal, and what was agreed becomes commitments.

**Languages.** The presentation and the notes are in the sponsor's language of the settings. Every new label exists in English and in French.

## Yours to decide

- How the agent's lines reach the tool, and how the presentation and the notes are verified: the synthesis is verified today as a Markdown file, and that check alone does not cover an HTML file.
- Where the stages are recorded: the list and its weights in the settings, and on a subject the stage it is in or the stages it passed. A change of stage is a fact of the register and goes through a proposal as any other.
- How the tool knows which meeting of the calendar snapshot is the weekly.
- The names of the files, and how a weekly written again replaces the files of the same day.
- How the change survives a reinstall or an update of the kit on the work machine, whose own files an update replaces.
- Anything the three example pages do not show: `HANDOFF.md` says what a screen was checked to hold.

## Proving it

A routine is proven by its scenario passing. These are the results to observe, whatever tests you write. Use fictional or anonymised material for them.

| Scenario | What must be seen |
|---|---|
| An ordinary weekly | One request writes the synthesis, the presentation and the notes; the three carry the same period and the same stamp. |
| The dashboard | One row per subject under Now or Next; those that changed first; the later ones in one line; the count of blocked points in the subtitle only when there is one. |
| The word of the week | Each of the five words on a subject whose records give it; a subject both new and advanced says "Nouveau". |
| A blocked subject | The sign on its row, the point on the decisions screen and in its detail, with who owes it and by how much it is late. |
| Progress | With a list of stages, each row shows its percentage and the detail names the stages; weights change the figure; with no list, no progress is drawn anywhere. |
| A value | "Aujourd'hui" and "Objectif" with their units; the baseline stands for today when nothing was measured since; one with no target, one never measured, each left empty and said. |
| One subject at a time | A click opens it; the keys walk the subjects; Escape comes back; a heavy subject scrolls inside its frame; a long list opens. |
| Scripts blocked | Every subject is drawn under the list; a row leads to its own; nothing is missing. |
| No wording that speaks to the sponsor | No title, subtitle or label of the presentation names the sponsor or says "you"; the private notes say whom to ask. |
| Agreed at the last weekly | A step marked agreed last week appears this week as a line of its subject; the notes list it with done or not done; the presentation shows no tally. |
| The PO's words | The capacity and the other points are shown as said, marked as the PO's; with none given, the plan screen says so and invents nothing. |
| A line that cites a record the register does not hold | The tool refuses it, says which, and no presentation is left that claims to be current. |
| A quiet week, nothing to decide, nothing planned | Each screen stays and says so, as in the catalogue of cases. |
| More subjects than the screen holds | The list scrolls under its title. |
| Printing | The PDF holds the list, the decisions and the plan, one screen per page; no detail, no annex, and nothing of the notes. |
| The notes | A file of its own; the presentation holds no link to it and no private line. |
| The morning of the weekly | The block of the meeting leads to both files. |
| After a reinstall of the kit | The presentation, the notes and the weekly routine's new steps are still there, and the PO's data is untouched. |
| By eye, in Edge, full screen | Beside `weekly-example.html` at the same size: the same layout, type, colours and spacing. |

What stays true of the weekly is checked too: source text is shown as text and never as markup; each file has no byte order mark and loads nothing from elsewhere; the synthesis is written and verified as before.

## Out of Scope

- A real minute of the meeting: the summary rewritten after the meeting with what was decided. It is the next step, not this one.
- Sending anything, creating the meeting, or scheduling the weekly.
- The PO's own load in the presentation.
- A health colour or any judgement of a subject that no record states.
- The history of past weeks inside the detail of a subject.
- A percentage estimated by the agent: progress comes from the stages or is not shown.
- A dark mode and a phone layout.
- Bringing the change back into the kit's repository. It is done afterwards, restated with fictional material, as the work machine's earlier hardening was.

## Further Notes

- The morning page is itself being rebuilt (`docs/design/morning-handoff/`, issue 43 of the kit's repository). The link from the block of the meeting belongs to whichever of the two is built second.
- Decided by the agent that wrote this specification, for the PO to overrule: the order in which the five words apply; what makes a subject "Bloqué"; that a step is "agreed" when the register holds it as a commitment; that the baseline stands for "today" until a value is measured; that the agreed steps of a weekly are kept in the workspace state; that a list beyond the screen scrolls; what the private notes hold.
- `HANDOFF.md` lists what was not verified: printing, a room screen, a video call, the keys by hand.
