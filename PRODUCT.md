# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

A Product Owner in a bank's AI team, who follows a dozen subjects for several internal clients (the fictional Example Bank and its client banks in every example). They are not an engineer. They read the kit's pages on a work laptop, in Edge on Windows, between meetings. The sponsor reads the weekly presentation on a shared screen.

## Product Purpose

PO Kit turns a coding agent into the PO's assistant. The agent reads mail, calendar, tracker and chat, keeps a register of commitments, decisions, risks and subjects, and writes pages the PO reads: the morning page, the weekly presentation, the steering pack. Success is a PO who knows each morning what to do, hour by hour, and misses nothing that is late or waiting.

## Positioning

Nothing reaches the register without the PO's yes, and no page changes anything: a page shows, a button copies a request the PO pastes into the agent's chat. The agent recommends; the PO decides.

## Operating Context

- The morning: the agent collects overnight, writes the morning page around 07:00, then offers the briefing, a short conversation in the chat that settles the day.
- The PO's working day runs from about 10:00 to 18:00. The page stays open in a browser tab all day and is revisited between meetings. It is not read on a phone.
- The pages are static HTML files written by the register tool from templates, opened from disk. No server, no network, no font to download.
- The kit is built here and runs on the PO's work machine under another agent and Windows PowerShell 5.1.

## Capabilities and Constraints

- The calendar is read-only: the agent never creates or moves an event.
- A page cannot save anything. A tick made on a page would not reach the register, so the page offers "tell the agent" buttons instead of ticks.
- A source that could not be read is said on the page, as a warning, never hidden.
- Every example is fictional (Example Bank, generic roles).
- Decided on 24 November 2026 for the morning page, not built yet: the day is one thread of blocks of real length on a half-hour scale (meetings fixed, tasks in the free time, small things bundled, lunch and gaps left empty, what did not fit listed as "Not today"); the plan is proposed by the agent before the briefing and agreed at it; a "now" line follows the clock; the pending items form a second plan, regrouped as "Waiting on you", "You are waiting on", the week's load, backlog alerts, and "To sort" last.

## Brand Commitments

- The kit stays neutral: every colour is named once, in one palette block, so an organisation can restyle a page by replacing it.
- The look of the weekly presentation (docs/design/weekly-handoff) is the family: navy headings, one blue accent, red only for what is late or needs attention. A state is said by a word and a sign, never by colour alone.
- Fonts installed with Windows only: Bahnschrift for titles, Segoe UI Variable for text.

## Evidence on Hand

- `docs/design/morning.html`: the morning page as designed before the redesign, with its fictional day.
- `docs/design/morning-handoff/`: the morning page the PO chose on 24 November 2026 (an agenda drawn to scale, a details panel beside it, the pending items in a second tab), not built yet.
- `docs/design/weekly-handoff/`: the weekly presentation the PO chose on 25 November 2026 (a dashboard of the subjects opened one at a time, in the look chosen on 23 November) and its private notes, not built yet.
- `routines/morning/SKILL.md`: what the morning routine does and what the page holds.

## Product Principles

1. One answer to "what do I do now": the day's thread, in the order of the clock.
2. Say a thing once. An item planned today is not listed again with a second button elsewhere.
3. Nothing disappears silently: what did not fit, what was not read and what waits are all said.
4. The page shows, the agent acts, the PO decides.
5. Red is rare, so that it means something.
