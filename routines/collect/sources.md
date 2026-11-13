# Reading mail, the tracker and chat

How the collect reads the sources `mail`, `tracker` and `chat` of `connections.json`. You only read them: you send nothing, and you create, change or delete nothing in a source.

**The watch lists bound what you read.** A source holds far more than the PO's subjects: private mail, the tickets of other teams, one-to-one chats. You search it, and you open only what the search returns: step 2. Never list the folder of a source or its subfolders (`ls -R exports`, `find exports`, `Get-ChildItem -Recurse exports`): their names alone tell what is private, as who the PO chats with one to one.

Take `mail`, then `tracker`, then `chat`. A source that cannot be read never stops the collect: it is **not covered**, you tell the PO why, and you go on.

## 1. Open the source

Its `mode` says how:

- `folder`: exported files, one per mail, per ticket or per chat message, under the folder that the entry names in `folder`. The mail the PO received is under `received/`, the mail the PO sent under `sent/`. A chat message is under the folder of its conversation: `channels/<name>/` for a channel, `group chats/<name>/` for a group chat, `one-to-one/<name>/` for a one-to-one chat. When the folder is missing, the source is not covered.
- `connector`: the connector that the entry names in `connector`. The entry must hold `"verified"` with `"result": "ok"` before you rely on it. When it does not, verify the connector now: make one harmless read through it (ask for one recent item), then write in the entry what it gave and today's date, as `AGENTS.md` shows, leave the rest of `connections.json` as it is, and write the file as UTF-8 without a byte order mark. A connector that this machine does not have, or whose read fails, gets `"result": "failed"`, and the source is not covered.

A connector that was verified and fails while you read leaves the source not covered too. Its `"verified"` stays.

## 2. Search the source for what the watch lists match

Each active subject carries a watch list, in its record `register/subjects/<identifier>.json`: `watch_list.people`, `watch_list.keywords`, `watch_list.tracker_projects` and `watch_list.chat_channels`.

- A mail matches when a person of a watch list sent it or received it, or when its subject or its text holds a keyword of a watch list, whatever the case of the letters.
- A ticket matches when its project is a tracker project of a watch list.
- A chat message matches when it was posted in a channel or a group chat that a watch list names in `chat_channels`. Nothing else opens chat: not a person, not a keyword.

**A one-to-one chat is never read**: a conversation between the PO and one other person, even when a watched person wrote it, even when a watch list names it. You do not list it, open it or mention it.

The source stays closed until you hold the watch lists. Then, in this order:

1. Read the watch lists, from the records of the subjects, on their own: nothing of a source is listed or read in the same go.
2. Search the source: mail once for each person and each keyword, the tracker once for each tracker project, chat once for each channel and group chat named. Through a connector, ask it for the mail of the person, the mail that holds the keyword, the tickets of the project, the messages of the channel or the group chat; a conversation the connector shows as one-to-one is left closed. In a folder, search the content of its files for the word, with a search that answers with the names of the files holding it and shows nothing of the others. For a tracker project the word is its key, as `LOAN`: the search returns the tickets of that project, and those of every other project stay closed. For chat, ask for the names of the files of the folder of the channel or the group chat named, as `channels/lending squad/`: these are its messages, and that folder is the only one of chat you look into.
3. What the searches returned are the matches: open these, and only these, each one by the name its search gave. Never open the files of a source through a pattern or a loop over its folder, as `exports/tracker/*` or `exports/chat/*`: that opens what no watch list matched.

Whatever no search returned stays closed, in a folder of two files as in a mailbox of thousands: you do not list it, open it or mention it. It is the PO's own mail, another team's ticket or a private chat, and nothing of it reaches the proposal or your answer.

Done when you hold the matches of the source, and have opened nothing else in it.

## 3. Keep what is new, oldest first, up to the cap

1. A mail is dated when it was sent, a ticket when it was last updated, a chat message when it was posted. Keep the matches dated after the cutoff of their source: `state/last-collect.json` gives it as `sources.mail.cutoff`, `sources.tracker.cutoff` and `sources.chat.cutoff`. A source without a cutoff there was never read: its first read starts seven days before this collect, and you tell the PO so.
2. Sort what you kept by date, oldest first.
3. `per_source_cap`, in `settings.json`, is the most items a collect reads in one source. Read the oldest ones, up to that number. When more remain, the cap is reached: the rest waits for the next collect, and you tell the PO that the cap was reached for this source.

## 4. Treat each mail, ticket and chat message read as a note

The routine goes on with what you read as it does with a note, in the order read. Four things differ:

- **What it is about.** The watch list says why you read it. Its content says what it is about: maybe another subject than the one whose watch list matched. When it matters to the PO's work and is about no subject, it goes to `unclassified`.
- **Who "I" is.** In a mail, the person who sent it: the PO in a sent mail. In a chat message, the person who wrote it. A promise the PO makes there is a commitment whose `owner` is `the PO`.
- **Its source.** `where`, in the `source` of a record, names it so that the PO finds it again, and so does the `source` of an unclassified item. The `mode` of the source decides how, for a mail, a ticket and a chat message alike:
  - `folder`: the path of the file, as you opened it, and nothing else: `exports/mail/sent/rate table.txt`, `exports/tracker/LOAN-12.txt`, `exports/chat/channels/lending squad/2026-02-27 1015 the lending analyst.txt`.
  - `connector`: the name of the source, then what finds the item there: `tracker: LOAN-12`, `mail: sent to the lending analyst on 2026-02-27, "Rate table"`, or `chat: lending squad, the lending analyst on 2026-02-27 at 10:15`.
- **It is no file of the inbox.** It stays where it is, and `notes_processed` does not name it.

## 5. Say in the proposal how far the source was read

A source read has one entry in `sources_read`, even when it held nothing new:

    { "source": "mail", "cutoff": "2026-02-27T16:45:00+01:00", "items": 50, "cap_reached": true }

- `items` is the number of mails, tickets or chat messages read.
- `cutoff` is how far the source is read: the time of this collect. When the cap was reached, it is the date of the last item read, written as `collected_at` is, and the entry states `"cap_reached": true`.

A source not covered has no entry there: `sources_not_covered` names it.

Done when `mail`, `tracker` and `chat` are each either read, with every match dated after the cutoff taken up to the cap, or not covered, with the reason told to the PO.
