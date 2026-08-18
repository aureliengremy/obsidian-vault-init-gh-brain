#!/usr/bin/env bash
#
# init-vault.sh — Initialise un nouveau vault Obsidian « second brain »
# (PARA + GitHub + Claude Code) à partir de INIT-vault-gh-obsidian.md.
#
# Usage :
#   ./init-vault.sh <chemin-du-nouveau-vault>
#
# Exemples :
#   ./init-vault.sh ~/vaults/vault-perso
#   ./init-vault.sh ~/vaults/vault-pro
#
# Le script vérifie les prérequis, prépare le dossier, y copie l'INIT,
# puis lance Claude Code avec la consigne d'initialisation. Le reste
# (questions, génération, dépôt GitHub) se passe dans Claude Code.

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

# --- Arguments ----------------------------------------------------------
[ $# -eq 1 ] || die "Usage : ./init-vault.sh <chemin-du-nouveau-vault>"

TARGET=$1
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INIT_FILE="$SCRIPT_DIR/INIT-vault-gh-obsidian.md"

echo
echo "${BOLD}Initialisation d'un vault second brain${RESET}"
echo "Cible : $TARGET"
echo

# --- Prérequis ----------------------------------------------------------
[ -f "$INIT_FILE" ] || die "INIT-vault-gh-obsidian.md introuvable à côté du script."

command -v git >/dev/null 2>&1 || die "git n'est pas installé."
ok "git présent"

command -v claude >/dev/null 2>&1 || die "Claude Code (claude) n'est pas installé. → https://claude.com/claude-code"
ok "Claude Code présent"

if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    ACCOUNT=$(gh api user --jq .login 2>/dev/null || echo "?")
    ok "GitHub CLI authentifié (compte : ${BOLD}${ACCOUNT}${RESET})"
    warn "Vérifie que c'est le BON compte pour ce vault (perso vs pro) —"
    warn "l'INIT te le redemandera avant de créer le dépôt."
  else
    warn "gh est installé mais non authentifié. Lance 'gh auth login' d'abord,"
    warn "ou l'INIT te donnera les commandes manuelles."
  fi
else
  warn "GitHub CLI (gh) absent : la création du dépôt sera manuelle."
fi

if command -v obsidian >/dev/null 2>&1; then
  ok "Obsidian CLI présent (les dashboards pourront être interrogés)"
else
  warn "Obsidian CLI absent (Obsidian ≥ 1.12, Réglages → Général)."
  warn "Non bloquant : l'agent utilisera le fallback dashboard.md."
fi

# --- Préparation du dossier --------------------------------------------
# Garde-fou : le vault ne doit JAMAIS être créé dans le dépôt du kit
# (Git imbriqué = croisement interdit entre l'outil et ses produits).
TARGET_ABS=$(cd "$(dirname "$TARGET")" 2>/dev/null && pwd)/$(basename "$TARGET") || TARGET_ABS=$TARGET
case "$TARGET_ABS" in
  "$SCRIPT_DIR"/*|"$SCRIPT_DIR")
    die "La cible est à l'intérieur du dépôt du kit. Choisis un dossier hors du kit (ex. ~/vaults/vault-perso)." ;;
esac

if [ -e "$TARGET" ]; then
  [ -d "$TARGET" ] || die "$TARGET existe et n'est pas un dossier."
  if [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
    die "$TARGET n'est pas vide. L'INIT s'exécute dans un dossier vide."
  fi
else
  mkdir -p "$TARGET"
fi
ok "Dossier prêt"

cp "$INIT_FILE" "$TARGET/"
ok "INIT copié dans le vault"

# --- Lancement ----------------------------------------------------------
echo
echo "${BOLD}Lancement de Claude Code...${RESET}"
echo "L'agent va te poser 3 questions (contexte, nom du dépôt, compte GitHub)."
echo

cd "$TARGET"
exec claude "Lis INIT-vault-gh-obsidian.md et exécute l'initialisation, phase par phase."
