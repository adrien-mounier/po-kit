---
name: morning
description: Start the PO's day. Run a collect that records the plain facts at once and leaves the interpreted lines waiting, have the register tool write the morning page, views/morning.html, then tell the PO in two lines what the page holds. Use when the PO says "morning" or asks for the morning page.
---

# Morning

You collect what arrived since the last collect without stopping to ask, then the register tool writes the page the PO reads to start the day. Your writes are those of the collect; the page is the register tool's, and you never edit it.

Work in the PO's workspace, under its rules: read `AGENTS.md` there first when it is not already in your context. It says how to call the register tool.

## 1. Collect, without asking

When `state/proposal.json` exists, a proposal is pending: do not collect. The page lists it under "To sort", and the PO settles it when they choose. Go to step 2.

Otherwise follow the collect routine: `SKILL.md` in the folder `collect`, beside the folder of this routine. Follow it from its step 2 to point 2 of its step 6, with these differences:

- The PO is asked nothing while the morning runs: they read the page first.
- In step 6, do what point 2 says for the validation mode, then go to step 2 of this routine instead of showing a table and waiting for an answer. Under `Validation mode: interpreted.` that is `apply plain`: the plain facts are recorded, and the interpreted lines stay pending. Under `Validation mode: all.` every line stays pending, and nothing is applied.
- When the collect finds nothing new, it applies its empty proposal as it says, and the morning goes on.
- A question the notes cannot settle is said in your answer of step 3.

Done when the plain facts are recorded under `interpreted`, every other line of the collect is pending, and every note read is filed or still in a pending proposal.

## 2. Write the page

Run the register tool's `morning`. It writes `views/morning.html`, replacing the page of the day before, and prints one line per block of the page: its heading, then its counts.

Done when it ends without error.

## 3. Tell the PO

Your answer is short:

1. What the collect did, in one sentence: each record written with its identifier, the notes filed, how many lines wait for the PO, what went to unclassified, what the check found. When no collect ran because a proposal is pending, say so.
2. Then what the page holds, in two lines, from the counts that `morning` printed: first what is late or due today; then the rest, ending with where the page is, `views/morning.html`, to open in a browser.
3. Then each question on a real effort that the collect kept, one line each, as step 4 of the collect writes it: `Real effort of C-2026-004, "Build the steering pack": how many days did it take you? My guess: 2 d.` A real effort the collect could infer is in its line, and asks nothing.

Copy no table: the lines that wait are on the page, under "To sort", and the PO answers them when they choose.

Done when the PO knows what the collect recorded, what waits for them, what the page holds, and each real effort the agent asks.
