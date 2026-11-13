---
name: subject
description: Create, modify, score or close a subject of the PO's register by asking the PO a few questions, and brainstorm with the PO the benefits it promises. Use when the PO wants to add a subject, change one (horizon, client banks, clearance, gates, watch list, next step), have one scored, see the ranked portfolio, close one, or define its benefits, gains or metrics.
---

# Create, modify or close a subject

The PO answers in plain words, you turn the answers into a proposal, and the register tool writes the record. Your only write is `state/proposal.json`.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool and how `settings.json` lists the gates, the objectives and the client banks.

## 1. Know which subject, and what to do with it

For each subject the PO names, one of three:

- **Create** a subject the register does not hold yet.
- **Modify** a subject: any answer of step 2 can change.
- **Close** a subject: its status becomes `closed`, and the record stays in the register with its history.

To modify or close, find the record. Each file under `register/subjects/` is one subject, and its name without `.json` is the identifier. When what the PO said fits no subject, or more than one, ask which one.

**Its open questions.** For a subject the register holds, read your open questions in `state/questions.json`: those about the subject or one of its records are asked in your next answer, numbered, each with its recommended answer, as `AGENTS.md` says. An answer the PO gives to one joins the proposal; one left unanswered stays in the list.

Done when each change names a new title or the identifier of one existing subject, and its open questions are asked.

## 2. Get every answer from the PO

Creating a subject takes the eight answers below. Modifying one takes only the answers that change.

| Ask the PO | Fields | Recorded as |
|---|---|---|
| Its title | `title` | text |
| Its kind | `kind` | `product` (a product the PO steers), `contribution` (to someone else's product) or `service` (rendered to the organisation) |
| Its horizon | `horizon` | `now`, `next` or `later` |
| Which client banks it concerns | `banks` | the names of the client banks, as `settings.json` lists them under `banks`; an empty list when the PO says "none" or "all": the subject concerns the whole group, or every bank |
| Its clearance, who gave it and when | `clearance`, `cleared_by`, `cleared_on` | `cleared` (with who and the date), `pending`, `out of frame` (work exists while a mandatory gate is missing) or `none` |
| The state of each gate | `gates` | one `{ "name": ..., "state": ... }` per gate that `settings.json` lists; the state is `unknown`, `not required`, `missing`, `planned` or `done` |
| Its watch list | `watch_list` | three lists: `people`, `keywords`, `tracker_projects` |
| Its next step | `next_step`, `next_date`, `next_date_confirmed` | text; a date when the PO gives one; confirmed is `true` when the PO says the date is confirmed |

Every answer comes from the PO's own words. "None", "not yet" and "nobody knows" are answers: record `none`, `unknown`, an empty list, or leave the field out. An answer the PO has not given is a question: ask for all the missing ones in one message, in the words of the left column, and stop there. The proposal waits for the PO's reply.

Record these too when the PO mentions them: `owning_entity`, `sponsor`, `decider`, `links`, `notes`, `objectives` (the numbers of the objectives the subject serves), and in the watch list `chat_channels` (the chat channels and group chats to read; the one-to-one chat with a person of the watch list, and a one-to-one message that holds one of its keywords, are read without being named here).

**A request for an AI use case.** When the PO describes a request for one, the new subject takes it in: `horizon` `later`, `clearance` `pending`, `kind` `product` unless the PO says otherwise; the gates, the watch list and the next step are not asked. Ask instead for its intake parts, in the PO's words: the problem (`problem`), the client bank (`banks`), who asks (`requested_by`), the data needed (`data_needed`) and the expected gain (`expected_gain`). A part the PO does not give does not hold the subject back: record it without that part, and keep a question for it, with your recommended answer.

**Whether the work changes.** For every subject you create, ask the PO whether the way people work changes or only a tool is added, with your recommended answer and why, as `Yes: the analysts would review a draft instead of writing the memo.`: in the same message as the missing answers, or with the preview table when none is missing. The answer is `work_changes`, `yes`, `no` or `unknown`, with one sentence in `work_changes_reason`. It does not hold the subject back either.

A question the PO leaves unanswered goes to your open questions once the subject is recorded, about it.

**Scores.** For each request for an AI use case you create, and for any subject the PO asks you to score or that lacks scores when the PO asks for the ranked portfolio, propose its scores yourself: they are not the PO's answers but yours, each with its reason in one short sentence:

- `value_score` and `value_reason`: what the subject would bring, from 1 (little) to 5 (a lot): its expected gain, and how many people or cases it serves;
- `feasibility_score` and `feasibility_reason`: how easily it can be done, from 1 (hard) to 5 (easy): the data it needs and whether that data is at hand;
- `risk_score` and `risk_reason`: what could go wrong, from 1 (little) to 5 (a lot): harm to a customer, sensitive data, an error no one would catch;
- `ai_act_high_risk` and `ai_act_reason`: the AI Act mark, below.

A score is a whole number from 1 to 5: the register tool refuses any other, and a score or a mark without its reason. A score you have nothing to ground is left out, with a question.

**The AI Act mark is a mark to check, never legal advice.** Give `true` when the use case would fall in an area that the EU AI Act lists as high-risk (its Annex III), such as assessing the creditworthiness or the credit score of natural persons, deciding their access to essential private services, or recruiting and managing workers; or when it would be the safety component of a product. Give `false` when it plainly falls in none, as a tool that drafts a text a person reviews. Name the area in `ai_act_reason`, and tell the PO that the mark is theirs and the organisation's compliance function's to confirm. When you cannot tell, leave the mark out and keep the question. The mark never weighs on a score: the ranked portfolio shows it beside the score.

Done when each answer needed is one the PO gave, and the scores to propose are written.

## 3. Write the proposal

When `state/proposal.json` already exists, a proposal is pending: preview it, show it to the PO and ask what to do with it before writing another.

Write `state/proposal.json` as UTF-8 without a byte order mark, one operation per subject.

To create:

```json
{ "operations": [ {
  "op": "create", "type": "subject", "interpreted": false,
  "fields": {
    "title": "Loan calculator", "kind": "service", "horizon": "later", "banks": ["Harbour Bank"],
    "clearance": "cleared", "cleared_by": "the head of lending", "cleared_on": "2026-01-15",
    "gates": [ { "name": "architecture review", "state": "done" } ],
    "watch_list": { "people": ["the lending analyst"], "keywords": ["loan"], "tracker_projects": ["LOAN"] },
    "next_step": "Review the first mock-up",
    "objectives": [1],
    "evidence_level": "fact",
    "source": { "where": "conversation with the PO", "read_on": "2026-03-02" }
  } } ] }
```

To modify or close:

```json
{ "operations": [ {
  "op": "update", "id": "loan-calculator", "interpreted": false,
  "source": { "where": "conversation with the PO", "read_on": "2026-03-02" },
  "fields": { "horizon": "now" }
} ] }
```

- `fields` of an update holds only the fields that change, each with its whole new value: a list is given whole.
- To close: `"fields": { "status": "closed" }`. A refused request is closed with its reason, after the notes it already holds: `"fields": { "status": "closed", "notes": "Refused on 2026-03-09: the data cannot leave the bank." }`.
- `read_on` is today's date, read from the machine.
- What the PO tells you is a plain fact: `"interpreted": false` and `"evidence_level": "fact"`.
- Your scores are not: they go in an update of their own, `"interpreted": true`, after the line that creates or modifies the subject, so that the PO can keep the subject and drop them. For a subject this proposal creates, the update names it by its line, `"id": "line 1"`; it carries the source `{ "where": "the agent's reading of the subject", "read_on": "<today's date>" }` and gives the scores and the mark with their reasons:

```json
{ "op": "update", "id": "line 1", "interpreted": true,
  "source": { "where": "the agent's reading of the subject", "read_on": "2026-03-02" },
  "fields": { "value_score": 4, "value_reason": "Every credit memo would take two hours instead of a day.",
              "feasibility_score": 3, "feasibility_reason": "The memos exist, but they must be gathered from three teams.",
              "risk_score": 2, "risk_reason": "An analyst reviews every draft before it is used.",
              "ai_act_high_risk": false, "ai_act_reason": "It drafts a memo an analyst reviews; it does not assess the creditworthiness of a person." } }
```
- The register tool sets the identifier, the dates and the history.

## 4. Preview, then apply once the PO accepts

1. Run the register tool's `preview`. When it refuses the proposal, it lists its reasons. Correct the proposal when the reason is its form. Ask the PO when the reason is an answer: a gate, an objective or a client bank that `settings.json` does not list is the PO's to add there.
2. Show the PO the table that `preview` printed.
3. Run `apply` once the PO accepts. An acceptance given ahead, with the request, counts. **Your scores are recorded only on a yes the PO gives them**: an acceptance given ahead covers them only when it accepts the proposal as `preview` shows it, or names the scores. When it covers only what the PO told you, run `apply plain`: it records the PO's answers and leaves your scores waiting; show the PO the table it prints under `Waiting for the PO`, and wait. When the PO wants a change, correct the proposal and preview again. When the PO wants nothing recorded, delete `state/proposal.json`.

For a subject a request created, run the register tool's `view intake <identifier>` once it is recorded, and tell the PO where the intake card is: a draft, to review before using it.

When the PO asks for the ranked portfolio, run the register tool's `view ranking` once the scores are applied (`view ranking bank <client bank>` for one client bank) and tell the PO where it is: `views/ranking.md`.

Done when the register tool has answered `Applied and committed`, and you have told the PO which subject was recorded, with its identifier. Once a new subject is recorded, offer in one line to brainstorm its benefits: step 5.

## 5. Brainstorm the benefits of a subject

A benefit is a gain the subject promises: a metric, its unit, its baseline, its target and who measures it. A subject may hold several. Do this step when the PO asks what a subject should deliver, its benefits, gains or metrics, or accepts your offer.

1. Read the benefits the subject already holds: the files under `register/benefits/` whose `subject` is its identifier.
2. Propose two to four measurable metrics that fit its use case: time saved, errors avoided, cost, satisfaction. For each, on one line: the metric, its unit, how it is measured (where the figure comes from), and who could measure it. As:

       1. Time a customer takes to open an account - minutes - timed from the first screen to the account opened, in the onboarding logs - the head of retail operations could measure it.

   These are proposals: nothing is recorded yet. A metric never measures how a person works.
3. Record only the metrics the PO picks, one benefit each. Its baseline and its target are the PO's numbers, as the PO gives them: never propose, estimate or compute one. Ask in one message for a baseline, a target or who measures it that the PO has not given; "not known yet" is an answer: leave the field out.

```json
{ "operations": [ {
  "op": "create", "type": "benefit", "interpreted": false,
  "fields": {
    "title": "Halve the time to open an account",
    "subject": "mobile-onboarding",
    "metric": "Time a customer takes to open an account",
    "unit": "minutes", "baseline": 40, "target": 20,
    "owner": "the head of retail operations",
    "evidence_level": "fact",
    "source": { "where": "conversation with the PO", "read_on": "2026-03-02" }
  } } ] }
```

- `subject`: the identifier of the subject, or `line 1` when line 1 of the same proposal creates it.
- `owner`: the one person who measures the metric. It says who measures it, nothing about how they work.
- `baseline`, `target` and `current_value` are numbers, in `unit`.
- A value is stated by a person, with its source: never measure or compute one yourself. A value the PO gives is an update of the benefit that gives `current_value` and `measured_on`, the date it was measured, together, with the source `{ "where": "the PO, in conversation", "read_on": "<today's date>" }`. The register tool refuses a value without its date.
- A new target is an update of `target`. A benefit reached is updated to `status` `achieved`, one given up to `dropped`. A different metric is a new benefit that names the old one in `supersedes`.

Then preview and apply as step 4. Done when each metric the PO picked is a benefit recorded with its identifier, told to the PO.
