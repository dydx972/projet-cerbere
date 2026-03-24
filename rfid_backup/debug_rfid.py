#!/usr/bin/env python3
"""Script de debug pour voir les données brutes du Promag MF7"""
import serial
import time
import subprocess

subprocess.call(['fuser', '-k', '/dev/ttyS0'], stderr=subprocess.DEVNULL)
time.sleep(0.5)

ser = serial.Serial('/dev/ttyS0', 9600, timeout=0)
ser.flushInput()

print("Approchez un badge... (Ctrl+C pour quitter)")
print("=" * 50)

try:
    while True:
        if ser.in_waiting > 0:
            time.sleep(0.15)  # attendre trame complète
            data = ser.read(ser.in_waiting)
            if data and any(b != 0 for b in data):
                print(f"Octets bruts     : {list(data)}")
                print(f"Hex brut         : {data.hex().upper()}")
                print(f"Hex (sans 0x00)  : {''.join(f'{b:02X}' for b in data if b != 0)}")
                print(f"ASCII            : {repr(data)}")
                print(f"Longueur         : {len(data)} octets")
                print("-" * 50)
                ser.flushInput()
                time.sleep(1)
        time.sleep(0.05)
except KeyboardInterrupt:
    print("\nFin.")
finally:
    ser.close()
