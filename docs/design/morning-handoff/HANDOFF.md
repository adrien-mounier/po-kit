# Morning page: the look and the organisation to reproduce

Date: 24 November 2026. Audience: the agent that builds the new morning page, on the machine where the kit runs. The PO chose this organisation among three prototypes (`docs/design/morning-prototypes/`, option A); this folder is the choice.

## What is here

| File | What it shows |
|---|---|
| `SPEC.md` | The behaviour to build: what the PO must be able to do, what is decided, what is yours, and the scenarios that prove it. |
| `morning-example.html` | The target page on an ordinary day, once the plan is agreed: the day as an agenda, the details of a block beside it, the pending items behind a second tab. |
| `morning-example-proposed.html` | The same day before the briefing: the plan is the agent's proposal. |

Both are hand-built examples with fictional content (Example Bank), each self-contained: one file, no network, no font to download. They are examples of an output, not templates and not a renderer: nothing here reads the register. Open them in Edge. Opened on another day than their own, they show a sample clock: 11:20 for the agreed day, 07:30 for the proposed one.

**This folder is complete on its own.** The prototypes (`docs/design/morning-prototypes/`) are a record of the two options not taken; nothing in them is needed to build.

## Decided by the PO

Treat these as requirements. Changing one is a product decision, to take back to the PO.

- **One thread through the day.** The page answers "what do I do now" in the order of the clock, from the first block to the end of the working hours. The "Do first" list is gone: its three priorities are blocks of the day that carry their number.
- **Blocks of real length on a half-hour scale.** Meetings are fixed. Tasks sit in the free time between them. Small things are bundled in one block that lists them. Lunch and gaps stay empty. What found no room is listed under the day as "Not today", so that nothing disappears silently.
- **The hours** are the PO's working hours; a meeting outside them stretches the day.
- **Proposed, then agreed.** The page written before the briefing shows the plan the agent proposes, marked as proposed; after the briefing it shows the plan agreed.
- **A clock, no tick.** The page follows the clock: past blocks fade, the running one is marked, the line darkens as the day goes. When no block is running, the next one is the one shown in the panel, marked "Next". Nothing can be ticked on the page, because a tick would not reach the register. A block's details offer "Done, tell the agent" and "Not today" instead: like every button, they copy a request.
- **One sentence at the top** says what matters today: what is late, what must start, whether the week fits.
- **The pending items are a second plan**, in this order: Waiting on you (what the PO owes, the decisions awaited from them, the messages awaiting their reply); You are waiting on (what others owe, the decisions the PO waits for); This week's load; Backlog alerts; To sort, last.
- **A source that was not read is said**, in the bar and in the group it hides lines from, as a warning.
- **Say a thing once.** A pending item that today's plan already covers shows "Planned 12:00", which leads to its block, and no second button.
- **Organisation A.** The day is drawn to scale on the left; the details of the selected block stay open in a panel on the right; the pending items are a second tab that carries their count.
- **The look is the one of the two examples**: their layout, their type, their colours, their spacing, their words. Reproduce it; do not redesign it. Where the page the tool writes and an example differ for the same content, the example is right.
- **Colour has one meaning each.** The look belongs to the family of the weekly presentation: navy titles, one blue accent, red only for what is late, a contradiction or a week that does not fit; amber for today. A state is said by a word and a sign, never by colour alone.
- **Read on a laptop, in Edge, kept open all day.** A phone is not designed and not wanted.
- **The kit stays neutral.** Every colour is named once, in the `:root` block marked "The palette". An organisation restyles the page by replacing that block.

## What the PO was asked, and answered

The eight questions of 24 November 2026, so that each requirement above can be traced. The PO accepted every answer below.

| Asked | Answered |
|---|---|
| What does the page show at 07:00, before the briefing? | The agent's proposed plan, marked proposed; it becomes agreed once the briefing is done. The briefing becomes "here is my plan, what do you change?". |
| What fills the day? | Blocks of real length on a half-hour scale: meetings fixed, work in the free time, small things bundled in one block, lunch and gaps left empty, what found no room listed as "Not today". The hours are the working hours of the settings; a meeting outside them stretches the day. |
| Does "Do first" stay? | No. Its three priorities are blocks that carry a priority mark. One sentence at the top keeps the headline. |
| A living page, or a photo of the morning? | It follows the clock: the past dimmed, the running block marked, the next one shown when none runs. No tick: "Done, tell the agent" in the details of a block. |
| What goes in the second plan? | Waiting on you; You are waiting on; This week's load, whose alarm rises into the sentence at the top; Backlog alerts; To sort, last. Decisions, the week's load and the warning of a source not read are kept. An item planned today shows "Planned" with its hour in place of a second button. |
| Where and how is it read? | A laptop, in Edge, kept open all day, never on a phone. |
| Is the look part of the problem? | No: one look, from the family of the weekly presentation. The options differed in organisation only. |
| What was delivered that day? | Three prototypes in English with fictional content. The PO then chose option A: the agenda and the side panel. |

After the choice, two things were changed and shown to the PO, and are in the examples: a block shorter than 45 minutes holds one line; a flag on the block's line replaces a red sentence.

## The states the examples do not draw

Each is decided in `SPEC.md`. Draw them with what the examples already hold, and nothing new:

- **A block that is done**: as a past block, with the check sign and the word "Done" where its flag was.
- **A page of another day**: no clock, nothing faded; the line of the bar that says the state of the plan says which day the page is of, with the warning sign.
- **No plan**, or a plan the tool refused: the meetings on the thread, the free time empty, and one sentence in the place of "Not today" saying that no plan is proposed.
- **The calendar not read**: the blocks of work on the thread, and the warning of a source not read, in the bar and above the day.
- **A day off**: one sentence in the place of the thread.
- **Two meetings that overlap**: side by side in the same rows.

## Yours to decide

- What `SPEC.md` leaves to you: the shape of the plan in the agent's notes, how the page is written, how the change survives a reinstall of the kit.
- Where the agent's judgement ends and the tool's writing begins, beyond the list under "What the tool computes".
- Whether the page keeps a dark mode. The page it replaces has one; this example is light only, and the PO has not said.

## How the example works

- **The scale.** The day is a grid whose rows are quarters of an hour, counted from the first block: a block's `grid-row` is its start and its end. A row has a minimum height and grows when the words of a block need more, so a block is as tall as it is long unless it could not be read.
- **One line or two.** A block shorter than 45 minutes holds one line: its title, a flag when something is late or due today, the client bank, its length. A longer block adds one sentence. The full explanation is in the panel.
- **The clock.** `data-date` on `body` is the day of the page; the script follows the clock on that day only. `data-sample-now` belongs to the example alone. The dot on the line is placed inside the running block in proportion to the time gone.
- **The panel.** The details of every block are in the page, one `section` each; the script shows the one selected. Without script, they all show, one under the other, and both views show: the page is whole without it.
- **Following.** The panel follows the clock until the PO selects another block; "Back to now" returns to it. The arrow keys walk the day.
- **Copying.** As on the page it replaces: the clipboard, then the older copy route, then a field to copy by hand.

## What the page holds

Checked on the example at 1366 by 768 and at 1680 by 950.

| Part | Holds |
|---|---|
| The day | 8 hours 30 in 11 blocks. At 768 pixels of height the last hour and a half is below the fold; the panel stays in view. |
| A block of 15 minutes | Its title on one line, cut with an ellipsis when it is too long. |
| The panel | A meeting with five facts, or a bundle of three things, without scrolling. A longer one scrolls inside the panel. |
| Pending | Two columns; five lines per group shown here. |

Not designed: a day of more than about 14 blocks, two meetings that overlap, a block that starts outside the quarter hours, a day with no meeting, a day with no plan because the briefing was refused. Apply the same rules and check the result by eye.

## What the tool computes, never the agent

- The row of each block, its length, and the free time left empty.
- How late a record is, what is due today, and the counts in the headings and on the Pending tab.
- "Planned 12:00" on a pending line: the tool finds the block of the day that names the record.
- The week's load and what does not fit, as on the page it replaces.
- What the clock marks: the script of the page, from the times the tool wrote.

Which task goes in which free time, what is bundled, what waits, the sentence at the top and the sentence of a block are judgement: the agent's proposal, then the PO's agreement at the briefing.

## Not verified

- The work machine: the titles need Bahnschrift and the text Segoe UI Variable. Both come with current Windows; the font stacks fall back to Segoe UI. Look at the result there, opened from disk.
- Printing, and browsers other than Edge and Chrome.
- French: every label here is in English, the default language of the views.
- No independent design review was run: the example was checked by the agent that built it.
