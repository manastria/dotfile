# `docx2pdf.sh` — .docx vers PDF et PDF « 2 pages par feuille »

> Script : [`.local/bin/docx2pdf.sh`](../.local/bin/docx2pdf.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`docx2pdf.sh` convertit un ou plusieurs documents Word `.docx` en PDF, puis fabrique pour chacun un second PDF « 2 pages par feuille » (A4 paysage, avec un cadre autour des pages) prêt pour la photocopieuse : `fiche.docx` donne `fiche.pdf` et `fiche-2p.pdf`, à côté du `.docx` ou dans le dossier de `--out`. Il se lance sous WSL, pilote Word côté Windows et fait l'imposition avec `pdfjam`. Le PDF est **exporté par Word lui-même**, jamais obtenu en « imprimant vers un PDF » : un pilote d'impression réécrit les polices et provoque des espaces parasites à la photocopieuse. Le script ne produit pas de `.docx` (voir `md2docx.sh` pour cela) et ne modifie jamais le `.docx` d'origine. Avec `--fusion NOM`, tous les `.docx` donnent **un seul** PDF `NOM.pdf` (et `NOM-2p.pdf`), dans l'ordre de la ligne de commande, ou alphabétique si l'on passe un joker comme `chapitre-*.docx` ; `--feuille-par-doc` y ajoute une page blanche après chaque document de pages impaires pour que chacun commence sur une nouvelle feuille à la photocopie. Les options utiles au quotidien sont `--sans-2p` (le PDF seul), `--fusion NOM` (un seul PDF pour tous les documents) et `--moteur libreoffice` (sans Word).

---

## Section utilisateur

### Description

`docx2pdf.sh` enchaîne en une commande ce qui se faisait en deux temps dans deux shells différents : l'export PDF par Word (PowerShell) puis l'imposition par `pdfjam` (bash). Il ne fait pas la conversion Markdown vers `.docx` : c'est le rôle de [`md2docx.sh`](md2docx.md).

Équivalent manuel, pour un fichier :

```bash
# côté PowerShell : export par Word ($d = document ouvert en lecture seule, 17 = PDF)
$d.ExportAsFixedFormat('C:\...\fiche.pdf', 17)
# côté bash : imposition
pdfjam --nup 2x1 --landscape --a4paper --frame true --outfile fiche-2p.pdf fiche.pdf
```

Par défaut, chaque `.docx` donne ses propres PDF. Avec `--fusion NOM`, les documents sont exportés un par un puis mis bout à bout dans **un seul** PDF `NOM.pdf` (par `pdfunite`, sans rien ré-encoder), et c'est ce PDF-là qui est mis « 2 pages par feuille » : `NOM-2p.pdf`. Aucun `FICHIER.pdf` individuel n'est alors écrit. L'ordre des pages est celui des fichiers sur la ligne de commande ; avec un joker, c'est le shell qui développe la liste par ordre alphabétique, le script n'a rien à trier.

Un document de pages impaires partage alors sa dernière feuille avec le début du suivant. Avec `--feuille-par-doc`, le script ajoute une page blanche à la fin de chaque document de pages impaires (sauf le dernier) : chaque document commence sur une nouvelle feuille, dans le PDF « 2 pages par feuille » comme à l'impression recto verso.

Le choix de l'export Word tient à un problème rencontré avec une fiche de cours : le PDF « 2 pages par feuille » avait été fabriqué en réimprimant le PDF de Word avec un pilote d'impression Windows (PDF-XChange en mode GDI). Ce pilote réécrit le texte lettre par lettre ; la photocopieuse affichait alors « Par où comme ence r » au lieu de « Par où commencer », alors que le fichier était correct à l'écran. `pdfjam` inclut au contraire les pages d'origine telles quelles.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| WSL | le script s'exécute sous WSL (il appelle des programmes Windows) | `wslpath -w .` |
| Microsoft Word (Windows) | export du PDF, moteur par défaut | `powershell.exe -NoProfile -Command "Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winword.exe'"` |
| LibreOffice (Windows ou Linux) | moteur de remplacement, avec `--moteur libreoffice` | `ls "/mnt/c/Program Files/LibreOffice/program/soffice.exe"` ou `soffice --version` |
| `pdfjam` | imposition 2 pages par feuille, et pages blanches de `--feuille-par-doc` (paquet `texlive-extra-utils`) | `pdfjam --version` |
| `pdfinfo` | nombre de pages et producteur du PDF (paquet `poppler-utils`) | `pdfinfo -v` |
| `pdfunite` | fusion des PDF, avec `--fusion` seulement (paquet `poppler-utils`) | `pdfunite -v` |

### Syntaxe

```bash
docx2pdf.sh FICHIER.docx... [--out DOSSIER] [--sans-2p] [--sans-cadre]
                            [--fusion NOM [--feuille-par-doc]] [--moteur word|libreoffice]
docx2pdf.sh -h|--help
```

| Option / argument | Défaut | Description |
| ------------------ | ------ | ----------- |
| `FICHIER.docx...` | — (obligatoire) | Un ou plusieurs documents à convertir, en liste explicite ou avec un joker (`*.docx`) |
| `--out DOSSIER` | dossier de chaque `.docx` (avec `--fusion` : celui du premier) | Dossier de sortie, créé si besoin |
| `--sans-2p` | désactivé | Ne produit pas le PDF `-2p` (le PDF simple seulement) |
| `--sans-cadre` | désactivé | Pas de cadre autour des pages du PDF 2 pages par feuille |
| `--fusion NOM` | désactivé (un PDF par `.docx`) | Un seul PDF `NOM.pdf` pour tous les `.docx`, dans l'ordre de la ligne de commande. Le `.pdf` de `NOM` est facultatif ; `NOM` ne contient pas de `/` (le dossier se choisit avec `--out`) |
| `--feuille-par-doc` | désactivé | **Avec `--fusion` uniquement** (erreur d'usage sinon) : chaque document commence sur une nouvelle feuille. Une page blanche est ajoutée après chaque document de pages impaires, sauf le dernier. Les pages blanches sont aussi dans `NOM.pdf`, qui garde ainsi la même pagination que `NOM-2p.pdf` |
| `--moteur M` | `word` | `word` ou `libreoffice` |
| `-h`, `--help` | — | Affiche l'en-tête du script, où qu'il soit dans la ligne de commande |

Les PDF existants sont **écrasés** sans question : ce sont des résultats dérivés du `.docx`.

**Ordre des documents avec `--fusion`.** Les pages se suivent dans l'ordre des arguments :

- liste explicite : `intro.docx annexes.docx conclusion.docx` donne l'introduction, les annexes, puis la conclusion ;
- joker : `chapitre-*.docx` est développé **par le shell**, par ordre alphabétique selon la locale (`LC_COLLATE`). Pour un ordre numérique fiable, nommer les fichiers `01-…`, `02-…` : `chapitre-10` passerait avant `chapitre-2` sinon.

Pour vérifier l'ordre avant de lancer (la conversion Word prend du temps), `echo chapitre-*.docx` affiche la liste exacte que recevra le script.

### Exemples d'utilisation

```bash
# Produit fiche.pdf et fiche-2p.pdf à côté de fiche.docx
docx2pdf.sh fiche.docx

# Seulement le PDF, dans un autre dossier
docx2pdf.sh fiche.docx --out ~/pdf --sans-2p

# Tous les .docx du répertoire courant
docx2pdf.sh *.docx

# Sans Word : conversion par LibreOffice
docx2pdf.sh fiche.docx --moteur libreoffice

# Un seul PDF (cours.pdf et cours-2p.pdf), chapitres dans l'ordre alphabétique
docx2pdf.sh chapitre-*.docx --fusion cours

# Ordre choisi à la main, résultat dans un autre dossier
docx2pdf.sh intro.docx annexes.docx conclusion.docx --fusion dossier --out ~/pdf

# Idem, chaque document commençant sur une nouvelle feuille (photocopie)
docx2pdf.sh chapitre-*.docx --fusion cours --feuille-par-doc
```

**Exemple de sortie** (chemins abrégés) :

```
[INFO]      Conversion : fiche (word)
[OK]        …/fiches/fiche.pdf (14 page(s), Microsoft® Word pour Microsoft 365)
[OK]        …/fiches/fiche-2p.pdf (7 feuille(s) A4 paysage)
```

Durée mesurée : environ 14 secondes pour un document de 14 pages, dont une dizaine pour le démarrage de Word.

**Exemple de sortie avec `--fusion`** (`chapitre-*.docx` : trois documents de 1, 2 et 3 pages) :

```
[INFO]      Conversion : chapitre-a (word)
[OK]        chapitre-a.docx (1 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Conversion : chapitre-b (word)
[OK]        chapitre-b.docx (2 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Conversion : chapitre-c (word)
[OK]        chapitre-c.docx (3 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Fusion de 3 PDF dans cours.pdf
[OK]        …/cours.pdf (6 page(s), 3 document(s))
[OK]        …/cours-2p.pdf (3 feuille(s) A4 paysage)
```

Les PDF intermédiaires n'apparaissent pas : ils vivent dans le dossier temporaire et sont supprimés avec lui. Le contenu a été vérifié page par page (a, puis b, puis c) et les polices Word restent incorporées sous leur nom d'origine.

**Exemple de sortie avec `--feuille-par-doc`** (`chapitre-*.docx` plus un quatrième document de 2 pages ; `chapitre-a` a 1 page et `chapitre-c` en a 3) :

```
[INFO]      Conversion : chapitre-a (word)
[OK]        chapitre-a.docx (1 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Page blanche ajoutée après chapitre-a.docx (nombre de pages impair).
[INFO]      Conversion : chapitre-b (word)
[OK]        chapitre-b.docx (2 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Conversion : chapitre-c (word)
[OK]        chapitre-c.docx (3 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Page blanche ajoutée après chapitre-c.docx (nombre de pages impair).
[INFO]      Conversion : annexe (word)
[OK]        annexe.docx (2 page(s), Microsoft® Word pour Microsoft 365)
[INFO]      Fusion de 4 PDF dans lot.pdf
[OK]        …/lot.pdf (10 page(s) dont 2 blanche(s), 4 document(s))
[OK]        …/lot-2p.pdf (5 feuille(s) A4 paysage)
```

Les pages blanches sont les pages 2 et 8 : chaque document commence sur une page impaire, donc à gauche d'une nouvelle feuille (vérifié page par page, avec la taille des pages inchangée).

**Limites à connaître avant d'imprimer un PDF fusionné.**

- Le PDF fusionné n'a **pas de signets** (le PDF de Word en a, pas `pdfunite`).
- Sans `--feuille-par-doc`, le PDF `-2p` est fabriqué à partir du PDF fusionné : un document dont le nombre de pages est impair partage sa dernière feuille avec la première page du document suivant (dans l'exemple de `--fusion` ci-dessus, la feuille 1 porte la page de `chapitre-a` et la première de `chapitre-b`).
- Avec `--feuille-par-doc`, les pages blanches sont **dans `NOM.pdf`** : à l'écran, un document de pages impaires est suivi d'une page vide.

**Vérifier un PDF avant de l'imprimer** : `pdfinfo fiche.pdf | grep Producer` doit afficher le producteur d'origine (« Microsoft® Word… »), et `pdffonts fiche-2p.pdf` les polices du document (par exemple `FiraSans-Regular`), pas des noms comme `~FP71A0`. Le script avertit lui-même si le producteur contient « GDI » ou « Print ».

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Toutes les conversions ont réussi |
| `1` | Erreur d'exécution : outil manquant (`pdfjam`, `pdfinfo`, `pdfunite`, `powershell.exe`), ou échec d'au moins une conversion (avec `--fusion` : échec de la conversion d'un `.docx` ou de la fusion ; rien n'est alors écrit) |
| `2` | Erreur d'usage : aucun fichier, option inconnue, valeur manquante pour `--out`/`--moteur`/`--fusion`, `NOM` de `--fusion` vide ou contenant `/`, `--feuille-par-doc` sans `--fusion`, fichier `.docx` introuvable |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — options et liste `INPUTS[@]` ; `--help` est reconnue à n'importe quelle position. `--fusion` valide son `NOM` ici (non vide, sans `/`, `.pdf` final retiré), et `--feuille-par-doc` est refusée sans `--fusion` (contrôle fait après la boucle, pour que l'ordre des deux options sur la ligne soit indifférent).
2. `validate_inputs` — chaque fichier doit exister et se terminer par `.docx`.
3. `check_tools` — `wslpath`, `pdfinfo`, puis `pdfunite` (avec `--fusion`), `pdfjam` (sauf `--sans-2p`) et `powershell.exe` (moteur Word).
4. `make_tmp` — dossier temporaire côté Windows, supprimé par un `trap ... EXIT`.
5. Selon `FUSION`, soit `convert_all`, soit `fusionner_tout`.

Mode par défaut (un PDF par `.docx`) :

- `convert_all` — boucle `convert_one` sur `INPUTS[@]` en comptant les échecs.
- `convert_one` — `dossier_sortie`, puis `docx_to_pdf` vers `DOSSIER/base.pdf`, puis `imposer_2p`.

Mode `--fusion` :

- `fusionner_tout` — `docx_to_pdf` vers `$TMP/partie-NNN.pdf` pour chaque fichier (numérotés dans l'ordre de `INPUTS[@]`) ; avec `--feuille-par-doc`, `ajouter_page_blanche` sur chaque partie de pages impaires sauf la dernière ; `pdfunite` vers `$TMP/fusion.pdf`, copie vers `DOSSIER/NOM.pdf`, puis `imposer_2p`.

Briques partagées par les deux modes :

- `docx_to_pdf DOCX PDF [LIBELLÉ]` — copie du `.docx` dans le dossier temporaire, `convertir_word` ou `convertir_libreoffice`, copie du PDF vers la destination, affichage des pages et du producteur, avertissement s'il ressemble à un pilote d'impression.
- `imposer_2p PDF` — produit `NOM-2p.pdf` à côté de `NOM.pdf` (`pdfjam`).
- `ajouter_page_blanche PDF` — ajoute une page blanche à la fin du PDF, qu'elle modifie sur place (`pdfjam`, utilisée par `--feuille-par-doc`).
- `dossier_sortie DOCX` — `--out` s'il est donné, sinon le dossier de `DOCX` ; le crée et l'affiche en chemin absolu.

### Détail des choix techniques

**Export par Word, pas impression vers PDF.** `ExportAsFixedFormat` écrit un PDF vectoriel avec les polices incorporées, sans passer par un pilote d'impression. C'est la raison d'être du script (voir *Description*). Les arguments positionnels de l'appel sont `(sortie, 17, ouvrir=$false, optimiser=0 (impression), plage=0, de=1, à=1, éléments=0, propriétés=$true, IRM=$true, signets=1)` : le dernier crée les signets de titres, qui rendent le PDF navigable (vérifié : le PDF de Word les contient, le PDF `-2p` produit par `pdfjam` non).

**Copie dans un dossier temporaire Windows.** Word n'ouvre pas bien un chemin WSL (`\\wsl.localhost\...`) ni un fichier d'un lecteur synchronisé comme Google Drive, et on ne veut pas qu'il écrive dans le dossier de cours. Le dossier est lu par `cmd.exe /c 'echo %TEMP%'`, lancé depuis `/mnt/c` : `cmd.exe` refuse un répertoire courant UNC.

**Script PowerShell passé par `-EncodedCommand`.** Les chemins Windows contiennent des antislashs et des espaces qui rendent les guillemets imbriqués fragiles. Le script est transmis en base64 UTF-16LE (`iconv` puis `base64 -w0`) et reçoit les chemins par variables d'environnement, que `WSLENV` fait passer du côté Windows.

**`$ProgressPreference = 'SilentlyContinue'`.** Sans lui, PowerShell écrit sur la sortie d'erreur un bloc XML (`#< CLIXML ... Préparation des modules`) qui pollue le terminal.

**Instance Word indépendante.** `New-Object -ComObject Word.Application` lance un processus Word distinct, même si Word est déjà ouvert (vérifié : deux processus coexistent, et `Quit()` ne ferme que le premier). Une session de travail en cours n'est donc ni utilisée ni fermée. Le document est ouvert en lecture seule (`Open($chemin, $false, $true)`) : le `.docx` ne peut pas être modifié par le script, et un document ouvert dans une autre instance ne bloque pas la conversion.

**Avertissement sur le producteur.** Le motif `GDI|[Pp]rint` détecte un PDF réimprimé (PDF-XChange GDI, « Microsoft Print to PDF »). Le script ne peut pas empêcher qu'un `.docx` vienne d'ailleurs, mais ce PDF-là est celui qui s'imprime mal.

**`install -m 0644` pour le PDF.** Un `cp` depuis le dossier temporaire `/mnt/c` conserverait les droits `rwx` que WSL attribue à tout fichier Windows.

**Une conversion échouée n'interrompt pas les autres** (mode par défaut). Comme dans `md2docx.sh`, `convert_all` traite tout le lot et ne fait échouer le script qu'à la fin.

**…sauf avec `--fusion`, où la première erreur arrête tout.** Chaque `.docx` produit alors un chapitre d'un document unique : continuer donnerait un PDF auquel il manque un chapitre, sans que rien ne le signale à qui l'imprime. `fusionner_tout` s'arrête donc par `die` et n'écrit rien (vérifié : un ancien `NOM.pdf` reste intact).

**`pdfunite` plutôt que `pdfjam` pour concaténer.** `pdfunite` (déjà fourni avec `pdfinfo`, paquet `poppler-utils`) recopie les pages sans les repasser par LaTeX et sans réécrire les polices, ce qui est la raison d'être du script. Vérifié avec `pdffonts` : les polices de Word restent incorporées sous leur nom d'origine (`Calibri-Bold`, `Cambria`), y compris pour les documents complétés d'une page blanche par `pdfjam` (`--feuille-par-doc`), qui inclut lui aussi les pages telles quelles. Contrepartie : `pdfunite` ne conserve pas les signets (le PDF de Word en avait un, le PDF fusionné aucun, contrôlé avec `qpdf --json`). `qpdf --pages` ne ferait pas mieux, car il ne garde que ceux du premier fichier.

**Fusion écrite dans `$TMP` puis installée.** Comme pour les PDF simples, `install -m 0644` règle les droits ; et comme `pdfunite` écrit son résultat dès qu'il démarre, passer par le dossier temporaire évite de laisser un PDF tronqué à la place d'un ancien résultat s'il échoue en route.

**Nom du PDF fusionné obligatoire, sans chemin.** Il n'y a pas de nom évident à déduire de N documents (le premier ? un préfixe commun ?), et un nom déduit se trompe en silence. `NOM` est donc un argument de `--fusion` ; il refuse `/` parce que le dossier de sortie a déjà son option (`--out`), et accepte `.pdf` en fin de nom pour que `--fusion cours` et `--fusion cours.pdf` soient équivalents.

**Pas de tri dans le script.** L'ordre « alphabétique avec un joker » vient du shell, qui développe `*.docx` avant le lancement ; le script reçoit déjà la liste ordonnée et conserve l'ordre reçu, ce qui sert aussi à l'ordre explicite. Trier dans le script casserait l'ordre explicite.

**Numérotation des fichiers intermédiaires (`partie-001.pdf`…).** Les `.docx` peuvent avoir le même nom dans deux dossiers différents, et des espaces ou des accents dans le nom ; les intermédiaires ont donc des noms sans rapport avec ceux des sources, et l'ordre de `pdfunite` est celui de la liste `parts` construite dans la boucle.

**`--feuille-par-doc` complète le PDF de chaque document, pas le PDF `-2p`.** Compléter seulement le `-2p` ferait deux paginations différentes (la page 5 de `NOM.pdf` ne serait pas la page 5 de `NOM-2p.pdf`) et ne servirait pas à l'impression recto verso du PDF simple, qui a le même problème de feuille partagée. Les pages blanches sont donc ajoutées **avant** la fusion, une fois pour toutes. Elles ne sont ajoutées qu'aux documents de pages impaires : un document de pages paires commence déjà sur une nouvelle feuille. Le **dernier** document n'est jamais complété : aucun document ne le suit, la page blanche finale ne servirait qu'à gaspiller une feuille.

**Taille de la page blanche : `--papersize` en `bp`.** Sans option de papier, `pdfjam` impose son papier par défaut (A4) et **redimensionne toutes les pages** du document : vérifié avec un PDF Letter (612×792), qui ressortait en A4 (595×842). `ajouter_page_blanche` relit donc la taille de la première page dans le PDF (`pdfinfo`, ligne `Page size`) et la passe à `pdfjam`. L'unité doit être `bp` (point PDF, 1/72 pouce) : avec `pt`, `pdfjam` utilise le point de TeX (1/72,27 pouce) et sort des pages de 609,7×789,0 au lieu de 612×792. Contrôlé en Letter et en A4 : tailles et polices inchangées.

**Syntaxe de la page blanche.** `pdfjam fichier.pdf '1-,{}'` : `1-` désigne toutes les pages et `{}` une page vide, en syntaxe `pdfpages`. Le fichier est réécrit sur place (`--outfile` = entrée) : `pdfjam` le supporte (vérifié : 4 pages deviennent 5), et la partie vit dans `$TMP`, que le script abandonne de toute façon si l'opération échoue.

### Dépendances externes

| Binaire | Rôle |
| ------- | ---- |
| `powershell.exe` | pilotage de Word par COM (moteur `word`) |
| `cmd.exe` | lecture de `%TEMP%` |
| `wslpath` | conversion de chemins WSL ⇄ Windows |
| `iconv`, `base64` | encodage du script PowerShell |
| `soffice` ou `soffice.exe` | moteur `libreoffice` |
| `pdfjam` (et `pdflatex`) | imposition 2 pages par feuille, page blanche de `--feuille-par-doc` |
| `pdfinfo` | nombre de pages et producteur |
| `pdfunite` | fusion des PDF (`--fusion`), poppler 24.02 testé |
| `awk` | réimpression de l'en-tête manpage par `--help` |

### Points d'extension

**Autre imposition** (4 pages par feuille, livret) — modifier le tableau `args` dans `imposer_2p`. Pour 4 pages en portrait avec un peu d'espace :

```bash
local args=(--quiet --nup 2x2 --a4paper --delta '0.3cm 0.3cm')
```

et pour un livret à plier : `--booklet true --nup 2x1 --landscape --a4paper`. Les options de `pdfjam` sont décrites dans la note « PDF n pages par feuille en ligne de commande avec pdfjam ».

**Autre taille de papier** — remplacer `--a4paper` par `--paper letterpaper` ou autre.

**Compléter à un autre multiple que 2** (par exemple 4 pages par feuille) — dans la boucle de `fusionner_tout`, remplacer le test de parité (`% 2`) par un calcul du nombre de pages manquantes, et faire construire à `ajouter_page_blanche` une liste de pages avec autant de `{}` que nécessaire :

```bash
manque=$(( (4 - $(pdf_field "$part" Pages) % 4) % 4 ))
spec='1-'; for ((k = 0; k < manque; k++)); do spec+=',{}'; done   # ex. '1-,{},{}'
pdfjam --quiet "$part" "$spec" --papersize "{${w}bp,${h}bp}" --outfile "$part"
```

Vérifié avec des PDF de 1 à 6 pages : tous ressortent à 4 ou 8 pages. `ajouter_page_blanche` n'ajoute aujourd'hui qu'une page, et `imposer_2p` (2 pages par feuille) resterait à adapter.

### Notes de maintenance

- **Word est requis pour la fidélité maximale.** Le moteur `libreoffice` donne 14 pages sur le document de référence comme Word, mais la mise en page n'est pas garantie identique : un `.docx` écrit pour Word peut être paginé autrement.
- **La première ouverture de Word peut être lente** (une dizaine de secondes) : ce n'est pas un blocage.
- **Un document protégé par mot de passe** ou en mode « modifications suivies non résolues » peut ouvrir une boîte de dialogue que `DisplayAlerts = 0` ne couvre pas ; le script attend alors indéfiniment. Non rencontré, non testé.
- **Chemins avec espaces** : testés côté sortie (`Program Files` pour LibreOffice), et en entrée comme en nom de PDF fusionné (`annexe avec espaces.docx`, `--fusion "mon cours.pdf"`). Les noms de `.docx` sont toujours entre guillemets dans le script.
- **`--feuille-par-doc` lit la taille de la première page seulement.** Un document aux pages de tailles mixtes (portrait et paysage, par exemple) reçoit une page blanche de la taille de sa première page.
- **`--fusion` n'a pas de garde-fou sur le nombre de fichiers** : avec un seul `.docx`, il produit simplement `NOM.pdf`, copie du PDF de ce document. Le même fichier donné deux fois est converti deux fois et apparaît deux fois dans le PDF.
- **`qpdf` signale un avertissement sur le PDF fusionné** (« reported number of objects (44) is not one plus the highest object number (127) »). Il vient de la façon dont `pdfunite` numérote les objets ; le PDF reste lisible (`pdfinfo`, `pdftotext`) et ce n'est pas un défaut du script.
- **Le moteur `libreoffice` fonctionne avec `--fusion`**, mais LibreOffice ouvre sans erreur un fichier qui n'est pas un vrai `.docx` (un texte renommé donne un PDF d'une page) : l'échec de conversion qui annule la fusion n'a donc été testé qu'avec une copie jetable du script qui force l'erreur.
