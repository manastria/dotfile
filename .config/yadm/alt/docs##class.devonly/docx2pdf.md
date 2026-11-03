# `docx2pdf.sh` — .docx vers PDF et PDF « 2 pages par feuille »

> Script : [`.local/bin/docx2pdf.sh`](../.local/bin/docx2pdf.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`docx2pdf.sh` convertit un ou plusieurs documents Word `.docx` en PDF, puis fabrique pour chacun un second PDF « 2 pages par feuille » (A4 paysage, avec un cadre autour des pages) prêt pour la photocopieuse : `fiche.docx` donne `fiche.pdf` et `fiche-2p.pdf`, à côté du `.docx` ou dans le dossier de `--out`. Il se lance sous WSL, pilote Word côté Windows et fait l'imposition avec `pdfjam`. Le PDF est **exporté par Word lui-même**, jamais obtenu en « imprimant vers un PDF » : un pilote d'impression réécrit les polices et provoque des espaces parasites à la photocopieuse. Le script ne produit pas de `.docx` (voir `md2docx.sh` pour cela) et ne modifie jamais le `.docx` d'origine. Les options utiles au quotidien sont `--sans-2p` (le PDF seul), `--out` (autre dossier) et `--moteur libreoffice` (sans Word).

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

Le choix de l'export Word tient à un problème rencontré avec une fiche de cours : le PDF « 2 pages par feuille » avait été fabriqué en réimprimant le PDF de Word avec un pilote d'impression Windows (PDF-XChange en mode GDI). Ce pilote réécrit le texte lettre par lettre ; la photocopieuse affichait alors « Par où comme ence r » au lieu de « Par où commencer », alors que le fichier était correct à l'écran. `pdfjam` inclut au contraire les pages d'origine telles quelles.

### Prérequis

| Outil | Rôle | Vérification |
| ----- | ---- | ------------ |
| WSL | le script s'exécute sous WSL (il appelle des programmes Windows) | `wslpath -w .` |
| Microsoft Word (Windows) | export du PDF, moteur par défaut | `powershell.exe -NoProfile -Command "Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\winword.exe'"` |
| LibreOffice (Windows ou Linux) | moteur de remplacement, avec `--moteur libreoffice` | `ls "/mnt/c/Program Files/LibreOffice/program/soffice.exe"` ou `soffice --version` |
| `pdfjam` | imposition 2 pages par feuille (paquet `texlive-extra-utils`) | `pdfjam --version` |
| `pdfinfo` | nombre de pages et producteur du PDF (paquet `poppler-utils`) | `pdfinfo -v` |

### Syntaxe

```bash
docx2pdf.sh FICHIER.docx... [--out DOSSIER] [--sans-2p] [--sans-cadre] [--moteur word|libreoffice]
docx2pdf.sh -h|--help
```

| Option / argument | Défaut | Description |
| ------------------ | ------ | ----------- |
| `FICHIER.docx...` | — (obligatoire) | Un ou plusieurs documents à convertir, en liste explicite ou avec un joker (`*.docx`) |
| `--out DOSSIER` | dossier de chaque `.docx` | Dossier de sortie, créé si besoin |
| `--sans-2p` | désactivé | Ne produit que `FICHIER.pdf` |
| `--sans-cadre` | désactivé | Pas de cadre autour des pages du PDF 2 pages par feuille |
| `--moteur M` | `word` | `word` ou `libreoffice` |
| `-h`, `--help` | — | Affiche l'en-tête du script, où qu'il soit dans la ligne de commande |

Les PDF existants sont **écrasés** sans question : ce sont des résultats dérivés du `.docx`.

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
```

**Exemple de sortie** (chemins abrégés) :

```
[INFO]      Conversion : fiche (word)
[OK]        …/fiches/fiche.pdf (14 page(s), Microsoft® Word pour Microsoft 365)
[OK]        …/fiches/fiche-2p.pdf (7 feuille(s) A4 paysage)
```

Durée mesurée : environ 14 secondes pour un document de 14 pages, dont une dizaine pour le démarrage de Word.

**Vérifier un PDF avant de l'imprimer** : `pdfinfo fiche.pdf | grep Producer` doit afficher le producteur d'origine (« Microsoft® Word… »), et `pdffonts fiche-2p.pdf` les polices du document (par exemple `FiraSans-Regular`), pas des noms comme `~FP71A0`. Le script avertit lui-même si le producteur contient « GDI » ou « Print ».

### Codes de retour

| Code | Signification |
| ---- | ------------- |
| `0` | Toutes les conversions ont réussi |
| `1` | Erreur d'exécution : outil manquant (`pdfjam`, `pdfinfo`, `powershell.exe`), ou échec d'au moins une conversion |
| `2` | Erreur d'usage : aucun fichier, option inconnue, valeur manquante pour `--out`/`--moteur`, fichier `.docx` introuvable |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `parse_args` — options et liste `INPUTS[@]` ; `--help` est reconnue à n'importe quelle position.
2. `validate_inputs` — chaque fichier doit exister et se terminer par `.docx`.
3. `check_tools` — `wslpath`, `pdfinfo`, puis `pdfjam` (sauf `--sans-2p`) et `powershell.exe` (moteur Word).
4. `make_tmp` — dossier temporaire côté Windows, supprimé par un `trap ... EXIT`.
5. `convert_all` — boucle `convert_one` sur `INPUTS[@]` en comptant les échecs.
6. `convert_one` — copie du `.docx` dans le dossier temporaire, `convertir_word` ou `convertir_libreoffice`, copie du PDF vers la destination, contrôle du producteur, puis `pdfjam`.

### Détail des choix techniques

**Export par Word, pas impression vers PDF.** `ExportAsFixedFormat` écrit un PDF vectoriel avec les polices incorporées, sans passer par un pilote d'impression. C'est la raison d'être du script (voir *Description*). Les arguments positionnels de l'appel sont `(sortie, 17, ouvrir=$false, optimiser=0 (impression), plage=0, de=1, à=1, éléments=0, propriétés=$true, IRM=$true, signets=1)` : le dernier crée les signets de titres, qui rendent le PDF navigable (vérifié : le PDF de Word les contient, le PDF `-2p` produit par `pdfjam` non).

**Copie dans un dossier temporaire Windows.** Word n'ouvre pas bien un chemin WSL (`\\wsl.localhost\...`) ni un fichier d'un lecteur synchronisé comme Google Drive, et on ne veut pas qu'il écrive dans le dossier de cours. Le dossier est lu par `cmd.exe /c 'echo %TEMP%'`, lancé depuis `/mnt/c` : `cmd.exe` refuse un répertoire courant UNC.

**Script PowerShell passé par `-EncodedCommand`.** Les chemins Windows contiennent des antislashs et des espaces qui rendent les guillemets imbriqués fragiles. Le script est transmis en base64 UTF-16LE (`iconv` puis `base64 -w0`) et reçoit les chemins par variables d'environnement, que `WSLENV` fait passer du côté Windows.

**`$ProgressPreference = 'SilentlyContinue'`.** Sans lui, PowerShell écrit sur la sortie d'erreur un bloc XML (`#< CLIXML ... Préparation des modules`) qui pollue le terminal.

**Instance Word indépendante.** `New-Object -ComObject Word.Application` lance un processus Word distinct, même si Word est déjà ouvert (vérifié : deux processus coexistent, et `Quit()` ne ferme que le premier). Une session de travail en cours n'est donc ni utilisée ni fermée. Le document est ouvert en lecture seule (`Open($chemin, $false, $true)`) : le `.docx` ne peut pas être modifié par le script, et un document ouvert dans une autre instance ne bloque pas la conversion.

**Avertissement sur le producteur.** Le motif `GDI|[Pp]rint` détecte un PDF réimprimé (PDF-XChange GDI, « Microsoft Print to PDF »). Le script ne peut pas empêcher qu'un `.docx` vienne d'ailleurs, mais ce PDF-là est celui qui s'imprime mal.

**`install -m 0644` pour le PDF.** Un `cp` depuis le dossier temporaire `/mnt/c` conserverait les droits `rwx` que WSL attribue à tout fichier Windows.

**Une conversion échouée n'interrompt pas les autres.** Comme dans `md2docx.sh`, `convert_all` traite tout le lot et ne fait échouer le script qu'à la fin.

### Dépendances externes

| Binaire | Rôle |
| ------- | ---- |
| `powershell.exe` | pilotage de Word par COM (moteur `word`) |
| `cmd.exe` | lecture de `%TEMP%` |
| `wslpath` | conversion de chemins WSL ⇄ Windows |
| `iconv`, `base64` | encodage du script PowerShell |
| `soffice` ou `soffice.exe` | moteur `libreoffice` |
| `pdfjam` (et `pdflatex`) | imposition 2 pages par feuille |
| `pdfinfo` | nombre de pages et producteur |
| `awk` | réimpression de l'en-tête manpage par `--help` |

### Points d'extension

**Autre imposition** (4 pages par feuille, livret) — modifier le tableau `args` dans `convert_one`. Pour 4 pages en portrait avec un peu d'espace :

```bash
local args=(--quiet --nup 2x2 --a4paper --delta '0.3cm 0.3cm')
```

et pour un livret à plier : `--booklet true --nup 2x1 --landscape --a4paper`. Les options de `pdfjam` sont décrites dans la note « PDF n pages par feuille en ligne de commande avec pdfjam ».

**Autre taille de papier** — remplacer `--a4paper` par `--paper letterpaper` ou autre.

### Notes de maintenance

- **Word est requis pour la fidélité maximale.** Le moteur `libreoffice` donne 14 pages sur le document de référence comme Word, mais la mise en page n'est pas garantie identique : un `.docx` écrit pour Word peut être paginé autrement.
- **La première ouverture de Word peut être lente** (une dizaine de secondes) : ce n'est pas un blocage.
- **Un document protégé par mot de passe** ou en mode « modifications suivies non résolues » peut ouvrir une boîte de dialogue que `DisplayAlerts = 0` ne couvre pas ; le script attend alors indéfiniment. Non rencontré, non testé.
- **Chemins avec espaces** : testés uniquement côté sortie (`Program Files` pour LibreOffice). Les noms de `.docx` sont toujours entre guillemets dans le script.
