#!/usr/bin/env python3
"""
NAME
    install-paquets-vm.py — paquets d'une VM pédagogique, décrits par un profil TOML

SYNOPSIS
    install-paquets-vm.py [-p NOM | -c CHEMIN] [-n] [--os ID:VERSION]
                          [--bureau NOM] [-h]

DESCRIPTION
    Lit un profil TOML composé de groupes de paquets, chacun soumis à des
    conditions (distribution, bornes de version, bureau). Retient les groupes
    qui correspondent à la machine, met le système à jour, retire puis
    installe les paquets retenus, et supprime les dépendances devenues
    inutiles.

    Un profil par objectif pédagogique : --profil NOM cherche NOM.toml dans
    cet ordre et s'arrête au premier trouvé, sans fusion :
        1. répertoire courant          ./NOM.toml
        2. configuration utilisateur   ~/.config/install-paquets-vm/NOM.toml
        3. configuration système       /etc/install-paquets-vm/NOM.toml
    --config CHEMIN charge un fichier précis, sans recherche.

    Le bureau est déduit du métapaquet installé (kubuntu-desktop,
    xubuntu-desktop, lubuntu-desktop, ubuntu-desktop et leurs variantes) ;
    il vaut « aucun » si aucun n'est installé. Le script se relance avec sudo
    si besoin ; --dry-run et --os ne modifient rien et n'exigent pas les
    droits root.

    Modèle commenté : ~/.config/install-paquets-vm/paquets.toml.sample.
    Hors VM pédagogique, install-paquets.sh (liste écrite dans le script)
    reste l'outil de référence.

OPTIONS
    -p, --profil NOM      Profil à chercher (défaut : paquets).
    -c, --config CHEMIN   Fichier TOML à charger, sans recherche.
    -n, --dry-run         Affiche le profil, l'OS, le bureau, les groupes
                          retenus et l'état de chaque paquet, sans rien
                          modifier.
    --os ID:VERSION       Simule une autre distribution (ex. ubuntu:26.04,
                          debian:12) : liste les paquets sans vérifier leur
                          état. Implique --dry-run.
    --bureau NOM          Force le bureau : kubuntu, xubuntu, lubuntu, ubuntu
                          ou aucun. Avec --os, « aucun » par défaut.
    -h, --help            Affiche cette aide.

EXAMPLES
    install-paquets-vm.py --dry-run
    install-paquets-vm.py --profil tp-reseau
    install-paquets-vm.py --config /media/usb/tp-docker.toml
    install-paquets-vm.py --os ubuntu:26.04 --bureau kubuntu

EXIT CODES
    0     Terminé avec succès, ou simulation (--dry-run, --os).
    1     Erreur d'exécution : Python < 3.11, sudo ou dpkg-query absent,
          /etc/os-release illisible, profil inaccessible, échec d'apt-get.
    2     Erreur d'usage : option inconnue ou sans valeur, --os ou --bureau
          invalide, profil introuvable.
    3     Profil invalide : syntaxe TOML, clé inconnue, valeur incorrecte, ou
          paquet à la fois à installer et à retirer sur cette machine.
    130   Interruption (Ctrl+C).
"""

from __future__ import annotations

import fnmatch
import os
import platform
import pwd
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import NoReturn

# tomllib n'existe qu'à partir de Python 3.11. L'échec est reporté à main()
# pour afficher un message clair plutôt qu'une trace d'erreur.
try:
    import tomllib
except ModuleNotFoundError:
    tomllib = None

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
APP = "install-paquets-vm"
PROFIL_DEFAUT = "paquets"

# Bureau (valeur de si.bureau et de --bureau) → motifs des métapaquets qui le
# signalent. Les motifs couvrent les variantes (-minimal…) sans les énumérer.
BUREAUX = {
    "kubuntu": ["kubuntu-desktop*"],
    "xubuntu": ["xubuntu-desktop*"],
    "lubuntu": ["lubuntu-desktop*"],
    "ubuntu": ["ubuntu-desktop*"],
}
BUREAU_AUCUN = "aucun"

CLES_PROFIL = {"description", "groupe", "renommages"}
CLES_GROUPE = {"nom", "si", "paquets", "retirer"}
CLES_SI = {"os", "version_min", "version_max", "bureau"}

# Règle de nommage de la Debian Policy. Elle garantit aussi qu'un nom ne
# commence jamais par « - » : un profil ne peut pas glisser d'option à
# apt-get, exécuté en root (ex. -oAPT::Update::Pre-Invoke::=commande).
NOM_PAQUET = re.compile(r"[a-z0-9][a-z0-9+.-]+")

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
RESET = "\033[0m"


# flush=True : hors terminal, la sortie standard est tamponnée par blocs et les
# messages du script apparaîtraient après ceux d'apt-get.
def afficher(texte: str = "") -> None:
    print(texte, flush=True)


def info(msg: str) -> None:
    afficher(f"{CYAN}[INFO]{RESET}      {msg}")


def success(msg: str) -> None:
    afficher(f"{GREEN}[OK]{RESET}        {msg}")


def warn(msg: str) -> None:
    afficher(f"{YELLOW}[ATTENTION]{RESET} {msg}")


def error(msg: str) -> None:
    print(f"{RED}[ERREUR]{RESET}    {msg}", file=sys.stderr, flush=True)


def die(msg: str, code: int = 1) -> NoReturn:
    error(msg)
    sys.exit(code)


# -----------------------------------------------------------------------------
# Structures
# -----------------------------------------------------------------------------
@dataclass
class Options:
    profil: str | None = None
    config: Path | None = None
    dry_run: bool = False
    os_simule: tuple[str, str] | None = None
    bureau: str | None = None


@dataclass
class Conditions:
    os: list[str] | None = None
    bureau: list[str] | None = None
    version_min: tuple[int, ...] | None = None
    version_max: tuple[int, ...] | None = None
    texte: str = ""


@dataclass
class Groupe:
    nom: str
    si: Conditions
    paquets: list[str]
    retirer: list[str]


@dataclass
class Profil:
    chemin: Path
    description: str
    groupes: list[Groupe]
    # nom canonique → [(os, préfixe de version, nom réel)]
    renommages: dict[str, list[tuple[str, tuple[int, ...], str]]]


@dataclass
class Contexte:
    os_id: str
    version: tuple[int, ...]
    bureaux: set[str]
    simule: bool


@dataclass
class Plan:
    groupes: list[tuple[Groupe, bool]]
    installer: list[tuple[str, str]] = field(default_factory=list)
    retirer: list[tuple[str, str]] = field(default_factory=list)


class ProfilInvalide(Exception):
    """Contenu de profil incorrect, converti en code de retour 3."""


# -----------------------------------------------------------------------------
# Options
# -----------------------------------------------------------------------------
def usage() -> None:
    print((__doc__ or "").strip("\n"))


def usage_error(msg: str) -> NoReturn:
    error(msg)
    print(f"Essayez : {Path(sys.argv[0]).name} --help", file=sys.stderr)
    sys.exit(2)


def valeur_option(option: str, reste: list[str]) -> str:
    # Sans ce contrôle, « --profil --dry-run » prendrait --dry-run pour le nom.
    if not reste or reste[0].startswith("-"):
        usage_error(f"{option} requiert une valeur.")
    return reste.pop(0)


def version_en_tuple(texte: str) -> tuple[int, ...] | None:
    morceaux = texte.split(".")
    if not all(m.isascii() and m.isdigit() for m in morceaux):
        return None
    return tuple(int(m) for m in morceaux)


def bureaux_valides() -> str:
    return ", ".join([*BUREAUX, BUREAU_AUCUN])


def parse_args(argv: list[str]) -> Options:
    opts = Options()
    reste = list(argv)
    while reste:
        arg = reste.pop(0)
        if arg in ("-h", "--help"):
            usage()
            sys.exit(0)
        elif arg in ("-n", "--dry-run"):
            opts.dry_run = True
        elif arg in ("-p", "--profil"):
            opts.profil = valeur_option(arg, reste)
        elif arg in ("-c", "--config"):
            opts.config = Path(valeur_option(arg, reste))
        elif arg == "--os":
            texte = valeur_option(arg, reste)
            os_id, sep, version = texte.partition(":")
            if not os_id or not sep or version_en_tuple(version) is None:
                usage_error(f"--os : « {texte} » invalide (attendu ID:VERSION, ex. ubuntu:26.04 ou debian:12).")
            opts.os_simule = (os_id, version)
        elif arg == "--bureau":
            opts.bureau = valeur_option(arg, reste)
            if opts.bureau not in BUREAUX and opts.bureau != BUREAU_AUCUN:
                usage_error(f"--bureau : « {opts.bureau} » inconnu (attendu : {bureaux_valides()}).")
        else:
            usage_error(f"Option inconnue : {arg}")

    if opts.profil is not None and opts.config is not None:
        usage_error("--profil et --config s'excluent : choisir l'un ou l'autre.")
    if opts.profil is not None:
        if opts.profil.endswith(".toml"):
            opts.profil = opts.profil[: -len(".toml")]
        if not opts.profil or "/" in opts.profil:
            usage_error("--profil attend un nom de profil, pas un chemin : utiliser --config CHEMIN.")
    # --os décrit une autre machine : rien ne doit être modifié sur celle-ci.
    if opts.os_simule is not None:
        opts.dry_run = True
    return opts


# -----------------------------------------------------------------------------
# Choix du profil
# -----------------------------------------------------------------------------
def home_appelant() -> Path:
    # Sous sudo, HOME vaut /root. Le ~/.config consulté doit rester celui de la
    # personne qui a lancé la commande, sinon le profil trouvé changerait entre
    # --dry-run (utilisateur) et l'installation (root).
    sudo_user = os.environ.get("SUDO_USER")
    if os.geteuid() == 0 and sudo_user and sudo_user != "root":
        try:
            return Path(pwd.getpwnam(sudo_user).pw_dir)
        except KeyError:
            pass
    return Path.home()


def emplacements(nom: str) -> list[tuple[Path, str]]:
    fichier = f"{nom}.toml"
    return [
        (Path.cwd() / fichier, "répertoire courant"),
        (home_appelant() / ".config" / APP / fichier, "~/.config"),
        (Path("/etc") / APP / fichier, "/etc"),
    ]


def est_fichier(chemin: Path) -> bool:
    # Path.is_file() lève PermissionError (au lieu de renvoyer False) quand un
    # répertoire parent n'est pas traversable : on le dit plutôt que de passer
    # silencieusement à l'emplacement suivant.
    try:
        return chemin.is_file()
    except PermissionError:
        die(f"Accès refusé à {chemin} : vérifier les droits du fichier et de son répertoire.")


def trouver_config(opts: Options) -> tuple[Path, str]:
    if opts.config is not None:
        if not est_fichier(opts.config):
            usage_error(f"Fichier de profil introuvable : {opts.config}")
        return opts.config.resolve(), "--config"

    nom = opts.profil or PROFIL_DEFAUT
    candidats = emplacements(nom)
    for chemin, source in candidats:
        if est_fichier(chemin):
            return chemin, source

    error(f"Profil « {nom} » introuvable. Emplacements consultés, par priorité :")
    for chemin, _ in candidats:
        print(f"    {chemin}", file=sys.stderr)
    print(f"Modèle commenté : ~/.config/{APP}/{PROFIL_DEFAUT}.toml.sample", file=sys.stderr)
    sys.exit(2)


# -----------------------------------------------------------------------------
# Lecture et validation du profil
# -----------------------------------------------------------------------------
def charger_profil(chemin: Path) -> Profil:
    try:
        with chemin.open("rb") as fichier:
            donnees = tomllib.load(fichier)
    except tomllib.TOMLDecodeError as e:
        die(f"{chemin} : syntaxe TOML invalide — {e}", 3)
    except OSError as e:
        die(f"Lecture impossible de {chemin} : {e.strerror}")

    try:
        return valider_profil(chemin, donnees)
    except ProfilInvalide as e:
        die(f"{chemin} : {e}", 3)


def verifier_cles(lieu: str, table: dict, autorisees: set[str]) -> None:
    # Une clé mal orthographiée serait sinon ignorée en silence : « versoin_max »
    # appliquerait le groupe partout, « paquet » le laisserait vide.
    inconnues = sorted(set(table) - autorisees)
    if inconnues:
        raise ProfilInvalide(
            f"{lieu} : clé inconnue « {', '.join(inconnues)} » (autorisées : {', '.join(sorted(autorisees))})."
        )


def liste_de_chaines(lieu: str, cle: str, valeur: object) -> list[str]:
    if isinstance(valeur, str):
        valeur = [valeur]
    if not isinstance(valeur, list) or not all(isinstance(v, str) and v for v in valeur):
        raise ProfilInvalide(f'{lieu} : « {cle} » doit être un texte ou une liste de textes, ex. {cle} = ["a", "b"].')
    return valeur


def verifier_nom_paquet(lieu: str, nom: str) -> None:
    if not NOM_PAQUET.fullmatch(nom):
        raise ProfilInvalide(
            f"{lieu} : nom de paquet invalide « {nom} » (minuscules, chiffres, + . - ; 2 caractères au moins)."
        )


def liste_de_paquets(lieu: str, cle: str, valeur: object) -> list[str]:
    noms = liste_de_chaines(lieu, cle, valeur)
    for nom in noms:
        verifier_nom_paquet(lieu, nom)
    return noms


def borne_version(lieu: str, cle: str, valeur: object) -> tuple[tuple[int, ...], str]:
    # Sans guillemets, TOML lit 24.10 comme le nombre 24.1 : la version voulue
    # est perdue, on refuse plutôt que de deviner.
    if isinstance(valeur, float):
        raise ProfilInvalide(f'{lieu} : si.{cle} = {valeur} doit être entre guillemets, ex. {cle} = "24.10".')
    # bool est une sous-classe d'int : « true » ne doit pas valoir la version 1.
    texte = str(valeur) if isinstance(valeur, int) and not isinstance(valeur, bool) else valeur
    version = version_en_tuple(texte) if isinstance(texte, str) else None
    if version is None:
        raise ProfilInvalide(f'{lieu} : si.{cle} invalide ({valeur!r}), attendu par ex. "24.04" ou "12".')
    return version, texte


def valider_conditions(lieu: str, brut: object) -> Conditions:
    if not isinstance(brut, dict):
        raise ProfilInvalide(f'{lieu} : « si » doit être une table, ex. si = {{ os = "ubuntu" }}.')
    verifier_cles(f"{lieu}, si", brut, CLES_SI)

    cond = Conditions()
    morceaux = []
    if "os" in brut:
        cond.os = liste_de_chaines(lieu, "si.os", brut["os"])
        morceaux.append("os = " + " ou ".join(cond.os))
    if "version_min" in brut:
        cond.version_min, texte = borne_version(lieu, "version_min", brut["version_min"])
        morceaux.append(f"version ≥ {texte}")
    if "version_max" in brut:
        cond.version_max, texte = borne_version(lieu, "version_max", brut["version_max"])
        morceaux.append(f"version ≤ {texte}")
    if "bureau" in brut:
        cond.bureau = liste_de_chaines(lieu, "si.bureau", brut["bureau"])
        for bureau in cond.bureau:
            if bureau not in BUREAUX and bureau != BUREAU_AUCUN:
                raise ProfilInvalide(f"{lieu} : bureau « {bureau} » inconnu (attendu : {bureaux_valides()}).")
        morceaux.append("bureau = " + " ou ".join(cond.bureau))
    cond.texte = ", ".join(morceaux)
    return cond


def valider_groupe(rang: int, brut: object) -> Groupe:
    if not isinstance(brut, dict):
        raise ProfilInvalide(f"groupe n°{rang} : table [[groupe]] attendue.")
    nom = brut.get("nom")
    if not isinstance(nom, str) or not nom:
        raise ProfilInvalide(f"groupe n°{rang} : clé « nom » absente ou vide.")
    lieu = f"groupe « {nom} »"
    verifier_cles(lieu, brut, CLES_GROUPE)
    return Groupe(
        nom=nom,
        si=valider_conditions(lieu, brut.get("si", {})),
        paquets=liste_de_paquets(lieu, "paquets", brut.get("paquets", [])),
        retirer=liste_de_paquets(lieu, "retirer", brut.get("retirer", [])),
    )


def valider_renommages(brut: object) -> dict[str, list[tuple[str, tuple[int, ...], str]]]:
    if not isinstance(brut, dict):
        raise ProfilInvalide("« renommages » doit être une table, ex. [renommages.netcat].")
    resultat: dict[str, list[tuple[str, tuple[int, ...], str]]] = {}
    for canonique, regles in brut.items():
        lieu = f"renommages.{canonique}"
        verifier_nom_paquet(lieu, canonique)
        if not isinstance(regles, dict):
            raise ProfilInvalide(f'{lieu} : table attendue, ex. "ubuntu:24.04" = "nom-reel".')
        resultat[canonique] = []
        for cle, reel in regles.items():
            os_id, sep, version_txt = cle.partition(":")
            version = version_en_tuple(version_txt) if sep else ()
            if not os_id or version is None:
                raise ProfilInvalide(f'{lieu} : clé « {cle} » invalide, attendu "os" ou "os:version" (ex. "ubuntu:24.04").')
            if not isinstance(reel, str):
                raise ProfilInvalide(f"{lieu} : « {cle} » doit désigner un nom de paquet.")
            verifier_nom_paquet(lieu, reel)
            resultat[canonique].append((os_id, version, reel))
    return resultat


def valider_profil(chemin: Path, donnees: dict) -> Profil:
    verifier_cles("profil", donnees, CLES_PROFIL)

    description = donnees.get("description", "")
    if not isinstance(description, str):
        raise ProfilInvalide("« description » doit être un texte.")

    groupes_bruts = donnees.get("groupe", [])
    # [groupe] (crochets simples) produit une table unique au lieu d'une liste.
    if not isinstance(groupes_bruts, list):
        raise ProfilInvalide("les groupes s'écrivent [[groupe]], avec des crochets doubles.")

    groupes: list[Groupe] = []
    for rang, brut in enumerate(groupes_bruts, start=1):
        groupe = valider_groupe(rang, brut)
        if any(g.nom == groupe.nom for g in groupes):
            raise ProfilInvalide(f"nom de groupe en double : « {groupe.nom} ».")
        groupes.append(groupe)

    return Profil(chemin, description, groupes, valider_renommages(donnees.get("renommages", {})))


# -----------------------------------------------------------------------------
# Détection de la machine
# -----------------------------------------------------------------------------
def paquets_installes(noms: list[str]) -> set[str]:
    if not noms:
        return set()
    # Un seul appel pour toute la liste. dpkg-query sort en code 1 dès qu'un nom
    # ne correspond à rien, mais liste quand même les autres : seule la sortie
    # standard compte.
    resultat = subprocess.run(
        ["dpkg-query", "--show", "--showformat=${Package}\t${db:Status-Abbrev}\n", *noms],
        capture_output=True,
        text=True,
        check=False,
    )
    installes = set()
    for ligne in resultat.stdout.splitlines():
        nom, _, statut = ligne.partition("\t")
        # 2e lettre de Status-Abbrev = état réel : « ii » installé, « rc »
        # supprimé mais fichiers de configuration conservés.
        if statut[1:2] == "i":
            installes.add(nom)
    return installes


def paquets_disponibles(noms: list[str]) -> set[str]:
    if not noms:
        return set()
    # Appelé avec plusieurs noms, apt-cache show renvoie 0 même si certains sont
    # inconnus. Un paquet purement virtuel (ex. mail-transport-agent) n'a pas de
    # fiche, alors qu'apt-get refuse de l'installer dès qu'il a plusieurs
    # fournisseurs : on relève donc les lignes « Package: ».
    resultat = subprocess.run(
        ["apt-cache", "show", "--no-all-versions", *noms],
        capture_output=True,
        text=True,
        check=False,
    )
    return {
        ligne.split(":", 1)[1].strip()
        for ligne in resultat.stdout.splitlines()
        if ligne.startswith("Package:")
    }


def detecter_bureaux() -> set[str]:
    motifs = [motif for liste in BUREAUX.values() for motif in liste]
    installes = paquets_installes(motifs)
    bureaux = {
        bureau
        for bureau, liste in BUREAUX.items()
        if any(fnmatch.fnmatchcase(nom, motif) for nom in installes for motif in liste)
    }
    return bureaux or {BUREAU_AUCUN}


def construire_contexte(opts: Options) -> Contexte:
    if opts.os_simule is not None:
        os_id, version_txt = opts.os_simule
        bureau = opts.bureau or BUREAU_AUCUN
        warn(f"OS simulé (--os) : {BOLD}{os_id} {version_txt}{RESET}, bureau {bureau} — ne décrit pas cette machine.")
        if opts.bureau is None:
            info("Bureau « aucun » par défaut en simulation : préciser --bureau pour en simuler un.")
        return Contexte(os_id, version_en_tuple(version_txt) or (), {bureau}, simule=True)

    if shutil.which("dpkg-query") is None:
        die("dpkg-query introuvable : Debian ou Ubuntu requis (--os permet de simuler ailleurs).")
    try:
        infos = platform.freedesktop_os_release()
    except OSError:
        die("/etc/os-release illisible — OS non supporté.")

    os_id = infos.get("ID", "unknown")
    version_txt = infos.get("VERSION_ID", "")
    # VERSION_ID est absent sur Debian testing/sid : version inconnue.
    version = version_en_tuple(version_txt) or ()
    info(f"OS détecté : {BOLD}{infos.get('PRETTY_NAME', os_id)}{RESET} (id={os_id}, version={version_txt or 'inconnue'})")
    if not version:
        warn("Version de l'OS inconnue : les groupes soumis à une condition de version sont écartés.")

    if opts.bureau is not None:
        bureaux = {opts.bureau}
        info(f"Bureau forcé (--bureau) : {opts.bureau}")
    else:
        bureaux = detecter_bureaux()
        info(f"Bureau détecté : {', '.join(sorted(bureaux))}")
    return Contexte(os_id, version, bureaux, simule=False)


# -----------------------------------------------------------------------------
# Sélection des paquets
# -----------------------------------------------------------------------------
def conditions_remplies(cond: Conditions, ctx: Contexte) -> bool:
    if cond.os is not None and ctx.os_id not in cond.os:
        return False
    if cond.bureau is not None and ctx.bureaux.isdisjoint(cond.bureau):
        return False
    if cond.version_min is None and cond.version_max is None:
        return True
    if not ctx.version:
        return False
    # Une borne ne compare que les composants qu'elle fournit : « 24 » couvre
    # 24.04 et 24.10, alors que « 24.04 » exclut 24.10.
    if cond.version_min is not None and ctx.version[: len(cond.version_min)] < cond.version_min:
        return False
    if cond.version_max is not None and ctx.version[: len(cond.version_max)] > cond.version_max:
        return False
    return True


def resoudre_nom(canonique: str, profil: Profil, ctx: Contexte) -> str:
    # La règle la plus précise l'emporte : "ubuntu:24.04", puis "ubuntu:24",
    # puis "ubuntu".
    reel, precision = canonique, -1
    for os_id, version, nom in profil.renommages.get(canonique, []):
        if os_id != ctx.os_id or ctx.version[: len(version)] != version:
            continue
        if len(version) > precision:
            reel, precision = nom, len(version)
    return reel


def construire_plan(profil: Profil, ctx: Contexte) -> Plan:
    plan = Plan(groupes=[(g, conditions_remplies(g.si, ctx)) for g in profil.groupes])
    # dict : dédoublonne en conservant l'ordre du profil.
    installer: dict[str, str] = {}
    retirer: dict[str, str] = {}
    for groupe, retenu in plan.groupes:
        if not retenu:
            continue
        for nom in groupe.paquets:
            installer.setdefault(nom, resoudre_nom(nom, profil, ctx))
        for nom in groupe.retirer:
            retirer.setdefault(nom, resoudre_nom(nom, profil, ctx))

    conflits = sorted(set(installer.values()) & set(retirer.values()))
    if conflits:
        die(f"{profil.chemin} : à la fois à installer et à retirer pour cette machine : {', '.join(conflits)}.", 3)

    plan.installer = list(installer.items())
    plan.retirer = list(retirer.items())
    return plan


# -----------------------------------------------------------------------------
# Affichage
# -----------------------------------------------------------------------------
def afficher_groupes(plan: Plan) -> None:
    afficher(f"\n{BOLD}Groupes du profil ([x] = retenu) :{RESET}")
    if not plan.groupes:
        afficher("  (aucun groupe)")
        return
    largeur = max(len(g.nom) for g, _ in plan.groupes)
    for groupe, retenu in plan.groupes:
        case = f"{GREEN}[x]{RESET}" if retenu else "[ ]"
        afficher(f"  {case} {groupe.nom:<{largeur}}  {groupe.si.texte or 'toujours'}")


def etat(nom: str, installes: set[str], disponibles: set[str], retrait: bool) -> str:
    if retrait:
        return f"{YELLOW}à retirer{RESET}" if nom in installes else "absent"
    if nom in installes:
        return f"{GREEN}installé{RESET}"
    if nom in disponibles:
        return f"{YELLOW}à installer{RESET}"
    return f"{RED}introuvable{RESET}"


def afficher_paquets(plan: Plan, ctx: Contexte) -> None:
    installes: set[str] | None = None
    disponibles: set[str] = set()
    # En simulation --os, dpkg et apt-cache décriraient cette machine et non la
    # cible : on se limite à la liste.
    if not ctx.simule:
        reels = list(dict.fromkeys(r for _, r in plan.installer + plan.retirer))
        installes = paquets_installes(reels)
        disponibles = paquets_disponibles([r for r in reels if r not in installes])

    for titre, paquets, retrait in (
        ("Paquets à installer", plan.installer, False),
        ("Paquets à retirer", plan.retirer, True),
    ):
        afficher(f"\n{BOLD}{titre} ({len(paquets)}) :{RESET}")
        if not paquets:
            afficher("  (aucun)")
        for canonique, reel in paquets:
            libelle = canonique if reel == canonique else f"{canonique} (-> {reel})"
            if installes is None:
                afficher(f"  - {libelle}")
            else:
                afficher(f"  - {libelle} : {etat(reel, installes, disponibles, retrait)}")
    afficher()


# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
def elever_privileges() -> None:
    if os.geteuid() == 0:
        return
    if shutil.which("sudo") is None:
        die("Droits root nécessaires et sudo absent : relancer en root.")
    # Tier 1 : pas de -E. « python3 » est résolu par sudo dans son secure_path,
    # et non via sys.executable : l'interpréteur exécuté en root ne doit pas
    # venir de l'environnement de l'utilisateur (pyenv, venv). sudo conserve le
    # répertoire courant et home_appelant() retrouve le ~ de l'appelant : le
    # profil trouvé après l'élévation est le même.
    os.execvp("sudo", ["sudo", "python3", os.path.realpath(__file__), *sys.argv[1:]])


def apt_get(*arguments: str) -> None:
    commande = ["apt-get", *arguments]
    env = {**os.environ, "DEBIAN_FRONTEND": "noninteractive"}
    try:
        subprocess.run(commande, check=True, env=env)
    except FileNotFoundError:
        die("apt-get introuvable : Debian ou Ubuntu requis.")
    except subprocess.CalledProcessError as e:
        die(f"Échec de « {' '.join(commande)} » (code {e.returncode}).")


def etape(numero: int, titre: str) -> None:
    afficher(f"\n{BOLD}--- Étape {numero} : {titre} ---{RESET}")


def executer(plan: Plan) -> None:
    etape(1, "Mise à jour")
    info("Mise à jour de la liste des paquets et mise à niveau...")
    apt_get("update", "-q")
    apt_get("upgrade", "-y")
    success("Mise à jour terminée.")

    etape(2, "Désinstallation")
    candidats = list(dict.fromkeys(r for _, r in plan.retirer))
    installes = paquets_installes(candidats)
    a_retirer = [nom for nom in candidats if nom in installes]
    if a_retirer:
        info(f"Désinstallation : {' '.join(a_retirer)}")
        apt_get("remove", "-y", *a_retirer)
        success("Désinstallation terminée.")
    else:
        info("Aucun paquet à retirer.")

    etape(3, "Installation")
    candidats = list(dict.fromkeys(r for _, r in plan.installer))
    installes = paquets_installes(candidats)
    manquants = [nom for nom in candidats if nom not in installes]
    disponibles = paquets_disponibles(manquants)
    ignores = [nom for nom in manquants if nom not in disponibles]
    a_installer = [nom for nom in manquants if nom in disponibles]
    if ignores:
        warn(f"Paquets introuvables dans les dépôts (ignorés) : {' '.join(ignores)}")
    if a_installer:
        info(f"Installation : {' '.join(a_installer)}")
        apt_get("install", "-y", *a_installer)
        success("Installation terminée.")
    else:
        success("Tous les paquets sont déjà installés.")

    etape(4, "Nettoyage")
    info("Nettoyage des dépendances inutiles...")
    apt_get("autoremove", "-y")
    success("Nettoyage terminé.")


# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
def main() -> None:
    opts = parse_args(sys.argv[1:])

    if tomllib is None:
        die(f"Python 3.11 ou plus récent requis (module tomllib) ; version actuelle : {platform.python_version()}.")

    # Profil cherché et validé avant l'élévation : un nom mal tapé ou un TOML
    # invalide est signalé sans demander de mot de passe.
    chemin, source = trouver_config(opts)
    profil = charger_profil(chemin)

    if not opts.dry_run:
        elever_privileges()

    afficher(f"\n{BOLD}=== Installation des paquets de la VM ==={RESET}\n")
    info(f"Profil : {BOLD}{chemin}{RESET} ({source})")
    if profil.description:
        info(f"Description : {profil.description}")

    ctx = construire_contexte(opts)
    if opts.dry_run and not ctx.simule:
        warn("Mode --dry-run : aucune modification ne sera effectuée.")

    plan = construire_plan(profil, ctx)
    afficher_groupes(plan)

    if opts.dry_run:
        afficher_paquets(plan, ctx)
        return

    executer(plan)
    afficher()
    success("Script terminé avec succès.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        error("Interrompu.")
        sys.exit(130)
