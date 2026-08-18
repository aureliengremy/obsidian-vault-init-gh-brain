# Flux de création d'un vault — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre la création d'un vault possible en deux modes équivalents — « crée un vault » depuis une session Claude ouverte dans le kit, ou `./init-vault.sh` sans argument dans un terminal — avec plan validé avant toute écriture.

**Architecture:** `init-vault.sh` devient le seul cerveau du paramétrage : il pose les questions ou les reçoit en flags, prépare le dossier cible, et persiste les réponses dans un bloc `## Paramètres` en tête de la copie de l'INIT. `INIT-vault-gh-obsidian.md` lit ce bloc, ne demande que ce qui manque, et présente un plan à valider avant de générer. Le skill `.claude/skills/new-vault/` orchestre les mêmes étapes depuis une session Claude via `--no-launch`.

**Tech Stack:** Bash (compatible macOS bash 3.2), `awk`, `grep`, `git`, `gh` (optionnel), Markdown.

**Spec:** [docs/superpowers/specs/2026-08-18-flux-creation-vault-design.md](../specs/2026-08-18-flux-creation-vault-design.md)

## Global Constraints

- Tout texte affiché à l'utilisateur est en **français**.
- Bash compatible **macOS bash 3.2** : pas de `declare -A`, pas de `${var^^}`, pas de `mapfile`. `printf -v` et `${!var}` sont autorisés.
- Aucune dépendance nouvelle : uniquement `bash`, `awk`, `grep`, `sed`, `git`, `gh`.
- `set -euo pipefail` dans `init-vault.sh` ; les tests tournent **sans** `set -e`.
- Aucun test ne doit toucher au réseau, à `gh`, à `claude`, ni créer quoi que ce soit hors d'un `mktemp -d`.
- Contexte valide : `PERSO` ou `PRO` uniquement.
- Nom de vault valide : kebab-case, regex `^[a-z0-9]+(-[a-z0-9]+)*$`.
- Messages de commit : français, présent, minuscule initiale (`ajoute…`, `réécrit…`), avec le trailer :

```
Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```

- Le nom du fichier INIT est `INIT-vault-gh-obsidian.md` partout, jamais renommé.

## Structure des fichiers

| Fichier | Responsabilité | Tâches |
|---|---|---|
| `INIT-vault-gh-obsidian.md` | Recette de génération + bloc `## Paramètres` lu par l'agent | 1, 4 |
| `init-vault.sh` | Paramétrage : flags, questions, garde-fous, préparation du dossier | 2, 3 |
| `tests/test-init-vault.sh` | Vérification automatisée du script (seul fichier de test) | 1, 2, 3 |
| `.claude/skills/new-vault/SKILL.md` | Orchestration du mode « via Claude » | 5 |
| `README.md` | Documentation des trois entrées | 6 |

---

### Task 1: Bloc `## Paramètres` dans l'INIT + harness de test

**Files:**
- Modify: `INIT-vault-gh-obsidian.md:9` (insertion après le séparateur d'en-tête)
- Create: `tests/test-init-vault.sh`

**Interfaces:**
- Consumes: rien.
- Produces: le bloc `## Paramètres` avec quatre clés exactes, que la Task 2 remplira par `awk` et que la Task 4 fera lire à l'agent :
  - `- Contexte :`
  - `- Dépôt GitHub :`
  - `- Compte GitHub :`
  - `- Chemin du vault :`

  Le harness expose les helpers `ok`, `ko`, `check`, `run`, `mktmp` réutilisés par les Tasks 2 et 3.

- [ ] **Step 1: Écrire le harness de test avec son premier cas (qui échoue)**

Créer `tests/test-init-vault.sh` :

```bash
#!/usr/bin/env bash
# tests/test-init-vault.sh — tests du script d'initialisation de vault.
# Bash pur : aucune dépendance à Claude, à gh ou au réseau.
# Usage : ./tests/test-init-vault.sh

set -uo pipefail

KIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$KIT_DIR/init-vault.sh"
INIT_NAME="INIT-vault-gh-obsidian.md"
KIT_INIT="$KIT_DIR/$INIT_NAME"

GREEN=$(tput setaf 2 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)
BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

PASS=0
FAIL=0

ok() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$1"; PASS=$((PASS + 1)); }
ko() { printf '  %s✘%s %s\n' "$RED" "$RESET" "$1"; FAIL=$((FAIL + 1)); }

# assert <condition-déjà-évaluée:0|1> <libellé>
assert() { if [ "$1" -eq 0 ]; then ok "$2"; else ko "$2"; fi; }

# check <obtenu> <attendu> <libellé>
check() {
  if [ "$1" = "$2" ]; then ok "$3"
  else ko "$3 (attendu « $2 », obtenu « $1 »)"; fi
}

# mktmp : dossier temporaire au chemin résolu (macOS : /var → /private/var)
mktmp() { local d; d=$(mktemp -d); (cd "$d" && pwd); }

# run <args...> : exécute le script sans TTY, capture sortie et code retour
RUN_OUT=""
RUN_RC=0
run() {
  RUN_OUT=$("$SCRIPT" "$@" </dev/null 2>&1)
  RUN_RC=$?
  return 0
}

# run_tty <réponses-sur-stdin> <args...> : force le mode interactif
run_tty() {
  local answers=$1; shift
  RUN_OUT=$(printf '%s' "$answers" | VAULT_INIT_ASSUME_TTY=1 "$SCRIPT" "$@" 2>&1)
  RUN_RC=$?
  return 0
}

printf '\n%sTests init-vault.sh%s\n\n' "$BOLD" "$RESET"

# --- 1. Le kit expose le bloc Paramètres vide ---------------------------
printf '%sBloc Paramètres du kit%s\n' "$BOLD" "$RESET"

grep -Fqx '## Paramètres' "$KIT_INIT"
assert $? "le kit contient la section ## Paramètres"

for cle in '- Contexte :' '- Dépôt GitHub :' '- Compte GitHub :' '- Chemin du vault :'; do
  grep -Fqx "$cle" "$KIT_INIT"
  assert $? "clé vide présente dans le kit : « $cle »"
done

# --- Bilan --------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '%s%d test(s) OK%s\n\n' "$GREEN" "$PASS" "$RESET"
  exit 0
else
  printf '%s%d échec(s) sur %d%s\n\n' "$RED" "$FAIL" "$((PASS + FAIL))" "$RESET"
  exit 1
fi
```

Puis le rendre exécutable :

```bash
chmod +x tests/test-init-vault.sh
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `./tests/test-init-vault.sh`
Expected: FAIL — 5 échecs (`le kit contient la section ## Paramètres` et les 4 clés), sortie 1.

- [ ] **Step 3: Ajouter le bloc `## Paramètres` à l'INIT**

Dans `INIT-vault-gh-obsidian.md`, insérer juste après la ligne `---` qui clôt l'en-tête (ligne 9), et avant `## Phase 1 — Paramétrage` :

```markdown
## Paramètres

<!-- Rempli par init-vault.sh. Une clé sans valeur est demandée en Phase 1. -->
- Contexte :
- Dépôt GitHub :
- Compte GitHub :
- Chemin du vault :

---
```

Les quatre clés doivent être écrites **exactement** ainsi, sans espace après les deux-points : le script les repère au caractère près.

- [ ] **Step 4: Relancer les tests pour vérifier qu'ils passent**

Run: `./tests/test-init-vault.sh`
Expected: PASS — `5 test(s) OK`, sortie 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test-init-vault.sh INIT-vault-gh-obsidian.md
git commit -m "ajoute le bloc Parametres a l'INIT et le harness de tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Script — cœur non interactif (flags, garde-fous, paramètres)

**Files:**
- Modify: `init-vault.sh` (réécriture complète)
- Modify: `tests/test-init-vault.sh` (ajout des cas 2 à 10, avant le bilan)

**Interfaces:**
- Consumes: le bloc `## Paramètres` de la Task 1, avec ses quatre clés exactes.
- Produces:
  - Flags : `--path`, `--parent`, `--name`, `--contexte`, `--repo`, `--account`, `--no-launch`, `-h|--help`, plus un argument positionnel équivalent à `--path`.
  - Fonctions internes réutilisées par la Task 3 : `ask VAR "libellé" "défaut"`, `is_tty`, `normalise_contexte`, `is_kebab`, `resolve_abs`.
  - Seam de test : la variable d'environnement `VAULT_INIT_ASSUME_TTY` force le mode interactif.
  - Sortie 0 en `--no-launch` avec le chemin préparé affiché ; sortie 1 sur toute erreur, sans rien créer.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `tests/test-init-vault.sh`, insérer ce bloc **avant** la section `# --- Bilan ---` :

```bash
# --- 2. Cas nominal : flags complets ------------------------------------
printf '\n%sCas nominaux%s\n' "$BOLD" "$RESET"

TMP=$(mktmp)
run --no-launch --parent "$TMP" --name vault-test \
    --contexte PRO --repo depot-test --account moncompte
check "$RUN_RC" "0" "cas nominal : sortie 0"
P="$TMP/vault-test/$INIT_NAME"
[ -f "$P" ]; assert $? "cas nominal : INIT copié dans le vault"
if [ -f "$P" ]; then
  grep -Fqx "- Contexte : PRO" "$P";                      assert $? "cas nominal : contexte écrit"
  grep -Fqx "- Dépôt GitHub : depot-test" "$P";           assert $? "cas nominal : dépôt écrit"
  grep -Fqx "- Compte GitHub : moncompte" "$P";           assert $? "cas nominal : compte écrit"
  grep -Fqx "- Chemin du vault : $TMP/vault-test" "$P";   assert $? "cas nominal : chemin écrit"
fi
rm -rf "$TMP"

# --- 3. Défaut : --repo omis → nom du vault -----------------------------
TMP=$(mktmp)
run --no-launch --parent "$TMP" --name vault-perso --contexte PERSO --account moncompte
check "$RUN_RC" "0" "repo par défaut : sortie 0"
grep -Fqx "- Dépôt GitHub : vault-perso" "$TMP/vault-perso/$INIT_NAME" 2>/dev/null
assert $? "repo par défaut : dépôt = nom du vault"
rm -rf "$TMP"

# --- 4. --path prime sur --parent/--name --------------------------------
TMP=$(mktmp)
OTHER=$(mktmp)
run --no-launch --parent "$OTHER" --name ignore-moi --path "$TMP/vault-prime" \
    --contexte PERSO --account moncompte
check "$RUN_RC" "0" "--path prioritaire : sortie 0"
[ -f "$TMP/vault-prime/$INIT_NAME" ]; assert $? "--path prioritaire : vault au bon endroit"
[ ! -e "$OTHER/ignore-moi" ];         assert $? "--path prioritaire : --parent/--name ignorés"
rm -rf "$TMP" "$OTHER"

# --- 5. Compat : argument positionnel = --path --------------------------
TMP=$(mktmp)
run --no-launch "$TMP/vault-positionnel" --contexte PERSO --account moncompte
check "$RUN_RC" "0" "positionnel : sortie 0"
[ -f "$TMP/vault-positionnel/$INIT_NAME" ]; assert $? "positionnel : équivaut à --path"
rm -rf "$TMP"

# --- 6..11. Cas d'échec : sortie 1, rien créé ---------------------------
printf '\n%sCas d'"'"'échec%s\n' "$BOLD" "$RESET"

TMP=$(mktmp)
mkdir -p "$TMP/vault-plein"
: > "$TMP/vault-plein/note.md"
run --no-launch --path "$TMP/vault-plein" --contexte PERSO --account moncompte
check "$RUN_RC" "1" "dossier non vide : sortie 1"
[ ! -e "$TMP/vault-plein/$INIT_NAME" ]; assert $? "dossier non vide : rien créé"
rm -rf "$TMP"

run --no-launch --path "$KIT_DIR/vault-interdit" --contexte PERSO --account moncompte
check "$RUN_RC" "1" "cible dans le kit : sortie 1"
[ ! -e "$KIT_DIR/vault-interdit" ]; assert $? "cible dans le kit : rien créé"

TMP=$(mktmp)
run --no-launch --path "$TMP/vault-x" --contexte AUTRE --account moncompte
check "$RUN_RC" "1" "contexte invalide : sortie 1"
[ ! -e "$TMP/vault-x" ]; assert $? "contexte invalide : rien créé"

run --no-launch --path "$TMP/Vault_Perso" --contexte PERSO --account moncompte
check "$RUN_RC" "1" "nom non kebab-case : sortie 1"
[ ! -e "$TMP/Vault_Perso" ]; assert $? "nom non kebab-case : rien créé"

run --no-launch --wat --path "$TMP/vault-y" --contexte PERSO --account moncompte
check "$RUN_RC" "1" "flag inconnu : sortie 1"
[ ! -e "$TMP/vault-y" ]; assert $? "flag inconnu : rien créé"

run --no-launch --path "$TMP/vault-z" --account moncompte
check "$RUN_RC" "1" "contexte manquant en non interactif : sortie 1"
[ ! -e "$TMP/vault-z" ]; assert $? "contexte manquant : rien créé"
rm -rf "$TMP"
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `./tests/test-init-vault.sh`
Expected: FAIL — les cas nominaux échouent (le script exige encore un argument positionnel et ne connaît aucun flag), sortie 1.

- [ ] **Step 3: Réécrire `init-vault.sh`**

Remplacer **tout** le contenu de `init-vault.sh` par :

```bash
#!/usr/bin/env bash
#
# init-vault.sh — Initialise un nouveau vault Obsidian « second brain »
# (PARA + GitHub + Claude Code) à partir de INIT-vault-gh-obsidian.md.
#
# Le script pose les questions de paramétrage (ou les reçoit en flags),
# prépare le dossier cible, y copie l'INIT avec ses paramètres, puis lance
# Claude Code. Le profil utilisateur, le plan et la génération se passent
# dans Claude Code.

set -euo pipefail

# --- Couleurs -----------------------------------------------------------
BOLD=$(tput bold 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

ok()   { echo "${GREEN}✔${RESET} $1"; }
warn() { echo "${YELLOW}⚠${RESET} $1"; }
die()  { echo "${RED}✘ $1${RESET}" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INIT_NAME="INIT-vault-gh-obsidian.md"
INIT_FILE="$SCRIPT_DIR/$INIT_NAME"
DEFAULT_PARENT="$HOME/vaults"

usage() {
  cat <<'EOF'
Usage :
  ./init-vault.sh                                   # interactif
  ./init-vault.sh --path ~/vaults/vault-pro \
                  --contexte PRO --repo vault-pro --account moncompte
  ./init-vault.sh --no-launch [...]                 # prépare sans lancer Claude
  ./init-vault.sh ~/vaults/vault-perso              # compat : positionnel = --path

Flags :
  --path <chemin>      chemin complet du vault (prime sur --parent/--name)
  --parent <dossier>   dossier parent des vaults        (défaut : ~/vaults)
  --name <nom>         nom du vault, en kebab-case
  --contexte PERSO|PRO
  --repo <nom>         nom du dépôt GitHub              (défaut : nom du vault)
  --account <compte>   compte ou organisation GitHub    (défaut : compte gh)
  --no-launch          prépare le dossier et s'arrête
  -h, --help           affiche cette aide
EOF
}

# --- Helpers ------------------------------------------------------------

# Mode interactif ? VAULT_INIT_ASSUME_TTY est un seam pour les tests.
is_tty() { [ -n "${VAULT_INIT_ASSUME_TTY:-}" ] || [ -t 0 ]; }

# normalise_contexte <valeur> → PERSO | PRO, ou code 1
normalise_contexte() {
  case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" in
    PERSO|1) printf 'PERSO' ;;
    PRO|2)   printf 'PRO' ;;
    *)       return 1 ;;
  esac
}

is_kebab() { printf '%s' "$1" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; }

# resolve_abs <chemin> → chemin absolu (tilde étendu, parent résolu si existant)
resolve_abs() {
  local p=$1 d b
  case "$p" in "~"|"~/"*) p="$HOME${p#\~}" ;; esac
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  p=${p%/}
  d=$(dirname "$p")
  b=$(basename "$p")
  if [ -d "$d" ]; then printf '%s/%s' "$(cd "$d" && pwd)" "$b"
  else printf '%s' "$p"; fi
}

# ask <NOM_VAR> <libellé> [défaut]
# Non interactif : applique le défaut, ou meurt si aucun défaut.
ask() {
  local __var=$1 __prompt=$2 __default=${3:-}
  [ -z "${!__var}" ] || return 0
  [ -n "$__default" ] || die "Valeur manquante : $__prompt. Fournis le flag correspondant."
  printf -v "$__var" '%s' "$__default"
}

# --- Arguments ----------------------------------------------------------
PATH_ARG=""
PARENT=""
NAME=""
CONTEXTE=""
REPO=""
ACCOUNT=""
NO_LAUNCH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --path)      [ $# -ge 2 ] || die "--path attend une valeur.";      PATH_ARG=$2; shift 2 ;;
    --parent)    [ $# -ge 2 ] || die "--parent attend une valeur.";    PARENT=$2;   shift 2 ;;
    --name)      [ $# -ge 2 ] || die "--name attend une valeur.";      NAME=$2;     shift 2 ;;
    --contexte)  [ $# -ge 2 ] || die "--contexte attend une valeur.";  CONTEXTE=$2; shift 2 ;;
    --repo)      [ $# -ge 2 ] || die "--repo attend une valeur.";      REPO=$2;     shift 2 ;;
    --account)   [ $# -ge 2 ] || die "--account attend une valeur.";   ACCOUNT=$2;  shift 2 ;;
    --no-launch) NO_LAUNCH=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    -*)          die "Flag inconnu : $1 (--help pour la liste)." ;;
    *)           [ -z "$PATH_ARG" ] || die "Trop d'arguments : $1"; PATH_ARG=$1; shift ;;
  esac
done

echo
echo "${BOLD}Initialisation d'un vault second brain${RESET}"
echo

# --- Prérequis ----------------------------------------------------------
[ -f "$INIT_FILE" ] || die "$INIT_NAME introuvable à côté du script."

command -v git >/dev/null 2>&1 || die "git n'est pas installé."
ok "git présent"

if [ "$NO_LAUNCH" -eq 0 ]; then
  command -v claude >/dev/null 2>&1 \
    || die "Claude Code (claude) n'est pas installé. → https://claude.com/claude-code"
  ok "Claude Code présent"
fi

GH_ACCOUNT=""
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    GH_ACCOUNT=$(gh api user --jq .login 2>/dev/null || printf '')
    ok "GitHub CLI authentifié (compte : ${BOLD}${GH_ACCOUNT:-?}${RESET})"
  else
    warn "gh est installé mais non authentifié. Lance 'gh auth login' d'abord,"
    warn "ou l'INIT te donnera les commandes manuelles."
  fi
else
  warn "GitHub CLI (gh) absent : la création du dépôt sera manuelle."
fi

if command -v obsidian >/dev/null 2>&1; then
  ok "Obsidian CLI présent (les vues .base pourront être interrogées)"
else
  warn "Obsidian CLI absent (Obsidian ≥ 1.12, Réglages → Général)."
  warn "Non bloquant : l'agent utilisera le fallback dashboard.md."
fi

# --- Paramètres ---------------------------------------------------------
if [ -z "$PATH_ARG" ]; then
  ask PARENT "Dossier parent des vaults" "$DEFAULT_PARENT"
  ask NAME   "Nom du vault (kebab-case)"
fi

if [ -n "$CONTEXTE" ]; then
  CONTEXTE=$(normalise_contexte "$CONTEXTE") \
    || die "Contexte invalide : attendu PERSO ou PRO."
else
  die "Valeur manquante : contexte. Fournis --contexte PERSO|PRO."
fi

# Chemin cible et nom du vault
if [ -n "$PATH_ARG" ]; then
  TARGET_ABS=$(resolve_abs "$PATH_ARG")
  NAME=$(basename "$TARGET_ABS")
else
  TARGET_ABS=$(resolve_abs "$PARENT/$NAME")
fi

is_kebab "$NAME" \
  || die "Nom de vault invalide : « $NAME ». Attendu du kebab-case (ex. vault-perso)."

ask REPO    "Nom du dépôt GitHub" "$NAME"
ask ACCOUNT "Compte ou organisation GitHub" "$GH_ACCOUNT"

# --- Garde-fous ---------------------------------------------------------
# Le vault ne doit JAMAIS être créé dans le dépôt du kit
# (Git imbriqué = croisement interdit entre l'outil et ses produits).
case "$TARGET_ABS" in
  "$SCRIPT_DIR"|"$SCRIPT_DIR"/*)
    die "La cible est à l'intérieur du dépôt du kit. Choisis un dossier hors du kit (ex. ~/vaults/vault-perso)." ;;
esac

if [ -e "$TARGET_ABS" ]; then
  [ -d "$TARGET_ABS" ] || die "$TARGET_ABS existe et n'est pas un dossier."
  if [ -n "$(ls -A "$TARGET_ABS" 2>/dev/null)" ]; then
    die "$TARGET_ABS n'est pas vide. L'INIT s'exécute dans un dossier vide."
  fi
fi

# --- Préparation du dossier --------------------------------------------
mkdir -p "$TARGET_ABS"
ok "Dossier prêt : $TARGET_ABS"

LC_ALL=C awk \
  -v ctx="$CONTEXTE" -v repo="$REPO" -v acct="$ACCOUNT" -v vpath="$TARGET_ABS" '
  /^- Contexte :/        { print "- Contexte : " ctx;      next }
  /^- Dépôt GitHub :/    { print "- Dépôt GitHub : " repo; next }
  /^- Compte GitHub :/   { print "- Compte GitHub : " acct; next }
  /^- Chemin du vault :/ { print "- Chemin du vault : " vpath; next }
  { print }
' "$INIT_FILE" > "$TARGET_ABS/$INIT_NAME"

grep -Fqx "- Contexte : $CONTEXTE" "$TARGET_ABS/$INIT_NAME" \
  || die "Le bloc ## Paramètres n'a pas pu être rempli — l'INIT du kit a-t-il été modifié ?"
ok "INIT copié avec ses paramètres"

# --- Récapitulatif ------------------------------------------------------
echo
echo "${BOLD}Récapitulatif${RESET}"
echo "  Vault    : $TARGET_ABS"
echo "  Contexte : $CONTEXTE"
echo "  Dépôt    : $REPO (privé)"
echo "  Compte   : ${ACCOUNT:-à préciser}"
echo

# --- Lancement ----------------------------------------------------------
if [ "$NO_LAUNCH" -eq 1 ]; then
  ok "Dossier préparé, Claude Code non lancé (--no-launch)."
  echo "$TARGET_ABS"
  exit 0
fi

echo "${BOLD}Lancement de Claude Code...${RESET}"
echo "L'agent te demandera ton profil, puis présentera un plan à valider."
echo

cd "$TARGET_ABS"
exec claude "Lis $INIT_NAME et exécute l'initialisation, phase par phase."
```

- [ ] **Step 4: Relancer les tests pour vérifier qu'ils passent**

Run: `./tests/test-init-vault.sh`
Expected: PASS — `30 test(s) OK`, sortie 0.

- [ ] **Step 5: Vérifier l'aide à la main**

Run: `./init-vault.sh --help`
Expected: le bloc d'usage s'affiche, sortie 0, aucun dossier créé.

- [ ] **Step 6: Commit**

```bash
git add init-vault.sh tests/test-init-vault.sh
git commit -m "reecrit init-vault.sh autour de flags et d'un bloc de parametres

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Script — mode interactif (questions, défauts, confirmation PRO)

**Files:**
- Modify: `init-vault.sh` (fonction `ask`, bloc contexte, ajout de la confirmation PRO)
- Modify: `tests/test-init-vault.sh` (ajout des cas interactifs, avant le bilan)

**Interfaces:**
- Consumes: `ask`, `is_tty`, `normalise_contexte` de la Task 2.
- Produces: ordre de prompt figé — `parent`, `nom`, `contexte`, `dépôt`, `compte`, puis confirmation `PRO`. Les tests de la Task 3 et le skill de la Task 5 dépendent de cet ordre.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `tests/test-init-vault.sh`, insérer ce bloc **avant** la section `# --- Bilan ---` :

```bash
# --- 12..16. Mode interactif -------------------------------------------
printf '\n%sMode interactif%s\n' "$BOLD" "$RESET"

# Ordre des questions : parent, nom, contexte, dépôt, compte [, confirmation PRO]
TMP=$(mktmp)
run_tty "$TMP
vault-inter
1
depot-inter
moncompte
" --no-launch
check "$RUN_RC" "0" "interactif : sortie 0"
P="$TMP/vault-inter/$INIT_NAME"
[ -f "$P" ]; assert $? "interactif : vault créé"
if [ -f "$P" ]; then
  grep -Fqx "- Contexte : PERSO" "$P";            assert $? "interactif : « 1 » vaut PERSO"
  grep -Fqx "- Dépôt GitHub : depot-inter" "$P";  assert $? "interactif : dépôt saisi"
  grep -Fqx "- Compte GitHub : moncompte" "$P";   assert $? "interactif : compte saisi"
fi
rm -rf "$TMP"

# Entrée vide sur le dépôt → défaut = nom du vault
TMP=$(mktmp)
run_tty "$TMP
vault-defaut
PERSO

moncompte
" --no-launch
check "$RUN_RC" "0" "interactif défaut : sortie 0"
grep -Fqx "- Dépôt GitHub : vault-defaut" "$TMP/vault-defaut/$INIT_NAME" 2>/dev/null
assert $? "interactif défaut : Entrée reprend le nom du vault"
rm -rf "$TMP"

# Contexte invalide puis valide → le script reboucle
TMP=$(mktmp)
run_tty "$TMP
vault-boucle
nimportequoi
PRO
depot-boucle
moncompte
o
" --no-launch
check "$RUN_RC" "0" "interactif boucle : sortie 0"
grep -Fqx "- Contexte : PRO" "$TMP/vault-boucle/$INIT_NAME" 2>/dev/null
assert $? "interactif boucle : contexte finalement PRO"
rm -rf "$TMP"

# PRO : confirmation refusée → sortie 1, rien créé
TMP=$(mktmp)
run_tty "$TMP
vault-refus
PRO
depot-refus
moncompte
n
" --no-launch
check "$RUN_RC" "1" "PRO refusé : sortie 1"
[ ! -e "$TMP/vault-refus" ]; assert $? "PRO refusé : rien créé"
rm -rf "$TMP"

# PRO : confirmation acceptée → vault créé
TMP=$(mktmp)
run_tty "$TMP
vault-accepte
PRO
depot-accepte
moncompte
o
" --no-launch
check "$RUN_RC" "0" "PRO accepté : sortie 0"
[ -f "$TMP/vault-accepte/$INIT_NAME" ]; assert $? "PRO accepté : vault créé"
rm -rf "$TMP"
```

- [ ] **Step 2: Lancer les tests pour vérifier qu'ils échouent**

Run: `./tests/test-init-vault.sh`
Expected: FAIL — les cas interactifs échouent (`ask` ne lit pas stdin, le contexte manquant tue le script), sortie 1.

- [ ] **Step 3: Rendre `ask` interactive**

Dans `init-vault.sh`, remplacer la fonction `ask` par :

```bash
# ask <NOM_VAR> <libellé> [défaut]
# Interactif : demande, avec le défaut entre crochets (Entrée l'accepte).
# Non interactif : applique le défaut, ou meurt si aucun défaut.
ask() {
  local __var=$1 __prompt=$2 __default=${3:-} __reply
  [ -z "${!__var}" ] || return 0
  if ! is_tty; then
    [ -n "$__default" ] || die "Valeur manquante : $__prompt. Fournis le flag correspondant."
    printf -v "$__var" '%s' "$__default"
    return 0
  fi
  while :; do
    if [ -n "$__default" ]; then printf '%s [%s] : ' "$__prompt" "$__default"
    else printf '%s : ' "$__prompt"; fi
    read -r __reply || __reply=""
    [ -n "$__reply" ] || __reply=$__default
    [ -n "$__reply" ] && break
    warn "Une valeur est requise."
  done
  printf -v "$__var" '%s' "$__reply"
}
```

- [ ] **Step 4: Rendre le contexte interactif**

Dans `init-vault.sh`, remplacer le bloc contexte :

```bash
if [ -n "$CONTEXTE" ]; then
  CONTEXTE=$(normalise_contexte "$CONTEXTE") \
    || die "Contexte invalide : attendu PERSO ou PRO."
else
  die "Valeur manquante : contexte. Fournis --contexte PERSO|PRO."
fi
```

par :

```bash
if [ -n "$CONTEXTE" ]; then
  CONTEXTE=$(normalise_contexte "$CONTEXTE") \
    || die "Contexte invalide : attendu PERSO ou PRO."
else
  is_tty || die "Valeur manquante : contexte. Fournis --contexte PERSO|PRO."
  CTX_REPLY=""
  while :; do
    printf 'Contexte — 1) PERSO  2) PRO : '
    read -r CTX_REPLY || CTX_REPLY=""
    if CONTEXTE=$(normalise_contexte "$CTX_REPLY"); then break; fi
    warn "Réponds PERSO, PRO, 1 ou 2."
  done
fi
```

- [ ] **Step 5: Ajouter la confirmation PRO**

Dans `init-vault.sh`, juste après la ligne `ask ACCOUNT "Compte ou organisation GitHub" "$GH_ACCOUNT"`, insérer :

```bash
# En contexte PRO, le compte doit être confirmé de vive voix.
# Non interactif : l'appelant (skill ou flags) porte cette responsabilité.
if [ "$CONTEXTE" = "PRO" ] && is_tty; then
  PRO_REPLY=""
  printf 'Contexte PRO : le compte « %s » est-il autorisé pour du contenu de travail ? [o/N] ' "${ACCOUNT:-?}"
  read -r PRO_REPLY || PRO_REPLY=""
  case "$PRO_REPLY" in
    [oOyY]*) ok "Compte confirmé" ;;
    *)       die "Confirmation refusée. Rien n'a été créé." ;;
  esac
fi
```

- [ ] **Step 6: Relancer les tests pour vérifier qu'ils passent**

Run: `./tests/test-init-vault.sh`
Expected: PASS — `43 test(s) OK`, sortie 0.

- [ ] **Step 7: Vérifier une session interactive réelle**

Run: `./init-vault.sh --no-launch`
Répondre : dossier parent `/tmp/vaults-essai`, nom `vault-essai`, contexte `1`, dépôt (Entrée), compte (Entrée ou un nom).
Expected: le récapitulatif s'affiche, le dossier existe, l'INIT y est paramétré.

Nettoyer :

```bash
rm -rf /tmp/vaults-essai
```

- [ ] **Step 8: Commit**

```bash
git add init-vault.sh tests/test-init-vault.sh
git commit -m "ajoute le mode interactif au script d'initialisation

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: INIT — Phase 1 réécrite et Phase 1 bis (plan à valider)

**Files:**
- Modify: `INIT-vault-gh-obsidian.md` (section `## Phase 1 — Paramétrage`, insertion d'une `## Phase 1 bis`, checklist de sortie)

**Interfaces:**
- Consumes: le bloc `## Paramètres` (Task 1), rempli par le script (Task 2).
- Produces: le contrat que le skill de la Task 5 exécute — Phase 1 (questions restantes + profil), Phase 1 bis (plan validé), puis Phases 2 à 4 inchangées.

- [ ] **Step 1: Remplacer la Phase 1**

Dans `INIT-vault-gh-obsidian.md`, remplacer intégralement la section qui va de `## Phase 1 — Paramétrage (questions à poser à l'utilisateur)` jusqu'à la ligne `- Langue des notes : **français**.` par :

```markdown
## Phase 1 — Paramétrage

Lire d'abord le bloc `## Paramètres` en tête de ce fichier.

- Une clé qui porte une valeur est **acquise** : ne pas la redemander.
- Une clé vide se demande à l'utilisateur, une question à la fois :
  1. **Contexte** : `PERSO` ou `PRO` ?
  2. **Nom du dépôt GitHub privé** à créer (ex. `vault-perso`, `vault-pro`) ?
  3. **Compte ou organisation GitHub** cible ?
  4. **Chemin du vault** : le dossier dans lequel générer (par défaut, le dossier courant).

Puis, **dans tous les cas**, poser la question qui n'est jamais pré-remplie :

5. **Qui es-tu et comment travailles-tu ?** → 2-3 phrases libres : métier/contexte,
   façon de raisonner, préférences de collaboration avec un agent (ex. « propose
   avant d'exécuter », « va droit au but »). Elles alimenteront la section
   « L'utilisateur » de l'AGENTS.md.

Vérifications avant d'aller plus loin :

- `gh auth status` confirme que le CLI est authentifié sur le compte indiqué.
- En contexte `PRO`, si le bloc `## Paramètres` était vide (donc sans passage par
  `init-vault.sh`), faire confirmer explicitement que ce compte est autorisé pour
  du contenu de travail.
- **Toutes** les commandes de ce fichier s'exécutent dans le dossier indiqué par
  « Chemin du vault » — jamais dans le dépôt du kit qui a produit ce fichier.

Règles fixes, non négociables (ne pas demander) :
- Dépôt **privé**, **isolé** : aucun remote, sous-module ou lien vers un autre vault.
- Vault **desktop uniquement** : aucune sync automatique, aucun usage mobile.
- Langue des notes : **français**.

---

## Phase 1 bis — Plan (validation obligatoire)

Avant d'écrire quoi que ce soit, présenter un plan court et **attendre une
validation explicite**. Le plan tient en une page et couvre :

- l'arborescence et la liste des fichiers à créer (§2.1) ;
- les adaptations liées au contexte : en `PRO`, l'ajout dans « Règles dures » de
  *« Jamais de données client nominatives ni de secrets de mandat dans le vault. »* ;
- le profil utilisateur reformulé en une phrase, pour qu'il soit corrigé s'il a été
  mal compris ;
- le nom du dépôt, le compte cible et le message du premier commit ;
- l'archivage de l'INIT en fin de parcours (Phase 4).

Tant que le plan n'est pas validé, **aucun fichier n'est créé**. Si l'utilisateur
ajuste, reprendre le plan et redemander la validation.
```

- [ ] **Step 2: Compléter la checklist de sortie**

Dans `INIT-vault-gh-obsidian.md`, dans la **Checklist de sortie** de la Phase 4, ajouter en première ligne :

```markdown
- [ ] Plan présenté et validé avant la première écriture
```

- [ ] **Step 3: Vérifier que le script remplit toujours le bloc**

Run:

```bash
./tests/test-init-vault.sh
```

Expected: PASS — `43 test(s) OK`. La Phase 1 a changé, le bloc `## Paramètres` n'a pas bougé.

- [ ] **Step 4: Vérifier la cohérence du fichier à l'œil**

Run: `grep -n '^## ' INIT-vault-gh-obsidian.md`
Expected: dans l'ordre — `## Paramètres`, `## Phase 1 — Paramétrage`, `## Phase 1 bis — Plan (validation obligatoire)`, `## Phase 2 — Génération des fichiers`, `## Phase 3 — Git & GitHub`, `## Phase 4 — Retrait de l'INIT`.

- [ ] **Step 5: Commit**

```bash
git add INIT-vault-gh-obsidian.md
git commit -m "fait lire les parametres a l'INIT et impose un plan valide

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Skill `/new-vault`

**Files:**
- Create: `.claude/skills/new-vault/SKILL.md`

**Interfaces:**
- Consumes: `init-vault.sh --no-launch` avec `--path`, `--contexte`, `--repo`, `--account` (Tasks 2-3) ; le contrat de phases de l'INIT (Task 4).
- Produces: le point d'entrée `/new-vault` du mode « via Claude ».

- [ ] **Step 1: Créer le skill**

Créer `.claude/skills/new-vault/SKILL.md` :

````markdown
---
name: new-vault
description: Crée un nouveau vault Obsidian « second brain » (PARA, dépôt GitHub privé isolé, piloté par Claude Code) depuis ce kit. Utiliser quand l'utilisateur demande de créer un vault, de lancer le script de création de vault, ou dit « nouveau vault », « init vault », « /new-vault ».
---

# Créer un vault

Orchestre `init-vault.sh` puis la recette `INIT-vault-gh-obsidian.md` pour produire
un vault complet, sans que l'utilisateur ait à quitter la session.

## Règle absolue

Le répertoire de travail de la session est **le kit**, pas le vault. Toute commande
qui concerne le vault s'exécute explicitement dans son dossier :

```bash
cd <vault> && <commande>     # ou : git -C <vault> <commande>
```

Ne jamais créer, modifier ou committer un fichier du vault depuis le kit. Ne jamais
committer dans le kit pendant la création d'un vault.

## Étape 1 — Questions

Poser les cinq questions ci-dessous. Les proposer d'un bloc quand l'interface le
permet, en respectant cet ordre. Ne pas demander le profil utilisateur ici : il est
demandé à l'étape 3, par l'INIT.

| # | Question | Défaut |
|---|---|---|
| 1 | Dossier parent des vaults | `~/vaults` |
| 2 | Nom du vault (kebab-case) | aucun |
| 3 | Contexte | `PERSO` ou `PRO`, aucun défaut |
| 4 | Nom du dépôt GitHub | le nom du vault |
| 5 | Compte ou organisation GitHub | le compte détecté |

Le compte par défaut se détecte ainsi :

```bash
gh api user --jq .login
```

Si la commande échoue, laisser le champ vide et prévenir que la création du dépôt
sera manuelle.

En contexte **PRO**, poser une sixième question, à part entière : *« Le compte
`<compte>` est-il autorisé pour du contenu de travail ? »* Une réponse négative
arrête tout, sans rien créer.

## Étape 2 — Préparation

Depuis le kit :

```bash
./init-vault.sh --no-launch \
  --path "<parent>/<nom>" \
  --contexte <PERSO|PRO> \
  --repo <depot> \
  --account <compte>
```

`--no-launch` est obligatoire : sans lui, le script lancerait une seconde instance
de Claude Code.

Si le script sort en erreur (dossier non vide, cible dans le kit, nom invalide,
prérequis manquant), **rapporter le message et s'arrêter**. Ne pas contourner à la
main : le script est le garde-fou.

## Étape 3 — Exécution de l'INIT

Lire `<vault>/INIT-vault-gh-obsidian.md` — son bloc `## Paramètres` est déjà rempli —
puis dérouler ses phases :

1. **Phase 1** : ne reste que la question du profil utilisateur (2-3 phrases).
2. **Phase 1 bis** : présenter le plan et **attendre une validation explicite**.
   Aucun fichier avant validation.
3. **Phase 2** : générer l'arborescence et les fichiers, dans le dossier du vault.
4. **Phase 3** : `git init`, premier commit, `gh repo create <depot> --private
   --source=. --push`. Si `gh` n'est pas authentifié sur le bon compte, ne pas créer
   le dépôt : fournir les commandes manuelles, comme l'INIT le prévoit.
5. **Phase 4** : archiver l'INIT dans `4-archives/`, committer.

## Étape 4 — Compte rendu

Terminer par :

- le chemin du vault et l'URL du dépôt ;
- les gestes suivants : ouvrir le vault dans Obsidian, activer le CLI
  (Réglages → Général), ouvrir chaque `.base` une fois pour valider sa syntaxe.

## Ce que ce skill ne fait pas

- Il ne duplique pas le contenu de l'INIT : il le lit dans le vault.
- Il n'écrit rien dans le kit.
- Il ne crée pas de dépôt GitHub sans que le compte ait été confirmé.
````

- [ ] **Step 2: Vérifier que le frontmatter est bien formé**

Run:

```bash
head -4 .claude/skills/new-vault/SKILL.md
```

Expected: `---`, puis `name: new-vault`, puis la ligne `description: …`, puis `---`.

- [ ] **Step 3: Vérifier la commande que le skill produit**

Run:

```bash
./init-vault.sh --no-launch --path /tmp/vaults-skill/vault-essai \
  --contexte PERSO --repo vault-essai --account moncompte
```

Expected: sortie 0, récapitulatif affiché, `/tmp/vaults-skill/vault-essai/INIT-vault-gh-obsidian.md` contient `- Contexte : PERSO`.

Nettoyer :

```bash
rm -rf /tmp/vaults-skill
```

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/new-vault/SKILL.md
git commit -m "ajoute le skill new-vault pour le mode via Claude

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: README — les trois entrées

**Files:**
- Modify: `README.md` — section « Usage » (lignes 69-93 avant édition), insertion avant « Prérequis », ajout en fin de « Sources & inspiration »

**Interfaces:**
- Consumes: l'interface finale du script (Tasks 2-3) et le nom du skill (Task 5).
- Produces: rien dont dépend une autre tâche.

- [ ] **Step 1: Remplacer la section « Usage »**

Dans `README.md`, remplacer intégralement la section qui va de `## Usage` jusqu'à la ligne qui précède `## Après l'init : la vie du vault` par :

```markdown
## Usage

Trois entrées, un seul comportement. Dans tous les cas, l'agent demande votre profil,
**présente un plan et attend votre validation** avant d'écrire quoi que ce soit.

### Depuis Claude Code (le plus simple)

Ouvrez une session dans le kit et demandez la création :

```bash
cd vault-init-kit && claude
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
```

- [ ] **Step 2: Ajouter l'arborescence du kit**

Dans `README.md`, juste avant la section `## Prérequis`, insérer :

```markdown
## Ce que contient le kit

```
vault-init-kit/
├── init-vault.sh                    # paramétrage : questions, garde-fous, préparation
├── INIT-vault-gh-obsidian.md        # la recette, consommée une fois par vault
├── .claude/skills/new-vault/        # le mode « via Claude »
├── tests/test-init-vault.sh         # tests du script (bash pur)
└── docs/                            # contexte de conception + specs et plans
```
```

- [ ] **Step 3: Ajouter la note sur l'écart docs / kit**

Dans `README.md`, à la fin de la section `## Sources & inspiration`, juste avant
`Méthode PARA : Tiago Forte, *Building a Second Brain*.`, insérer :

```markdown
> À noter : la page concept décrit un troisième vault « vie courante », synchronisé
> et accessible sur mobile. Il est hors du périmètre de ce kit, qui produit des
> vaults **desktop uniquement, sans sync automatique**.
```

- [ ] **Step 4: Vérifier qu'aucune mention obsolète ne subsiste**

Run:

```bash
grep -n "3 questions\|chmod +x init-vault" README.md
```

Expected: aucune sortie (la mention « 3 questions » et l'ancienne invocation ont disparu).

- [ ] **Step 5: Vérifier la suite complète**

Run: `./tests/test-init-vault.sh`
Expected: PASS — `43 test(s) OK`, sortie 0.

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "documente les trois entrees de creation d'un vault

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Vérification finale (après la Task 6)

- [ ] `./tests/test-init-vault.sh` → `43 test(s) OK`
- [ ] `./init-vault.sh --help` → aide affichée, sortie 0
- [ ] `git status` propre, six commits ajoutés
- [ ] **Essai de bout en bout, à déclencher par l'utilisateur** : création d'un
      `vault-test` jetable dans les deux modes, puis suppression du dépôt GitHub.
      Ne rien créer sur le compte de l'utilisateur sans validation explicite.
