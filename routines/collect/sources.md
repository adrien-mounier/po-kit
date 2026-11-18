# Reading mail, the tracker and chat

How the collect reads the sources `mail`, `tracker` and `chat` of `connections.json`. You only read them: you send nothing, and you create, change or delete nothing in a source. The backlog routine reads the tracker this way too, to find a ticket the PO names: its key is the word searched.

**The watch lists bound what you read.** A source holds far more than the PO's subjects: private mail, the tickets of other teams, private one-to-one chats. You search it, and you open only what the search returns: step 2. Never list the folder of a source or its subfolders (`ls -R exports`, `find exports`, `Get-ChildItem -Recurse exports`, `ls exports/chat/one-to-one`): their names alone tell what is private, as who the PO chats with one to one.

Take `mail`, then `tracker`, then `chat`. A source that cannot be read never stops the collect: it is **not covered**, you tell the PO why, and you go on.

## 1. Open the source

Its `mode` says how:

- `folder`: exported files, one per mail, per ticket or per chat message, under the folder that the entry names in `folder`. The mail the PO received is under `received/`, the mail the PO sent under `sent/`. A chat message is under the folder of its conversation: `channels/<name>/` for a channel, `group chats/<name>/` for a group chat, `one-to-one/<name>/` for a one-to-one chat. When the folder is missing, the source is not covered.
- `connector`: the connector that the entry names in `connector`. The entry must hold `"verified"` with `"result": "ok"` before you rely on it. When it does not, verify the connector now: make one harmless read through it (ask for one recent item), then write in the entry what it gave and today's date, as `AGENTS.md` shows, leave the rest of `connections.json` as it is, and write the file as UTF-8 without a byte order mark. A connector that this machine does not have, or whose read fails, gets `"result": "failed"`, and the source is not covered.

  Verifying a connector also tests, once each, the searches step 2 makes in its source, with a word of a watch list: in mail, the mail of a person (`person`) and the mail that holds a keyword (`keyword`); in the tracker, the tickets of a project or a queue (`project`) and one ticket by its key (`ticket`); in chat, the messages of a channel or a group chat (`channel`), the one-to-one chat with a person (`person`), and the other one-to-one messages that hold a keyword (`keyword`). A search is `true` when the connector makes it and answers with what matches, showing nothing of the rest; `false` when it does not make it, or makes it only by listing the mailbox, the tickets or the conversations for you to open them one by one. Write them in `"searches"` of `"verified"`, as `AGENTS.md` shows. An entry verified before without `"searches"`, or with one of them missing, has them tested now; one whose `"verified"` names another connector than the entry is verified again.

A connector that was verified and fails while you read leaves the source not covered too. Its `"verified"` stays.

## 2. Search the source for what the watch lists match

Each active subject carries a watch list, in its record `register/subjects/<identifier>.json`: `watch_list.people`, `watch_list.keywords`, `watch_list.tracker_projects` (a project's key, or a queue's name), `watch_list.tracker_tickets` (single tickets, by their key or number) and `watch_list.chat_channels`.

- A mail matches when a person of a watch list sent it or received it, or when its subject or its text holds a keyword of a watch list, whatever the case of the letters.
- A ticket matches when its project, or its queue, is a tracker project of a watch list, or when a watch list names it in `tracker_tickets`.
- A chat message matches when it was posted in a channel or a group chat that a watch list names in `chat_channels`, or in the one-to-one chat between the PO and a person that a watch list names in `people`. A message of another one-to-one chat matches when its text holds a keyword of a watch list, whatever the case of the letters: that message, not the rest of its conversation. A message of a channel or a group chat that no watch list names never matches, keyword or not.

**A message of a one-to-one chat that matches nothing is never read**: no watched person wrote it and it holds no keyword. You do not list it, open it, quote it, record it or mention it, nor the name of its conversation. What a message you read says of a person's performance or career stays out, as `AGENTS.md` says.

The source stays closed until you hold the watch lists. Then, in this order:

1. Read the watch lists, from the records of the subjects, on their own: nothing of a source is listed or read in the same go. Then run `select <source>`, as `select mail`: `search_from` is where every search of the source starts, and each entry of `catch_up` is an entry of a watch list added since the source was last read, which you search from its own `from` too.
2. Search the source: mail once for each person and each keyword, the tracker once for each tracker project and once for each ticket a watch list names, chat once for each channel and group chat named, once for each person of a watch list and once for each keyword. Through a connector, ask it for the mail of the person, the mail that holds the keyword, the tickets of the project, the messages of the channel or the group chat, the one-to-one conversation of the PO with the person, the one-to-one messages that hold the keyword; anything else the connector shows of a one-to-one conversation is left closed. In a folder, search the content of its files for the word, with a search that answers with the names of the files holding it and shows nothing of the others. For a tracker project the word is its key, as `LOAN`: the search returns the tickets of that project, and those of every other project stay closed. For chat, ask for the names of the files of the folder of each channel or group chat named, as `channels/lending squad/`, and of the folder of the one-to-one chat of each person of a watch list, named as the watch list writes them, as `one-to-one/the lending analyst/`: these are their messages, and these folders are the only ones of chat you look into whole. A folder that is not there holds nothing for this collect: you do not look for it under another name. Then search the content of the files under `one-to-one/` for each keyword, as for mail, with a search that answers with the names of the files holding it and shows nothing of the others: the messages it names are matches too, and the others stay closed. A search that the connector's `verified.searches` gives as `false` is not made, and never replaced by a wider one: what only it would find stays unread, and you tell the PO which search was not made, in one line.
3. What the searches returned are the matches. For each one, keep what finds it again and when it is dated: through a connector, its identifier and its time as the connector's answer gives them; in a folder, the path the search gave and the date in the lines that open the file, up to the first empty line. You open no match whole yet, and never a file of a source through a pattern or a loop over its folder, as `exports/tracker/*` or `exports/chat/*`: that opens what no watch list matched.

Whatever no search returned stays closed, in a folder of two files as in a mailbox of thousands: you do not list it, open it or mention it. It is the PO's own mail, another team's ticket or a private chat, and nothing of it reaches the proposal or your answer.

Done when you hold, for each match, what finds it again and its date, and have opened nothing else in the source.

## 3. Have the register tool choose what to read

1. Write the matches of the source in `state/<source>-matches.json`, as `state/mail-matches.json`, each one once: `[ { "id": "...", "when": "2026-03-10T08:00:00.1234567+01:00", "where": "..." } ]`.
   - `id` names the item and its version, so that the same item is never read twice and a changed one is read again: the identifier the connector gives a mail or a chat message; for a ticket, its key and the time of its last update, as `LOAN-12@2026-03-10T08:00:00+01:00`; in a folder, the path of the file.
   - `when` is its date as the source gives it, to the fraction of a second when it gives one, with its UTC offset: a mail is dated when it was sent, a ticket when it was last updated, a chat message when it was posted.
   - `where` is what finds it again, as step 4 below says.
   - `matched_by` names the entries of the watch lists its searches were for, each as `people: the lending analyst`, `keywords: loan`, `chat_channels: lending squad`, `tracker_projects: LOAN` or `tracker_tickets: LOAN-77`.

   When a source gives no identifier or no date for its matches, it is not covered: tell the PO what it lacks.
2. Run `select <source> state/<source>-matches.json`. It keeps the matches dated from the cutoff of the source on, `state/last-collect.json` giving it, leaves out those already read, sorts them by date, oldest first, and returns the oldest, up to `per_source_cap` of `settings.json`, in `selected`. The matches of a catch-up, dated from its own `from`, come first, marked `"catch_up": true`: one of them may already be in the register, read through another entry, so check before you propose it again. A match dated after this run waits for the next one. A source never read before is read from seven days before this collect: tell the PO so. When more matches remain than the cap, `sources_read` says `"cap_reached": true`: the rest waits for the next collect, and you tell the PO that the cap was reached for this source.
3. Open the matches of `selected`, and only them, each one by what finds it again.
4. An entry added to a watch list is read back seven days without you having to remember it: `apply` names it in the collect state, `select <source>` gives it in `catch_up`, and the collect that read it, once applied, clears it.

## 4. Treat each mail, ticket and chat message read as a note

The routine goes on with what you read as it does with a note, in the order read. Four things differ:

- **What it is about.** The watch list says why you read it. Its content says what it is about: maybe another subject than the one whose watch list matched. When it matters to the PO's work and is about no subject, it goes to `unclassified`, unless it asks for an AI use case: that is a new subject, as "A request for an AI use case" says in the routine.
- **Who "I" is.** In a mail, the person who sent it: the PO in a sent mail. In a chat message, the person who wrote it. A promise the PO makes there is a commitment whose `owner` is `the PO`.
- **Its source.** `where`, in the `source` of a record, names it so that the PO finds it again, and so does the `source` of an unclassified item. The `mode` of the source in `connections.json` decides how, never the kind of item: a mail, a ticket and a chat message alike.
  - `folder`: the path of the file, as you opened it, and nothing else: `exports/mail/sent/rate table.txt`, `exports/tracker/LOAN-12.txt`, `exports/chat/channels/lending squad/2026-02-27 1015 the lending analyst.txt`, `exports/chat/one-to-one/the lending analyst/2026-02-27 1130 the lending analyst.txt`. A chat message read from a folder is a file as a mail or a ticket is: its `where` is that path, even when the file names its channel, its author and its date.
  - `connector`, and only then, as there is no file: the name of the source, then what finds the item there: `tracker: LOAN-12`, `mail: sent to the lending analyst on 2026-02-27, "Rate table"`, or `chat: lending squad, the lending analyst on 2026-02-27 at 10:15`.
- **It is no file of the inbox.** It stays where it is, and `notes_processed` does not name it.

## 5. Say in the proposal how far the source was read

A source read has one entry in `sources_read`, even when it held nothing new: the one `select` returned, copied as it is, as

    { "source": "mail", "cutoff": "2026-02-27T16:45:00+01:00", "items": 50, "cap_reached": true, "cursor_ids": ["..."], "caught_up": ["people: the lending analyst"] }

You never change it: its `cutoff`, `cursor_ids`, `caught_up` and `catch_up` say where the next collect starts, and `apply` keeps them only once the PO's proposal is applied. A proposal dropped or never applied leaves the source where it was, and the next collect reads the same matches again.

A source not covered has no entry there: `sources_not_covered` names it.

Done when `mail`, `tracker` and `chat` are each either read, with what `select` chose, or not covered, with the reason told to the PO.
