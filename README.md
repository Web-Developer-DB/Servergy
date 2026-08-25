# Servergy

**Servergy** startet und stoppt einen Homeserver bei Bedarf: Start über
Wake-on-LAN, sicheres Herunterfahren über SSH. So läuft der Server nicht
unnötig und bleibt mit einem Knopfdruck verfügbar.

Der aktuelle Entwicklungsstand enthält einen nutzbaren ersten End-to-End-Stand
für Android, Linux und Windows:

- Homeserver-Profil mit Host, SSH-Benutzer, MAC- und Broadcast-Adresse
- Wake-on-LAN mit drei Magic Packets
- Erreichbarkeitsprüfung über den SSH-Port
- SSH-Verbindungstest und kontrolliertes Herunterfahren
- sichere Passwortablage über den jeweiligen System-Schlüsselspeicher
- SSH-Host-Key-Prüfung mit expliziter Bestätigung beim ersten Kontakt

## Voraussetzungen

Servergy verwaltet bewusst **genau einen** Homeserver. Der Server muss über das
lokale Netzwerk erreichbar sein, wenn er läuft. Für das Starten müssen
Wake-on-LAN im BIOS/UEFI und im Betriebssystem beziehungsweise im
Netzwerkadapter aktiviert sein.

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
| Android | flutter build apk | Zum Starten wird lokaler Netzwerkzugriff benötigt. |
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

## Status

Dies ist ein erster funktionaler Entwicklungsstand. Vor einer Veröffentlichung
folgen noch App-Icons, Android-spezifische Berechtigungsprüfung auf aktuellen
Versionen, weitere Tests sowie ein Test auf echten Android-, Ubuntu- und
Windows-Geräten.
