// PROTOTYPE. What the three options share: the clock, the details of a block, the pending groups,
// the top bar and the buttons that copy a request for the agent.
(function () {
  const D = window.DAY;
  const qs = new URLSearchParams(location.search);
  const PK = window.PK = { proposed: qs.get('state') === 'proposed' };
  if (PK.proposed) document.documentElement.classList.add('is-proposed');

  document.body.insertAdjacentHTML('afterbegin', `<svg width="0" height="0" style="position:absolute" aria-hidden="true">
    <symbol id="i-copy" viewBox="0 0 24 24"><rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/></symbol>
    <symbol id="i-check" viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></symbol>
    <symbol id="i-alert" viewBox="0 0 24 24"><path d="M12 3.5l9.5 16.5h-19z"/><path d="M12 10v4.5"/><path d="M12 17.5v.01"/></symbol>
    <symbol id="i-clock" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></symbol>
    <symbol id="i-chev" viewBox="0 0 24 24"><path d="M9.5 6l6 6-6 6"/></symbol>
    <symbol id="i-meet" viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.25"/><path d="M2.75 19.5c.5-3.5 3-5.5 6.25-5.5s5.75 2 6.25 5.5"/><path d="M16 5.5a3.25 3.25 0 0 1 0 6"/><path d="M18.25 14.5c1.75.75 2.75 2.5 3 5"/></symbol>
    <symbol id="i-stack" viewBox="0 0 24 24"><path d="M5 7h14"/><path d="M5 12h14"/><path d="M5 17h9"/></symbol>
    <symbol id="i-x" viewBox="0 0 24 24"><path d="M6 6l12 12"/><path d="M18 6L6 18"/></symbol>
  </svg>`);

  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const icon = PK.icon = n => `<svg class="i" aria-hidden="true"><use href="#i-${n}"/></svg>`;
  const fmt = PK.fmt = m => ('0' + Math.floor(m / 60)).slice(-2) + ':' + ('0' + m % 60).slice(-2);
  PK.dur = m => { const h = Math.floor(m / 60), r = m % 60; return h ? h + ' h' + (r ? ' ' + ('0' + r).slice(-2) : '') : r + ' min'; };
  const btn = PK.btn = (a, cls) => `<button class="btn ${cls || ''}" type="button" data-ask="${esc(a.ask)}">${icon('copy')}<span class="lbl">${a.label}</span></button>`;
  const bank = b => b ? `<span class="bank">${b}</span>` : '';
  PK.pick = n => n ? `<span class="pick" aria-hidden="true">${n}</span><span class="sr">Priority ${n}: </span>` : '';
  PK.kindIcon = b => b.kind === 'meeting' ? icon('meet') : b.kind === 'bundle' ? icon('stack') : '';
  PK.block = id => D.blocks.find(b => b.id === id);
  PK.selectable = D.blocks.filter(b => b.kind !== 'break');

  // The clock: ?now=11:20 fixes it; otherwise the real time, or a sample time outside the hours of the day.
  PK.now = () => {
    const p = qs.get('now');
    if (p) { const a = p.split(':'); return +a[0] * 60 + +a[1]; }
    const d = new Date(), m = d.getHours() * 60 + d.getMinutes();
    return m >= D.start && m < D.end ? m : D.demoNow;
  };
  PK.stateOf = (b, now) => now >= b.end ? 'past' : now >= b.start ? 'now' : 'later';
  // The block to look at: the one running, or the next one when the clock is in a gap or a break.
  PK.current = now => PK.selectable.find(b => now < b.end) || PK.selectable[PK.selectable.length - 1];
  PK.tick = fn => { fn(PK.now()); setInterval(() => fn(PK.now()), 30000); };

  const kindWord = { meeting: 'Meeting', task: 'Task', bundle: 'Short things' };
  PK.detail = (b, now) => {
    const st = PK.stateOf(b, now);
    const pill = st === 'now' ? '<span class="nowpill">Now</span>' : st === 'past' ? '<span class="nowpill quiet">Earlier today</span>'
      : b === PK.current(now) ? '<span class="nowpill quiet">Next</span>' : '';
    const facts = b.facts ? `<dl class="facts">${b.facts.map(f => `<dt>${f[0]}</dt><dd>${f[1]}</dd>`).join('')}</dl>` : '';
    const items = b.items ? `<ol class="items">${b.items.map(i => `<li><span><span class="t">${i.title}</span><span class="who">${i.state ? i.state + ', ' : ''}${i.who}${i.ref ? ` &middot; <span class="id">${i.ref}</span>` : ''}</span></span>${btn(i.action)}</li>`).join('')}</ol>` : '';
    const acts = [];
    if (b.action) acts.push(btn(b.action, 'primary'));
    if (b.kind === 'meeting') acts.push(btn({ label: 'Tell the agent the outcome', ask: `Here is what the ${fmt(b.start)} decided or changed (${b.title}): ` }));
    else {
      acts.push(btn({ label: 'Done, tell the agent', ask: b.done }));
      acts.push(btn({ label: 'Not today', ask: `Take "${b.title}" out of today's plan and tell me where it fits` }, 'plain'));
    }
    return `<h2 class="d-title" id="d-title" tabindex="-1">${PK.pick(b.pick)}${b.title}</h2>
      <p class="d-meta"><span class="when">${fmt(b.start)} to ${fmt(b.end)}</span><span>${kindWord[b.kind]}, ${PK.dur(b.end - b.start)}</span>${bank(b.bank)}${pill}</p>
      ${b.key ? `<p class="d-key">${b.key}</p>` : ''}${facts}${items}
      <div class="d-actions">${acts.join('')}</div>`;
  };

  PK.notToday = () => `<section class="nottoday" aria-labelledby="h-not"><h2 id="h-not">Not today</h2>
    <p>${PK.proposed ? 'The agent found no room for these.' : 'Agreed at the briefing: these wait.'}</p>
    <ul>${D.notToday.map(n => `<li><span class="t">${n.title}</span><span class="why">${n.why} <span class="id">${n.ref}</span></span></li>`).join('')}</ul></section>`;

  const row = r => {
    const b = r.planned && PK.block(r.planned);
    const act = b ? `<a class="planned" href="#${b.id}" data-goto="${b.id}">${icon('clock')}${r.plannedLabel || 'Planned ' + fmt(b.start)}</a>` : r.action ? btn(r.action) : '';
    return `<li class="prow${r.state ? ' is-' + r.state : ''}">
      <span class="when">${r.state === 'late' ? icon('alert') : ''}${r.when}${r.lag ? `<span class="lag">${r.lag}</span>` : ''}</span>
      <span class="what"><span class="t">${r.kind ? `<span class="kind">${r.kind}:</span> ` : ''}${r.title}</span>${bank(r.bank)}<span class="sub"><span>${r.who}</span>${r.ref ? `<span class="ref">${r.ref}</span>` : ''}</span></span>
      <span class="act">${act}</span></li>`;
  };
  const body = (key, g) => {
    if (key !== 'week') return `<ul class="rows">${g.rows.map(row).join('')}</ul>${g.note ? `<p class="note"><span>${icon('alert')} ${g.note.text}</span>${btn(g.note.action)}</p>` : ''}`;
    return `<p class="week-cap">${g.caption}</p>
      <ol class="days">${g.days.map(d => `<li class="${d.today ? 'is-today' : ''}${d.over ? ' over' : ''}"><span class="d">${d.d}</span><span class="sq" aria-hidden="true">${d.sq.map(s => `<i class="${s}"></i>`).join('') || 'none'}</span></li>`).join('')}</ol>
      <p class="suggest"><span><b>Suggestion:</b> ${g.suggest} ${g.next}</span><span class="btns">${g.actions.map(a => btn(a)).join('')}</span></p>
      <h3>To start soon</h3><ul class="rows">${g.start.map(row).join('')}</ul>`;
  };
  // One pending group; fold = true draws it as a group that opens, closed unless open is true.
  PK.group = (key, fold, open) => {
    const g = D.pending[key], h = `<h2 id="h-${key}">${g.title} <span class="count">${g.count}</span></h2>`;
    return fold
      ? `<details class="pg" id="p-${key}"${open ? ' open' : ''}><summary>${icon('chev').replace('class="i"', 'class="i chev"')}${h}</summary>${body(key, g)}</details>`
      : `<section class="pg" id="p-${key}" aria-labelledby="h-${key}">${h}${body(key, g)}</section>`;
  };
  PK.pendingCount = ['you', 'them', 'backlog', 'sort'].reduce((n, k) => n + D.pending[k].rows.length, 0);

  // The top bar and the sentence under it. extra is markup an option adds inside the bar (tabs).
  PK.header = extra => {
    const plan = PK.proposed
      ? `${icon('clock')}<span><b>Plan proposed</b> by the agent at ${D.written}, not agreed yet</span>${btn({ label: 'Start the briefing', ask: "Let's do the briefing" }, 'onbar')}`
      : `${icon('check')}<span><b>Plan agreed</b> at the briefing, ${D.agreed}</span>`;
    document.getElementById('top').innerHTML = `<div class="wrap"><div><h1>${D.date}</h1><p class="plan">${plan}</p></div>
      <p class="sources">${icon('check')} Read: mail, calendar, tracker<span class="fail">${icon('alert')} Not read: Chat, the connector failed</span></p>${extra || ''}</div>`;
  };
  PK.footer = () => `<footer class="wrap"><p>This page changes nothing. Each button copies a request; paste it into the agent&rsquo;s chat. ${D.register} Next brief tomorrow around 07:00.</p></footer><div class="toast" id="toast" role="status" aria-live="polite"></div>`;

  // ---------- Copying a request ----------
  let hideTimer, back;
  const toast = () => document.getElementById('toast');
  function hide() { const t = toast(); if (t.classList.contains('stay')) { t.innerHTML = ''; if (back) back.focus(); } t.classList.remove('show', 'stay'); }
  function say(html, stay) { const t = toast(); t.innerHTML = html; t.classList.add('show'); t.classList.toggle('stay', !!stay); clearTimeout(hideTimer); if (!stay) hideTimer = setTimeout(hide, 3200); }
  function fallbackCopy(text) {
    const ta = document.createElement('textarea'); ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta); ta.select(); let ok = false; try { ok = document.execCommand('copy'); } catch (e) { ok = false; } document.body.removeChild(ta); return ok;
  }
  function done(b, ok) {
    const text = b.dataset.ask;
    if (!ok) { // both copy routes refused: hand the request over in a field until it is closed
      back = b;
      say(`<label for="req">Could not copy. Copy the request by hand:</label><input id="req" readonly value="${esc(text)}"><button type="button" id="req-close">Close</button>`, true);
      const f = document.getElementById('req'); f.focus(); f.select();
      document.getElementById('req-close').addEventListener('click', hide);
      return;
    }
    const lbl = b.querySelector('.lbl'), use = b.querySelector('use');
    if (!b.dataset.label) b.dataset.label = lbl.textContent;
    b.style.minWidth = b.offsetWidth + 'px';
    lbl.textContent = 'Copied'; use.setAttribute('href', '#i-check'); b.classList.add('copied');
    say(`Copied <q>${esc(text)}</q>. Paste it into the agent&rsquo;s chat.`);
    clearTimeout(b._t);
    b._t = setTimeout(() => { lbl.textContent = b.dataset.label; use.setAttribute('href', '#i-copy'); b.classList.remove('copied'); }, 1600);
  }
  document.addEventListener('keydown', e => { if (e.key === 'Escape' && toast() && toast().classList.contains('stay')) hide(); });
  document.addEventListener('click', e => {
    const go = e.target.closest('[data-goto]');
    if (go) { e.preventDefault(); if (PK.onGoto) PK.onGoto(go.dataset.goto); return; }
    const b = e.target.closest('[data-ask]');
    if (!b) return;
    b.title = 'Copies the request: ' + b.dataset.ask;
    const text = b.dataset.ask;
    if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(text).then(() => done(b, true), () => done(b, fallbackCopy(text)));
    else done(b, fallbackCopy(text));
  });
})();
