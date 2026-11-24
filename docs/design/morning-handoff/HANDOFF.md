# Morning page: the look and the organisation to reproduce

Date: 24 November 2026. Audience: the agent that specifies and builds the new morning page. The PO chose this organisation among three prototypes (`docs/design/morning-prototypes/`, option A); this folder is the choice.

## What is here

| File | What it shows |
|---|---|
| `morning-example.html` | The target page on an ordinary day, once the plan is agreed: the day as an agenda, the details of a block beside it, the pending items behind a second tab. |

It is a hand-built example with fictional content (Example Bank), self-contained: one file, no network, no font to download. It is an example of an output, not a template and not a renderer: nothing here reads the register. Open it in Edge. Opened on another day than its own, it shows a sample clock of 11:20.

The prototypes stay as a record of the two options not taken, and as the only place that shows the page **before the briefing**: `morning-prototypes/a-agenda-panel.html?state=proposed`.

## Decided by the PO

Treat these as requirements. Changing one is a product decision, to take back to the PO.

- **One thread through the day.** The page answers "what do I do now" in the order of the clock, from the first block to the end of the working hours. The "Do first" list is gone: its three priorities are blocks of the day that carry their number.
- **Blocks of real length on a half-hour scale.** Meetings are fixed. Tasks sit in the free time between them. Small things are bundled in one block that lists them. Lunch and gaps stay empty. What found no room is listed under the day as "Not today", so that nothing disappears silently.
- **The hours** are the PO's working hours; a meeting outside them stretches the day.
- **Proposed, then agreed.** The page written before the briefing shows the plan the agent proposes, marked as proposed; after the briefing it shows the plan agreed.
- **A clock, no tick.** The page follows the clock: past blocks fade, the running one is marked, the line darkens as the day goes. Nothing can be ticked on the page, because a tick would not reach the register. A block's details offer "Done, tell the agent" and "Not today" instead: like every button, they copy a request.
- **One sentence at the top** says what matters today: what is late, what must start, whether the week fits.
- **The pending items are a second plan**, in this order: Waiting on you (what the PO owes, the decisions awaited from them, the messages awaiting their reply); You are waiting on (what others owe, the decisions the PO waits for); This week's load; Backlog alerts; To sort, last.
- **Say a thing once.** A pending item that today's plan already covers shows "Planned 12:00", which leads to its block, and no second button.
- **Organisation A.** The day is drawn to scale on the left; the details of the selected block stay open in a panel on the right; the pending items are a second tab that carries their count.
- **The look** is the family of the weekly presentation: navy titles, one blue accent, red only for what is late, a contradiction or a week that does not fit; amber for today. A state is said by a word and a sign, never by colour alone.
- **Read on a laptop, in Edge, kept open all day.** A phone is not designed and not wanted.
- **The kit stays neutral.** Every colour is named once, in the `:root` block marked "The palette". An organisation restyles the page by replacing that block.

## Yours to decide

- How the agent builds the plan, what it writes for the register tool to draw, and how the briefing settles it. This is new behaviour of the morning routine and needs its own specification.
- Where the agent's judgement ends and the tool's writing begins, beyond the list under "What the tool computes".
- Whether the page keeps a dark mode. The page it replaces has one; this example is light only, and the PO has not said.
- What a page left open overnight says. The example follows the clock only on its own day and shows no clock otherwise; it does not yet say "this page is yesterday's".

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
- The page before the briefing exists in the prototype only, not as a self-contained example.
- Printing, and browsers other than Edge and Chrome.
- French: every label here is in English, the default language of the views.
- No independent design review was run: the example was checked by the agent that built it.
