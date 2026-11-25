# Weekly presentation: the look and the organisation to reproduce

Date: 25 November 2026. Audience: the agent that builds the weekly presentation, on the machine where the kit runs. It replaces the handoff of 23 November: the look chosen then is kept; what the screens hold and how they are organised was decided since.

## What is here

| File | What it shows |
|---|---|
| `SPEC.md` | The behaviour to build: what the PO must be able to do, what is decided, what is yours, and the scenarios that prove it. |
| `weekly-example.html` | The presentation on an ordinary week: four screens. Open a subject on the first one. |
| `weekly-example-notes.html` | The PO's private notes for the same weekly: one page, never shown, never sent. |
| `weekly-example-cases.html` | Five special cases, one per screen. It is a catalogue, not one real deck, and it has no script: each screen is drawn in the state it shows. |

All are hand-built with fictional content (Example Bank), each self-contained: one file, no network, no font to download. They are examples of an output, not templates and not a renderer: nothing here reads the register. Open them in Edge, press F11.

**This folder is complete on its own.** `docs/design/weekly-dashboard-prototypes/` holds the three ways of opening a subject that the PO compared, and `docs/design/weekly-prototypes/` the eight looks compared on 23 November; nothing in them is needed to build.

The examples are in French, the sponsor's language here. In the kit's repository a person is a role; on the work machine the names are those of the register.

## Decided by the PO

Treat these as requirements. Changing one is a product decision, to take back to the PO.

- **The look is the one of the examples**: their layout, their type, their colours, their spacing, their words. Reproduce it; do not redesign it. Where the page the tool writes and an example differ for the same content, the example is right.
- **The meeting.** A weekly point between the PO and the sponsor, 30 minutes to an hour, on the screen of a room or shared in a video call. The PO shares and leads.
- **The order is: what was done, what is needed, what is planned.** Four screens: the progress of the week; the decisions to take and what blocks; the plan until the next weekly; one annex, the value delivered.
- **A rolling week.** The weekly is held on a Tuesday: the week runs from the Tuesday before to the Monday, and the plan until the next Tuesday. The period starts at the previous weekly, as the kit already counts it.
- **No title and no subtitle names the sponsor or speaks to them.** No "what I need from you", no "expected from the sponsor". A person is named wherever it is a fact: "security review, the architect, 4 December".
- **The first screen is a dashboard: one row per subject** the PO works on now or next. Those that changed come first; those with no change follow, dimmed. The subjects planned for later are one closing line. There is no banner of figures above the list: only the number of blocked points, in the subtitle, and only when there is one.
- **A row says six things**: the subject and its client bank; how far it is, as a percentage; a word for the week; one line on what changed; a sign when it is blocked; the date of its next milestone. No health colour.
- **The word for the week is one of five**, each tied to a fact of the register: "Étape franchie" (a commitment of the subject was kept or a decision was taken), "En cours" (work is recorded, nothing is completed yet), "Nouveau" (the subject entered this week), "Reporté" (a date of the subject was pushed back), "Sans changement" (nothing was recorded). "Bloqué" is not a sixth word: it is a sign beside, since a subject may advance and be blocked.
- **One subject at a time.** A click on a row, or Enter, opens the subject: it takes the screen and the list becomes a column on the left. Up and down go from one subject to the next; Escape comes back to the list.
- **The detail of a subject holds six parts**: this week, next, what blocks, decisions to take, in progress (with who and when), value measured. A part with nothing is left out. A long list shows its first lines, then "+ 3 autres" to open. The detail shows the week and what is open today, never the history: an older week is read in the weekly of its date. A heavy subject scrolls inside its frame.
- **What was agreed at the last weekly has no block and no score.** Its outcome is an ordinary line of "this week" in the detail of its subject, said as a fact. The full list, with what was not done, is in the private notes.
- **How far a subject is, is a percentage**, drawn as a bar: the share of its stages that are passed. The organisation gives its list of stages once, in the settings, each with an optional weight; without weights the stages count the same. With no list, no progress is shown anywhere. The PO accepts that the figure is approximate.
- **A value is said in two numbers, "Aujourd'hui" and "Objectif"**, each with its unit, never as a bar. "Aujourd'hui" is the last value known: the last one measured, or the starting value when none was measured since. Either is left empty when it is not known: not every benefit has a clear objective.
- **The decisions screen is neutral.** A decision shows its date, its title and what happens without it. A blocked point shows what is late, by how much, and who owes it.
- **The plan** lists the steps until the next weekly, each marked proposed or agreed; the dated milestones of the next four weeks; the team capacity and up to three other points, both in the PO's own words, given when they ask for the weekly. The agent invents neither.
- **The PO's own load is not in the presentation.**
- **Private notes** are a separate page, written with the presentation: what was agreed at the last weekly and what became of it, which subjects to open first, whom to ask for which decision, what to have validated. The PO reads them on their laptop beside the big screen. They are never shown and never sent, and the presentation holds nothing private.
- **What is sent after the meeting is the presentation printed to PDF**: the list of subjects, the decisions and blocked points, the plan. The detail of the subjects and the annex stay out of it.
- **Moved with a click or with the keys.** A small script is allowed for that. The page stays whole without it, with no network and no font to download.
- **The kit stays neutral.** Every colour is named once, in the `:root` block marked "The palette". An organisation restyles the presentation by replacing that block.

## What the PO was asked, and answered

The questions of 25 November 2026, so that each requirement above can be traced.

| Asked | Answered |
|---|---|
| Start from the five screens chosen on 23 November, or from nothing? | Keep the look; change what the screens hold and their order. |
| How does the meeting run? | 30 minutes to an hour, on a room screen or in a video call; the PO leads; the file is sent afterwards. |
| What comes first? | The progress of the week, as in an agile ceremony: what was done, then what is needed, then the plan for the following week. The week is rolling, Tuesday to Monday. Clear, not messy. |
| A block "what I need from you"? | No wording that speaks to the sponsor. "Decisions to take" and "blocked points" are fine. People may be named; only titles and subtitles never name the sponsor. |
| Show the PO's own load, to ask for an arbitration? | No. It stays private. |
| A block "agreed last week, 2 of 3 done"? | No score: it reads as a grade. No banner of figures at all; "blocked" may stay if it sits discreetly. |
| Two screens, essentials then progress by subject? | One main screen: a dashboard of all the subjects, walked one by one; a click on a row shows its detail. |
| What does a row say, which subjects, in what order? | The recommendation: facts only, no health colour; the subjects of now and next; those that changed first. "Moved" was unclear: the column is "this week", with five words. |
| How is the presentation driven? | With a click or with the arrow keys. |
| What is sent as the minutes? | The high-level view: the list of subjects, with the decisions and the plan, printed from the same file. |
| How does the detail of a subject open? | Three prototypes; the PO chose the full view, the list reduced to a column. It must hold a subject with much detail as well as one with little. |
| The bar "start, target" under "value measured"? | Unclear: it read as the progress of the project and mixed units. Keep the idea, say it as "today" and "objective", leave empty what is not known. |
| A progress bar for the subject? | Yes, as a simple percentage, even approximate, from the stages of the organisation's governance once the PO gives them. |
| Private notes? | A separate page, read on the laptop beside the big screen. |
| Before and after the meeting? | The morning page of that day leads to the presentation and the notes; the next morning's briefing asks what the weekly decided, and what was agreed becomes commitments. |

## The special cases

`weekly-example-cases.html` draws them, one per screen:

1. **A week where nothing was recorded**: every row says "Sans changement", dimmed; the subtitle carries no blocked point.
2. **More subjects than the screen holds**: the list scrolls inside the first screen, under its title; the screen is never cut over two.
3. **A subject opened with gaps**: no list of stages was given, so no progress is shown, on the rows or in the detail; one value has no objective, another was never measured.
4. **Nothing to decide and nothing blocked**: the screen stays and says so.
5. **Nothing planned**: the screen stays and says so; a part of the side column with nothing says so in one line, and "other points" is left out.

A zero is said, never hidden: a screen is not removed because it is empty.

## Yours to decide

What `SPEC.md` leaves to you: how the presentation and the notes are written and verified, where the stages of a subject are recorded, how the change survives a reinstall of the kit.

## How the examples work

- **Sizing.** `html { font-size: min(1.3vw, 2.3vh); }` makes `1rem` a fixed share of the screen: every size is in `rem`, and the presentation scales as a slide does, on a laptop as on a room screen.
- **Screens.** One screen is one slide; they snap with CSS, and the dots on the right are plain links.
- **A row is a link to its subject.** Without script, every subject is drawn under the list and a row leads to its own: the page is whole. With script, the class `js` on `html` shows one subject at a time, in the height of the screen.
- **The script** opens a subject, walks them with the keys and comes back to the list; it opens the subject an address names (`#sujet-memo`). It saves nothing and loads nothing.
- **Long lists** are native `details`: they open without script.
- **Signs.** The sign of a word is an image embedded as a `data:image` address and used as a mask, so it takes the colour of its word.
- **Colour has one meaning each.** Blue is the accent; red is only what blocks or is late; green, amber and navy belong to the words of the week. A state is said by a word and a sign, never by colour alone.
- **Printing.** The print rules keep the list, the decisions and the plan, one screen per page, and leave out the detail and the annex.

## What a screen holds

Checked on the examples at 1366 by 768 and at 1920 by 1080. The first two lines were measured; the others say what the examples show, which fits with room to spare.

| Screen | Holds |
|---|---|
| The dashboard | 7 subjects and the closing line; beyond, the list scrolls (case 2 of the catalogue shows 12) |
| The detail of a subject | Any length: it scrolls inside its frame; "this week" shows 4 lines and the other lists 3 before "+ N autres" |
| Decisions and blocked points | 3 decisions and 2 blocked points are shown |
| The plan | 4 steps, 4 milestones, the capacity sentence and 1 other point are shown |
| Value delivered | 3 values are shown |

Beyond what is shown, nothing was designed: apply the same rules and check the result by eye.

## What the tool computes, never the agent

- The word of the week of a subject, its "blocked" sign and the count of blocked points.
- The percentage of a subject, from its stages passed and their weights.
- The dates, how late a thing is, the split between what changed and what did not, the order of the rows.
- The two numbers of a value, as the register holds them. It computes nothing between them.
- What the private notes say of the last weekly: each step agreed then, and whether its record is done.

The line on what changed, the next step and what blocks are written by the agent from the export of the period, each citing its record; `SPEC.md` says what evidence each needs.

## Not verified

- Printing to PDF: the rules are written and were never run.
- A room screen and a video call: the examples were checked in a browser at laptop and large-screen sizes only.
- The work machine: the titles need Bahnschrift and the text Segoe UI Variable. Both come with current Windows; the font stacks fall back to Segoe UI.
- The keys were checked by sending key events to the page, not by hand on a keyboard or with a presentation remote.
- English: every label here is in French.
- No independent design review was run: the examples were checked by the agent that built them.
