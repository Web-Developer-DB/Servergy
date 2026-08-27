# Release-Checkliste

- [ ] Paketversion `X.Y.Z-beta.N+BUILD` und Git-Tag `vX.Y.Z-beta.N` stimmen
      überein; der Build-Zähler ist größer als im vorherigen Beta-Artefakt.
- [ ] `flutter analyze` und `flutter test` sind erfolgreich.
- [ ] Android-, Linux- und Windows-Release-Build erfolgreich erstellt; der
      Launchername und das Servergy-Icon sind auf jeder Plattform sichtbar.
- [ ] Android-APK ist mit dem produktiven Keystore signiert.
- [ ] Windows-Bundle ist mit dem produktiven Zertifikat signiert.
- [ ] SHA-256-Prüfsummen aller Release-Dateien erzeugt und geprüft.
- [ ] Die vollständigen Realtest-Protokolle aus `docs/beta.md` für Android 12+
      und Android 17, Ubuntu 24.04 LTS mit Secret Service sowie Windows 11 sind
      abgeschlossen.
- [ ] WOL im LAN, VPN ohne Broadcast, falsches Passwort, falscher Schlüssel,
      geänderter Host-Key und tatsächliches Herunterfahren manuell geprüft.
- [ ] Server-Anleitung und Datenschutztext entsprechen dem Release.
- [ ] README, Architektur-, Entwicklungs- und Beta-Dokumentation aktualisiert.
- [ ] Keine Passwörter, Schlüssel, privaten IPs oder MAC-Adressen in Commit,
      Screenshot, Diagnoseexport oder Release-Artefakt enthalten.
