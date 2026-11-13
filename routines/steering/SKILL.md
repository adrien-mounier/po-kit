---
name: steering
description: Draft the steering pack for a steering committee of the PO's calendar - one self-contained HTML deck of six slides, views/steering/<date>.html, that the register tool writes from the register and from your commentary, verified like the weekly synthesis, for the PO to present and print to PDF. Use when the PO says "steering pack", asks for the pack of a steering committee, or pastes the request the morning page's button copies ("Draft the steering pack for ... of 2026-03-09").
---

# Steering pack

The register tool writes the deck from the register: the ranked portfolio, the benefits against their target, the decisions, the risks and the commitments late. You write its commentary, one sentence per slide and the next steps, from what the register tool exports and from nothing else. Your only write is `state/steering.json`; the deck is the register tool's, and you never edit it. You send nothing: the deck is a draft that counts for nothing until the PO uses it, and sharing its PDF is the PO's.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool.

## 1. Run the check

Run the register tool's `check`. When it counts one or more errors, read `views/check-report.md`, show the PO each error it lists under `## Errors`, with its rule, and end there: the register cannot be trusted for a pack.

Done when the check counts 0 error. Warnings let the pack go on.

## 2. Find the committee

- **The PO named it**, with its date, as the morning page's request does (`... of 2026-03-09`): that date is the committee's.
- **Otherwise** run the register tool's `steering`, with no date. It names each steering committee of today's calendar snapshot within five working days whose pack is not written yet, as `Steering committee to prepare: Retail steering committee on 2026-03-09, decisions taken since 2026-02-09.` Take the first. When it names none, ask the PO for the date of the committee and end there.

**The period** starts at the last committee: list the names of the files of `views/steering/`, and take the latest date before the committee's. When there is none, it starts four weeks before the committee. Their names are all you take from them.

Done when you hold the date of the committee and the date its period starts on.

## 3. Read the material

1. Run the register tool's `export` with the date the period starts on, as `export 2026-02-09`. It prints every record the deck may speak of, with its identifier.
2. Run the register tool's `view ranking`, then read `views/ranking.md`: the order the portfolio slide shows.

Done when you hold the export and the ranked portfolio.

## 4. Write the commentary

Write `state/steering.json`, as UTF-8 without a byte order mark, replacing the last one, in the sponsor's language (`languages.sponsor` of `settings.json`):

    { "headline": "Onboarding is on track; the committee is asked to fund the second wave [D-2026-002].",
      "portfolio": "Mobile onboarding leads the portfolio [mobile-onboarding].",
      "value": "Onboarding time is down from 40 to 31 minutes against a target of 20 [B-2026-001].",
      "decisions": "One decision is asked of the committee today [D-2026-002].",
      "risks": "The test accounts are late and hold up the pilot [C-2026-001].",
      "next_steps": [ "The PO writes the pilot report by 20 March [C-2026-002].",
                      "The tech lead delivers the test accounts [C-2026-001]." ] }

- `headline`: the one message the committee should leave with, for the title slide.
- `portfolio`, `value`, `decisions`, `risks`: one sentence each on what matters in that slide: the head of the ranking, the gains against their targets, what is asked of the committee, what threatens the plan.
- `next_steps`: three to five, each one sentence, from the open commitments and the decisions awaited of the export: who does what, by when.

Each sentence says what lines of the export say and ends with the identifier of each record in square brackets, as the export prints it. A fact, a date or a name is there because a line of the export gives it. Keep the evidence level: `reported` is what a person said, `hypothesis` a guess. A value of a benefit is quoted as the export gives it, never computed.

Done when every part is written and every sentence cites the records it speaks of.

## 5. Have the register tool write the deck

Run the register tool's `steering` with the date of the committee, as `steering 2026-03-09`. It writes `views/steering/2026-03-09.html`, replacing the last one.

When it prints `Not verified: state\steering.json`, a sentence cites a record that is missing or superseded: correct it from the export, where a superseded record no longer appears, and run `steering` again.

When it prints `Not verified: views\steering\<date>.html`, the deck it would write fails the check of `verify`, and it wrote none: a record's own text cites a record missing or superseded, or the stamp is cut. You cannot correct that: tell the PO the deck was not written and each line of why, offer no deck, and end there.

Done when it prints where the deck is written.

## 6. Have the register tool verify it

Run the register tool's `verify` with the path of the deck, as `verify views/steering/2026-03-09.html`.

`Verified` means the deck counts as drawn from the register. `Not verified` comes with what failed: correct the commentary from the export, run `steering` once more, as step 5 says, and verify again. When it fails again, tell the PO the deck failed `verify` and each line of why, offer nothing, and end there: a deck that fails is never offered. The deck is the register tool's: you never edit, move or delete it.

Done when `verify` answers `Verified`.

## 7. Tell the PO

Your answer is short:

1. Where the deck is, `views/steering/<date>.html`, to open in a browser: six slides, one landscape page each.
2. The headline you wrote, and the next steps, one line each.
3. To share it: print it to PDF from the browser, landscape, with background graphics on, one slide per page. The PDF is the PO's to send; you send nothing.
4. That it is a draft: the PO reads it before using it, and asks for any change. A change to a fact goes through a proposal and the deck is written again; a change to the commentary is yours, then step 5 again.
5. The warnings the check counted.

Done when the PO knows where the deck is, what it says, how to share it, and that nothing was sent.
