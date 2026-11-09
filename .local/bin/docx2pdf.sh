#!/usr/bin/env bash
# NAME
#     docx2pdf.sh — convertit des .docx en PDF (export Word) et en PDF « 2 pages par feuille »
#
# SYNOPSIS
#     docx2pdf.sh FICHIER.docx... [--out DOSSIER] [--sans-2p] [--sans-cadre]
#                                 [--fusion NOM] [--moteur word|libreoffice]
#     docx2pdf.sh -h|--help
#
# DESCRIPTION
#     Pour chaque FICHIER.docx, produit deux PDF :
#         FICHIER.pdf      le document, exporté par Word lui-même
#         FICHIER-2p.pdf   le même, deux pages portrait par feuille A4 paysage
#                          (pdfjam), prêt pour la photocopieuse
#
#     À lancer sous WSL : Word (ou LibreOffice) est piloté côté Windows par
#     powershell.exe, puis pdfjam s'exécute côté Linux. Les deux PDF sont créés
#     à côté du .docx, ou dans DOSSIER avec --out. Un PDF existant est écrasé.
#
#     Le PDF est exporté par Word (ExportAsFixedFormat) et non obtenu en
#     « imprimant vers un PDF » : un pilote d'impression réécrit les polices
#     lettre par lettre, ce qui fait apparaître des espaces parasites à la
#     photocopieuse. Le script affiche le producteur (Producer) du PDF et
#     avertit s'il ressemble à un pilote d'impression.
#
#     Word est lancé en lecture seule, invisible, dans sa propre instance : une
#     session Word déjà ouverte n'est ni utilisée ni fermée. Le .docx est copié
#     dans un dossier temporaire Windows, supprimé en fin de script.
#
#     Avec --fusion NOM, les .docx ne donnent plus un PDF chacun mais un seul :
#     NOM.pdf (et NOM-2p.pdf), les documents étant mis bout à bout (pdfunite)
#     dans l'ordre de la ligne de commande. Avec un joker (*.docx), c'est le
#     shell qui développe la liste par ordre alphabétique (selon la locale).
#     Aucun FICHIER.pdf individuel n'est écrit. Si un seul .docx échoue,
#     rien n'est produit : un PDF auquel il manquerait un chapitre trompe.
#
# OPTIONS
#     FICHIER.docx...   Un ou plusieurs fichiers à convertir (obligatoire).
#     --out DOSSIER     Dossier de sortie, créé si besoin (défaut : celui de
#                       chaque .docx ; avec --fusion, celui du premier .docx).
#     --sans-2p         Ne produire que le PDF simple (pas de -2p).
#     --sans-cadre      Pas de cadre autour de chaque page du PDF 2 pages par
#                       feuille.
#     --fusion NOM      Un seul PDF pour tous les .docx, nommé NOM.pdf (le
#                       .pdf est ajouté s'il manque ; pas de « / » dans NOM :
#                       --out choisit le dossier).
#     --moteur M        word (défaut) ou libreoffice.
#     -h, --help        Affiche cette aide.
#
# EXAMPLES
#     # Produit fiche.pdf et fiche-2p.pdf à côté de fiche.docx
#     docx2pdf.sh fiche.docx
#
#     # Seulement le PDF, dans un autre dossier
#     docx2pdf.sh fiche.docx --out ~/pdf --sans-2p
#
#     # Tous les .docx du répertoire courant
#     docx2pdf.sh *.docx
#
#     # Sans Word : conversion par LibreOffice
#     docx2pdf.sh fiche.docx --moteur libreoffice
#
#     # Un seul PDF (cours.pdf et cours-2p.pdf), chapitres dans l'ordre alphabétique
#     docx2pdf.sh chapitre-*.docx --fusion cours
#
#     # Ordre choisi à la main, résultat dans un autre dossier
#     docx2pdf.sh intro.docx annexes.docx conclusion.docx --fusion dossier --out ~/pdf
#
# EXIT CODES
#     0   Toutes les conversions ont réussi.
#     1   Erreur d'exécution : outil manquant, ou échec d'au moins une conversion
#         (avec --fusion : échec de la conversion d'un .docx ou de la fusion).
#     2   Erreur d'usage : aucun fichier, option inconnue, NOM de --fusion
#         invalide, fichier .docx introuvable.
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly LIBREOFFICE_EXE="/mnt/c/Program Files/LibreOffice/program/soffice.exe"

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

usage() {
    # Réimprime le bloc d'en-tête manpage (même convention que md2docx.sh) :
    # l'aide reste juste même si l'en-tête grossit.
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}
usage_error() { error "$*"; echo "Essayez : $(basename "$0") --help" >&2; exit 2; }

# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
INPUTS=()
OUT_DIR=""
DEUX_PAGES=1
CADRE=1
FUSION=""   # nom (sans .pdf) du PDF fusionné ; vide = un PDF par .docx
MOTEUR="word"

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --out)        [[ $# -ge 2 ]] || usage_error "--out demande un dossier."
                          OUT_DIR="$2"; shift 2 ;;
            --sans-2p)    DEUX_PAGES=0; shift ;;
            --sans-cadre) CADRE=0; shift ;;
            --fusion)     [[ $# -ge 2 ]] || usage_error "--fusion demande un nom de fichier."
                          FUSION="${2%.pdf}"   # « cours » et « cours.pdf » sont équivalents
                          # Un nom vide ou avec « / » donnerait un chemin imprévu : le dossier se choisit avec --out
                          [[ -n "$FUSION" && "$FUSION" != */* ]] \
                              || usage_error "--fusion attend un nom de fichier sans « / » (dossier : --out)."
                          shift 2 ;;
            --moteur)     [[ $# -ge 2 ]] || usage_error "--moteur demande word ou libreoffice."
                          MOTEUR="$2"; shift 2 ;;
            -h|--help)    usage; exit 0 ;;
            -*)           usage_error "Option inconnue : $1" ;;
            *)            INPUTS+=("$1"); shift ;;
        esac
    done

    [[ ${#INPUTS[@]} -gt 0 ]] || usage_error "Fichier(s) .docx manquant(s)."
    [[ "$MOTEUR" == "word" || "$MOTEUR" == "libreoffice" ]] \
        || usage_error "Moteur inconnu : $MOTEUR (word ou libreoffice)."
}

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
validate_inputs() {
    local f
    for f in "${INPUTS[@]}"; do
        [[ -f "$f" && "$f" == *.docx ]] || usage_error "Fichier .docx introuvable : $f"
    done
}

check_tools() {
    command -v wslpath >/dev/null 2>&1 || die "'wslpath' introuvable : ce script s'exécute sous WSL."
    command -v pdfinfo >/dev/null 2>&1 || die "'pdfinfo' introuvable (paquet poppler-utils)."
    if [[ -n "$FUSION" ]]; then
        command -v pdfunite >/dev/null 2>&1 || die "'pdfunite' introuvable (paquet poppler-utils)."
    fi
    if [[ $DEUX_PAGES -eq 1 ]]; then
        command -v pdfjam >/dev/null 2>&1 || die "'pdfjam' introuvable (paquet texlive-extra-utils)."
    fi
    if [[ "$MOTEUR" == "word" ]]; then
        command -v powershell.exe >/dev/null 2>&1 || die "'powershell.exe' introuvable : Word se pilote depuis Windows."
    fi
}

# -----------------------------------------------------------------------------
# Dossier temporaire côté Windows
# -----------------------------------------------------------------------------
# Word n'ouvre pas bien un chemin WSL (\\wsl.localhost\...) ni un fichier d'un
# lecteur synchronisé, et ne doit pas écrire directement dans le dossier de cours.
TMP=""
make_tmp() {
    local win_temp
    # cd /mnt/c : cmd.exe refuse un répertoire courant UNC (\\wsl.localhost\...)
    win_temp="$( cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r' )"
    [[ -n "$win_temp" ]] || die "Impossible de lire le dossier temporaire Windows (%TEMP%)."
    TMP="$(wslpath -u "$win_temp")/docx2pdf-$$"
    mkdir -p "$TMP"
    trap 'rm -rf "$TMP"' EXIT
}

# -----------------------------------------------------------------------------
# Conversion en PDF
# -----------------------------------------------------------------------------
# Script PowerShell : ouvre le .docx en lecture seule et l'exporte avec Word.
# 17 = wdExportFormatPDF ; le 4e argument 0 = qualité impression ; le dernier
# argument 1 = signets de titres dans le PDF. Les chemins arrivent par variables
# d'environnement (voir convertir_word), ce qui évite tout problème de guillemets.
read -r -d '' PS_WORD <<'EOF' || true
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$w = New-Object -ComObject Word.Application
try {
  $w.Visible = $false
  $w.DisplayAlerts = 0
  $d = $w.Documents.Open($env:DOCX_IN, $false, $true)
  try { $d.ExportAsFixedFormat($env:PDF_OUT, 17, $false, 0, 0, 1, 1, 0, $true, $true, 1) }
  finally { $d.Close($false) }
}
finally { $w.Quit() }
EOF

convertir_word() {  # $1 = .docx, $2 = .pdf à produire (chemins WSL)
    local encoded
    # -EncodedCommand attend du UTF-16LE en base64 : contourne les guillemets de la ligne de commande
    encoded="$(printf '%s' "$PS_WORD" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)"
    # WSLENV transmet les variables à Windows (sans /w : les chemins sont déjà convertis par wslpath -w)
    DOCX_IN="$(wslpath -w "$1")" PDF_OUT="$(wslpath -w "$2")" WSLENV="DOCX_IN:PDF_OUT" \
        powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand "$encoded" >/dev/null
}

convertir_libreoffice() {  # $1 = .docx, $2 = .pdf à produire (chemins WSL)
    local in="$1" pdf="$2" dir
    dir="$(dirname "$pdf")"
    # Profil isolé (-env:UserInstallation) : évite de se heurter à une instance LibreOffice déjà ouverte
    if command -v soffice >/dev/null 2>&1; then
        soffice -env:UserInstallation="file://$TMP/lo_profile" --headless --convert-to pdf \
            --outdir "$dir" "$in" >/dev/null 2>&1
    else
        [[ -x "$LIBREOFFICE_EXE" ]] || { error "LibreOffice introuvable (ni 'soffice', ni $LIBREOFFICE_EXE)."; return 1; }
        "$LIBREOFFICE_EXE" -env:UserInstallation="file:///$(wslpath -m "$TMP/lo_profile")" --headless \
            --convert-to pdf --outdir "$(wslpath -w "$dir")" "$(wslpath -w "$in")" >/dev/null 2>&1
    fi
}

pdf_field() {  # $1 = PDF, $2 = champ de pdfinfo (Pages, Producer...)
    pdfinfo "$1" | sed -n "s/^$2: *//p"
}

# -----------------------------------------------------------------------------
# Briques communes aux deux modes (un PDF par .docx / un PDF fusionné)
# -----------------------------------------------------------------------------
dossier_sortie() {  # $1 = .docx de référence ; crée le dossier de sortie et affiche son chemin absolu
    local dest="${OUT_DIR:-$(dirname "$1")}"
    mkdir -p "$dest"
    realpath "$dest"
}

docx_to_pdf() {  # $1 = .docx, $2 = .pdf à produire, $3 = libellé affiché (défaut : $2)
    local docx="$1" pdf="$2" label="${3:-$2}" base pages producer
    base="$(basename "$docx" .docx)"

    info "Conversion : ${BOLD}${base}${RESET} (${MOTEUR})"
    rm -f "$TMP/in.docx" "$TMP/in.pdf"
    cp "$docx" "$TMP/in.docx"

    if [[ "$MOTEUR" == "word" ]]; then
        convertir_word "$TMP/in.docx" "$TMP/in.pdf" || { error "$base : export Word en PDF échoué."; return 1; }
    else
        convertir_libreoffice "$TMP/in.docx" "$TMP/in.pdf" || { error "$base : conversion LibreOffice échouée."; return 1; }
    fi
    [[ -s "$TMP/in.pdf" ]] || { error "$base : aucun PDF produit."; return 1; }

    install -m 0644 "$TMP/in.pdf" "$pdf"  # cp garderait les droits rwx du lecteur Windows
    pages="$(pdf_field "$pdf" Pages)"
    producer="$(pdf_field "$pdf" Producer)"
    success "${label} (${pages} page(s), ${producer})"
    # Un PDF « réimprimé » par un pilote GDI a ses polices réécrites : il s'imprime mal.
    if [[ "$producer" =~ GDI|[Pp]rint ]]; then
        warn "Producteur « ${producer} » : ce PDF semble réimprimé, ses polices ont pu être réécrites."
    fi
}

imposer_2p() {  # $1 = PDF source ; produit son jumeau « -2p.pdf » à côté
    local pdf="$1" out feuilles
    out="${pdf%.pdf}-2p.pdf"
    local args=(--quiet --nup 2x1 --landscape --a4paper)
    [[ $CADRE -eq 1 ]] && args+=(--frame true)
    pdfjam "${args[@]}" --outfile "$out" -- "$pdf" \
        || { error "$(basename "$pdf") : pdfjam a échoué."; return 1; }
    feuilles="$(pdf_field "$out" Pages)"
    success "${out} (${feuilles} feuille(s) A4 paysage)"
}

# -----------------------------------------------------------------------------
# Mode par défaut : un PDF par .docx
# -----------------------------------------------------------------------------
convert_one() {
    local docx base dest
    docx="$(realpath "$1")"
    base="$(basename "$docx" .docx)"
    dest="$(dossier_sortie "$docx")"

    docx_to_pdf "$docx" "$dest/$base.pdf" || return 1
    [[ $DEUX_PAGES -eq 1 ]] || return 0
    imposer_2p "$dest/$base.pdf"
}

convert_all() {
    local failures=0 f
    for f in "${INPUTS[@]}"; do
        convert_one "$f" || failures=$((failures + 1))
    done
    [[ $failures -eq 0 ]] || die "$failures conversion(s) échouée(s) sur ${#INPUTS[@]}."
}

# -----------------------------------------------------------------------------
# Mode --fusion : un seul PDF pour tous les .docx
# -----------------------------------------------------------------------------
fusionner_tout() {
    local parts=() part dest out f i=0 pages
    # Le dossier par défaut est celui du premier .docx, puisqu'il n'y a qu'un seul résultat
    dest="$(dossier_sortie "$(realpath "${INPUTS[0]}")")"
    out="$dest/$FUSION.pdf"

    # Les PDF intermédiaires restent dans $TMP, numérotés pour que l'ordre de
    # pdfunite soit celui de INPUTS (ordre de la ligne de commande, ou ordre
    # alphabétique du shell pour un joker).
    for f in "${INPUTS[@]}"; do
        i=$((i + 1))
        part="$TMP/partie-$(printf '%03d' "$i").pdf"
        # Échec = arrêt immédiat : un PDF fusionné incomplet est pire que pas de PDF
        docx_to_pdf "$(realpath "$f")" "$part" "$(basename "$f")" \
            || die "Fusion annulée : $(basename "$f") n'a pas pu être converti."
        parts+=("$part")
    done

    info "Fusion de ${#parts[@]} PDF dans ${BOLD}${FUSION}.pdf${RESET}"
    # Écrit dans $TMP puis installé : un échec de pdfunite n'écrase pas un ancien résultat
    pdfunite "${parts[@]}" "$TMP/fusion.pdf" || die "pdfunite a échoué."
    install -m 0644 "$TMP/fusion.pdf" "$out"
    pages="$(pdf_field "$out" Pages)"
    success "${out} (${pages} page(s), ${#parts[@]} document(s))"

    [[ $DEUX_PAGES -eq 1 ]] || return 0
    imposer_2p "$out" || exit 1  # imposer_2p a déjà affiché l'erreur
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    validate_inputs
    check_tools
    make_tmp
    if [[ -n "$FUSION" ]]; then
        fusionner_tout
    else
        convert_all
    fi
}

main "$@"
