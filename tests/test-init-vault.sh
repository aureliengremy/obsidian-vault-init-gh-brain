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

printf '\n%sTests init-vault.sh%s\n\n' "$BOLD" "$RESET"

# --- 1. Le kit expose le bloc Paramètres vide ---------------------------
printf '%sBloc Paramètres du kit%s\n' "$BOLD" "$RESET"

grep -Fqx '## Paramètres' "$KIT_INIT"
assert $? "le kit contient la section ## Paramètres"

for cle in '- Contexte :' '- Dépôt GitHub :' '- Compte GitHub :' '- Chemin du vault :'; do
  grep -Fqx -- "$cle" "$KIT_INIT"
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
