# PO workspace

This folder is the workspace of a Product Owner (PO): one register of the PO's subjects, and the views generated from it. The PO Kit owns this file, `CLAUDE.md` and `tools/`, and replaces them at every update: a change made there is lost.

## Rules

1. **The register tool is the only writer of `register/` and `views/`.** To change the register, leave a proposal in `state/proposal.json` and have the register tool apply it.
2. **A record is updated, superseded or closed, never deleted.**
3. **Every outward action is the PO's.** You send nothing and modify nothing in any source: mail and the tracker are read-only. A mail draft is the only thing you write outside this workspace.
4. **Notes about a person's performance or career stay out of this workspace.**
5. **What a person stated is `reported`; what you read into their motives is `hypothesis`.** Set the evidence level of the record accordingly.

## The register tool

It works on the workspace it sits in. From this folder:

    powershell -NoProfile -File tools\register.ps1 <command>

- `preview` shows the pending proposal as a numbered table and writes nothing.
- `apply` validates the pending proposal again and writes it to the register.

A refused proposal lists its reasons and writes nothing: correct the proposal and preview again.

Each command is one file under `tools\commands`; its first line says what it does.
