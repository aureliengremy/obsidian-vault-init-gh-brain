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

# Bac à sable : ni gh ni claude réels pendant les tests (aucun réseau,
# et un résultat indépendant de l'état d'authentification de la machine).
STUB_DIR=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' > "$STUB_DIR/gh"
printf '#!/bin/sh\nexit 1\n' > "$STUB_DIR/claude"
chmod +x "$STUB_DIR/gh" "$STUB_DIR/claude"
PATH="$STUB_DIR:$PATH"
export PATH

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

# run_tty_limite <réponses> <args...> : comme run_tty, mais tue le script
# au bout de ~5 s et renvoie RUN_RC=124. Sert à prouver qu'il ne boucle pas.
run_tty_limite() {
  local answers=$1; shift
  local out pid n
  out=$(mktemp)
  ( printf '%s' "$answers" | VAULT_INIT_ASSUME_TTY=1 "$SCRIPT" "$@" >"$out" 2>&1 ) &
  pid=$!
  n=0
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 50 ]; do
    sleep 0.1
    n=$((n + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    RUN_RC=124
  else
    wait "$pid"
    RUN_RC=$?
  fi
  RUN_OUT=$(cat "$out")
  rm -f "$out"
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

# --- 2. Cas nominal : flags complets ------------------------------------
printf '\n%sCas nominaux%s\n' "$BOLD" "$RESET"

TMP=$(mktmp)
run --no-launch --parent "$TMP" --name vault-test \
    --contexte PRO --repo depot-test --account moncompte
check "$RUN_RC" "0" "cas nominal : sortie 0"
P="$TMP/vault-test/$INIT_NAME"
[ -f "$P" ]; assert $? "cas nominal : INIT copié dans le vault"
if [ -f "$P" ]; then
  grep -Fqx -- "- Contexte : PRO" "$P";                      assert $? "cas nominal : contexte écrit"
  grep -Fqx -- "- Dépôt GitHub : depot-test" "$P";           assert $? "cas nominal : dépôt écrit"
  grep -Fqx -- "- Compte GitHub : moncompte" "$P";           assert $? "cas nominal : compte écrit"
  grep -Fqx -- "- Chemin du vault : $TMP/vault-test" "$P";   assert $? "cas nominal : chemin écrit"
fi
rm -rf "$TMP"

# --- 3. Défaut : --repo omis → nom du vault -----------------------------
TMP=$(mktmp)
run --no-launch --parent "$TMP" --name vault-perso --contexte PERSO --account moncompte
check "$RUN_RC" "0" "repo par défaut : sortie 0"
grep -Fqx -- "- Dépôt GitHub : vault-perso" "$TMP/vault-perso/$INIT_NAME" 2>/dev/null
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

# --- 12. Substitution impossible : sortie 1, rien créé ------------------
# Tourne contre une copie jetable du kit : aucun fichier versionné n'est
# touché (pas de sauvegarde ni de trap de restauration nécessaires).
FAUX_KIT=$(mktmp)
TMP=$(mktmp)
cp "$SCRIPT" "$FAUX_KIT/init-vault.sh"
chmod +x "$FAUX_KIT/init-vault.sh"
sed 's/^- Contexte :$/- Contexte ALTEREE :/' "$KIT_INIT" > "$FAUX_KIT/$INIT_NAME"
RUN_OUT=$("$FAUX_KIT/init-vault.sh" --no-launch --path "$TMP/vault-altere" \
          --contexte PERSO --account moncompte </dev/null 2>&1)
RUN_RC=$?
check "$RUN_RC" "1" "substitution impossible : sortie 1"
[ ! -e "$TMP/vault-altere" ]; assert $? "substitution impossible : rien créé"
rm -rf "$FAUX_KIT" "$TMP"

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
  grep -Fqx -- "- Contexte : PERSO" "$P";            assert $? "interactif : « 1 » vaut PERSO"
  grep -Fqx -- "- Dépôt GitHub : depot-inter" "$P";  assert $? "interactif : dépôt saisi"
  grep -Fqx -- "- Compte GitHub : moncompte" "$P";   assert $? "interactif : compte saisi"
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
grep -Fqx -- "- Dépôt GitHub : vault-defaut" "$TMP/vault-defaut/$INIT_NAME" 2>/dev/null
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
grep -Fqx -- "- Contexte : PRO" "$TMP/vault-boucle/$INIT_NAME" 2>/dev/null
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

# --- 17..18. Fin de flux prématurée : le script meurt, il ne boucle pas --
printf '\n%sFin de flux prématurée%s\n' "$BOLD" "$RESET"

# Aucune réponse : EOF dès la première question sans défaut (le nom du vault)
TMP=$(mktmp)
run_tty_limite "$TMP
" --no-launch
check "$RUN_RC" "1" "EOF sur le nom : sortie 1 (pas de boucle)"
[ ! -e "$TMP/vault-inexistant" ]; assert $? "EOF sur le nom : rien créé"
rm -rf "$TMP"

# Parent et nom fournis, EOF au moment du contexte
TMP=$(mktmp)
run_tty_limite "$TMP
vault-eof
" --no-launch
check "$RUN_RC" "1" "EOF sur le contexte : sortie 1 (pas de boucle)"
[ ! -e "$TMP/vault-eof" ]; assert $? "EOF sur le contexte : rien créé"
rm -rf "$TMP"

rm -rf "$STUB_DIR"

# --- Bilan --------------------------------------------------------------
printf '\n'
if [ "$FAIL" -eq 0 ]; then
  printf '%s%d test(s) OK%s\n\n' "$GREEN" "$PASS" "$RESET"
  exit 0
else
  printf '%s%d échec(s) sur %d%s\n\n' "$RED" "$FAIL" "$((PASS + FAIL))" "$RESET"
  exit 1
fi
