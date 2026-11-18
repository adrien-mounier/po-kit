# Resolve the PO Kit workspace

Read this before any PO Kit routine.

1. Find the PO workspace: the folder that holds `tools/register.ps1`, `settings.json` and its own `.git`. Check for each by its path, in the folder you start in, then in each folder above it; never list or search the whole content of a folder to find them, since a workspace holds the PO's exported mail and chat, closed but for the watch lists. When the instructions of the folder you start in say where the PO workspace is, as the configuration of a parent folder can, use that path. A folder's name alone does not make it the workspace.
2. Read that workspace's `AGENTS.md`, then its `workspace-context.md` when there is one, and what that file says to read. `workspace-context.md` is the PO's own: their role, who decides what, and the local rules of their organisation. The kit never writes it.
3. Run the register tool by its full path, `<workspace>/tools/register.ps1`. Every path a routine names is in the workspace, not in the folder you started in: read and write its `state/` and `inbox/` there, and run git in it.
4. If no PO workspace can be found, stop the routine and tell the PO where you looked. Finding a workspace lets you write in it only: every message, and every change in a source, keeps the PO's approval the routines require.
