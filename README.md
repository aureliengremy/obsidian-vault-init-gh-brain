# 🧠 vault-init-kit

> Initialise un vault Obsidian « second brain » — méthode **PARA**, versionné sur **GitHub**, piloté par **Claude Code** — en une commande.

Un seul fichier de recette (`INIT-vault-gh-obsidian.md`), un script de lancement, et Claude Code génère tout le reste : arborescence, conventions, templates, vues Bases, dashboard, dépôt GitHub privé.

```bash
./init-vault.sh ~/vaults/vault-perso
```

---

## Le modèle à deux niveaux

Ce dépôt est **l'outil**, pas un vault. Il se clone, s'améliore et se versionne comme n'importe quel projet. Chaque exécution du script produit un **vault indépendant**, avec son propre dépôt GitHub privé, sans aucun lien avec le kit ni avec les autres vaults :

```
vault-init-kit (ce dépôt)          ──produit──▶  vault-perso  (dépôt privé isolé)
  évolue via commits/PR            ──produit──▶  vault-pro    (dépôt privé isolé)
```

Les vaults déjà créés ne dépendent pas des évolutions du kit : leur INIT est archivé chez eux, leur `AGENTS.md` vit sa vie. Une amélioration du kit ne profite qu'aux vaults créés ensuite — c'est voulu. Si une leçon apprise dans un vault mérite d'être généralisée, reporte-la dans l'INIT du kit et commit.

## Pourquoi

Deux problèmes distincts se posent quand on branche un agent IA sur ses notes :

1. **L'agent ne vous connaît pas** → réponse : un `AGENTS.md` permanent, chargé à chaque session (via un `CLAUDE.md` pointeur d'une ligne, pour rester portable vers n'importe quel agent).
2. **L'agent ne peut pas tout lire** → réponse : des vues agrégées (`.base` interrogées via Obsidian CLI, dashboard régénéré) au lieu de parcourir le vault.

Et un troisième, plus sournois : **la base pourrit**. Un second brain « append-only » accumule des informations périmées et contradictoires — et on ne peut pas compter sur l'agent pour repérer qu'une donnée est mauvaise. La parade installée ici : à chaque ingestion, trancher entre **événement** (ce qui s'est produit → on ajoute, daté, dans un journal) et **état** (ce qui est vrai maintenant → on remplace, à un seul endroit). L'historique, c'est Git qui le garde.

## Principes du vault généré

- **Markdown pur, zéro lock-in** — tout reste lisible sans Obsidian, exploitable par n'importe quel agent
- **PARA** — classement par actionnabilité, jamais par sujet
- **État / Événement** — la base ne pourrit pas : les états se remplacent, les événements s'empilent datés
- **Isolation stricte** — un vault = un dépôt GitHub privé, aucun lien entre vaults (parfait pour séparer pro et perso)
- **Boucle rétrospective** — chaque correction devient une ligne dans « Leçons apprises », validée par diff
- **Desktop uniquement** — pas de sync automatique, un commit par session de travail

## Ce que l'INIT génère

```
vault/
├── CLAUDE.md            # pointeur → AGENTS.md (portabilité inter-agents)
├── AGENTS.md            # mémoire permanente : conventions, règles, leçons
├── .gitignore           # config Obsidian ignorée, exceptions choisies
├── 0-inbox/             # capture brute, triée à la revue hebdo
├── 1-projects/          # 1 dossier/projet, index.md avec État courant + Journal
├── 2-areas/             # responsabilités continues
├── 3-resources/         # références sans engagement
├── 4-archives/          # on n'efface jamais, on archive
├── _bases/              # vues .base natives (projets actifs, inbox, revue)
├── _dashboards/         # dashboard.md régénéré par l'agent — jamais source de vérité
├── _templates/          # projet / note / revue-hebdo
└── _assets/
```

## Ce que contient le kit

```
vault-init-kit/
├── init-vault.sh                    # paramétrage : questions, garde-fous, préparation
├── INIT-vault-gh-obsidian.md        # la recette, consommée une fois par vault
├── .claude/skills/new-vault/        # le mode « via Claude »
├── tests/test-init-vault.sh         # tests du script (bash pur)
└── docs/                            # contexte de conception + specs et plans
```

## Prérequis

| Outil | Rôle | Obligatoire |
|---|---|---|
| [Claude Code](https://claude.com/claude-code) | exécute l'INIT et pilote le vault | ✅ |
| `git` | versionnement | ✅ |
| [GitHub CLI](https://cli.github.com) (`gh`), authentifié | création du dépôt privé | Recommandé |
| Obsidian ≥ 1.12 + CLI activé (Réglages → Général) | interroger les `.base` sans lire les fichiers | Recommandé |

## Usage

Trois entrées, un seul comportement. Dans tous les cas, l'agent demande votre profil,
**présente un plan et attend votre validation** avant d'écrire quoi que ce soit.

### Depuis Claude Code (le plus simple)

Clonez le kit, ouvrez une session dedans et demandez la création :

```bash
git clone <ce-dépôt> && cd vault-init-kit && claude
```

Puis : `/new-vault` — ou simplement « crée un vault ». Le skill pose les questions,
prépare le dossier, présente le plan, génère le vault et crée le dépôt privé.

### En terminal, interactif

```bash
./init-vault.sh
```

Le script pose cinq questions — dossier parent, nom du vault, contexte `PERSO`/`PRO`,
nom du dépôt, compte GitHub — puis lance Claude Code, qui prend le relais pour le
profil, le plan et la génération.

### En terminal, tout en flags

```bash
./init-vault.sh --path ~/vaults/vault-pro \
                --contexte PRO --repo vault-pro --account mon-compte
```

Aucune question n'est posée pour les valeurs fournies. Flags disponibles :
`--path`, `--parent`, `--name`, `--contexte`, `--repo`, `--account`, `--no-launch`
(prépare le dossier sans lancer Claude), `--help`.

Le script vérifie les prérequis, affiche le compte GitHub authentifié (pour éviter de
créer le vault pro sur le compte perso...), refuse un dossier non vide ou situé dans
le kit, puis copie l'INIT avec ses paramètres dans le dossier cible.

### Sans le script

L'INIT reste utilisable seul : son bloc `## Paramètres` est vide, l'agent pose alors
toutes les questions lui-même.

```bash
mkdir ~/vaults/vault-perso && cd ~/vaults/vault-perso
cp <chemin>/INIT-vault-gh-obsidian.md .
claude "Lis INIT-vault-gh-obsidian.md et exécute l'initialisation, phase par phase."
```

### Plusieurs vaults

Le même INIT sert pour tous les vaults — c'est le paramétrage qui fait la différence.
Typiquement : un vault **perso** et un vault **pro**, sur deux machines, deux dépôts
GitHub isolés, zéro croisement.

## Après l'init : la vie du vault

- **Capturer** dans `0-inbox/` sans réfléchir ; **trier** à la revue hebdo (P/A/R ou suppression)
- **Un commit par session**, message court au présent
- **Fin de session** : l'agent régénère le dashboard et propose sa rétrospective
- **Revue hebdo** : checklist fournie, incluant l'**audit anti-pourrissement** (états contradictoires ou périmés — l'agent propose des diffs, vous validez)

## Sources & inspiration

Tout le contexte de conception est dans [`docs/`](docs/) :

- [`concept-second-brain-para.html`](docs/concept-second-brain-para.html) — la page de présentation du système : architecture des vaults, méthode PARA en détail, flux d'une note, arborescence
- [`obsidian-claude-code-resume.md`](docs/obsidian-claude-code-resume.md) (+ [version HTML](docs/obsidian-claude-code-resume.html)) — *How I Run My Whole Life From Obsidian and Claude Code* : les deux problèmes (connaître / tout lire), le duo CLAUDE.md → AGENTS.md, les dashboards, la boucle rétrospective
- [`rotting-second-brain-resume.md`](docs/rotting-second-brain-resume.md) (+ [version HTML](docs/rotting-second-brain-resume.html)) — *Your AI Second Brain Is Slowly Rotting* : le diagnostic append-only et la distinction état/événement

> À noter : la page concept décrit un troisième vault « vie courante », synchronisé
> et accessible sur mobile. Il est hors du périmètre de ce kit, qui produit des
> vaults **desktop uniquement, sans sync automatique**.

Méthode PARA : Tiago Forte, *Building a Second Brain*.

## Licence

Fais-en ce que tu veux. 🍁
