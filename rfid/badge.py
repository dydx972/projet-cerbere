#!/usr/bin/env python3
import serial
import RPi.GPIO as GPIO
import time
import json

RELAY_PIN      = 22
DOOR_OPEN_SECS = 10
ANTI_REBOND    = 2
FICHIER_BADGES = '/home/kyriann/badges.json'

GPIO.setwarnings(False)
GPIO.setmode(GPIO.BCM)
GPIO.setup(RELAY_PIN, GPIO.OUT, initial=GPIO.HIGH)

time.sleep(1)
ser = serial.Serial('/dev/ttyS0', 9600, timeout=0)
ser.flushInput()

def charger_badges():
    try:
        with open(FICHIER_BADGES, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

def similarite(uid1, uid2):
    commun = sum(1 for a, b in zip(uid1, uid2) if a == b)
    return commun / max(len(uid1), len(uid2))

def badge_reconnu(data, badges):
    uid_brut = ''.join(f'{b:02X}' for b in data if b != 0)
    meilleur_score = 0
    meilleur_nom = None
    for nom, lectures in badges.items():
        for lecture in lectures:
            if lecture in uid_brut or uid_brut in lecture:
                return nom
            score = similarite(uid_brut, lecture)
            if score > meilleur_score:
                meilleur_score = score
                meilleur_nom = nom
    if meilleur_score > 0.70:
        return meilleur_nom
    return None

badges = charger_badges()
print(f"Controle acces demarre - {len(badges)} badge(s) charge(s)")
print("Approche ton badge...")

dernier_nom = ""
derniere_detection = 0

try:
    while True:
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            if data and any(b != 0 for b in data):
                nom = badge_reconnu(data, badges)
                maintenant = time.time()
                if nom and (nom != dernier_nom or (maintenant - derniere_detection) > ANTI_REBOND):
                    dernier_nom = nom
                    derniere_detection = maintenant
                    print(f"Acces accorde - Bonjour {nom} !")
                    GPIO.output(RELAY_PIN, GPIO.LOW)
                    time.sleep(DOOR_OPEN_SECS)
                    GPIO.output(RELAY_PIN, GPIO.HIGH)
                    print("Gache fermee - Approche ton badge...")
                    ser.flushInput()
                elif not nom:
                    print("Acces refuse !")
                    ser.flushInput()
                    time.sleep(1)
        time.sleep(0.05)
except KeyboardInterrupt:
    print("\nArret.")
finally:
    ser.close()
    GPIO.output(RELAY_PIN, GPIO.HIGH)
    GPIO.cleanup()
