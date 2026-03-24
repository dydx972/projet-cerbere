#!/usr/bin/env python3
"""
CERBERE - API REST pour ouverture de porte a distance
Tourne sur le Raspberry Pi RFID (192.168.1.49)
Ecoute sur le port 5000

Usage :
    sudo python3 door_api.py
"""

import subprocess
import threading
import json
from http import server
from urllib.parse import urlparse

SECRET = "cerbere2026"

def ouvrir_porte(duree=5):
    subprocess.call(["sudo", "python3", "/home/kyriann/gache.py", "--duree", str(duree)])

class DoorHandler(server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[DOOR API] {args[0]}")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_POST(self):
        path = urlparse(self.path).path

        if path == "/ouvrir":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length) if content_length > 0 else b"{}"

            try:
                data = json.loads(body)
            except Exception:
                data = {}

            token = data.get("secret", "")
            if token != SECRET:
                self.send_response(403)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps({"success": False, "error": "Non autorise"}).encode())
                return

            duree = min(int(data.get("duree", 5)), 30)

            t = threading.Thread(target=ouvrir_porte, args=(duree,))
            t.start()

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({
                "success": True,
                "message": f"Porte ouverte pour {duree} secondes"
            }).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if urlparse(self.path).path == "/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps({"success": True, "status": "online"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    httpd = server.HTTPServer(("0.0.0.0", 5000), DoorHandler)
    print("CERBERE Door API sur http://192.168.1.49:5000")
    httpd.serve_forever()
