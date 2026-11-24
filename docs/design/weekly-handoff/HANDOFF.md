# Weekly presentation: the look to reproduce

Date: 23 November 2026. Audience: the agent that implements the weekly HTML presentation described in `docs/weekly-html-exploratory-spec-20261123.md`. That specification leaves the look open; the PO has now chosen it, and this folder is the choice.

## What is here

| File | What it shows |
|---|---|
| `weekly-example.html` | The target look on an ordinary week: five slides. |
| `weekly-example-cases.html` | The same look on special cases: a week with nothing to report, a table that runs over two slides, a slide with nothing to decide. It is a catalogue, not one real deck. |

Both are hand-built prototypes with fictional content (Example Bank). They are examples of an output, not a template and not a renderer: nothing here reads the register. Open either in Edge, press F11, and move with the wheel, the arrow keys or the space bar.

## Decided by the PO

Treat these as requirements. Changing one is a product decision, to take back to the PO.

- **The look** is the one of `weekly-example.html`: its layout, its type, its colours, its spacing.
- **Five slides, in this order**: the week's essentials; progress by subject; decisions and dependencies; next week; then one annex, value delivered. There is no title-only slide and no label above a title: the name of the deck sits in the footer.
- **It is shown on a shared screen in a video call.** Type is large, a slide holds few items, contrast is strong. Narrow screens and dark mode are not designed and not wanted.
- **One screen is one slide.** Slides snap; motion is discreet (each part rises as its slide comes in) and the deck is whole without it.
- **No script, no network, no font to download.** The file is self-contained and uses fonts installed with Windows.
- **A busy week**: the subjects that moved come first, one full row each, and the table goes on over the next slide under the same title marked `1/2`, `2/2`. The subjects that did not move are named in one line under the last row. Nothing is left out.
- **A quiet week**: every slide stays and says what is absent, in a dashed box. A zero is shown as a zero. Where an absence could be misread, the slide says what was not covered.
- **No presenter notes** in this version: the file may be sent to the sponsor, and whatever it holds can be read.
- **The kit stays neutral.** Every colour is named once, in the `:root` block marked "The palette", and nowhere else. An organisation restyles the deck by replacing that block.
- **Printing to PDF** matters less than the screen, but one slide must print as one page.

## Yours to decide

How the HTML is produced, where the agent's judgement ends and the tool's writing begins, how the deck is validated, where it is stored and under what name: all as the specification says. The examples take no position on any of it.

## How the examples work

Worth keeping, because each solves something the constraints make awkward.

- **Sizing.** `html { font-size: min(1.3vw, 2.3vh); }` makes `1rem` a fixed share of the screen, so a 16:9 window is about 77rem by 43.5rem at any resolution. Every size is in `rem`; the deck scales as a slide does and never reflows.
- **Navigation without script.** `scroll-snap-type: y mandatory` on `html`, one `100vh` slide per snap point. The dots on the right are plain links to `#s1`, `#s2`. Each slide needs its own `view-timeline-name` (`--s1`, `--s2`) and the matching rule for its dot, all listed in `timeline-scope`: emit as many as the deck has slides. The examples list six.
- **Motion.** Scroll-driven animations inside `@supports (animation-timeline: view())` and `prefers-reduced-motion: no-preference`. A browser without them shows everything in place.
- **Signs.** The sign in a movement pill is an SVG embedded as a `data:image` address and used as a mask, so it takes the colour of its word. This stays within the rules the steering template already obeys: no address but `data:image/...`, no backslash.
- **Colour has one meaning each.** Blue is the accent, and what is asked of the sponsor. Red is only for what is late or needs attention. A movement is said by a word, a sign and a colour, never by colour alone.

## What a slide holds

Measured on the examples at 16:9. Beyond these, continue on a next slide as the subject table does.

| Slide | Holds |
|---|---|
| Essentials | Up to 3 highlights, 1 attention point, 1 requested decision, 4 figures |
| Progress by subject | 6 rows, each cell on at most two lines |
| Decisions and dependencies | 2 decisions, 2 dependencies, the capacity sentence |
| Next week | 4 steps |
| Value delivered | 5 benefits |

Only the subject table was designed and checked running over two slides. Three decisions or six benefits are not designed: apply the same rule and check the result by eye.

## What the tool computes, never the agent

The examples show a few derived values. Each must come from the register tool, as the steering pack's do.

- The four figures of the first slide: they count records.
- How late a commitment is ("3 jours de retard").
- Where a bar stands between a baseline and a target. No bar when the baseline, the target or the value is missing: the row says which is missing instead, as the annex shows.
- The split of a table over slides.

The three highlights, the attention point and the movement label of a subject are judgement. The specification says what evidence each needs.

## Not verified

- Printing to PDF: the rules are written (`@page`, one slide per page) and were never run.
- The work machine: the titles need Bahnschrift and the text Segoe UI Variable. Both come with current Windows; the font stacks fall back to Segoe UI. Look at the result there.
- Long text: a cell that runs over two lines pushes the rows down, and a slide clips what does not fit. The renderer must choose how many rows a slide takes, as the steering pack does.
- Browsers other than Edge and Chrome.
- English: the examples are in French, the sponsor's language here. Every label needs its English form.
