# Servergy

**Servergy** startet und stoppt einen Homeserver bei Bedarf: Start über
Wake-on-LAN, sicheres Herunterfahren über SSH. So läuft der Server nicht
unnötig und bleibt mit einem Knopfdruck verfügbar.

Der aktuelle Entwicklungsstand enthält einen nutzbaren ersten End-to-End-Stand
für Android, Linux und Windows:

- geführtes Homeserver-Onboarding mit Host, SSH-Benutzer, MAC- und Broadcast-Adresse
- Wake-on-LAN mit drei Magic Packets
- Erreichbarkeitsprüfung über den SSH-Port
- SSH-Verbindungstest und kontrolliertes Herunterfahren
- importierbare SSH-Privatschlüssel mit Passwort-Fallback
- sichere Passwort- und Schlüsselablage über den jeweiligen System-Schlüsselspeicher
- SSH-Host-Key-Prüfung mit expliziter Bestätigung beim ersten Kontakt
- abbrechbare Start- und Ausschaltvorgänge sowie redigiertes lokales Diagnoseprotokoll

## Voraussetzungen

Servergy verwaltet bewusst **genau einen** Homeserver. Der Server muss über das
lokale Netzwerk oder ein bereits eingerichtetes VPN erreichbar sein, wenn er
läuft. Für das Starten müssen
Wake-on-LAN im BIOS/UEFI und im Betriebssystem beziehungsweise im
Netzwerkadapter aktiviert sein.

Wake-on-LAN benötigt einen Broadcast-Pfad; viele VPNs leiten Broadcasts nicht
weiter. In diesem Fall funktioniert die SSH-Steuerung über VPN, das Einschalten
aber nur im Heimnetz oder über einen selbst betriebenen WOL-Relay.

Für das sichere Ausschalten verlangt die App nicht einen frei wählbaren
sudo-Befehl. Stattdessen führt sie ausschließlich
/usr/local/sbin/servergy-poweroff aus. Die einmalige Servereinrichtung steht
in [docs/server-setup.md](docs/server-setup.md).

## Lokale Entwicklung

1. Flutter SDK installieren und ein Gerät oder Emulator verbinden.
2. Abhängigkeiten laden: flutter pub get
3. Prüfen: flutter analyze und flutter test
4. Starten: flutter run

Auf Linux benötigt flutter_secure_storage zur Laufzeit die Bibliothek
libsecret. Unter Debian/Ubuntu: sudo apt install libsecret-1-dev
libsecret-1-0.

## Plattformen

| Plattform | Paket/Start | Hinweis |
| --- | --- | --- |
| Android | flutter build apk | Android 12 (API 31) oder neuer; Build mit Android API 37; zum Starten wird lokaler Netzwerkzugriff benötigt. |
| Ubuntu/Linux | flutter build linux | Benötigt libsecret-1 für gespeicherte Geheimnisse. |
| Windows | flutter build windows | Der Build erfolgt auf einem Windows-Rechner. |

## Sicherheitsprinzipien

- Passwörter liegen nie in shared_preferences, Logs oder der Profil-JSON.
- Das Passwort kann ausschließlich auf ausdrücklichen Wunsch gespeichert
  werden; sonst lebt es nur für die aktuelle Aktion im Speicher.
- Ein unbekannter SSH-Host-Key muss bestätigt werden. Ein geänderter Key wird
  blockiert.
- Die Key-Vertrauensentscheidung ist an Host und SSH-Port gebunden.
- Der Ausschaltbefehl ist auf einen festen Server-Helper beschränkt.
- Die App nutzt keinen Hintergrunddienst, keine Cloud und keine Telemetrie.
- Das exportierbare Diagnoseprotokoll enthält keine Zugangsdaten, Schlüssel,
  Benutzernamen, Hostadressen oder MAC-Adressen.

Details zur lokalen Datenverarbeitung stehen in [docs/privacy.md](docs/privacy.md).

## Status

Der Funktionsumfang ist für einen ersten Release vorbereitet. Vor einem echten
Release müssen die Checkliste in [docs/release-checklist.md](docs/release-checklist.md)
abgearbeitet, echte Plattformtests durchgeführt und die GitHub-Signing-Secrets
hinterlegt werden.
