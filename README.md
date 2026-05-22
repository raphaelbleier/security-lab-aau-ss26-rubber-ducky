# Security Lab AAU SS2026 – W02 Rubber Ducky

**Universität Klagenfurt – System Security Lab SS 2026**
**Autoren: Raphael Bleier, Joachim Lugger**
**LV-Leiter: Assoc.Prof. Peter Schartner**

---

## Inhalt

Dieses Repository enthält die Lösungen für **Aufgabenblatt W02a – Rubber Ducky** aus dem System Security Lab (SS2026) an der AAU Klagenfurt.

| Aufgabe | Beschreibung | Dateien |
|---|---|---|
| W02a.1 | Hello World | `W02a/payloads/W02a1_hello_world.txt` |
| W02a.2 | Information Gathering | `W02a/payloads/W02a2_info_gathering.txt`, `W02a/scripts/info_gather.ps1` |
| W02a.3 | HID-Angriffe (Theorie) | `W02a/README.md` |
| W02a.4 | Externes Script laden & ausführen | `W02a/payloads/W02a4_script_loader.txt` |
| W02a.5 | Reverse Shell | `W02a/payloads/W02a5_reverse_shell_trigger.txt`, `W02a/scripts/reverse_shell.ps1` |
| W02a.6 | Eigener Angriff (WLAN-Exfiltration) | `W02a/payloads/W02a6_custom_attack.txt`, `W02a/scripts/custom_attack.ps1` |
| W02a.7 | Absicherungsideen (Theorie) | `W02a/README.md` |

Vollständige Dokumentation, Theorieantworten und Setup-Anleitung: [`W02a/README.md`](W02a/README.md)

---

## Struktur

```
.
├── LAB_SS2026_W02_DE.pdf          # Originales Aufgabenblatt
└── W02a/
    ├── README.md                  # Vollständige Doku & Theorieantworten
    ├── payloads/                  # DuckyScript Payloads (für Rubber Ducky)
    │   ├── W02a1_hello_world.txt
    │   ├── W02a2_info_gathering.txt
    │   ├── W02a4_script_loader.txt
    │   ├── W02a5_reverse_shell_trigger.txt
    │   └── W02a6_custom_attack.txt
    ├── scripts/                   # PowerShell Payloads (vom Server gehostet)
    │   ├── info_gather.ps1
    │   ├── reverse_shell.ps1
    │   └── custom_attack.ps1
    └── server/
        └── server.py              # Python HTTP-Server (Angreifer-Seite)
```

---

## Schnellstart

### 1. Angreifer-Server starten
```bash
cd W02a/server/
cp ../scripts/reverse_shell.ps1 payload.ps1   # für W02a.5
python3 server.py 8080
```

### 2. IP-Adresse eintragen
In allen Payload-Dateien `ATTACKER_IP` durch die eigene IP ersetzen.

### 3. Rubber Ducky konfigurieren
1. Payload in [PayloadStudio](https://payloadstudio.hak5.org) öffnen
2. **Settings → Compiler Settings → Language → `de`** setzen
3. Kompilieren → `inject.bin` auf SD-Karte kopieren

### 4. Für Reverse Shell (W02a.5): Listener starten
```bash
nc -lvp 4444
```

---

## Rechtlicher Hinweis

Alle Payloads und Scripts sind ausschließlich für den Einsatz in der **gesicherten Laborumgebung** der AAU Klagenfurt im Rahmen der Lehrveranstaltung erstellt. Der Einsatz außerhalb autorisierter Umgebungen ist illegal und verstößt gegen geltendes Recht. Siehe auch den Hinweis im Aufgabenblatt.
