# Archiv: Alpha-Status

## Kennzeichnung

Dieser Stand dokumentiert die abgeschlossene Alpha-Phase. Der aktuelle
Release-Prozess und die verbindliche Abnahme stehen in [beta.md](beta.md).

## Am Alpha-Abschluss bereits umgesetzt

- V3-Profilformat mit Migration aus V1/V2
- Secure Storage für Passwort, privaten Schlüssel und Host-Key-Vertrauen
- geführtes Onboarding mit optionalem WOL-Schritt
- lokale SSH-Kandidatensuche über mDNS und begrenzten TCP-Scan
- Android-17-LAN-Freigabe und kurzlebiger Multicast-Lock
- SSH-Test, Fingerprint-Bestätigung und Host-Key-Wechselblockade
- feste Shutdown-Kommandokette mit Bestätigungsantwort
- 90-Sekunden-WOL-Polling und 60-Sekunden-Shutdown-Polling
- lokales Diagnoseprotokoll ohne sensible Endpunktdaten
- fokussierter Einrichtungsassistent mit Fortschrittsanzeige für kleine Displays

## Aus Alpha übernommene Grenzen

- Nur ein Homeserver wird verwaltet.
- Ein ausgeschalteter Server kann nicht durch den Netzwerksucher entdeckt werden.
- Der Sucher findet nur SSH-Kandidaten; MAC-Adressen werden nicht automatisch
  ermittelt.
- Der automatische Suchbereich ist auf einen lokalen `/24`-Ausschnitt begrenzt.
- VPN-Ziele werden manuell konfiguriert; VPN-Broadcast-Unterstützung wird nicht
  von Servergy eingerichtet.
- Der dokumentierte Shutdown-Helper setzt systemd auf dem Server voraus.
- Android-Emulatoren ersetzen keinen echten WOL-LAN-Test im Heimnetz.
- Release-Signierung, finale Icons und öffentliche Distribution wurden in die
  Beta-Freigabe überführt.

## Historische Alpha-Abnahme-Matrix

| Bereich | Alpha-Kriterium | Ergebnis |
| --- | --- | --- |
| Analyse | `flutter analyze` ohne Befund | offen pro Release-Lauf |
| Tests | `flutter test` erfolgreich | offen pro Release-Lauf |
| Linux | Debug-Bundle erzeugt | zuletzt erfolgreich |
| Android | Kotlin-/Manifest-Integration kompiliert | zuletzt erfolgreich |
| Android real | API 31+ Einrichtung und gespeichertes Passwort | manuell offen |
| Discovery | mDNS, Portscan, Abbruch und keine Treffer | manuell/Fake-Tests erweitern |
| SSH | Schlüssel, Passwort, falscher Zugang, Host-Key-Wechsel | manuell offen |
| WOL | LAN-Start mit ausgeschaltetem Server | manuell offen |
| Shutdown | Helper-Bestätigung und echtes Ausschalten | manuell offen |
| VPN | SSH ohne WOL-Broadcast | manuell offen |

## Aus Alpha übernommene Abnahmeziele

Diese Ziele werden in der verbindlichen Beta-Abnahme weitergeführt:

1. Analyse und Unit-/Widgettests grün sind.
2. Android auf einem echten API-31+-Gerät installiert und getestet wurde.
3. Linux mit Secret Service und Windows auf Zielsystemen getestet wurden.
4. Passwort, privater Schlüssel, Host-Key-Wechsel und Abbruchdialoge geprüft sind.
5. Ein echter WOL-Start und ein echter SSH-Shutdown dokumentiert sind.
6. Serveranleitung, README, Datenschutz und Versionsnummer zusammenpassen.
7. Signierte Artefakte und SHA-256-Prüfsummen erst in einem späteren Release-
   Workflow erzeugt und unabhängig geprüft werden.
