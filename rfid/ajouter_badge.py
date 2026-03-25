#!/usr/bin/env python3
import serial
import time
import json
import subprocess

FICHIER_BADGES = '/home/kyriann/badges.json'

subprocess.call(['fuser', '-k', '/dev/ttyS0'])
time.sleep(0.5)

ser = serial.Serial('/dev/ttyS0', 9600, timeout=0)
ser.flushInput()

def charger_badges():
    try:
        with open(FICHIER_BADGES, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

def sauvegarder_badges(badges):
    with open(FICHIER_BADGES, 'w') as f:
        json.dump(badges, f, indent=2)

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
                return nom, 100
            score = similarite(uid_brut, lecture)
            if score > meilleur_score:
                meilleur_score = score
                meilleur_nom = nom
    if meilleur_score > 0.70:
        return meilleur_nom, int(meilleur_score * 100)
    return None, 0

badges = charger_badges()

print("=====================================")
print("  Gestion des badges")
print("=====================================")
print("1. Ajouter un badge")
print("2. Supprimer un badge")
print("3. Voir tous les badges")
print("4. Tester un badge")
print("5. Reenregistrer tous les badges")
choix = input("Ton choix : ")

if choix == "1":
    nom = input("Nom du proprietaire : ")
    print(f"Passe le badge de {nom} 10 fois...")
    lectures = []
    compteur = 0
    while compteur < 10:
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            if data and any(b != 0 for b in data):
                uid = ''.join(f'{b:02X}' for b in data if b != 0)
                lectures.append(uid)
                compteur += 1
                print(f"Lecture {compteur}/10 enregistree")
                ser.flushInput()
                time.sleep(1)
        time.sleep(0.05)
    badges[nom] = lectures
    sauvegarder_badges(badges)
    print(f"Badge de {nom} ajoute avec 10 lectures !")

elif choix == "2":
    print("Badges existants :")
    for nom in badges:
        print(f"  - {nom}")
    nom = input("Nom du badge a supprimer : ")
    if nom in badges:
        del badges[nom]
        sauvegarder_badges(badges)
        print(f"Badge de {nom} supprime !")
    else:
        print("Badge non trouve !")

elif choix == "3":
    print("Badges enregistres :")
    for nom in badges:
        print(f"  - {nom}")

elif choix == "4":
    print("Passe ton badge pour tester...")
    detecte = False
    for i in range(50):
        if ser.in_waiting > 0:
            data = ser.read(ser.in_waiting)
            if data and any(b != 0 for b in data):
                nom, score = badge_reconnu(data, badges)
                if nom:
                    print(f"Badge reconnu : {nom} (score: {score}%)")
                else:
                    print("Badge non reconnu !")
                detecte = True
                break
        time.sleep(0.1)
    if not detecte:
        print("Aucun badge detecte.")

elif choix == "5":
    print("Badges a reenregistrer :")
    for nom in badges:
        print(f"  - {nom}")
    nom = input("Quel badge reenregistrer ? ")
    if nom in badges:
        print(f"Passe le badge de {nom} 10 fois...")
        lectures = []
        compteur = 0
        while compteur < 10:
            if ser.in_waiting > 0:
                data = ser.read(ser.in_waiting)
                if data and any(b != 0 for b in data):
                    uid = ''.join(f'{b:02X}' for b in data if b != 0)
                    lectures.append(uid)
                    compteur += 1
                    print(f"Lecture {compteur}/10 enregistree")
                    ser.flushInput()
                    time.sleep(1)
            time.sleep(0.05)
        badges[nom] = lectures
        sauvegarder_badges(badges)
        print(f"Badge de {nom} reenregistre avec 10 lectures !")
    else:
        print("Badge non trouve !")

ser.close()
print("Termine !")
