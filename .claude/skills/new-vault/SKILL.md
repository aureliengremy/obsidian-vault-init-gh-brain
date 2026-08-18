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
