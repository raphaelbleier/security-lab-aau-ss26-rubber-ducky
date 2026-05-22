# Security Lab AAU SS2026 – W02 Rubber Ducky

**Universitat Klagenfurt – System Security Lab SS 2026**
**Autoren: Raphael Bleier, Joachim Lugger**
**LV-Leiter: Assoc.Prof. Peter Schartner**

---

## Inhalt

Losungen fur **Aufgabenblatt W02a – Rubber Ducky** aus dem System Security Lab (SS2026) an der AAU Klagenfurt.

Exfiltration erfolgt vollstandig uber einen **Telegram Bot** – kein lokaler Server notwendig.
PowerShell-Payloads werden per **BITS** von GitHub geladen (Temp-Datei, wird nach Ausfuhrung geloscht).
Alle Payloads enthalten **AMSI-Bypass + Byte-Array-String-Obfuskierung** gegen Windows Defender.

| Aufgabe | Beschreibung | Dateien |
|---|---|---|
| W02a.1 | Hello World | `W02a/payloads/W02a1_hello_world.txt` |
| W02a.2 | Information Gathering | `W02a/payloads/W02a2_info_gathering.txt`, `W02a/scripts/info_gather.ps1` |
| W02a.3 | HID-Angriffe (Theorie) | `W02a/README.md` |
| W02a.4 | Externes Script laden & ausfuhren | `W02a/payloads/W02a4_script_loader.txt` |
| W02a.5 | Reverse Shell | `W02a/payloads/W02a5_reverse_shell_trigger.txt`, `W02a/scripts/reverse_shell.ps1` |
| W02a.6 | Eigener Angriff – WLAN-Exfiltration | `W02a/payloads/W02a6_custom_attack.txt`, `W02a/scripts/custom_attack.ps1` |
| W02a.6 | Browser Credential Stealer | `W02a/payloads/W02a6_credential_steal_trigger.txt`, `W02a/scripts/credential_stealer.ps1` |
| W02a.6+ | DevRecon – Developer Credential Harvester | `W02a/payloads/W02a6_devrecon_trigger.txt`, `W02a/scripts/developer_recon.ps1` |
| W02a.7 | Absicherungsideen (Theorie) | `W02a/README.md` |

Vollstandige Dokumentation, Theorieantworten und Setup-Anleitung: [`W02a/README.md`](W02a/README.md)

---

## Struktur

```
.
├── LAB_SS2026_W02_DE.pdf              # Originales Aufgabenblatt
└── W02a/
    ├── README.md                      # Vollstandige Doku & Theorieantworten
    ├── payloads/                      # DuckyScript Payloads (fur Rubber Ducky)
    │   ├── W02a1_hello_world.txt
    │   ├── W02a2_info_gathering.txt
    │   ├── W02a4_script_loader.txt
    │   ├── W02a5_reverse_shell_trigger.txt
    │   ├── W02a6_custom_attack.txt
    │   ├── W02a6_credential_steal_trigger.txt
    │   └── W02a6_devrecon_trigger.txt
    └── scripts/                       # PowerShell Payloads (BITS von GitHub geladen)
        ├── info_gather.ps1            # System-Info Exfiltration
        ├── reverse_shell.ps1          # TCP Reverse Shell
        ├── custom_attack.ps1          # WLAN-Passwort-Exfiltration
        ├── credential_stealer.ps1     # Windows CredMan + Chromium-Credentials
        └── developer_recon.ps1        # SSH Keys, Git-Tokens, Persistenz
```

---

## Schnellstart

### 1. Rubber Ducky konfigurieren

1. Payload in [PayloadStudio](https://payloadstudio.hak5.org) offnen
2. **Settings → Compiler Settings → Language → `de`** setzen (Y/Z-Layout!)
3. Kompilieren → `inject.bin` auf SD-Karte kopieren
4. Rubber Ducky einstecken – fertig

Kein Server, kein Setup. Alle Ergebnisse kommen per Telegram.

### 2. Nur fur W02a.5 (Reverse Shell): Listener & IP eintragen

Da eine TCP Reverse Shell keine externe API nutzen kann, muss die Angreifer-IP manuell eingetragen werden:

```powershell
# In W02a/scripts/reverse_shell.ps1:
$ATTACKER_IP = "192.168.x.x"   # eigene IP eintragen
$PORT        = 4444
```

Dann committen & pushen, damit die aktuelle Version auf GitHub liegt.

Listener starten:
```bash
nc -lvp 4444
```

---

## Rechtlicher Hinweis

Alle Payloads und Scripts sind ausschliesslich fur den Einsatz in der **gesicherten Laborumgebung** der AAU Klagenfurt im Rahmen der Lehrveranstaltung erstellt. Der Einsatz ausserhalb autorisierter Umgebungen ist illegal und verstosst gegen geltendes Recht.
