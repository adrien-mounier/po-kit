// PROTOTYPE. Une semaine fictive à Example Bank, partagée par les trois options pour que seule
// la façon d'ouvrir le détail d'un sujet diffère. « Mémo de crédit » est chargé exprès, et
// « Tableau de bord qualité » presque vide, pour voir comment le détail tient les deux.
(function () {
  const id = s => ` <span class="id">${s}</span>`;
  window.WEEK = {
    period: 'Du mardi 17 au lundi 23 novembre 2026',
    foot: 'Semaine du mar. 17 au lun. 23 nov. 2026 · registre au 24 nov. 2026, 08:40 · chat lu en partie',
    deck: 'Point hebdomadaire · Example Bank',
    words: { done: 'Étape franchie', adv: 'En cours', new: 'Nouveau', def: 'Reporté', none: 'Sans changement' },
    later: '3 sujets prévus pour plus tard : Signature électronique, Aide à la conformité, Résumé d\'appels.',

    subjects: [
      { key: 'onboarding', name: 'Onboarding mobile', bank: 'Toutes les banques', mv: 'done',
        line: 'Le scan de pièce d\'identité est livré en recette', date: '27 nov.',
        week: [
          { t: 'Scan de pièce d\'identité livré en recette.' + id('C-2026-003') },
          { t: 'Recette démarrée avec deux conseillers, selon le tech lead.' + id('C-2026-018') }
        ],
        next: [{ t: 'Test en agence pilote', sub: 'À partir du 27 novembre, une fois les agences choisies' }],
        decisions: [{ t: 'Choisir les agences pilotes' + id('D-2026-002'), sub: 'Pour le 27 nov. · Sans décision : le test en agence glisse à janvier.' }],
        progress: [{ t: 'Parcours de signature', sub: 'Le tech lead · 3 déc.' }],
        value: [{ name: 'Délai d\'ouverture de compte' + id('B-2026-001'), from: '9 jours', to: '2 jours', now: '4 jours', when: 'mesuré le 18 nov.', pct: 71 }] },

      { key: 'memo', name: 'Mémo de crédit', bank: 'Harbour Bank', mv: 'done', blocked: true,
        line: 'Périmètre du pilote arrêté : deux équipes crédit', date: '1 déc.',
        week: [
          { t: 'Périmètre du pilote arrêté : deux équipes crédit, prêts aux entreprises seulement.' + id('D-2026-004') },
          { t: 'Relance du tech lead pour les comptes de test, faite le 24.' + id('C-2026-005') },
          { t: 'Vingt mémos anonymisés reçus de Harbour Bank.' + id('C-2026-010') },
          { t: 'Calendrier du pilote envoyé au responsable risque crédit.' + id('C-2026-012') },
          { t: 'Risque de résidence des données rouvert, selon le responsable conformité.' + id('R-2026-003') },
          { t: 'Modèle de mémo validé par les deux équipes.' + id('C-2026-015') },
          { t: 'Classement AI Act proposé : risque limité.' + id('D-2026-007') }
        ],
        next: [{ t: 'Ouvrir les comptes de test, puis lancer le pilote', sub: 'À partir du 1er décembre, avec les deux équipes crédit' }],
        blocks: [
          { t: 'Comptes de test : 3 jours de retard' + id('C-2026-005'), sub: 'Le tech lead · dus le 20 nov.' },
          { t: 'Avis sur la résidence des données' + id('R-2026-003'), sub: 'Le responsable conformité · sans date' }
        ],
        decisions: [
          { t: 'Valider le classement AI Act du mémo de crédit' + id('D-2026-007'), sub: 'Pour le 28 nov. · Sans décision : le pilote n\'ouvre pas aux équipes.' },
          { t: 'Retenir l\'hébergement : sur site ou cloud du groupe' + id('D-2026-005'), sub: 'Sans date fixée · Sans décision : le coût du pilote reste inconnu.' }
        ],
        progress: [
          { t: 'Revue sécurité' + id('C-2026-006'), sub: 'L\'architecte · 4 déc.' },
          { t: 'Estimation du coût d\'hébergement' + id('C-2026-019'), sub: 'L\'architecte · 27 nov.' },
          { t: 'Formation des deux équipes crédit', sub: 'Le responsable risque crédit · 2 déc.' },
          { t: 'Jeu de test élargi à cinquante mémos', sub: 'Le tech lead · 5 déc.' },
          { t: 'Note de cadrage pour le comité de pilotage', sub: 'Le PO · 9 déc.' }
        ],
        value: [
          { name: 'Mémos relus sans correction' + id('B-2026-004'), from: '40 %', to: '80 %', now: '55 %', when: 'mesuré le 20 nov.', pct: 37 },
          { name: 'Temps de rédaction d\'un mémo' + id('B-2026-003'), from: '3 h', to: '1 h', now: null }
        ] },

      { key: 'litiges', name: 'Litiges carte', bank: 'North Bank', mv: 'new',
        line: 'Demande reçue, fiche d\'entrée rédigée', date: '26 nov.',
        week: [
          { t: 'Demande d\'un assistant pour les litiges carte reçue de North Bank.' + id('card-disputes') },
          { t: 'Fiche d\'entrée rédigée, en attente de revue.' }
        ],
        next: [{ t: 'Revue d\'entrée', sub: 'Jeudi 26 novembre' }],
        decisions: [{ t: 'Arbitrer la priorité entre Litiges carte et Assistant conseiller' + id('D-2026-008'), sub: 'Sans date fixée · Sans décision : les deux sujets se partagent la même équipe en décembre.' }] },

      { key: 'agence', name: 'Recherche d\'agence', bank: 'Toutes les banques', mv: 'adv',
        line: 'Maquettes en cours de validation, selon le tech lead', date: '2 déc.',
        week: [{ t: 'Maquettes présentées aux deux banques, en cours de validation, selon le tech lead.' + id('C-2026-007') }],
        next: [{ t: 'Découpage en tickets', sub: 'À partir du 2 décembre' }],
        progress: [{ t: 'Validation des maquettes' + id('C-2026-007'), sub: 'Le tech lead · 28 nov.' }] },

      { key: 'conseiller', name: 'Assistant conseiller', bank: 'Harbour Bank', mv: 'def',
        line: 'Revue sécurité reportée au 4 décembre', date: '4 déc.',
        week: [{ t: 'Revue sécurité reportée du 25 novembre au 4 décembre : dossier incomplet.' + id('C-2026-006') }],
        next: [{ t: 'Revue sécurité', sub: 'Vendredi 4 décembre' }],
        progress: [{ t: 'Dossier de la revue sécurité' + id('C-2026-006'), sub: 'L\'architecte · 3 déc.' }] },

      { key: 'qualite', name: 'Tableau de bord qualité', bank: 'North Bank', mv: 'none',
        line: 'Rien d\'enregistré cette semaine', date: '',
        week: [], next: [{ t: 'Sans prochaine étape connue' }] }
    ],

    decisions: [
      { when: 'Pour le 27 nov.', t: 'Choisir les agences pilotes de l\'onboarding mobile', cons: 'Le test en agence glisse à janvier.', meta: 'Onboarding mobile' + id('D-2026-002') },
      { when: 'Pour le 28 nov.', t: 'Valider le classement AI Act du mémo de crédit', cons: 'Le pilote n\'ouvre pas aux équipes.', meta: 'Mémo de crédit' + id('D-2026-007') },
      { when: 'Sans date fixée', nodate: true, t: 'Arbitrer la priorité entre Litiges carte et Assistant conseiller', cons: 'Les deux sujets se partagent la même équipe en décembre.', meta: 'Litiges carte, Assistant conseiller' + id('D-2026-008') }
    ],
    blockers: [
      { t: 'Comptes de test', by: 'Le tech lead · bloque Mémo de crédit' + id('C-2026-005'), due: '3 jours de retard', late: true },
      { t: 'Avis sur la résidence des données', by: 'Le responsable conformité · bloque Mémo de crédit' + id('R-2026-003'), due: 'Sans date' }
    ],
    steps: [
      { t: 'Ouvrir les comptes de test du mémo de crédit', res: 'Résultat attendu : les comptes ouverts avant jeudi.', meta: 'Le tech lead · jeudi 26 nov.' + id('C-2026-005'), st: 'agreed' },
      { t: 'Tenir la revue d\'entrée de Litiges carte', res: 'Résultat attendu : une demande acceptée, ou refusée avec son motif.', meta: 'Le PO · jeudi 26 nov.' + id('card-disputes'), st: 'agreed' },
      { t: 'Lancer le test en agence pilote', res: 'Résultat attendu : deux agences équipées. Sous réserve du choix des agences.', meta: 'Sans responsable · sans échéance' + id('D-2026-002'), st: 'proposed' },
      { t: 'Remettre le dossier de la revue sécurité', res: 'Résultat attendu : un dossier complet avant le 4 décembre.', meta: 'L\'architecte · jeudi 3 déc.' + id('C-2026-006'), st: 'proposed' }
    ],
    milestones: [
      { d: '26 nov.', t: 'Revue d\'entrée, Litiges carte' },
      { d: '4 déc.', t: 'Revue sécurité, Assistant conseiller' },
      { d: '11 déc.', t: 'Comité de pilotage' },
      { d: '15 déc.', t: 'Ouverture du pilote, Mémo de crédit' }
    ],
    capacity: 'L\'équipe perd un développeur du 30 novembre au 4 décembre.',
    others: ['Présenter la démarche d\'entrée des demandes au comité de pilotage du 11 décembre.']
  };
})();
