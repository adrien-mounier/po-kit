// PROTOTYPE. What the three options share: the rows of the dashboard, the detail of a subject,
// the three screens that follow, and the keys that walk the subjects.
(function () {
  const W = window.WEEK, WK = window.WK = { subjects: W.subjects };
  const blocked = W.subjects.filter(s => s.blocked).length;

  WK.lede = `${W.period} · ${W.subjects.length} sujets${blocked ? ` · <span class="n-block sign alert">${blocked} point${blocked > 1 ? 's' : ''} bloquant${blocked > 1 ? 's' : ''}</span>` : ''}`;
  WK.cols = `<li class="cols dcols" aria-hidden="true"><span>Sujet</span><span>Cette semaine</span><span>Ce qui a changé</span><span></span><span style="text-align:right">Prochaine étape</span><span></span></li>`;
  WK.pill = s => `<span class="mv ${s.mv}">${W.words[s.mv]}</span>`;
  WK.row = (s, i) => `<button class="subject row${s.mv === 'none' ? ' is-quiet' : ''}" type="button" data-i="${i}" id="row-${s.key}" aria-expanded="false">
      <span class="who"><span class="nm">${s.name}</span><span class="bank">${s.bank}</span></span>
      ${WK.pill(s)}
      <span class="chg">${s.line}</span>
      <span>${s.blocked ? '<span class="flag sign alert">Bloqué</span>' : ''}</span>
      <span class="nextd">${s.date}</span>
      <span class="chev" aria-hidden="true"></span>
    </button>`;
  WK.later = `<p class="later">${W.later}</p>`;
  WK.foot = n => `<footer class="foot"><span>${W.foot}</span><span class="deck">${W.deck}</span><span class="pg">${n} / 4</span></footer>`;

  // A list shows its first three lines; the others open on a click, without script.
  const item = x => `<li>${x.t}${x.sub ? `<span class="sub">${x.sub}</span>` : ''}</li>`;
  const list = (items, n) => {
    const a = items.slice(0, n), b = items.slice(n);
    return `<ul>${a.map(item).join('')}</ul>${b.length ? `<details class="more"><summary>+ ${b.length} autre${b.length > 1 ? 's' : ''}</summary><ul>${b.map(item).join('')}</ul></details>` : ''}`;
  };
  const sec = (cls, label, items, n) => items && items.length ? `<section class="d-sec ${cls}"><p class="label">${label}</p>${list(items, n || 3)}</section>` : '';
  const value = v => `<div class="measure"><p class="m-t">${v.name}</p>${v.now
    ? `<div class="scale"><span class="from">Départ <b>${v.from}</b></span><span class="track"><i style="width:${v.pct}%"></i></span><span class="to">Cible <b>${v.to}</b></span></div><p class="m-v"><b>${v.now}</b> ${v.when}</p>`
    : `<p class="m-v">Départ ${v.from}, cible ${v.to}. Pas encore mesuré.</p>`}</div>`;
  WK.detail = s => `<div class="detail">
      <div class="d-col">
        ${s.week.length ? sec('s-week', 'Cette semaine', s.week, 4) : '<section class="d-sec"><p class="label">Cette semaine</p><p class="none">Rien d\'enregistré sur la période.</p></section>'}
        ${sec('s-next', 'Ensuite', s.next)}
      </div>
      <div class="d-col">
        ${sec('s-blocks', 'Ce qui bloque', s.blocks)}
        ${sec('s-decisions', 'Décisions à prendre', s.decisions)}
        ${sec('s-progress', 'En cours', s.progress)}
        ${s.value ? `<section class="d-sec"><p class="label">Valeur mesurée</p>${s.value.map(value).join('')}</section>` : ''}
      </div>
    </div>`;
  WK.head = s => `<div class="d-head"><h2 class="d-title" id="d-title">${s.name}</h2>${WK.pill(s)}${s.blocked ? '<span class="flag sign alert">Bloqué</span>' : ''}<span class="bank">${s.bank}</span></div>`;
  WK.walk = i => `<p class="walk"><button type="button" data-step="-1"${i === 0 ? ' disabled' : ''}>Précédent</button><span>${i + 1} / ${W.subjects.length}</span><button type="button" data-step="1"${i === W.subjects.length - 1 ? ' disabled' : ''}>Suivant</button></p>`;

  // The three screens after the dashboard: the same in every option.
  WK.rest = () => `
  <section class="slide" id="s2">
    <header class="head"><h2>Décisions à prendre et points bloquants</h2><p class="lede">${W.decisions.length} décisions · ${W.blockers.length} points bloquants</p></header>
    <div class="body decide neutral">
      <ol class="decisions">${W.decisions.map(d => `<li><p class="when${d.nodate ? ' nodate' : ''}">${d.when}</p><h3>${d.t}</h3><p class="cons"><span class="k">Sans décision</span> ${d.cons}</p><p class="meta">${d.meta}</p></li>`).join('')}</ol>
      <div class="deps" style="grid-row:1 / span 2"><p class="label">Points bloquants</p><ul>${W.blockers.map(b => `<li><b>${b.t}</b><span class="by">${b.by}</span><span class="due${b.late ? ' late' : ''}">${b.due}</span></li>`).join('')}</ul></div>
    </div>
    ${WK.foot(2)}
  </section>
  <section class="slide" id="s3">
    <header class="head"><h2>Plan jusqu'à mardi prochain</h2><p class="lede">Du mardi 24 au lundi 30 novembre · des propositions, à valider</p></header>
    <div class="body nextweek">
      <ol class="steps">${W.steps.map(s => `<li><div class="s-main"><h3>${s.t}</h3><p class="res">${s.res}</p><p class="meta">${s.meta}</p></div><span class="st ${s.st}">${s.st === 'agreed' ? 'Convenu' : 'Proposé'}</span></li>`).join('')}</ol>
      <div class="side">
        <div class="miles"><p class="label">Jalons des quatre prochaines semaines</p><ul>${W.milestones.map(m => `<li><b>${m.d}</b><span>${m.t}</span></li>`).join('')}</ul></div>
        <div><p class="label">Capacité de l'équipe</p><p class="q">${W.capacity}</p><cite>Selon le PO</cite></div>
        <div><p class="label">Autres points</p>${W.others.map(o => `<p class="q">${o}</p>`).join('')}<cite>Selon le PO</cite></div>
      </div>
    </div>
    ${WK.foot(3)}
  </section>
  <section class="slide" id="s4">
    <header class="head"><h2>Valeur apportée</h2><p class="lede">Annexe · 3 indicateurs suivis</p></header>
    <div class="body"><ol class="values">
      <li class="cols vcols" aria-hidden="true"><span>Sujet</span><span>Indicateur</span><span>Du départ à la cible</span><span style="text-align:right">Dernière mesure</span></li>
      ${W.subjects.filter(s => s.value).map(s => s.value.map(v => `<li class="value"><div class="who"><h3>${s.name}</h3><span class="bank">${s.bank}</span></div><p class="metric">${v.name}</p><div class="scale"><span class="from">Départ <b>${v.from}</b></span><span class="track"><i style="width:${v.pct || 0}%"></i></span><span class="to">Cible <b>${v.to}</b></span></div><div class="now">${v.now ? `<b>${v.now}</b><span>${v.when}</span>` : '<span class="nothing">Pas encore mesuré</span>'}</div></li>`).join('')).join('')}
    </ol></div>
    ${WK.foot(4)}
  </section>`;

  // The keys: up and down walk the subjects, Enter opens (a row is a button), Escape closes.
  // On the last row, down is left to the browser: it goes on to the next screen.
  WK.keys = o => document.addEventListener('keydown', e => {
    if (e.target.closest && e.target.closest('summary')) return;
    const rows = [].slice.call(document.querySelectorAll('.subject.row')), open = o.current();
    const dir = e.key === 'ArrowDown' || e.key === 'ArrowRight' ? 1 : e.key === 'ArrowUp' || e.key === 'ArrowLeft' ? -1 : 0;
    if (e.key === 'Escape' && open > -1) { e.preventDefault(); o.close(); rows[open].focus(); return; }
    if (!dir) return;
    if (open > -1) { if (W.subjects[open + dir]) { e.preventDefault(); o.open(open + dir); } return; }
    if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') return;
    const at = rows.indexOf(document.activeElement);
    if (at > -1 && rows[at + dir]) { e.preventDefault(); rows[at + dir].focus(); }
  });
})();
