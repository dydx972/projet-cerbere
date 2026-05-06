import RPi.GPIO as GPIO
import time
import requests

PIR_PIN = 17
LED_PIN = 18

# Adresse du serveur de ton equipier
ENDPOINT   = "http://192.168.1.199/api/detections.php"
ID_CAPTEUR = 1      # PIR Salle W13
SEUIL_ALERTE = 30   # secondes : si detection > 30s, une alerte est generee

GPIO.setmode(GPIO.BCM)
GPIO.setup(PIR_PIN, GPIO.IN)
GPIO.setup(LED_PIN, GPIO.OUT)

print("Initialisation du capteur PIR...")
time.sleep(2)
print("Pret ! Surveillance en cours...")

def enregistrer_detection(duree):
    alerte = duree >= SEUIL_ALERTE
    details = "Presence prolongee " + str(duree) + "s" if alerte else "Passage normal"
    payload = {
        "id_capteur":               ID_CAPTEUR,
        "duree_detection_secondes": duree,
        "alerte_generee":           alerte,
        "details":                  details
    }
    try:
        r = requests.post(ENDPOINT, json=payload, timeout=5)
        data = r.json()
        if data.get("success"):
            print("  -> BDD OK : id=" + str(data["id_detection"])
                  + (" | ALERTE creee" if data["alerte"] else ""))
        else:
            print("  -> Erreur serveur : " + str(data.get("error")))
    except Exception as e:
        print("  -> Serveur injoignable : " + str(e))

try:
    while True:
        if GPIO.input(PIR_PIN) == GPIO.HIGH:
            debut = time.time()
            print("MOUVEMENT DETECTE ! [" + time.strftime("%H:%M:%S") + "]")
            GPIO.output(LED_PIN, GPIO.HIGH)

            # Attend que le mouvement s'arrete
            while GPIO.input(PIR_PIN) == GPIO.HIGH:
                time.sleep(0.1)

            duree = int(time.time() - debut)
            GPIO.output(LED_PIN, GPIO.LOW)
            print("Zone libre. Duree : " + str(duree) + "s [" + time.strftime("%H:%M:%S") + "]")

            # Envoie les donnees au serveur
            enregistrer_detection(duree)
            time.sleep(1)
        else:
            time.sleep(0.1)

except KeyboardInterrupt:
    print("Arret du systeme.")

finally:
    GPIO.output(LED_PIN, GPIO.LOW)
    GPIO.cleanup()
