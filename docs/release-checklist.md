# Release-Checkliste

- [ ] Paketversion `X.Y.Z+BUILD` und Git-Tag `vX.Y.Z` stimmen überein; für
      Servergy 0.1.0 ist die Paketversion `0.1.0+8` und der Tag `v0.1.0`.
- [ ] `flutter analyze` und `flutter test` sind erfolgreich.
- [ ] Android-Release-Build und Linux-x86_64-AppImage erfolgreich erstellt;
      App-Name und Servergy-Icon sind auf beiden Plattformen sichtbar.
- [ ] Android-APK ist mit dem produktiven Keystore signiert.
- [ ] Linux-AppImage startet auf einem unterstützten Linux-Desktop.
- [ ] SHA-256-Prüfsummen aller Release-Dateien erzeugt und geprüft.
- [ ] Die vollständigen Realtest-Protokolle aus
      `docs/release-readiness.md` für Android 12+
      und Android 17, Ubuntu 24.04 LTS mit Secret Service sowie Windows 11 sind
      abgeschlossen.
- [ ] WOL im LAN, VPN ohne Broadcast, falsches Passwort, falscher Schlüssel,
      geänderter Host-Key und tatsächliches Herunterfahren manuell geprüft.
- [ ] Server-Anleitung und Datenschutztext entsprechen dem Release.
- [ ] README, Architektur-, Entwicklungs- und Release-Dokumentation aktualisiert.
- [ ] Keine Passwörter, Schlüssel, privaten IPs oder MAC-Adressen in Commit,
      Screenshot, Diagnoseexport oder Release-Artefakt enthalten.
