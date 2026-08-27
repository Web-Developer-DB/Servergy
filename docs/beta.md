# Beta-Status und Freigabe

## Kennzeichnung

Die aktuelle Zielversion ist **Servergy 0.1.0-beta.1+3**. Sie wird als
signierter GitHub-Pre-Release über den Tag **`v0.1.0-beta.1`** verteilt. Die
Beta ist für einen verwalteten Homeserver gedacht und keine Zusage für jede
Router-, VPN- oder Wake-on-LAN-Kombination.

## Automatische Gates

Vor jedem Beta-Tag müssen erfolgreich sein:

- `dart format --output=none --set-exit-if-changed lib test tool`
- `flutter analyze`
- `flutter test`
- Android-, Linux- und Windows-Debug-Build in Pull-Request-CI
- signierte Android- und Windows-Release-Builds, Linux-Release-Bundle sowie
  SHA-256-Prüfsummen in der Tag-Pipeline
- Versions-, Tag- und Icon-Konsistenzprüfung in der Release-Pipeline

## Verbindliche Realtest-Matrix

| Plattform | Referenzsystem | Erforderliche Prüfung | Ergebnis / Datum / Tester |
| --- | --- | --- | --- |
| Android | Android 12 oder neuer | Einrichtung mit SSH-Schlüssel und Passwort, Discovery, Host-Key-Wechsel, Diagnoseexport | offen |
| Android | Android 17 / API 37 | LAN-Freigabe akzeptiert und abgelehnt, mDNS/Scan, WOL, Shutdown | offen |
| Linux | Ubuntu 24.04 LTS, GNOME, Secret Service | Nutzer-Installer, Startmenü-Icon, Speicherung, SSH, WOL, Shutdown, Diagnoseexport, Uninstall | offen |
| Windows | Windows 11 | Signatur, Produktname/Icon, Speicherung, SSH, WOL, Shutdown, Diagnoseexport, Uninstall | offen |
| VPN | eine getestete VPN-Verbindung | SSH über VPN ohne WOL-Broadcast; verständliche Einschränkung im UI | offen |

Bei jedem erfolgreichen WOL- und Shutdown-Test werden Servermodell,
Netzwerkkonstellation und Datum privat im Release-Review festgehalten, aber
nicht mit Zugangsdaten, IP-Adressen oder MAC-Adressen in Git veröffentlicht.

## Beta-Feedback

Tester verwenden die GitHub-Issue-Vorlagen für Fehlerberichte und Feedback.
Diagnoseexporte sind optional und bereits redigiert. Passwörter, private
Schlüssel, vollständige IP-Adressen, MAC-Adressen oder Screenshots mit diesen
Daten dürfen nicht hochgeladen werden.

## Freigabeentscheidung

Ein Beta-Release wird nur veröffentlicht, wenn alle automatischen Gates grün,
die Matrix ohne blockierende Fehler dokumentiert und die Android-/Windows-
Signatursecrets in GitHub verfügbar sind. Linux wird als Nutzer-Bundle unter
`~/.local/share/servergy` installiert und benötigt kein Administratorrecht.
