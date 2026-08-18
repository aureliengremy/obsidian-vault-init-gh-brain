# Résumé — How I Run My Whole Life From Obsidian And Claude Code

- **Vidéo** : https://www.youtube.com/watch?v=Ws7lekerTrA
- **Auteur** : se présente par son prénom, que le transcript automatique rend « Artum » ; physicien de formation, il construit ce système depuis deux ans
- **Langue source** : anglais (auto-généré)
- **Source** : résumé du transcript `how-i-run-my-whole-life-from-obsidian-and-claude-code-Ws7lekerTrA-en/transcript.md`

> Le transcript est auto-généré et malmène le vocabulaire : « Claude » y devient
> *cloud*, *cloth*, *clo* ou *CL*, « AI » devient *EI*, « notes » devient *nodes* et
> « vault » devient *world*. Les termes sont rétablis ici.

## TL;DR

Tout tient dans **un dossier de fichiers texte**, ouvert avec Obsidian et pointé par
Claude Code. Trois composants seulement : le dossier, un fichier que l'agent lit avant de
toucher à quoi que ce soit, et l'agent lui-même. L'objectif n'était pas de s'organiser
mais d'**arrêter de réexpliquer sa vie à une IA à chaque ouverture**. Le cœur technique
tient en deux problèmes distincts qui appellent deux réponses distinctes : l'agent *ne
vous connaît pas* (réponse : un `CLAUDE.md` chargé à chaque session) et il *ne peut pas
tout lire* (réponse : des tableaux de bord agrégés qu'on interroge au lieu de parcourir
les fichiers). S'y ajoutent des routines déclenchées pendant le sommeil et un **système
rétrospectif** qui réinjecte chaque correction dans la mémoire ou les skills — « toute la
différence entre utiliser une IA et en entraîner une ». La vidéo se termine sur un aveu
rare : après un an, son propre système est en désordre, et ça n'empêche rien.

## Le système

### 1. Trois composants, pas plus

Un dossier, un fichier lu par l'agent avant toute action, et Claude Code — ou n'importe
quel agent — pointé sur ce dossier. C'est tout.

### 2. Le dossier : du texte, et rien d'autre

- Ce sont **des fichiers texte sur son disque**. Obsidian n'est qu'« une jolie fenêtre sur
  ce dossier » : supprimé, tous les fichiers restent et s'ouvrent avec n'importe quoi.
- L'enjeu est plus important qu'il n'y paraît : **rien de ce qu'on construit n'est
  prisonnier** — ni d'une application, ni d'une IA, ni du cloud de qui que ce soit.
- Chaque note porte quelques champs en tête : **le type de note, son état, la date**. Ce
  sont eux qui feront avancer les choses toutes seules plus tard.
- Les notes se lient entre elles par double crochet, avec un graphe local pour visualiser
  les relations.

### 3. Brancher l'agent

Installer l'outil, choisir comme répertoire de travail **le dossier du vault**. « Aucun
téléversement, aucun import, aucun compte à connecter. »

Et parce que tout est du texte brut, **on peut changer d'IA** : Claude Code aujourd'hui,
Codex demain. C'est le fondement de l'argument d'indépendance.

### 4. Ce qu'un dossier permet qu'une fenêtre de chat ne permet pas

Sa démonstration : demander une analyse des notes quotidiennes pour dégager les schémas
récurrents de la semaine et les actions à plus fort levier.

- L'agent lit en direct l'ensemble des notes quotidiennes **et** des revues
  hebdomadaires, construit un tableau des scores par domaine de vie, et produit un rapport
  HTML consultable.
- L'analyse est pertinente « parce qu'elle repose uniquement sur les notes que j'écris ».
- Il pose lui-même la limite : « ce n'est qu'un avis, un second regard, à prendre ou à
  laisser ». La valeur est dans la **vue d'ensemble sur une longue période**.

### 5. Deux problèmes distincts — la colonne vertébrale de la vidéo

- **L'agent ne vous connaît pas.** À chaque nouvelle session il oublie qui vous êtes, sur
  quoi vous travaillez, vos préférences, vos règles.
- **L'agent ne peut pas tout lire.** Il ne lit qu'environ **300 fichiers** d'un coup ; la
  fenêtre de contexte ne suffit pas pour un vault de milliers de notes. Pire, une demande
  vague le fait **parcourir tout le vault** et gaspiller son contexte en recherche.
- ⚠ Le seuil qu'il donne : la commande `/context` le montre à **136 k tokens** au moment
  de la démonstration, et **au-delà d'environ 300 k tokens** commence selon lui une zone
  où « l'agent prend des raccourcis et fait de mauvais choix ». Ce sont ses chiffres, sans
  référence.

« Deux problèmes, et ils appellent deux réponses différentes. »

### 6. Réponse au premier problème — un seul fichier

Un `CLAUDE.md` chargé automatiquement à chaque démarrage de session.

- **L'astuce de portabilité** : ce fichier demande de lire un `AGENTS.md`, ce qui rend le
  vault **indépendant du modèle et du fournisseur**. « Aujourd'hui Claude, mais qui sait,
  dans un mois ce sera Codex. »
- **Ce qu'il y met** : la carte de ses différents vaults (personnel, client) ; comment
  travailler avec lui — « je suis physicien, j'aime raisonner à partir des principes
  premiers et remettre en question les bonnes pratiques » ; son style de travail, son
  profil de voix, ce qu'il faut lire avant de rédiger ; des **règles dures sur ce qu'il ne
  faut jamais faire**, dont ne jamais exposer d'identifiants ; ses skills ; et la
  structure du vault, « incroyablement importante pour que l'agent sache où il est au lieu
  de fouiller à l'aveugle ».
- **La dernière section est la plus importante** : à chaque fois que l'agent se trompe ou
  casse quelque chose, il y ajoute une ligne pour qu'il déclenche son skill rétrospectif,
  réfléchisse à la session et mette à jour les règles — « pour qu'il ne refasse jamais
  cette erreur ».
- Et comme c'est un fichier texte : lisible, modifiable, versionnable, et transportable
  vers une autre IA l'an prochain.

### 7. Réponse au second problème — les tableaux de bord

Un type de note appelé **dashboard**, regroupé dans un seul dossier, qui agrège
l'information par sujet.

- Ils reposent sur les **bases Obsidian** — des tableaux qu'on peut embarquer dans
  n'importe quel fichier. Problème : **l'agent ne sait pas les lire nativement**.
- La solution : **Obsidian CLI**, une interface en ligne de commande qui permet d'exécuter
  depuis un terminal n'importe quelle commande de la palette. Il démontre la liste des
  vues d'une base, puis une requête qui renvoie les résultats **dans un format structuré**,
  celui que l'agent préfère.
- **Le déblocage réel** : on ne lit plus les fichiers un par un — qui peuvent être très
  longs — on lit **une seule vue de tableau**. C'est ce qui rend la solution économe en
  contexte.
- **L'agent a d'abord échoué**, ne sachant pas se servir de l'outil. Sa réponse : lui
  fournir les **skills Obsidian de Kepano**, après quoi il exécute la requête tout seul.
- Le concept est généralisable : un tableau de bord par projet, par idée, « littéralement
  n'importe quoi ». S'y ajoutent des commandes pour chercher dans le vault, suivre les
  liens sortants d'une note, ou récupérer toutes les notes portant une propriété donnée —
  **sans tout lire**.

### 8. Les routines — la partie qui tourne pendant le sommeil

« C'est la partie que j'utilise le plus, et elle se passe pendant que je dors. »

- Une routine déclenchée à **6 h du matin** tous les jours : l'agent ouvre son tableau de
  bord d'alignement, fait la revue quotidienne et la planification de la journée, puis lui
  pose des questions sur son sommeil, son ressenti, son énergie, ses objectifs et le
  prochain pas à faire.
- Les réponses sont écrites dans sa note du jour. « Je n'ai rien lancé, je n'étais même pas
  devant l'ordinateur — je me lève et tout est prêt. »
- **Le revers, qu'il énonce lui-même** : l'ordinateur doit rester allumé et connecté. Sa
  parade : `caffeinate` sur son Mac pour qu'il ne se mette jamais en veille.

### 9. Le tableau de bord quotidien

Toutes les entrées journalières suivent un modèle — humeur, énergie — et alimentent le
**tableau de bord d'alignement** : scores de sommeil, énergie, régularité à la salle.
Plus d'un an de données accumulées, ce qui permet d'observer les tendances sur une année
entière.

### 10. Les sessions et leurs plans

Un autre type de note : le **contexte donné au modèle pour travailler sur une tâche**.

- Une session porte un **statut** (proposé, actif), un **livrable**, des **contraintes** et
  une **définition du terminé**.
- On passe le statut à actif et on demande à l'agent de charger le contexte de cette note
  dans la session de travail. Une session peut **s'étaler sur plusieurs jours sans perdre
  le contexte**.
- Chaque session a son **plan** : les étapes à suivre pour atteindre l'objectif. Il insiste
  sur la nécessité : sans spécification, « le résultat sera générique », il faudra
  recommencer, et la qualité restera moyenne.

### 11. Le système rétrospectif — la boucle

Un skill qu'il lance **sur chaque session** : analyser la session en cours et extraire les
enseignements à réinjecter dans le système.

- **Étape 1 — extraire les signaux** : les corrections, le travail effectué, les étapes
  manquantes, ce qui a bien marché.
- **Étape 2 — cartographier** : déterminer où chaque correction doit atterrir, dans quelle
  partie du vault et dans quel skill.
- **Le critère de routage, énoncé clairement** : si l'enseignement doit être **partagé sur
  l'ensemble du travail**, il va dans la **mémoire** ; sinon, il va dans les **skills**.
- **L'humain garde la main** : l'agent propose des diffs, l'auteur choisit ce qu'il applique.
- Le résultat : « rien de ce que vous faites ne disparaît » — l'erreur commise ne reviendra
  pas la semaine suivante. « C'est toute la différence entre utiliser une IA et en
  entraîner une. »
- Le renversement qu'il souligne : ce n'est plus vous qui vous adaptez à l'outil, c'est
  l'outil qu'on éduque à votre façon de travailler.

### 12. L'aveu final

Il montre son système **après un an**, et le qualifie de désordre : des liens qui pointent
vers des notes supprimées, des centaines de notes qui ne mènent à rien, des notes encore
marquées « en cours » et plus touchées depuis le printemps.

« Mais ça ne m'empêche pas de livrer le travail. Le système n'a pas besoin d'être parfait,
il a besoin de vous apporter de la valeur. »

## Citations marquantes

- « Je n'ai pas construit ça pour être organisé. Je l'ai construit pour arrêter de réexpliquer ma vie à une IA à chaque fois que je l'ouvre. » *(traduit)*
- « Si je supprime Obsidian maintenant, tous ces fichiers sont encore là — rien de ce que vous construisez ici n'est prisonnier. » *(traduit)*
- « Deux problèmes, et ils appellent deux réponses différentes : il ne me connaît pas, et il ne peut pas tout lire. » *(traduit)*
- « On ne lit pas tous les fichiers. On lit juste cette vue de tableau. » *(traduit)*
- « C'est toute la différence entre utiliser une IA et en entraîner une. » *(traduit)*
- « Le système n'a pas besoin d'être parfait. Il a besoin de vous apporter de la valeur pour livrer votre travail. » *(traduit)*

## À retenir

- **Le texte brut est la garantie d'indépendance.** Des fichiers dans un dossier survivent à l'application qui les affiche, au modèle qui les lit et au fournisseur qui l'héberge. Tout le reste du système en découle.
- **Séparer les deux problèmes est l'idée structurante.** « Il ne me connaît pas » et « il ne peut pas tout lire » sont deux pannes différentes ; les confondre mène à empiler du contexte au lieu de l'organiser.
- **Un fichier d'entrée qui en appelle un autre** (`CLAUDE.md` → `AGENTS.md`) suffit à rendre l'installation portable d'un agent à l'autre. Le coût est d'une ligne.
- **Agréger avant d'interroger.** Lire une vue de tableau plutôt que mille fichiers est ce qui rend le système tenable quand le vault grossit — c'est le vrai verrou technique, et il se résout par la structure, pas par une fenêtre de contexte plus grande.
- **Un agent bloqué sur un outil se débloque avec un skill**, pas avec un meilleur prompt. Sa démonstration le montre en direct : échec, ajout du skill, réussite.
- **Écrire la correction là où elle sera relue.** Le critère mémoire/skills — partagé partout ou spécifique à une tâche — est simple et transposable à n'importe quelle installation d'agent.
- **Garder la main sur ce qui est appliqué** : l'agent propose des diffs, l'humain tranche. Un système qui se corrige tout seul sans validation corrigerait aussi ce qu'il ne fallait pas.
- **Spécifier ou refaire.** Sans livrable, contraintes et définition du terminé, le résultat est générique et le travail est à recommencer.
- **Un système imparfait qui sert vaut mieux qu'un système propre qu'on entretient.** L'aveu final — liens morts, notes orphelines, statuts périmés — est la partie la plus utile de la vidéo pour quiconque a déjà abandonné un système de notes par culpabilité.
- ⚠ **Les seuils chiffrés sont les siens** : environ 300 fichiers lisibles d'un coup, une zone de dégradation au-delà d'environ 300 k tokens. Ce sont des observations d'usage, présentées sans référence, et elles dépendent du modèle et de la version.
- ⚠ **La vidéo mène à un programme payant**, mentionné deux fois — au milieu de l'explication puis en conclusion. Le contenu technique reste utilisable tel quel sans y souscrire.
