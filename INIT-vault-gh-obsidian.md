# INIT-vault-gh-obsidian.md

> **Recette d'initialisation d'un vault Obsidian « second brain » (méthode PARA), versionné sur GitHub, piloté par Claude Code.**
>
> **Usage :** déposer ce fichier seul dans un dossier vide (ou utiliser `init-vault.sh`), lancer Claude Code dans ce dossier, et demander : *« Lis INIT-vault-gh-obsidian.md et exécute l'initialisation. »*
>
> Ce fichier est **consommé une seule fois**. Il génère tous les autres fichiers du vault — y compris le `CLAUDE.md` permanent — puis se retire (phase 4). Il est réutilisable tel quel sur n'importe quelle machine : les paramètres sont demandés à l'exécution, rien à éditer.

---

## Paramètres

<!-- Rempli par init-vault.sh. Une clé sans valeur est demandée en Phase 1. -->
- Contexte :
- Dépôt GitHub :
- Compte GitHub :
- Chemin du vault :

---

## Phase 1 — Paramétrage (questions à poser à l'utilisateur)

Avant de créer quoi que ce soit, poser ces questions et attendre les réponses :

1. **Contexte** : `PERSO` ou `PRO` ?
2. **Nom du dépôt GitHub privé** à créer (ex. `vault-perso`, `vault-pro`) ?
3. **Compte/organisation GitHub** cible ? → Vérifier avec `gh auth status` que le CLI est authentifié sur le bon compte **avant** de créer le dépôt. En contexte `PRO`, faire confirmer explicitement que ce compte est autorisé pour du contenu de travail.
4. **Qui es-tu et comment travailles-tu ?** → 2-3 phrases libres : métier/contexte, façon de raisonner, préférences de collaboration avec un agent (ex. « propose avant d'exécuter », « va droit au but »). Elles alimenteront la section « L'utilisateur » de l'AGENTS.md.

Règles fixes, non négociables (ne pas demander) :
- Dépôt **privé**, **isolé** : aucun remote, sous-module ou lien vers un autre vault.
- Vault **desktop uniquement** : aucune sync automatique, aucun usage mobile.
- Langue des notes : **français**.

---

## Phase 2 — Génération des fichiers

Créer l'arborescence et les fichiers suivants, dans cet ordre.

### 2.1 Arborescence

```
vault/
├── CLAUDE.md            # pointeur vers AGENTS.md (§2.3)
├── AGENTS.md            # mémoire permanente de l'agent (§2.4)
├── .gitignore           # §2.2
├── 0-inbox/
│   └── bienvenue.md     # §2.7
├── 1-projects/          # 1 sous-dossier par projet, chacun avec index.md
├── 2-areas/
├── 3-resources/
├── 4-archives/
├── _bases/              # vues .base (§2.6)
│   ├── projets-actifs.base
│   ├── inbox-a-trier.base
│   └── revue.base
├── _dashboards/
│   └── dashboard.md     # agrégat régénéré par l'agent (§2.8)
├── _templates/          # §2.5
│   ├── projet.md
│   ├── note.md
│   └── revue-hebdo.md
└── _assets/             # images, pièces jointes
```

Ajouter un `.gitkeep` dans chaque dossier vide.

### 2.2 `.gitignore` (contenu exact)

```gitignore
# Config Obsidian ignorée par défaut
.obsidian/*

# ... sauf ce qu'on veut retrouver en clonant :
!.obsidian/app.json
!.obsidian/appearance.json
!.obsidian/core-plugins.json
!.obsidian/community-plugins.json

# Jamais versionné : état d'interface volatile
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash/
.DS_Store
```

### 2.3 `CLAUDE.md` (contenu exact — volontairement minimal)

```markdown
# CLAUDE.md

Lis `AGENTS.md` et applique-le intégralement. C'est la mémoire permanente
de ce vault : conventions, structure, règles et leçons apprises.
```

> Pourquoi ce détour : `AGENTS.md` contient tout le réel. `CLAUDE.md` n'est
> qu'un pointeur, ce qui rend le vault portable vers n'importe quel autre
> agent (Codex, etc.) au coût d'une ligne.

### 2.4 `AGENTS.md` (générer à partir de ce gabarit)

Adapter les mentions `{{CONTEXTE}}` selon la réponse de la Phase 1.
En contexte `PRO`, ajouter dans « Règles dures » : *« Jamais de données
client nominatives ni de secrets de mandat dans le vault. »*

```markdown
# AGENTS.md — mémoire permanente du vault {{CONTEXTE}}

## Ce qu'est ce vault

Second brain en Markdown plat, organisé par la méthode PARA, versionné sur
un dépôt GitHub privé et isolé. Desktop uniquement, pas de sync automatique.

## L'utilisateur

{{PROFIL_UTILISATEUR — rédigé depuis les réponses de la Phase 1 :
qui il est, comment il raisonne, comment collaborer avec lui.}}

## Principes non négociables

1. **Markdown pur, zéro lock-in.** Tout doit rester lisible sans Obsidian.
2. **Classement par actionnabilité, jamais par sujet.**
3. **Notes atomiques et liées** par [[wikilinks]].
4. **On ne supprime pas, on archive** dans `4-archives/`.
5. **Isolation stricte** : ne jamais référencer, cloner ou lier un autre vault.
6. **La base ne doit jamais pourrir** : toute information est soit un
   événement, soit un état (voir « Ingestion »), et un état périmé se
   remplace au moment où on l'apprend — jamais « plus tard ».

## Structure et tests de classement

| Dossier | Test (dans l'ordre) |
|---|---|
| `1-projects/` | Il y a un livrable ou une deadline ? |
| `2-areas/` | C'est un standard à maintenir dans le temps ? |
| `3-resources/` | Intéressant mais sans engagement ? |
| `4-archives/` | Plus aucune action prévue ? |

Autres dossiers : `0-inbox/` (capture brute), `_bases/` (vues),
`_dashboards/` (agrégats), `_templates/`, `_assets/`.
Les notes bougent entre catégories ; l'arborescence de premier niveau, jamais.

## Ingestion : état ou événement (à trancher à CHAQUE entrée)

Avant d'écrire une information dans le vault, répondre à cette question —
c'est un processus imposé, pas une consigne vague :

- **Événement** — quelque chose s'est produit (décision prise, livrable
  envoyé, réunion tenue). → **Ajouter** une ligne datée `YYYY-MM-DD` dans
  le `## Journal` de la note concernée. Un événement ne périme jamais.
- **État** — quelque chose est vrai maintenant (un tarif, un statut, une
  deadline, une architecture retenue). → **Remplacer** l'ancienne valeur
  dans le bloc `## État courant` de la note concernée, avec sa date de
  mise à jour : `- Tarif : X *(maj YYYY-MM-DD)*`. Un état vit à
  **un seul endroit** ; l'historique des valeurs, c'est Git qui le garde.
  La date permet à l'audit de repérer les états dormants.

Corollaires :
- Ne jamais accoler un nouvel état à côté de l'ancien « pour mémoire ».
- Si une information contredit un état existant ailleurs (dashboard,
  autre note), corriger l'autre occurrence dans la même session ou la
  signaler explicitement à l'utilisateur.
- Le dashboard n'est **jamais** une source de vérité : il est régénéré
  depuis les notes, pas l'inverse.

## Conventions de notes

- Frontmatter obligatoire hors inbox :
  `type` (projet|area|ressource|note), `statut` (actif|pause|livré|archivé,
  projets uniquement), `créé` (YYYY-MM-DD), `tags` ([]).
- Nommage kebab-case, descriptif, sans date dans le nom de fichier.
- Une idée = une note ; scinder au-delà de ~300 lignes ou deux idées.
- Toute nouvelle note est créée **depuis le template correspondant**
  de `_templates/` — jamais de structure improvisée.
- Chaque projet a un `index.md` : Objectif, Contraintes, Définition du
  terminé, État courant, Journal, Prochaines étapes, Notes liées.
- **Reprendre un projet** = charger son `index.md` (État courant + Journal),
  jamais se fier à la mémoire d'une conversation précédente. L'index doit
  donc toujours suffire à reprendre le travail après des semaines.

## Lire le vault sans tout parcourir (règle de contexte)

Ne jamais parcourir le vault à l'aveugle. Dans l'ordre :

1. **Obsidian CLI** (officiel, Obsidian ≥ 1.12, CLI activé dans
   Réglages → Général). L'app se lance en arrière-plan si besoin.
   Commandes utiles :
   - `obsidian base:query path="_bases/projets-actifs.base" format=json`
     → l'état des projets sans lire un seul index.md
   - `obsidian search query="..." format=json limit=10`
   - `obsidian backlinks file="Nom de note"`
   - `obsidian property:search name="statut" value="actif"`
   - `obsidian unresolved` → liens morts (utile en revue hebdo)
2. **Fallback sans CLI** : lire `_dashboards/dashboard.md` (agrégat
   régénéré en fin de session), jamais les dossiers entiers.
3. La lecture complète d'un dossier n'est permise que sur demande explicite.

## Fin de session (rituel de l'agent)

1. Régénérer `_dashboards/dashboard.md` (voir sa structure en tête du fichier).
2. Proposer un commit : message court, français, au présent
   (`ajoute notes projet X`, `archive projet Y`, `revue hebdo`).
3. **Rétrospective** : si l'utilisateur a corrigé l'agent pendant la session,
   proposer un diff sur ce fichier — une ligne dans « Leçons apprises » si la
   correction vaut pour tout le vault, ou une mise à jour du template/de la
   note concernée si elle est spécifique. L'utilisateur valide chaque diff.

## Audit anti-pourrissement (à la revue hebdo, sur demande)

Quand l'utilisateur lance la revue hebdo, proposer un audit :

1. Repérer les **états dupliqués ou contradictoires** entre notes,
   dashboard et journaux (mêmes grandeurs, valeurs différentes).
2. Repérer les états dont la date *(maj ...)* est ancienne dans des
   projets actifs — un état dormant est un état suspect.
3. **S'arrêter là** : présenter la liste des corrections proposées sous
   forme de diffs. Ne rien modifier sans validation explicite — un outil
   qui nettoie une base doit s'arrêter avant d'effacer, pas après.

## Règles dures

- Ne jamais supprimer une note — toujours archiver.
- Ne jamais réorganiser l'arborescence de premier niveau.
- Ne jamais ajouter de sync automatique, hook, CI ou tâche planifiée sans
  demande explicite.
- Jamais de token, secret ou credential dans le vault, même dans une note.
- Ne jamais référencer un autre vault.

## Leçons apprises

> Une ligne par leçon, datée. Ajoutée uniquement via le rituel de
> rétrospective, avec validation de l'utilisateur.

- (vide pour l'instant)
```

### 2.5 Templates (`_templates/`)

**`projet.md` :**

```markdown
---
type: projet
statut: actif
créé: {{date}}
tags: []
---

# {{titre}}

## Objectif

## Contraintes

## Définition du terminé
<!-- Critères vérifiables. Sans eux, le résultat sera générique. -->
- [ ]

## État courant
<!-- CE QUI EST VRAI MAINTENANT. On REMPLACE, on n'empile pas — chaque
     ligne porte sa date de maj. L'historique des valeurs vit dans Git. -->
- Statut : actif *(maj {{date}})*
- Prochaine échéance : *(maj {{date}})*

## Journal
<!-- CE QUI S'EST PRODUIT. Lignes datées, on AJOUTE, jamais modifié. -->
- {{date}} — création du projet

## Prochaines étapes
- [ ]

## Notes liées
```

**`note.md` :**

```markdown
---
type: note
créé: {{date}}
tags: []
---

# {{titre}}
```

**`revue-hebdo.md` :**

```markdown
---
type: note
créé: {{date}}
tags: [revue]
---

# Revue hebdo — {{date}}

- [ ] Inbox vidée (classer en P/A/R ou supprimer)
- [ ] Statuts des projets à jour
- [ ] Projets terminés archivés (dossier complet → 4-archives/)
- [ ] Audit anti-pourrissement : états contradictoires ou périmés traités
- [ ] `obsidian unresolved` : liens morts traités
- [ ] Dashboard régénéré
```

### 2.6 Vues `_bases/` (syntaxe Bases, YAML)

**`projets-actifs.base` :**

```yaml
views:
  - type: table
    name: Projets actifs
    filters:
      and:
        - file.inFolder("1-projects")
        - statut == "actif"
    order:
      - file.name
      - statut
      - créé
```

**`inbox-a-trier.base` :**

```yaml
views:
  - type: table
    name: Inbox à trier
    filters:
      and:
        - file.inFolder("0-inbox")
    order:
      - file.name
      - file.ctime
```

**`revue.base` :**

```yaml
views:
  - type: table
    name: En pause ou dormant
    filters:
      and:
        - file.inFolder("1-projects")
        - statut == "pause"
    order:
      - file.name
      - file.mtime
```

> Après création, demander à l'utilisateur d'ouvrir chaque `.base` dans
> Obsidian une fois pour valider la syntaxe (le format évolue encore) et
> corriger si l'app signale une erreur.

### 2.7 `0-inbox/bienvenue.md`

Une courte note (la rédiger) expliquant le premier geste : toute idée se
capture ici sans réfléchir au classement ; le tri se fait à la revue hebdo.

### 2.8 `_dashboards/dashboard.md`

Créer le fichier avec, en commentaire HTML en tête, sa règle de régénération :
il est **écrit par l'agent, jamais à la main**, en fin de session, **depuis
les notes** (jamais l'inverse — le dashboard n'est pas une source de vérité).
Structure :

```markdown
<!-- Régénéré par l'agent en fin de session, depuis les notes.
     Jamais édité à la main. Jamais source de vérité. -->
# Dashboard — {{date de régénération}}

## Projets actifs
| Projet | Statut | Prochaine étape |
|---|---|---|

## Inbox
{{nombre de notes en attente}} note(s) à trier.

## Signaux
<!-- projets en pause depuis longtemps, liens morts, inbox > 15 notes,
     états contradictoires repérés -->
```

Le remplir une première fois (vide mais structuré).

---

## Phase 3 — Git & GitHub

1. `git init` puis premier commit : `initialise le vault (structure PARA)`.
2. Créer le dépôt : `gh repo create <nom> --private --source=. --push`
   (si `gh` absent : fournir les commandes manuelles et s'arrêter là).
3. Vérifications finales :
   - `git remote -v` → un seul remote, le bon compte.
   - Aucun sous-module, aucun chemin pointant hors du vault.
   - `git status` propre.

---

## Phase 4 — Retrait de l'INIT

1. Déplacer ce fichier vers `4-archives/INIT-vault-gh-obsidian.md`.
2. Commit : `archive la recette d'initialisation`.
3. Confirmer à l'utilisateur : le vault est prêt, `CLAUDE.md` → `AGENTS.md`
   prend le relais pour toutes les sessions futures.

**Checklist de sortie** (tout doit être vrai) :
- [ ] Arborescence complète, `.gitignore` exact
- [ ] `CLAUDE.md` pointeur + `AGENTS.md` adapté au contexte PERSO/PRO
- [ ] 3 templates (projet avec État courant / Journal), 3 `.base`,
      dashboard initialisé, bienvenue.md
- [ ] Dépôt GitHub privé créé, poussé, isolé
- [ ] INIT archivé
