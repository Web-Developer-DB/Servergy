# Release-Checkliste

- [ ] Versionsnummer und Git-Tag `vX.Y.Z` geprüft; Alpha-Versionen tragen ein
      SemVer-Prerelease wie `0.1.0-alpha.1`.
- [ ] `flutter analyze` und `flutter test` sind erfolgreich.
- [ ] Android-, Linux- und Windows-Release-Build erfolgreich erstellt.
- [ ] Android-APK ist mit dem produktiven Keystore signiert.
- [ ] Windows-Bundle ist mit dem produktiven Zertifikat signiert.
- [ ] SHA-256-Prüfsummen aller Release-Dateien erzeugt und geprüft.
- [ ] Test auf Android 12+, Ubuntu/Linux mit Secret Service und Windows erfolgt.
- [ ] WOL im LAN, VPN ohne Broadcast, falsches Passwort, falscher Schlüssel,
      geänderter Host-Key und tatsächliches Herunterfahren manuell geprüft.
- [ ] Server-Anleitung und Datenschutztext entsprechen dem Release.
- [ ] README, Architektur-, Entwicklungs- und Alpha-Dokumentation aktualisiert.
- [ ] Keine Passwörter, Schlüssel, privaten IPs oder MAC-Adressen in Commit,
      Screenshot, Diagnoseexport oder Release-Artefakt enthalten.
