# Design — Flux de création d'un vault

- **Date** : 2026-08-18
- **Statut** : validé, prêt pour le plan d'implémentation
- **Portée** : `init-vault.sh`, `INIT-vault-gh-obsidian.md`, `.claude/skills/new-vault/SKILL.md`, `tests/test-init-vault.sh`, `README.md`

## Problème

Créer un vault demande aujourd'hui de connaître le chemin cible **avant** de lancer quoi que ce soit, et il n'existe aucun chemin praticable depuis une session Claude déjà ouverte.

Deux défauts précis :

1. **Le script ne demande rien.** Le chemin du vault est un argument positionnel obligatoire. Les questions de paramétrage (contexte, dépôt, compte) arrivent plus tard, posées par Claude en lisant l'INIT.
2. **Le mode « via Claude » n'existe pas.** `init-vault.sh` se termine par `exec claude "…"`, conçu pour un humain dans un terminal. Appelé depuis une session Claude, il ouvrirait un agent imbriqué sans terminal et bloquerait.

S'y ajoute une incohérence : le script annonce 3 questions, l'INIT en pose 4.

## Objectif

Deux modes, un seul comportement.

- **Via Claude**, depuis une session ouverte dans le kit : « crée un vault » → questions → plan → validation → vault créé.
- **En terminal** : `./init-vault.sh` sans argument → mêmes questions → Claude prend le relais pour le plan et la génération.

Dans les deux cas les questions portent sur l'endroit du vault, son nom, et les trois spécificités (contexte, dépôt, compte). Le profil utilisateur reste une question de conversation, posée par Claude, pas par le script.

## Approche retenue

**Le script est le seul cerveau du paramétrage.** Il pose les questions ou les reçoit en flags, prépare le dossier, et **persiste les réponses** dans un bloc `## Paramètres` en tête de la copie de l'INIT. L'INIT reste la source de vérité de *ce qui est généré* ; le skill n'est qu'un chef d'orchestre.

Deux approches ont été écartées :

- **Le skill fait tout, le script devient un wrapper** — le mode terminal perdrait les vérifications et garde-fous bash, et rien ne serait testable sans LLM.
- **L'INIT reste le cerveau, le script passe les réponses dans le prompt** — les réponses ne survivraient pas à un plantage de session, et le mode via Claude resterait impraticable.

## Composants

### 1. `init-vault.sh`

#### Interface

```bash
./init-vault.sh                          # interactif : pose les questions
./init-vault.sh --path ~/vaults/vault-pro --contexte PRO \
                --repo vault-pro --account aureliengremy   # zéro question
./init-vault.sh --no-launch [...]        # prépare le dossier, ne lance pas Claude
./init-vault.sh ~/vaults/vault-perso     # compat : positionnel = --path
```

Flags : `--path`, `--parent`, `--name`, `--contexte`, `--repo`, `--account`, `--no-launch`.
`--path` accepte un chemin complet et prend le pas sur `--parent` / `--name`. Son dernier segment devient le nom du vault et subit la même validation kebab-case.

#### Questions

Posées dans cet ordre, uniquement si la valeur n'est pas déjà fournie par un flag. Le défaut entre crochets s'accepte par Entrée.

| # | Question | Défaut |
|---|---|---|
| 1 | Dossier parent des vaults | `~/vaults` |
| 2 | Nom du vault (= nom du dossier) | aucun, kebab-case vérifié |
| 3 | Contexte `PERSO` / `PRO` | aucun ; accepte `PERSO`/`PRO` ou `1`/`2` |
| 4 | Nom du dépôt GitHub | nom du vault |
| 5 | Compte GitHub | compte détecté par `gh api user --jq .login` |

En contexte `PRO`, une confirmation supplémentaire est demandée après la question 5 : *« ce compte est autorisé pour du contenu de travail ? [o/N] »*. Une réponse négative interrompt le script sans rien créer.

#### Déroulé

1. Vérification des prérequis — `git`, `claude` obligatoires ; `gh` et `obsidian` recommandés (comportement actuel inchangé).
2. Questions (celles qui restent).
3. Garde-fous — cible hors du dépôt du kit, dossier inexistant ou vide.
4. `mkdir -p` de la cible.
5. Copie de l'INIT **avec le bloc `## Paramètres` rempli**.
6. Récapitulatif affiché : chemin, contexte, dépôt, compte.
7. `exec claude "Lis INIT-vault-gh-obsidian.md et exécute l'initialisation, phase par phase."` — sauf en `--no-launch`, où le script affiche le chemin préparé et sort en 0.

#### Erreurs

Chacune affiche un message clair, sort en 1, et **ne crée rien** : flag inconnu, contexte hors `PERSO|PRO`, nom de vault non kebab-case, cible non vide, cible à l'intérieur du kit, prérequis obligatoire absent, refus de la confirmation `PRO`.

### 2. `INIT-vault-gh-obsidian.md`

Trois changements ; le reste du fichier est inchangé.

#### a. Bloc `## Paramètres`

Inséré en tête, après l'en-tête. Vide dans le kit, rempli par le script dans la copie :

```markdown
## Paramètres

<!-- Rempli par init-vault.sh. Si une valeur manque, la Phase 1 la demande. -->
- Contexte : PRO
- Dépôt GitHub : vault-pro
- Compte GitHub : aureliengremy
- Chemin du vault : /Users/…/vaults/vault-pro
```

Dans le kit, les quatre clés sont présentes avec une valeur vide (`- Contexte :`) — la structure reste visible, et une clé sans valeur signifie « à demander ». Le bloc vide garde ainsi l'INIT utilisable sans le script : la Phase 1 pose alors toutes les questions, comme aujourd'hui.

Le champ *Chemin du vault* sert au mode via Claude : il indique à l'agent le dossier dans lequel exécuter chaque commande.

#### b. Phase 1 réécrite

Lire le bloc `## Paramètres`. Ne poser que les questions dont la valeur manque, puis **toujours** la question du profil utilisateur (2-3 phrases : métier, façon de raisonner, préférences de collaboration). En contexte `PRO`, si le compte n'a pas déjà été confirmé par le script, le faire confirmer.

Les règles fixes non négociables restent identiques : dépôt privé et isolé, desktop uniquement, notes en français.

#### c. Nouvelle Phase 1 bis — Plan

Avant toute écriture, l'agent présente un plan de génération court et **attend une validation explicite** :

- l'arborescence et les fichiers à créer ;
- les adaptations liées au contexte (en `PRO`, la règle « jamais de données client nominatives ni de secrets de mandat ») ;
- le nom du dépôt, le compte cible, le premier commit ;
- l'archivage de l'INIT en fin de parcours.

Rien n'est écrit tant que le plan n'est pas validé. Si l'utilisateur ajuste, l'agent reprend le plan et redemande.

La numérotation des phases existantes ne change pas — génération (2), Git & GitHub (3), retrait de l'INIT (4) : la phase plan s'intercale sous le nom « Phase 1 bis » précisément pour l'éviter.

### 3. `.claude/skills/new-vault/SKILL.md`

Skill versionné dans le kit, donc disponible sans installation dès qu'une session Claude Code s'ouvre dans le dépôt. Déclenchement : `/new-vault`, ou une formulation comme « crée un vault », « lance le script de création de vault ».

Déroulé en quatre temps :

1. **Questions** — les cinq mêmes que le script, mêmes défauts, posées via `AskUserQuestion`. Le compte détecté par `gh api user` est proposé en défaut. En contexte `PRO`, la confirmation « compte autorisé pour du contenu de travail » est une question à part entière.
2. **Préparation** — exécution de `./init-vault.sh --no-launch --path … --contexte … --repo … --account …` depuis le kit. Si le script sort en erreur, le skill affiche le message et **s'arrête** ; aucun contournement manuel.
3. **Exécution de l'INIT** — lecture de `<vault>/INIT-vault-gh-obsidian.md`, puis déroulé de ses phases : profil utilisateur, plan présenté et validé, génération, Git & GitHub, archivage.
4. **Compte rendu** — chemin du vault, URL du dépôt, gestes suivants (ouvrir dans Obsidian, activer le CLI, ouvrir chaque `.base` une fois pour valider la syntaxe).

**Règle absolue inscrite dans le skill** : toutes les commandes s'exécutent dans le dossier du vault (`cd <vault> && …`, `git -C <vault> …`). Le répertoire de travail de la session reste le kit — c'est le piège principal de ce mode.

Le skill ne duplique pas le contenu de l'INIT, n'écrit rien dans le kit, et ne crée pas le dépôt si `gh` n'est pas authentifié sur le bon compte : il fournit alors les commandes manuelles, comme le prévoit déjà l'INIT.

### 4. `tests/test-init-vault.sh`

Bash pur, aucune dépendance à Claude ni à GitHub. `--no-launch` rend le script entièrement testable.

Cas nominaux :

- flags complets → dossier créé, INIT copié, bloc `## Paramètres` contenant les bonnes valeurs, sortie 0 ;
- `--repo` omis → dépôt = nom du vault ;
- `--path` complet → `--parent` et `--name` ignorés ;
- argument positionnel → équivalent à `--path`.

Cas d'échec, chacun devant sortir en 1 **sans rien créer** : dossier non vide, cible à l'intérieur du kit, contexte invalide, nom non kebab-case, flag inconnu.

Chaque cas travaille dans un `mktemp -d` nettoyé en sortie. Le lanceur affiche une liste verte/rouge et sort en 1 si un cas échoue.

### 5. `README.md`

- Section « Usage » réécrite autour des trois entrées : via Claude, terminal interactif, terminal en flags.
- Correction de la mention « 3 questions » (le script en pose jusqu'à 5, Claude ajoute le profil).
- Arborescence du kit ajoutée : `init-vault.sh`, `INIT-vault-gh-obsidian.md`, `.claude/skills/new-vault/`, `tests/`, `docs/`.
- Note sur l'écart docs / kit : la page concept décrit un troisième vault « vie courante » synchronisé sur mobile, hors périmètre du kit (qui impose desktop uniquement, sans sync).

## Flux de données

```
                  ┌── mode terminal ──┐        ┌── mode via Claude ──┐
                  │  ./init-vault.sh  │        │  /new-vault (skill) │
                  └─────────┬─────────┘        └──────────┬──────────┘
                            │ questions                   │ questions (AskUserQuestion)
                            ▼                             ▼
                            └────────► init-vault.sh ◄─────┘
                                       (--no-launch en mode Claude)
                                             │
                                             ▼
                              <vault>/INIT-….md + bloc Paramètres
                                             │
                                             ▼
                        Claude : profil → PLAN → validation → génération
                                             │
                                             ▼
                          git init · gh repo create --private · archivage
```

## Vérification

- **Automatisée** : `./tests/test-init-vault.sh` couvre le script (cas nominaux et cas d'échec).
- **Manuelle, à déclencher par l'utilisateur** : un essai de bout en bout sur un vault jetable (`vault-test`), dans les deux modes, suivi de la suppression du dépôt. Aucun dépôt n'est créé sur le compte de l'utilisateur sans validation explicite.
- Les parties INIT et skill ne sont pas testables automatiquement : elles reposent sur un agent.

## Hors périmètre

- Installation du skill en global (`~/.claude/skills/`) : le skill vit dans le kit, une session Claude ouverte dans le kit suffit.
- Vault mobile synchronisé (troisième vault de la page concept) : mentionné dans le README, non couvert par le kit.
- Toute modification de ce que l'INIT génère (arborescence, templates, `.base`, `AGENTS.md`) : ce design ne touche qu'au **flux de création**, pas au contenu produit.
