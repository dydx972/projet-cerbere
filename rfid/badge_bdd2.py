#!/usr/bin/env python3
"""
CERBERE - Lecteur RFID avec connexion BDD (v2)
Usage :
    sudo python3 badge_bdd2.py --scan-gpio          # trouve le pin relais
    sudo python3 badge_bdd2.py --mode enregistrement
    sudo python3 badge_bdd2.py --mode lecture        (défaut)
"""

import serial
import RPi.GPIO as GPIO
import requests
import time
import argparse
import subprocess
import sys
import hashlib
import os

# ─── CONFIGURATION ────────────────────────────────────────────
SERVEUR        = "http://192.168.1.120"
ID_PORTE       = 1
DOOR_OPEN_SECS = 5
ANTI_REBOND    = 2

CONFIG_FILE    = "/home/kyriann/.cerbere_pin"   # pin sauvegardé après scan
PINS_CANDIDATS = [4, 5, 6, 17, 18, 20, 22, 23, 24, 25, 26, 27]

# ─── PIN RELAIS ───────────────────────────────────────────────
def charger_pin():
    """Lit le pin sauvegardé, ou 22 par défaut."""
    if os.path.exists(CONFIG_FILE):
        try:
            return int(open(CONFIG_FILE).read().strip())
        except Exception:
            pass
    return 22

def sauvegarder_pin(pin):
    with open(CONFIG_FILE, "w") as f:
        f.write(str(pin))

RELAY_PIN = charger_pin()

# ─── SCAN GPIO : TROUVE LE RELAIS ─────────────────────────────
def scan_gpio():
    """Pulse chaque pin candidat LOW pendant 2s — appuyez sur Entrée si le relais clique."""
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BCM)

    print("=" * 54)
    print("  SCAN GPIO — RECHERCHE DU PIN RELAIS")
    print("  Chaque pin sera activé (LOW) pendant 2 secondes.")
    print("  Appuyez sur Entrée si vous entendez le relais.")
    print("  Appuyez sur 'n' + Entrée pour passer au suivant.")
    print("=" * 54)

    for pin in PINS_CANDIDATS:
        try:
            GPIO.setup(pin, GPIO.OUT, initial=GPIO.HIGH)
        except Exception:
            continue

        print(f"\n  → Test BCM {pin}  (activation dans 1s...)", end="", flush=True)
        time.sleep(1)
        GPIO.output(pin, GPIO.LOW)
        print(f"  [ACTIF]", end="", flush=True)

        # Attendre réponse utilisateur (avec timeout 3s)
        import select
        rdy, _, _ = select.select([sys.stdin], [], [], 3)
        reponse = sys.stdin.readline().strip().lower() if rdy else ""

        GPIO.output(pin, GPIO.HIGH)

        if reponse != "n":
            print(f"\n  [TROUVÉ] Pin relais = BCM {pin}")
            sauvegarder_pin(pin)
            GPIO.cleanup()
            return pin

        GPIO.setup(pin, GPIO.IN)  # libère le pin

    print("\n  [ÉCHEC] Aucun pin identifié. Vérifiez le câblage.")
    GPIO.cleanup()
    return None

# ─── INIT GPIO + SERIAL ───────────────────────────────────────
def init_hardware():
    subprocess.call(['fuser', '-k', '/dev/ttyS0'], stderr=subprocess.DEVNULL)
    time.sleep(0.5)
    GPIO.setwarnings(False)
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(RELAY_PIN, GPIO.OUT, initial=GPIO.HIGH)
    ser = serial.Serial('/dev/ttyS0', 9600, timeout=0)
    ser.flushInput()
    return ser

# ─── LECTURE UID ──────────────────────────────────────────────
def lire_uid(ser):
    """
    Lit l'UID badge depuis le flux UART brut.
    Accumule les octets non-nuls entre les lectures pour capturer
    la trame complète même si elle arrive en plusieurs morceaux.
    """
    if ser.in_waiting == 0:
        return None

    data = ser.read(ser.in_waiting)
    non_nuls = bytes(b for b in data if b != 0)

    if not non_nuls:
        return None

    # Des octets détectés — attendre la fin de la trame (35ms max)
    time.sleep(0.05)
    if ser.in_waiting > 0:
        extra = ser.read(ser.in_waiting)
        non_nuls += bytes(b for b in extra if b != 0)

    if len(non_nuls) >= 4:
        stable = non_nuls[1:] if len(non_nuls) > 1 else non_nuls
        return hashlib.md5(stable).hexdigest()[:16].upper()

    return None

# ─── OUVRIR LA GÂCHE ──────────────────────────────────────────
def ouvrir_gache():
    print(f"  -> Gâche ouverte (pin BCM {RELAY_PIN}).")
    GPIO.output(RELAY_PIN, GPIO.LOW)
    time.sleep(DOOR_OPEN_SECS)
    GPIO.output(RELAY_PIN, GPIO.HIGH)
    print("  -> Gâche verrouillée.")

# ══════════════════════════════════════════════════════════════
#  MODE ENREGISTREMENT
# ══════════════════════════════════════════════════════════════
def mode_enregistrement(ser):
    print("=" * 50)
    print("  MODE ENREGISTREMENT — CERBERE v2")
    print(f"  Serveur : {SERVEUR}  |  Pin relais : BCM {RELAY_PIN}")
    print("  Approchez un badge pour l'enregistrer.")
    print("  Ctrl+C pour quitter.")
    print("=" * 50)

    dernier_uid        = ""
    derniere_detection = 0

    while True:
        uid = lire_uid(ser)
        if uid:
            maintenant = time.time()
            if uid == dernier_uid and (maintenant - derniere_detection) < ANTI_REBOND:
                time.sleep(0.02)
                continue

            dernier_uid        = uid
            derniere_detection = maintenant
            ser.flushInput()

            print(f"\nBadge détecté — UID : {uid}")

            try:
                r = requests.get(f"{SERVEUR}/api/badges.php", timeout=5)
                badges_existants = [b["uid_badge"] for b in r.json().get("data", [])]
            except Exception as e:
                print(f"  [ERREUR] Serveur : {e}")
                time.sleep(1)
                continue

            if uid in badges_existants:
                print("  [INFO] Badge déjà enregistré.")
                time.sleep(1)
                continue

            print("  Entrez les informations du badge :")
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
                "uid_badge"        : uid,
                "type_badge"       : type_badge,
                "id_utilisateur"   : id_user,
                "date_attribution" : time.strftime("%Y-%m-%d"),
                "date_expiration"  : date_exp,
            }
            try:
                r = requests.post(f"{SERVEUR}/api/badges.php", json=payload, timeout=5)
                data = r.json()
                if data.get("success"):
                    print(f"\n  [OK] Badge {uid} enregistré (id={data['id']}).")
                else:
                    print(f"\n  [ERREUR] {data.get('error', 'Erreur inconnue')}")
            except Exception as e:
                print(f"\n  [ERREUR] {e}")

            print("\n  Approchez un autre badge ou Ctrl+C pour quitter.")

        time.sleep(0.02)

# ══════════════════════════════════════════════════════════════
#  MODE LECTURE
# ══════════════════════════════════════════════════════════════
def mode_lecture(ser):
    print("=" * 50)
    print("  MODE LECTURE — CERBERE v2")
    print(f"  Serveur : {SERVEUR}  |  Porte : {ID_PORTE}  |  Pin : BCM {RELAY_PIN}")
    print("  Approchez un badge.")
    print("  Ctrl+C pour quitter.")
    print("=" * 50)

    dernier_uid        = ""
    derniere_detection = 0

    while True:
        uid = lire_uid(ser)
        if uid:
            maintenant = time.time()
            if uid == dernier_uid and (maintenant - derniere_detection) < ANTI_REBOND:
                time.sleep(0.02)
                continue

            dernier_uid        = uid
            derniere_detection = maintenant
            ser.flushInput()

            print(f"\nBadge détecté — UID : {uid}")

            try:
                r = requests.post(
                    f"{SERVEUR}/api/badge_check.php",
                    json={"uid": uid, "id_porte": ID_PORTE},
                    timeout=5,
                )
                data = r.json()
            except Exception as e:
                print(f"  [ERREUR] Serveur injoignable : {e}")
                print("  Accès refusé par défaut.")
                time.sleep(1)
                continue

            utilisateur = data.get("utilisateur") or "Inconnu"
            details     = data.get("details", "")

            if data.get("autorise"):
                print(f"  [ACCÈS ACCORDÉ] {utilisateur}")
                print(f"  -> {details}")
                ouvrir_gache()
            else:
                print(f"  [ACCÈS REFUSÉ] {utilisateur}")
                print(f"  -> {details}")

        time.sleep(0.02)

# ─── POINT D'ENTRÉE ───────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CERBERE v2 - Contrôle RFID")
    parser.add_argument("--mode", choices=["enregistrement", "lecture"],
                        default="lecture")
    parser.add_argument("--scan-gpio", action="store_true",
                        help="Détecte automatiquement le pin du relais")
    args = parser.parse_args()

    if args.scan_gpio:
        pin = scan_gpio()
        if pin:
            RELAY_PIN = pin
            print(f"\n  Pin sauvegardé dans {CONFIG_FILE}")
            print(f"  Relancez : sudo python3 badge_bdd2.py --mode lecture")
        sys.exit(0)

    print(f"  [CONFIG] Pin relais : BCM {RELAY_PIN}  "
          f"(modifiable avec --scan-gpio)")

    ser = init_hardware()
    try:
        if args.mode == "enregistrement":
            mode_enregistrement(ser)
        else:
            mode_lecture(ser)
    except KeyboardInterrupt:
        print("\nArrêt.")
    finally:
        ser.close()
        GPIO.output(RELAY_PIN, GPIO.HIGH)
        GPIO.cleanup()
