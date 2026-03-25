#!/usr/bin/env python3
"""
CERBERE - Script de détection PIR HC-SR501
Enregistre chaque détection dans la table logs_detections de la BDD.

Usage :
    python3 pir_detection.py --capteur 1   # PIR Salle W13  (GPIO 17)
    python3 pir_detection.py --capteur 2   # PIR Laboratoire (GPIO 18)
"""

import RPi.GPIO as GPIO
import pymysql
import time
import argparse
import sys
from datetime import datetime

# ─── CONFIGURATION BDD ────────────────────────────────────────────────────────
DB_HOST = "localhost"
DB_NAME = "cerbere_db"
DB_USER = "root"
DB_PASS = "pi"

# Seuil en secondes : au-delà, une alerte est générée automatiquement
SEUIL_ALERTE_SECONDES = 30

# ─── CONNEXION BDD ────────────────────────────────────────────────────────────
def get_db():
    return pymysql.connect(
        host=DB_HOST, db=DB_NAME,
        user=DB_USER, password=DB_PASS,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )

# ─── CHARGEMENT DU CAPTEUR ────────────────────────────────────────────────────
def charger_capteur(db, id_capteur):
    with db.cursor() as cur:
        cur.execute(
            "SELECT * FROM capteurs_presence WHERE id_capteur = %s AND actif = 1",
            (id_capteur,)
        )
        capteur = cur.fetchone()
    if not capteur:
        print(f"[ERREUR] Capteur ID={id_capteur} introuvable ou inactif en BDD.")
        sys.exit(1)
    return capteur

# ─── ENREGISTREMENT DÉTECTION ─────────────────────────────────────────────────
def enregistrer_detection(db, id_capteur, duree, alerte, details):
    with db.cursor() as cur:
        # Insère dans logs_detections
        cur.execute(
            """INSERT INTO logs_detections
               (id_capteur, duree_detection_secondes, alerte_generee, details)
               VALUES (%s, %s, %s, %s)""",
            (id_capteur, duree, 1 if alerte else 0, details)
        )
        id_detection = db.insert_id()

        # Met à jour derniere_detection dans capteurs_presence
        cur.execute(
            "UPDATE capteurs_presence SET derniere_detection = NOW() WHERE id_capteur = %s",
            (id_capteur,)
        )

        # Si alerte : insère aussi dans la table alertes
        if alerte:
            cur.execute(
                """INSERT INTO alertes (type_alerte, niveau_gravite, id_capteur, message)
                   VALUES ('presence_suspecte', 'warning', %s, %s)""",
                (id_capteur, details)
            )

    return id_detection

# ─── BOUCLE PRINCIPALE ────────────────────────────────────────────────────────
def run(id_capteur):
    db = get_db()
    capteur = charger_capteur(db, id_capteur)

    nom     = capteur["nom_capteur"]
    gpio    = capteur["gpio_pin"]
    maintien = capteur["temps_maintien_secondes"]

    print(f"[CERBERE] Capteur : {nom}")
    print(f"[CERBERE] GPIO PIN : {gpio}  |  Maintien : {maintien}s  |  Seuil alerte : {SEUIL_ALERTE_SECONDES}s")
    print("[CERBERE] En attente de détections... (Ctrl+C pour arrêter)\n")

    GPIO.setmode(GPIO.BCM)
    GPIO.setup(gpio, GPIO.IN)

    en_detection = False
    debut_detection = None

    try:
        while True:
            etat = GPIO.input(gpio)

            if etat == GPIO.HIGH and not en_detection:
                # Début de détection
                en_detection = True
                debut_detection = time.time()
                ts = datetime.now().strftime("%H:%M:%S")
                print(f"[{ts}] Mouvement détecté !")

            elif etat == GPIO.LOW and en_detection:
                # Fin de détection
                duree = int(time.time() - debut_detection)
                en_detection = False

                alerte = duree >= SEUIL_ALERTE_SECONDES
                details = f"Durée : {duree}s"
                if alerte:
                    details += f" — Présence prolongée (seuil {SEUIL_ALERTE_SECONDES}s dépassé)"

                id_det = enregistrer_detection(db, id_capteur, duree, alerte, details)

                ts = datetime.now().strftime("%H:%M:%S")
                flag = " ⚠ ALERTE générée" if alerte else ""
                print(f"[{ts}] Fin détection — {duree}s — ID log={id_det}{flag}")

            time.sleep(0.1)

    except KeyboardInterrupt:
        print("\n[CERBERE] Arrêt du script.")

    finally:
        GPIO.cleanup()
        db.close()

# ─── POINT D'ENTRÉE ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CERBERE - Détection PIR")
    parser.add_argument(
        "--capteur", type=int, required=True,
        help="ID du capteur en BDD (1 = PIR W13, 2 = PIR Laboratoire)"
    )
    args = parser.parse_args()
    run(args.capteur)
