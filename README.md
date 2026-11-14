# PO Kit

A kit that turns a coding agent into a Product Owner's assistant. The agent reads the PO's notes, mail, tracker, chat and calendar, keeps one register of the PO's subjects, and writes the PO's morning page, weekly synthesis and steering pack. It recommends; the PO decides. It sends nothing and changes nothing in a source without the PO.

Every example in this repository is fictional: Example Bank and its client banks, Harbour Bank, North Bank and Alpine Bank. Words are defined in `GLOSSARY.md`.

## How it fits together

- **The kit** is this repository: the routines, the register tool, the workspace template and their tests. An update replaces it whole.
- **The workspace** is a folder on the PO's machine, under version control. It holds the PO's data and is never touched by an update:
  - `register/`: the subjects, commitments, decisions, risks and benefits, one file each;
  - `inbox/`: the notes the PO drops for the agent; `inbox/done/` once processed;
  - `views/`: what the agent writes for the PO to read: the portfolio, the morning page, the weekly synthesis, the steering packs, the check report;
  - `state/`: the agent's work in progress: the pending proposal, its open questions, the calendar snapshot, the backlog changes and alerts;
  - `settings.json` and `connections.json`: the PO's, edited by hand (below).
- **The register tool**, `tools/register.ps1` in the workspace, is the only writer of the register and the views. The agent never edits a record itself: it leaves a proposal, and the tool checks it, refuses it whole if anything is wrong, and writes it once the PO agreed. A record is updated, superseded or closed, never deleted.
- **The routines**, under `routines/`, are the skills the agent follows. The installer copies them to the folder where the agent looks for its skills.
- **The workspace rules**, `AGENTS.md` (and `CLAUDE.md`, the same for another agent), sit in the workspace and bind the agent whatever the routine.

## What the PO says

| The PO says | The agent | Routine |
|---|---|---|
| "morning" | collects what is new, records the plain facts, reads the calendar, and writes the morning page: today's meetings with a brief each, what to do first, messages awaiting a reply, what to start soon, the workload of the next ten working days, backlog alerts, reminders. Then offers a short briefing in numbered questions. | `morning` |
| "collect", or pastes notes | turns the inbox, the pasted text, and the mail, tickets and chat messages within the watch lists into a proposal of commitments, decisions, risks and updates, shown before anything is recorded | `collect` |
| "new subject", "change the subject…", "score it", "close it" | asks a few questions, then proposes the subject; brainstorms its benefits; scores it and writes the ranked portfolio | `subject` |
| "weekly" | writes the weekly synthesis for the sponsor, in the sponsor's language, checks every claim against the register, and leaves it as a mail draft when the mail connection can | `weekly` |
| "steering pack" | drafts a six-slide deck for a steering committee of the calendar, from the register, for the PO to present and print to PDF | `steering` |
| "reword ticket…", "draft the tickets from this note", "split…", "how should I order the backlog?" | proposes ticket texts, splits and an order; changes the tracker only after the PO approved each exact text with its approval code | `backlog` |

A request for an AI use case, in any source, becomes a subject at once with an intake card, marked for a check under the EU AI Act when it might be high-risk. The mark is to check, never legal advice.

## What the agent may and may not do

- **It reads; the PO acts.** Mail, chat and the calendar are read-only. Outside the workspace the agent writes only a mail draft, and in the tracker only a ticket's text that the PO approved (below).
- **The tracker: one change at a time, approved with a code.** The agent may create a ticket or reword its title, description or acceptance criteria. It shows the exact text with a 6-character approval code; the change is applied only when the PO gives that code back in a later message. The register tool refuses any close, delete, reopen, move, or change of status, assignee, estimate, sprint or priority. Without a tracker connection that may write, the PO pastes the text.
- **No judgement of people.** Nothing about a person's performance or career is recorded. A backlog alert is about the ticket, never about who works on it.
- **Facts and guesses are kept apart.** What someone said is `reported`; what the agent reads into it is `hypothesis`. Every record keeps its source.
- **Only the watch lists are read.** Each subject has a watch list: people, keywords, chat channels, tracker projects. The agent searches the sources for them and opens only what the search returns. It never lists a source's folder, since the names alone can be private. The calendar folder is the one exception: the morning routine may list it.
- **Values of benefits are stated by a person**, with their source. The agent never measures or estimates one.

### The chat rule

Decided by the owner on 2026-11-13, replacing user story 32 of the tranche 2 spec (#16, #20):

- A channel or group chat is read when a watch list names it.
- **A one-to-one chat with a person on a watch list is read in full.**
- **Any other one-to-one chat is searched only for the subjects' keywords**, and only the messages that hold one are used, not the rest of the conversation.
- A one-to-one message that matches nothing is never opened, quoted, recorded or mentioned, nor the name of its conversation.

The rule lives in `routines/collect/sources.md` and is proven by the `collect-chat` scenario.

## The PO's two files

`settings.json` bounds what a record may say and tunes the views: the organisation's gates, the PO's objectives, the client banks, the kinds of task, working hours, the "start soon" margin, the words that mark a steering committee or a refinement session in a meeting title, how stale a ticket may get, the sponsor and the languages.

`connections.json` says how each source (`notes`, `mail`, `tracker`, `chat`, `calendar`) is read on this machine:

- `{ "mode": "off" }`: not read;
- `{ "mode": "folder", "folder": "exports/mail" }`: read from exported files;
- `{ "mode": "connector", "connector": "<name>" }`: read through a connector the agent knows, read-only. `"drafts": true` on mail lets the agent leave the weekly synthesis as a draft; `"writes": true` on the tracker, set by the PO alone, lets it apply approved changes. Until issue #36 ships, the approval code is checked after a connector write, so leave `writes` off.

## Install or update

From a clone of this repository, in Windows PowerShell 5.1:

    powershell -NoProfile -File install.ps1 -Workspace <folder> -SkillsFolder <folder>

A new or empty folder becomes a workspace. Run again, it replaces only what the kit owns. If the machine's execution policy refuses scripts, the installer stops; ask IT, never bypass it.

## Tests

- **The kit's tests**, free, one file at a time: `powershell -NoProfile -File tests\run.ps1 <name>`, where `<name>` is a file of `tests\` without `.tests.ps1`.
- **The scenarios** run the real agent on the Example Bank workspace and check the facts it leaves; they cost money. `powershell -NoProfile -File scenarios\run.ps1 -Agent "<command>" [scenario ...] [-Keep]`. The header of `scenarios\run.ps1` gives the command used on the build machine. A routine counts as proven on a machine when its scenarios pass there.

## Where the decisions are

The specs and tickets are this repository's GitHub issues: tranche 1 (#1, the register, collect, weekly synthesis and check), tranche 2 (#16, the morning secretary), tranche 3 (#17, the portfolio and steering pack), tranche 4 (#18, the backlog). Open work carries the `ready-for-agent` or `ready-for-human` label.
