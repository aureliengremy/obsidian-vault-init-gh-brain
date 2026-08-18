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

is_kebab() { [[ $1 =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; }

# refuse_multiligne <valeur> <nom du champ> — un saut de ligne corromprait le bloc
refuse_multiligne() {
  case "$1" in
    *"
"*) die "Valeur invalide pour $2 : un retour à la ligne n'est pas autorisé." ;;
  esac
}

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
    read -r __reply || die "Entrée interrompue avant la réponse à : $__prompt."
    [ -n "$__reply" ] || __reply=$__default
    [ -n "$__reply" ] && break
    warn "Une valeur est requise."
  done
  printf -v "$__var" '%s' "$__reply"
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
  is_tty || die "Valeur manquante : contexte. Fournis --contexte PERSO|PRO."
  CTX_REPLY=""
  while :; do
    printf 'Contexte — 1) PERSO  2) PRO : '
    read -r CTX_REPLY || die "Entrée interrompue avant la réponse au contexte (PERSO/PRO)."
    if CONTEXTE=$(normalise_contexte "$CTX_REPLY"); then break; fi
    warn "Réponds PERSO, PRO, 1 ou 2."
  done
fi

# Chemin cible et nom du vault
if [ -n "$PATH_ARG" ]; then
  TARGET_ABS=$(resolve_abs "$PATH_ARG")
  NAME=$(basename "$TARGET_ABS")
else
  TARGET_ABS=$(resolve_abs "$PARENT/$NAME")
fi

# Un retour à la ligne réel dans une valeur corromprait le bloc ## Paramètres
# (nouvelles lignes injectées) et, pour --parent, le nom du dossier créé.
# Ce contrôle précède les garde-fous et toute création : aucun des trois
# volets de la correction (ce contrôle, is_kebab ancré, validation post-awk)
# ne suffit seul.
refuse_multiligne "$NAME" "le nom du vault"
refuse_multiligne "$TARGET_ABS" "le chemin du vault"

is_kebab "$NAME" \
  || die "Nom de vault invalide : « $NAME ». Attendu du kebab-case (ex. vault-perso)."

ask REPO    "Nom du dépôt GitHub" "$NAME"
ask ACCOUNT "Compte ou organisation GitHub" "$GH_ACCOUNT"

refuse_multiligne "$REPO" "le dépôt GitHub"
refuse_multiligne "$ACCOUNT" "le compte GitHub"

# En contexte PRO, le compte doit être confirmé de vive voix.
# Non interactif : l'appelant (skill ou flags) porte cette responsabilité.
if [ "$CONTEXTE" = "PRO" ] && is_tty; then
  PRO_REPLY=""
  printf 'Contexte PRO : le compte « %s » est-il autorisé pour du contenu de travail ? [o/N] ' "${ACCOUNT:-?}"
  read -r PRO_REPLY || die "Entrée interrompue avant la confirmation PRO. Rien n'a été créé."
  case "$PRO_REPLY" in
    [oOyY]*) ok "Compte confirmé" ;;
    *)       die "Confirmation refusée. Rien n'a été créé." ;;
  esac
fi

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
# L'INIT paramétré est construit et validé AVANT toute création :
# un échec ne doit laisser ni dossier ni fichier derrière lui.
TMP_INIT=$(mktemp "${TMPDIR:-/tmp}/init-vault.XXXXXX")
trap 'rm -f "$TMP_INIT"' EXIT

CTX="$CONTEXTE" REPO_V="$REPO" ACCT="$ACCOUNT" VPATH="$TARGET_ABS" LC_ALL=C awk '
  /^- Contexte :/        { print "- Contexte : " ENVIRON["CTX"];         next }
  /^- Dépôt GitHub :/    { print "- Dépôt GitHub : " ENVIRON["REPO_V"];  next }
  /^- Compte GitHub :/   { print "- Compte GitHub : " ENVIRON["ACCT"];   next }
  /^- Chemin du vault :/ { print "- Chemin du vault : " ENVIRON["VPATH"]; next }
  { print }
' "$INIT_FILE" > "$TMP_INIT"

grep -Fqx -- "- Contexte : $CONTEXTE" "$TMP_INIT" \
  || die "Le bloc ## Paramètres n'a pas pu être rempli — l'INIT du kit a-t-il été modifié ?"

# Chaque clé doit apparaître exactement une fois : une valeur qui aurait
# échappé aux contrôles ci-dessus (nouvelle ligne injectée) dupliquerait ou
# ajouterait une clé ici. Ce contrôle est complémentaire du grep ci-dessus :
# l'un détecte une substitution qui n'a pas pris, l'autre une clé absente ou
# dupliquée.
# Ancré en début de ligne (comme les motifs awk /^.../ ci-dessus) : une valeur
# qui contient littéralement le texte d'une clé (ex. antislash-n suivi du nom
# d'une clé, resté inerte sur sa propre ligne) ne doit pas compter comme une
# clé dupliquée — seule une VRAIE ligne de clé en tête compte.
for cle in "- Contexte :" "- Dépôt GitHub :" "- Compte GitHub :" "- Chemin du vault :"; do
  n=$(grep -c -- "^$cle" "$TMP_INIT" || true)
  [ "$n" -eq 1 ] \
    || die "Le bloc ## Paramètres est corrompu ($n occurrence(s) de « $cle »)."
done

mkdir -p "$TARGET_ABS" 2>/dev/null || die "Impossible de créer $TARGET_ABS (droits insuffisants ?)."
ok "Dossier prêt : $TARGET_ABS"

mv "$TMP_INIT" "$TARGET_ABS/$INIT_NAME"
chmod 644 "$TARGET_ABS/$INIT_NAME"
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
