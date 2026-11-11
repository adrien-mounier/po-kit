# PO Kit

An installable kit that turns a coding agent into a Product Owner's assistant. Vocabulary is in `GLOSSARY.md`; the build is specified in this repo's GitHub issues.

## Everything here is fictional

Examples, fixtures, tests, issues and commit messages use the fictional Example Bank and generic roles (the PO, the sponsor, the tech lead).

The owner's real material lives only in a workspace on their work machine. When the owner pastes or describes something from their employer, take the behaviour it reveals and restate it with Example Bank: real names, real subjects, internal tool names and real documents never enter this repo, its issues or its commits.

## Two machines, two models

The kit is built and tested here with Claude Code. It runs on the owner's work machine under Codex CLI and Windows PowerShell 5.1, with a different model.

- Write every script for Windows PowerShell 5.1 with no dependency, and run it in that edition before calling it done.
- Write every file the kit produces as UTF-8 without a byte order mark; 5.1's defaults do otherwise.
- Routines name no agent-specific and no connector-specific tool, so they run unchanged on both machines.
- A routine is proven by its scenario passing, here and again on the work machine.

## Agent skills

### Issue tracker

Specs and tickets are GitHub issues in `adrien-mounier/po-kit`, via `gh`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels, unchanged. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` at the root, `docs/adr/` created when the first decision needs recording. See `docs/agents/domain.md`.
