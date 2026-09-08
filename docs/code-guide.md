# Codekarte für Entwicklung und KI-Unterstützung

Diese Seite ergänzt die Kommentare im Quellcode. Sie beantwortet zuerst die
Frage „wo gehört eine Änderung hin?“ und hält die Regeln fest, die bei einer
Änderung nicht versehentlich verletzt werden dürfen.

## Einstiegspunkt und Abhängigkeiten

`lib/main.dart` initialisiert Flutter und erstellt den Riverpod-`ProviderScope`.
`lib/servergy_app.dart` ist ausschließlich die Präsentationsschicht: Sie zeigt
Zustand, fragt nach sichtbarer Nutzerbestätigung und ruft Methoden der
Controller auf. Widgets dürfen keine Sockets, SSH-Clients, Secure Storage oder
freien Remote-Befehle verwenden.

```text
Widget / Dialog
  -> ServerController oder DiscoveryController
    -> Gateway-Interface (für Tests ersetzbar)
      -> Service (Socket, SSH, Platform Channel, Storage)
        -> Gerät / lokales Netzwerk / Homeserver
```

Die wichtigsten Riverpod-Provider sind:

| Provider | Aufgabe | Typischer Verbraucher |
| --- | --- | --- |
| `controllerProvider` | Profil, Status, Aktionen und Diagnose | Dashboard, Setup, Einstellungen |
| `discoveryProvider` | Kurzlebige Serversuche | Setup-Schritt „Server“ |
| `appearanceProvider` | Darstellungswahl | `ServergyApp`, Einstellungen |
| `languageProvider` | Sprachwahl | `ServergyApp`, Einstellungen |
| `appMetadataProvider` | Paketversion/Build/Kanal | Über-Servergy-Bereich |

## Ordner und Verantwortlichkeiten

| Pfad | Verantwortung | Nicht hier ablegen |
| --- | --- | --- |
| `lib/core/models.dart` | Reine Domänentypen, Parser und Validierung | Flutter, I/O, Persistenz |
| `lib/core/services.dart` | Infrastruktur und Gateway-Interfaces | Widget- oder Dialoglogik |
| `lib/core/controller.dart` | Asynchrone Abläufe, Status, Abbruch, sichere Fehler | Konkretes Widget-Layout |
| `lib/core/appearance.dart`, `language.dart` | Unabhängige UI-Präferenzen | Serverdaten oder Geheimnisse |
| `lib/servergy_app.dart` | Navigation, Formulardrafts, Dialoge, Darstellung | SSH-/Socket-Aufrufe |
| `lib/l10n/*.arb` | Übersetzungsquellen | Geschäftslogik |
| `test/` | Sicherheits-, Controller- und Widget-Regressionen | Echte Netzwerkzugriffe |
| `tool/` | Reproduzierbare Asset-/Dokumentationsgeneratoren | Produktlaufzeit-Code |

Die Dateien unter `android/`, `linux/flutter/` und `windows/flutter/` enthalten
teilweise Flutter-generierten Runner-Code. Änderungen dort sind nur sinnvoll,
wenn sie eine Plattformintegration betreffen. Insbesondere sollten generierte
Plugin-Registrierungen nicht manuell dokumentiert oder angepasst werden.

## Die zentralen Datenobjekte

`ServerProfile` ist das öffentliche Konfigurationsobjekt für genau einen
Server. Es enthält Name, Host, SSH-Port, Benutzer, Anmeldemodus und optional
Wake-on-LAN-Daten. Seine JSON-Repräsentation ist V3.

Die folgenden Werte dürfen niemals in `ServerProfile.toJson`,
`DiagnosticEvent` oder UI-Logs erscheinen:

- SSH-Passwort
- privater Schlüssel
- Schlüssel-Passphrase
- sudo-Passwort
- rohe SSH-/sudo-Fehlerausgabe
- Host-Key-Fingerprint außerhalb des expliziten Vertrauensdialogs

`SettingsStore` speichert deshalb das öffentliche Profil und die begrenzten
Diagnosen in `SharedPreferencesAsync`; Passwort, privater Schlüssel und
Host-Key-Vertrauen liegen separat im `FlutterSecureStorage`.

`SecretUpdate` ist wichtig für Edit-Formulare: `keep` bedeutet „vorhandenes
Geheimnis nicht lesen und nicht verändern“, `replace` speichert ein neues und
`delete` entfernt es. Ein leeres Passwortfeld ist nicht automatisch ein
Löschbefehl.

## Vertrauens- und Sicherheitsgrenzen

```text
Discovery result  -- candidate only -->  setup form
setup form        -- SSH test ------->  host-key dialog
user accepts key  -- scoped trust --->  secure storage (host:port)
successful SSH    -- then only ------>  profile + selected secret saved
```

Ein mDNS- oder TCP-Scan beweist niemals, welches Gerät gefunden wurde. Der
Vertrauensübergang geschieht ausschließlich in `SshService._connect`: Beim
ersten Kontakt sieht der Nutzer Algorithmus und OpenSSH-SHA-256-Fingerprint.
Später müssen Algorithmus, Fingerprint und Scope `host:port` exakt stimmen.
Eine Änderung blockiert die Verbindung, statt stillschweigend neues Vertrauen
zu speichern.

## Zeitliche Abläufe

`ServerController` besitzt einen monotonen `_operation`-Zähler. Jede
langlaufende Aktion erzeugt ein Token; nach jedem `await` darf nur noch ein
gleiches, gemountetes Token den Zustand ändern. Abbrechen erhöht den Zähler und
beendet die sichtbare Aktion. Das kann einen schon gestarteten Socket nicht
sofort beenden, verhindert aber zuverlässig späte Statusüberschreibungen.

| Aktion | Ablauf | Obergrenze |
| --- | --- | --- |
| Aktualisieren | TCP-Verbindung zum SSH-Port | 2 Sekunden je Probe |
| Starten | Offline prüfen → 3 WOL-Pakete → TCP-Polling | 90 Sekunden |
| SSH-Test | Credential lesen/abfragen → Host-Key prüfen → `printf servergy-ok` | SSH-Timeouts: 8/10 Sekunden |
| Herunterfahren | Offline prüfen → fester Helper → TCP-Polling | 60 Sekunden |
| Discovery | Scope bestimmen → mDNS + TCP-Batches | /24 maximal, 24 parallele TCP-Probes |

Alle Netzwerkaktionen werden erst durch sichtbare Nutzerinteraktion gestartet.
Es gibt keinen Hintergrunddienst und keine stillen Wiederholungen.

## SSH und Provisioning

`SshGateway` stellt nur drei normale Operationen bereit: Test, Poweroff und
WOL-Erkennung. Es besitzt ausdrücklich keine API für beliebige Befehle.

Die einmalige Installation ist über `ServerProvisioningGateway` getrennt. Sie
kennt exakt drei konstante Payloads:

1. `/usr/local/sbin/servergy-poweroff`
2. `/etc/systemd/system/servergy-poweroff.service`
3. `/etc/sudoers.d/servergy`

Vor dem Upload werden Helper und Unit per SHA-256 geprüft. Die Dateien werden
zuerst in ein zufälliges privates SFTP-Staging-Verzeichnis geschrieben.
`visudo` validiert die sudoers-Datei vor und nach der Installation; Besitz,
Rechte und Hashes der Helper-Dateien werden geprüft, bevor die sudoers-Regel
freigeschaltet wird. Das einmal erfragte sudo-Passwort geht nur per stdin an
`sudo -S` und wird weder persistiert noch in eine Shell-Zeile interpoliert.

Die WOL-Erkennung verwendet ebenfalls nur einen versionierten, festen
Linux-Befehl. Die Antwort wird als enges Tab-Protokoll validiert, bevor eine
MAC-Adresse als Vorschlag im Setup erscheint.

## Wie neue Funktionen sicher ergänzt werden

1. Ergänze zuerst einen Domänentyp oder einen stabilen Fehlercode in `models`.
2. Formuliere ein schmales Gateway-Interface in `services`; vermeide freie
   Strings als Remote-Befehle oder Pfade.
3. Implementiere die Operation im Service und behandle rohe Fehler dort.
4. Orchestriere sie im Controller mit Busy-Sperre, Token-Checks, Abbruch,
   Timeout und einem redigierten `DiagnosticEvent`.
5. Füge eine ausdrückliche UI-Aktion mit passender Bestätigung/Erklärung hinzu.
6. Ergänze Fake-basierte Controller-Tests und bei sichtbarem Verhalten einen
   Widget-Test.
7. Führe `flutter analyze` und `flutter test` aus.

Neue Diagnosefelder müssen auf Geheimnisse und lokale Netzwerkinformationen
geprüft werden. Neue gespeicherte Werte brauchen einen versionierten Schlüssel
und einen klaren Migrationspfad.

## Prüfen und generieren

```bash
flutter analyze
flutter test
dart run tool/generate_readme_showcase.dart
dart run tool/generate_launcher_icons.dart
```

Die beiden Tool-Befehle verändern gezielt abgeleitete Bilddateien. Sie sind
nicht Teil des normalen Testlaufs und sollten nur ausgeführt werden, wenn ihre
jeweiligen Quellbilder geändert wurden.
