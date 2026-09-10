# Release-Readiness für Servergy 0.1.0

Dieses Dokument beschreibt die verbindlichen Prüfungen für den ersten stabilen
Servergy-Release. Die automatische Pipeline erzeugt veröffentlichbare
Artefakte erst mit produktiven Android- und Windows-Signaturen.

## Automatische Gates

Vor dem Tag `v0.1.0` müssen erfolgreich sein:

- `dart format --output=none --set-exit-if-changed lib test tool`
- `flutter analyze`
- `flutter test`
- der reproduzierbare Icon-Generator ohne Git-Diff
- Android-Release-Build und Linux-x86_64-AppImage
- signierte Android-APK, Linux-AppImage und SHA-256-Summen

Der Release-Workflow akzeptiert sowohl stabile SemVer-Tags als auch spätere
Prereleases und setzt den GitHub-Pre-Release-Status automatisch aus der
Paketversion.

## Verbindliche Realtest-Matrix

| Plattform | Referenzsystem | Erforderliche Prüfung | Ergebnis / Datum / Tester |
| --- | --- | --- | --- |
| Android | Android 12 oder neuer | Einrichtung mit SSH-Schlüssel und Passwort, Discovery, Host-Key-Wechsel, Diagnoseexport, Darstellung System/Hell/Dunkel | offen |
| Android | Android 17 / API 37 | LAN-Freigabe akzeptiert und abgelehnt, mDNS/Scan, WOL, Shutdown, Darstellung | offen |
| Linux | Ubuntu 24.04 LTS, GNOME, Secret Service | AppImage-Start, Darstellung, Speicherung, SSH, WOL, Shutdown und Diagnoseexport | offen |
| VPN | eine getestete VPN-Verbindung | SSH über VPN ohne WOL-Broadcast; verständliche Einschränkung im UI | offen |

Bei jedem erfolgreichen WOL- und Shutdown-Test werden Servermodell,
Netzwerkkonstellation und Datum privat im Release-Review festgehalten, aber
nicht mit Zugangsdaten, IP-Adressen oder MAC-Adressen in Git veröffentlicht.

## Datenschutz und Rückmeldungen

Die Darstellungsauswahl wird ausschließlich lokal gespeichert. Sie enthält
keine Profil-, Netzwerk-, Zugangsdaten- oder Diagnosewerte. Diagnoseexporte
bleiben optional und redigiert; Passwörter, private Schlüssel, vollständige
IP-Adressen, MAC-Adressen oder ungeschwärzte Screenshots dürfen nicht
hochgeladen werden.

## Freigabeentscheidung

`v0.1.0` wird erst veröffentlicht, wenn alle automatischen Gates grün sind, die
Realtest-Matrix keine blockierenden Fehler enthält und die produktiven
Android-Signatursecrets in GitHub verfügbar sind. Lokale Debug-APKs sind
ausschließlich für Entwicklung und Geräteprüfungen geeignet; der
Android-Release-Build verweigert ohne Produktionskeystore bewusst die
Erstellung.
