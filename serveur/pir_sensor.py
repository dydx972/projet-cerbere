import sys
sys.path.insert(0, '/home/pi/.local/lib/python3.7/site-packages')
import grovepi
import time

pir_sensor = 8
grovepi.pinMode(pir_sensor, 'INPUT')

print('Capteur PIR Mini Grove sur D8 - Detection de mouvement...')
print('Ctrl+C pour arreter')
print()

try:
    while True:
        motion = grovepi.digitalRead(pir_sensor)
        if motion == 1:
            print(f'[{time.strftime("%H:%M:%S")}] >>> MOUVEMENT DETECTE! <<<')
        else:
            print(f'[{time.strftime("%H:%M:%S")}] . pas de mouvement')
        time.sleep(1)
except KeyboardInterrupt:
    print('\nArret du capteur.')
