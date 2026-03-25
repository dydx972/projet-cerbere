#!/usr/bin/env python3
"""
CERBERE - Contrôle gâche électrique + ventouse magnétique
Raspberry Pi Relay Board (PCA9554 @ 0x20, registre 0x06)
Channel 1 = gâche (NO1/COM1)
Channel 2 = ventouse (NO2/COM2)

Usage :
    sudo python3 gache.py              # Ouvre 5 secondes puis referme
    sudo python3 gache.py --duree 10   # Ouvre 10 secondes
    sudo python3 gache.py --ouvrir     # Ouvre et reste ouvert
    sudo python3 gache.py --fermer     # Ferme la gâche + ventouse
"""

import smbus
import argparse
import time

I2C_BUS     = 1
DEVICE_ADDR = 0x20
DEVICE_REG  = 0x06
RELAY_MASK  = 0x03  # bit 0 (gâche) + bit 1 (ventouse)

bus = smbus.SMBus(I2C_BUS)
reg_data = 0xFF
bus.write_byte_data(DEVICE_ADDR, DEVICE_REG, reg_data)

def ouvrir():
    global reg_data
    reg_data &= ~RELAY_MASK
    bus.write_byte_data(DEVICE_ADDR, DEVICE_REG, reg_data)
    print("Gâche + ventouse libérées.")

def fermer():
    global reg_data
    reg_data |= RELAY_MASK
    bus.write_byte_data(DEVICE_ADDR, DEVICE_REG, reg_data)
    print("Gâche + ventouse verrouillées.")

def main():
    parser = argparse.ArgumentParser(description="Contrôle gâche + ventouse")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--ouvrir", action="store_true", help="Ouvrir (reste ouvert)")
    group.add_argument("--fermer", action="store_true", help="Fermer")
    group.add_argument("--duree", type=int, default=5, help="Durée d'ouverture en secondes (défaut: 5)")
    args = parser.parse_args()

    try:
        if args.ouvrir:
            ouvrir()
            print("Ctrl+C pour fermer et quitter.")
            while True:
                time.sleep(1)
        elif args.fermer:
            fermer()
        else:
            ouvrir()
            print(f"Fermeture dans {args.duree} secondes...")
            time.sleep(args.duree)
            fermer()
    except KeyboardInterrupt:
        print()
        fermer()
    finally:
        bus.close()

if __name__ == "__main__":
    main()
