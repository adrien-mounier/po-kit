// PROTOTYPE. One fictional day at Example Bank, shared by the three options so that only the
// organisation of the page differs. Times are minutes since midnight.
(function () {
  const late = s => `<b class="late"><svg class="i" aria-hidden="true"><use href="#i-alert"/></svg> ${s}</b>`;
  const soon = s => `<b class="soon">${s}</b>`;
  const id = s => `<span class="id">${s}</span>`;

  window.DAY = {
    date: 'Monday 16 November',
    written: '07:12',
    agreed: '09:20',
    start: 570,   // 09:30: the stand-up stretches the day before the working hours
    end: 1080,    // 18:00
    demoNow: 680, // 11:20, used when the page is opened outside the hours of the day
    lede: `<b class="late">Two things are late</b>, the steering deck has to start today, and <b class="late">this week is 2 days short</b>.`,
    register: 'Register at 07:11: 14 subjects, 23 open commitments, 6 open decisions, 5 risks.',

    blocks: [
      { id: 'b-standup', start: 570, end: 585, kind: 'meeting',
        title: 'Stand-up: Mail triage assistant', short: 'Stand-up',
        key: `${late('Your go-live checklist is 2 days late.')} They will ask.`,
        facts: [
          ['Subjects', 'mail-triage'],
          ['Open commitments', `You owe the go-live checklist to the head of operations, <b>2 days late</b> (${id('C-2026-008')}). It is planned at 12:00.`],
          ['Decisions awaited', 'None'],
          ['Worth raising', 'MTA-61, language detection for German mails, has had no update for 34 days']
        ],
        action: { label: 'Brief me', ask: 'Brief me for the 09:30 stand-up on the Mail triage assistant' } },

      { id: 'b-chase', start: 600, end: 615, kind: 'task', pick: 1, bank: 'North Bank',
        title: 'Chase the head of payments for the KYC test dataset', short: 'Chase dataset',
        key: `${late('3 days late.')} The KYC pilot is blocked without it, and Friday&rsquo;s steering committee will ask.`,
        facts: [
          ['Owed by', 'The head of payments, since Wed 11'],
          ['What', '200 anonymised IDs to test the KYC reader'],
          ['Record', `kyc-reader &middot; ${id('C-2026-011')}`]
        ],
        action: { label: 'Draft reminder', ask: 'Draft the reminder for C-2026-011' },
        done: 'I chased the head of payments for C-2026-011 today' },

      { id: 'b-scope', start: 615, end: 660, kind: 'task', bank: 'North Bank',
        title: 'Confirm the KYC reader test scope', short: 'Test scope',
        key: `${soon('Due today')}, to the tech lead. The 11:00 review needs it.`,
        facts: [
          ['For', 'The tech lead'],
          ['Due', 'Today'],
          ['Prepares', 'The 11:00 architecture review'],
          ['Record', `kyc-reader &middot; ${id('C-2026-013')}`]
        ],
        action: { label: 'Draft it', ask: 'Draft the test scope confirmation for C-2026-013' },
        done: 'C-2026-013 is done: I sent the test scope to the tech lead' },

      { id: 'b-arch', start: 660, end: 720, kind: 'meeting', bank: 'North Bank',
        title: 'Architecture review, KYC reader', short: 'Architecture review',
        key: 'The hosting decision lacks its cost estimate: it cannot be taken today.',
        facts: [
          ['With', 'The architect, the tech lead'],
          ['Subjects', 'kyc-reader'],
          ['Open commitments', `<ul><li>You owe the test scope to the tech lead, due today (${id('C-2026-013')})</li><li>The architect owes the hosting options, due Wed 18 (${id('C-2026-009')})</li></ul>`],
          ['Decisions awaited', `Hosting: on-premise or the group cloud (${id('D-2026-005')})`],
          ['Missing to decide', '<b>The architect&rsquo;s cost estimate; the security team&rsquo;s view on the group cloud</b>']
        ],
        action: { label: 'Brief me', ask: 'Brief me for the 11:00 architecture review of the KYC document reader' } },

      { id: 'b-replies', start: 720, end: 750, kind: 'bundle',
        title: 'Replies and nudges', short: 'Replies',
        key: `3 short things. ${late('The first is 2 days late.')}`,
        items: [
          { title: 'Send the go-live checklist', who: 'to the head of operations', state: late('2 days late'), ref: 'C-2026-008',
            action: { label: 'Draft it', ask: 'Draft the email sending the go-live checklist for C-2026-008' } },
          { title: 'Nudge the architect for the hosting options', who: 'due Wed 18, no sign of progress', ref: 'C-2026-009',
            action: { label: 'Nudge', ask: 'Draft a nudge to the architect for C-2026-009, due Wed 18' } },
          { title: 'Classify the Alpine Bank mail on pilot pricing', who: 'from the COO office, no subject yet',
            action: { label: 'Classify', ask: 'Help me classify the Alpine Bank mail about Mail triage pilot pricing' } }
        ],
        done: 'The three replies and nudges of 12:00 are done' },

      { id: 'b-lunch', start: 750, end: 810, kind: 'break', title: 'Lunch', short: 'Lunch' },

      { id: 'b-prep', start: 810, end: 840, kind: 'task', pick: 3, bank: 'Harbour Bank',
        title: 'Prepare the 14:00 with Harbour Bank', short: 'Prepare',
        key: 'They will ask for the pilot scope, which the sponsor has not decided.',
        facts: [
          ['Prepares', 'The 14:00 credit memo pilot check-in'],
          ['Decision awaited', `Pilot scope: corporate loans only, or SME too (${id('D-2026-004')}), from the sponsor`],
          ['You owe them', `The pilot timeline, due Wed 18 (${id('C-2026-012')})`]
        ],
        action: { label: 'Brief me', ask: 'Brief me for the 14:00 with Harbour Bank' },
        done: 'I am ready for the 14:00 with Harbour Bank' },

      { id: 'b-harbour', start: 840, end: 885, kind: 'meeting', bank: 'Harbour Bank',
        title: 'Credit memo pilot check-in', short: 'Harbour Bank',
        key: 'They will ask for the pilot scope: still undecided.',
        facts: [
          ['With', 'Harbour Bank&rsquo;s credit risk lead, the tech lead'],
          ['Subjects', 'credit-memo'],
          ['Open commitments', `<ul><li>You owe the pilot timeline, due Wed 18 (${id('C-2026-012')})</li><li>Harbour Bank owes 20 anonymised sample memos, due Thu 19 (${id('C-2026-010')})</li></ul>`],
          ['Decisions awaited', `Pilot scope: corporate loans only, or SME too (${id('D-2026-004')}), from the sponsor`],
          ['Missing to decide', `<b>The sponsor&rsquo;s position; the data residency risk on the sample memos is still open (${id('R-2026-003')})</b>`]
        ],
        action: { label: 'Brief me', ask: 'Brief me for the 14:00 with Harbour Bank' } },

      { id: 'b-deck', start: 885, end: 990, kind: 'task', pick: 2,
        title: 'Start the steering committee deck', short: 'Steering deck',
        key: `${soon('Today is the latest start')}: due Thursday, 2 days of work, not started.`,
        facts: [
          ['For', 'The sponsor'],
          ['Due', 'Thu 19'],
          ['Effort', '2 days, adjusted &times;1.4 from past steering packs'],
          ['Today', '2 h 45 of it, in two blocks: now and at 17:00'],
          ['Record', `steering-q4 &middot; ${id('C-2026-014')}`]
        ],
        action: { label: 'Outline it', ask: 'Draft an outline of the steering committee deck for C-2026-014' },
        done: 'I started the steering committee deck, C-2026-014' },

      { id: 'b-sponsor', start: 990, end: 1020, kind: 'meeting',
        title: '1:1 with the sponsor', short: 'Sponsor',
        key: 'Ask for the pilot scope decision, needed by Friday.',
        facts: [
          ['Subjects', 'steering-q4, credit-memo, ai-act'],
          ['Open commitments', `You owe the steering committee deck, due Thu 19 (${id('C-2026-014')})`],
          ['Decisions awaited', `<ul><li>From the sponsor: pilot scope for credit memo drafting (${id('D-2026-004')}), needed by Friday</li><li>From you: AI Act risk classification of credit memo drafting (${id('D-2026-007')}), due Wed 18</li></ul>`],
          ['Missing to decide', '<b>Your draft classification proposal: it did not fit today, see Not today</b>']
        ],
        action: { label: 'Brief me', ask: 'Brief me for the 16:30 with the sponsor' } },

      { id: 'b-deck2', start: 1020, end: 1080, kind: 'task',
        title: 'Steering committee deck, continued', short: 'Deck, continued',
        key: 'One more hour, with what the sponsor just said about the pilot scope.',
        facts: [
          ['For', 'The sponsor'],
          ['Due', 'Thu 19'],
          ['Record', `steering-q4 &middot; ${id('C-2026-014')}`]
        ],
        action: { label: 'Where am I', ask: 'Show where I am on the steering committee deck, C-2026-014' },
        done: 'I worked 2 h 45 on the steering committee deck today, C-2026-014' }
    ],

    notToday: [
      { title: 'Draft the AI Act classification proposal', why: 'About 1 h, due Wed 18. Proposed for tomorrow, 10:00.', ref: 'D-2026-007' },
      { title: 'Scoring grid, Q1 portfolio', why: '2 days left of 3. Start by Wed 18.', ref: 'C-2026-016' },
      { title: 'Acceptance criteria for MTA-88', why: 'Before Thursday&rsquo;s refinement.', ref: 'MTA-88' }
    ],

    pending: {
      you: {
        title: 'Waiting on you',
        count: `<b class="late">1 late</b>, <b class="soon">1 due today</b>, 3 this week`,
        rows: [
          { state: 'late', when: 'Thu 12', lag: '2 days late', title: 'Send the go-live checklist', who: 'to the head of operations', ref: 'mail-triage &middot; C-2026-008', planned: 'b-replies' },
          { state: 'soon', when: 'Today', title: 'Confirm the KYC reader test scope', bank: 'North Bank', who: 'to the tech lead', ref: 'kyc-reader &middot; C-2026-013', planned: 'b-scope' },
          { when: 'Wed 18', title: 'Send the pilot timeline', bank: 'Harbour Bank', who: 'to the credit risk lead', ref: 'credit-memo &middot; C-2026-012',
            action: { label: 'Draft it', ask: 'Draft the pilot timeline for C-2026-012' } },
          { when: 'Wed 18', kind: 'Decision', title: 'AI Act classification, credit memo drafting', bank: 'Harbour Bank', who: 'for the compliance officer', ref: 'ai-act &middot; D-2026-007',
            action: { label: 'Draft proposal', ask: 'Draft my AI Act classification proposal for D-2026-007' } },
          { when: 'Thu 19', title: 'Steering committee deck', who: 'to the sponsor', ref: 'steering-q4 &middot; C-2026-014', planned: 'b-deck' }
        ],
        note: { text: 'Messages awaiting your reply: none in mail. <b>Chat was not read this morning</b>, the connector failed: questions asked there are missing from this page.',
          action: { label: 'Retry chat', ask: 'Retry the chat collect and list the chat messages awaiting my reply' } }
      },
      them: {
        title: 'You are waiting on',
        count: `<b class="late">1 late</b>, 3 this week`,
        rows: [
          { state: 'late', when: 'Wed 11', lag: '3 days late', title: 'KYC test dataset (200 anonymised IDs)', bank: 'North Bank', who: 'from the head of payments', ref: 'kyc-reader &middot; C-2026-011', planned: 'b-chase', plannedLabel: 'Chase planned 10:00' },
          { when: 'Wed 18', title: 'Hosting options for the KYC reader', bank: 'North Bank', who: 'from the architect', ref: 'kyc-reader &middot; C-2026-009', planned: 'b-replies', plannedLabel: 'Nudge planned 12:00' },
          { when: 'Thu 19', title: '20 anonymised sample credit memos', bank: 'Harbour Bank', who: 'from the credit risk lead', ref: 'credit-memo &middot; C-2026-010',
            action: { label: 'Nudge', ask: "Draft a nudge to Harbour Bank's credit risk lead for C-2026-010, due Thu 19" } },
          { when: 'Fri 20', kind: 'Decision', title: 'Pilot scope: corporate only, or SME too', bank: 'Harbour Bank', who: 'from the sponsor, asked 4 Nov', ref: 'credit-memo &middot; D-2026-004', planned: 'b-sponsor', plannedLabel: 'To raise at 16:30' },
          { when: 'Fri 27', kind: 'Decision', title: 'Hosting: on-premise or the group cloud', bank: 'North Bank', who: 'from the architect', ref: 'kyc-reader &middot; D-2026-005',
            action: { label: 'What&rsquo;s missing', ask: 'Show what D-2026-005 is still waiting for' } }
        ]
      },
      week: {
        title: 'This week&rsquo;s load',
        count: `<b class="late">2 days of work do not fit</b>`,
        caption: 'Steering committee on Fri 20: <b>4 days of work, 2 days free.</b> One square is half a day free of meetings.',
        days: [
          { d: 'Today', sq: ['p'], today: true }, { d: 'Tue 17', sq: ['p'] }, { d: 'Wed 18', sq: ['p'] },
          { d: 'Thu 19', sq: [] }, { d: 'Fri 20', sq: ['p'] }, { d: 'Does not fit', sq: ['x', 'x', 'x', 'x'], over: true }
        ],
        next: 'Next week: 2 days of work, 4 days free. 2 days still open.',
        suggest: 'Start the steering deck today as planned, or ask to move the scoring grid (C-2026-016) to Fri 27.',
        actions: [
          { label: 'Block time', ask: 'Block time for the steering committee deck C-2026-014 in my free slots this week' },
          { label: 'Ask to move', ask: 'Draft a request to move C-2026-016 to Fri 27' }
        ],
        start: [
          { state: 'soon', when: 'Today', title: 'Steering committee deck', who: '2 days, due Thu 19, not started', planned: 'b-deck' },
          { when: 'Wed 18', title: 'Scoring grid, Q1 portfolio', who: '2 days left, due Tue 24, started',
            action: { label: 'Where am I', ask: 'Show where I am on the use-case scoring grid, C-2026-016' } },
          { when: 'Mon 23', title: 'DPIA input, mail triage', who: '2 days, due Thu 26, not started',
            action: { label: 'What it needs', ask: 'Tell me what the DPIA input for the Mail triage assistant needs, C-2026-017' } }
        ]
      },
      backlog: {
        title: 'Backlog alerts',
        count: `<b class="late">1 contradicts a decision</b>, 2 not ready for Thursday, 1 stale`,
        rows: [
          { state: 'late', when: 'KYC-142', title: 'Keep full ID scans for model retraining', bank: 'North Bank', who: 'against D-2026-002: masked images only',
            action: { label: 'Show conflict', ask: 'Show the tickets that contradict D-2026-002' } },
          { when: 'MTA-88', title: 'Route mails to shared mailboxes', who: 'not ready: no acceptance criteria',
            action: { label: 'Draft criteria', ask: 'Draft acceptance criteria for MTA-88' } },
          { when: 'CMD-31', title: 'Credit memo template', bank: 'Harbour Bank', who: 'not ready: no estimate, no owner',
            action: { label: 'What it needs', ask: "List what CMD-31 needs before Thursday's refinement" } },
          { when: 'MTA-61', title: 'Language detection for German mails', who: 'stale: no update for 34 days',
            action: { label: 'Close or keep', ask: 'Show the history of MTA-61 and suggest whether to close it' } }
        ]
      },
      sort: {
        title: 'To sort',
        count: '1 proposal waiting for your yes, 2 unclassified, 1 stale subject',
        rows: [
          { when: 'Proposal', title: 'New commitment: architect&rsquo;s hosting cost estimate, Fri 20', who: 'from Thursday&rsquo;s mail',
            action: { label: 'Say yes', ask: "Yes to the collect proposal: add the architect's hosting cost estimate as a commitment due Fri 20" } },
          { when: 'Mail', title: 'Pricing question about the Mail triage pilot', bank: 'Alpine Bank', who: 'from the COO office', planned: 'b-replies' },
          { when: 'OPS-907', title: 'Shared mailbox quota increase', who: 'ticket, raised by IT operations',
            action: { label: 'Classify', ask: 'Help me classify ticket OPS-907' } },
          { when: '21 days', title: 'alpine-onboarding', bank: 'Alpine Bank', who: 'stale subject: no update since 26 Oct',
            action: { label: 'What&rsquo;s open', ask: 'Show what is still open on alpine-onboarding' } }
        ]
      }
    }
  };
})();
