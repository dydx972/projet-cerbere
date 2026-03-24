#!/usr/bin/env python3
"""
CERBERE - Lecteur RFID avec connexion BDD
Inspiré fidèlement de badge.py (PROMAG MF7, UART /dev/ttyS0).

Usage :
    sudo python3 badge_bdd.py --mode enregistrement
    sudo python3 badge_bdd.py --mode lecture  (défaut)
"""

import serial
import RPi.GPIO as GPIO
import requests
import time
import argparse
import subprocess
import json

# ─── CONFIGURATION ────────────────────────────────────────────
SERVEUR        = "http://192.168.1.120"
ID_PORTE       = 1

RELAY_PIN      = 22
DOOR_OPEN_SECS = 5
ANTI_REBOND    = 2
NB_LECTURES    = 5

SEUIL_SIMILARITE = 0.85
MIN_UID_LEN      = 10    # ignorer les lectures partielles trop courtes

# ─── INIT (identique à badge.py) ──────────────────────────────
subprocess.call(['fuser', '-k', '/dev/ttyS0'], stderr=subprocess.DEVNULL)
time.sleep(0.5)

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(RELAY_PIN, GPIO.OUT, initial=GPIO.HIGH)

time.sleep(1)
ser = serial.Serial('/dev/ttyS0', 9600, timeout=0)
ser.flushInput()

# ─── LECTURE PROPRE DU LECTEUR ────────────────────────────────
def lire_badge():
    """
    Quand des données arrivent, on attend un court instant pour laisser
    le lecteur finir d'envoyer sa trame, puis on lit tout.
    On ne flush PAS avant la lecture pour ne pas perdre les données
    d'un passage rapide.
    """
    if ser.in_waiting == 0:
        return None

    # Attendre que la trame soit complète
    time.sleep(0.15)
    data = ser.read(ser.in_waiting)

    if not data or not any(b != 0 for b in data):
        return None

    uid = ''.join(f'{b:02X}' for b in data if b != 0)

    if len(uid) < MIN_UID_LEN:
        ser.flushInput()
        return None

    return uid

# ─── SIMILARITÉ (copié de badge.py) ───────────────────────────
def similarite(uid1, uid2):
    commun = sum(1 for a, b in zip(uid1, uid2) if a == b)
    return commun / max(len(uid1), len(uid2))

# ─── RECONNAISSANCE (corrigé) ────────────────────────────────
def badge_reconnu(uid_brut, badges_db):
    if len(uid_brut) < MIN_UID_LEN:
        return None, None

    meilleur_score = 0
    meilleur_uid   = None
    meilleur_id    = None

    for badge in badges_db:
        uid_badge = badge["uid_badge"]

        if badge.get("lectures_json"):
            try:
                lectures = json.loads(badge["lectures_json"])
            except Exception:
                lectures = [uid_badge]
        else:
            lectures = [uid_badge]

        for lecture in lectures:
            if len(lecture) < MIN_UID_LEN:
                continue

            # Match exact
            if uid_brut == lecture:
                return uid_badge, badge["id_badge"]

            # Containment seulement si longueurs proches
            ratio_len = len(uid_brut) / len(lecture)
            if 0.7 <= ratio_len <= 1.3:
                if lecture in uid_brut or uid_brut in lecture:
                    return uid_badge, badge["id_badge"]

            # Similarité
            score = similarite(uid_brut, lecture)
            if score > meilleur_score:
                meilleur_score = score
                meilleur_uid   = uid_badge
                meilleur_id    = badge["id_badge"]

    if meilleur_score > SEUIL_SIMILARITE:
        return meilleur_uid, meilleur_id
    return None, None

# ─── CACHE BADGES ─────────────────────────────────────────────
_badges_cache    = []
_cache_ts        = 0
CACHE_DUREE      = 60

def get_badges(force=False):
    global _badges_cache, _cache_ts
    if force or time.time() - _cache_ts > CACHE_DUREE:
        try:
            r = requests.get(f"{SERVEUR}/api/badges.php", timeout=5)
            _badges_cache = r.json().get("data", [])
            _cache_ts = time.time()
        except Exception as e:
            print(f"  [WARN] Cache badges non rafraîchi : {e}")
    return _badges_cache

# ─── OUVRIR LA GÂCHE ──────────────────────────────────────────
def ouvrir_gache():
    print("  -> Ouverture gâche + ventouse...")
    subprocess.call(["sudo", "python3", "/home/kyriann/gache.py", "--duree", str(DOOR_OPEN_SECS)])
    print("  -> Gâche verrouillée.")

# ══════════════════════════════════════════════════════════════
#  MODE ENREGISTREMENT
# ══════════════════════════════════════════════════════════════
def mode_enregistrement():
    print("=" * 50)
    print("  MODE ENREGISTREMENT — CERBERE")
    print(f"  Serveur : {SERVEUR}")
    print("  Ctrl+C pour quitter.")
    print("=" * 50)

    while True:
        print("\nApprochez un badge...")
        while True:
            uid_premier = lire_badge()
            if uid_premier:
                break
            time.sleep(0.05)

        ser.flushInput()

        badges = get_badges(force=True)
        uid_bdd, _ = badge_reconnu(uid_premier, badges)
        if uid_bdd:
            print(f"  [INFO] Badge déjà enregistré (UID en BDD : {uid_bdd}).")
            time.sleep(1)
            continue

        print(f"\nNouveau badge détecté. Passez-le {NB_LECTURES} fois pour l'enregistrer...")
        lectures  = [uid_premier]
        compteur  = 1
        print(f"  Lecture 1/{NB_LECTURES} : {uid_premier}")
        time.sleep(1)

        while compteur < NB_LECTURES:
            uid = lire_badge()
            if uid:
                lectures.append(uid)
                compteur += 1
                print(f"  Lecture {compteur}/{NB_LECTURES} : {uid}")
                ser.flushInput()
                time.sleep(1)
            time.sleep(0.05)

        print("\n  Informations du badge :")
        type_badge = input("  Type [Mifare_Classic] : ").strip() or "Mifare_Classic"

        try:
            r = requests.get(f"{SERVEUR}/api/utilisateurs.php", timeout=5)
            users = r.json().get("data", [])
            print("\n  Utilisateurs disponibles :")
            for u in users:
                print(f"    [{u['id_utilisateur']}] {u['nom']} {u['prenom']}")
            id_user = input("  ID utilisateur (vide = inconnu) : ").strip()
            id_user = int(id_user) if id_user.isdigit() else None
        except Exception:
            id_user = None

        date_exp = input("  Date d'expiration (YYYY-MM-DD, vide = aucune) : ").strip() or None

        payload = {
            "uid_badge"       : lectures[0],
            "lectures_json"   : json.dumps(lectures),
            "type_badge"      : type_badge,
            "id_utilisateur"  : id_user,
            "date_attribution": time.strftime("%Y-%m-%d"),
            "date_expiration" : date_exp,
        }
        try:
            r = requests.post(f"{SERVEUR}/api/badges.php", json=payload, timeout=5)
            d = r.json()
            if d.get("success"):
                print(f"\n  [OK] Badge enregistré en BDD avec {NB_LECTURES} lectures (id={d['id']}).")
            else:
                print(f"\n  [ERREUR] {d.get('error', 'Erreur inconnue')}")
        except Exception as e:
            print(f"\n  [ERREUR] {e}")

        print("\n  Approchez un autre badge ou Ctrl+C pour quitter.")

# ══════════════════════════════════════════════════════════════
#  MODE LECTURE
# ══════════════════════════════════════════════════════════════
def mode_lecture():
    print("=" * 50)
    print("  MODE LECTURE — CERBERE")
    print(f"  Serveur : {SERVEUR}  |  Porte ID : {ID_PORTE}")
    print("  Approchez un badge.")
    print("  Ctrl+C pour quitter.")
    print("=" * 50)

    badges = get_badges(force=True)
    print(f"  {len(badges)} badge(s) chargé(s) depuis la BDD.")

    dernier_uid     = ""
    derniere_detect = 0

    try:
        while True:
            uid_brut = lire_badge()
            if uid_brut:
                uid_bdd, id_badge = badge_reconnu(uid_brut, badges)
                maintenant = time.time()

                if uid_bdd and (uid_bdd != dernier_uid or (maintenant - derniere_detect) > ANTI_REBOND):
                    dernier_uid     = uid_bdd
                    derniere_detect = maintenant

                    print(f"\nBadge reconnu (UID lu: {uid_brut}).")

                    try:
                        r = requests.post(
                            f"{SERVEUR}/api/badge_check.php",
                            json={"uid": uid_bdd, "id_porte": ID_PORTE},
                            timeout=5,
                        )
                        d = r.json()
                    except Exception as e:
                        print(f"  [ERREUR] Serveur : {e}")
                        print("  Accès refusé par défaut.")
                        ser.flushInput()
                        time.sleep(1)
                        continue

                    utilisateur = d.get("utilisateur") or "Inconnu"
                    details     = d.get("details", "")

                    if d.get("autorise"):
                        print(f"  [ACCÈS ACCORDÉ] {utilisateur}")
                        print(f"  -> {details}")
                        ouvrir_gache()
                    else:
                        print(f"  [ACCÈS REFUSÉ] {utilisateur}")
                        print(f"  -> {details}")

                    ser.flushInput()
                    badges = get_badges()

                elif not uid_bdd:
                    print(f"  Accès refusé — badge inconnu (UID: {uid_brut}).")
                    ser.flushInput()
                    time.sleep(1)

            time.sleep(0.05)

    except KeyboardInterrupt:
        print("\nArrêt.")

# ─── POINT D'ENTRÉE ───────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CERBERE - Contrôle RFID")
    parser.add_argument("--mode", choices=["enregistrement", "lecture"], default="lecture")
    args = parser.parse_args()

    try:
        if args.mode == "enregistrement":
            mode_enregistrement()
        else:
            mode_lecture()
    except KeyboardInterrupt:
        print("\nArrêt.")
    finally:
        ser.close()
        GPIO.output(RELAY_PIN, GPIO.HIGH)
        GPIO.cleanup()
