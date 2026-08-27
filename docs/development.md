# Entwicklungs- und Testanleitung

## Umgebung einrichten

1. Repository auf dem Branch `Dev` auschecken.
2. Flutter SDK passend zu `environment.sdk` in `pubspec.yaml` installieren.
3. Android Studio mit Android SDK 37 und einem JDK aus Android Studio installieren.
4. Unter Linux die Secret-Service-Bibliotheken installieren:

~~~bash
sudo apt install libsecret-1-dev libsecret-1-0
~~~

5. Abhängigkeiten laden und statische Prüfung starten:

~~~bash
flutter pub get
flutter analyze
flutter test
~~~

## App starten

~~~bash
flutter devices
flutter run
~~~

Für Android empfiehlt sich ein aktuelles Pixel-Gerät mit API 35/36 für die
normale UI-Prüfung und ein echtes Android-17/API-37-Gerät für die lokale
Netzwerkfreigabe. Ein Emulator kann TCP/SSH über `10.0.2.2` zu einem Dienst auf
dem Entwicklungsrechner erreichen; ein echter WOL-Broadcast in das Heimnetz ist
damit nicht automatisch gegeben.

Die App ist absichtlich auf Vordergrundaktionen beschränkt. Beim Testen muss
die App geöffnet bleiben, während WOL- und Shutdown-Polling laufen.

## Qualitätsgates vor jedem Commit

~~~bash
dart format lib test
flutter analyze
flutter test
flutter build linux --debug
~~~

Android-Checks benötigen das Android-Studio-JDK:

~~~bash
JAVA_HOME=/opt/android-studio/jbr \
  ./android/gradlew -p android :app:compileDebugKotlin --offline --no-daemon
flutter build apk --debug
~~~

Der vollständige Android-Build kann wegen Gradle-/SDK-Caches länger dauern.
Ein erfolgreicher Kotlin-Task beweist die native Berechtigungsbrücke, ersetzt
aber nicht die Installation des APK auf einem echten Gerät.

## Realgerät-Test

Für einen reproduzierbaren End-to-End-Test werden benötigt:

- ein eingeschalteter Server mit laufendem SSH-Dienst,
- ein separater `servergy`-Benutzer ohne sudo-Gruppenmitgliedschaft,
- der root-eigene `/usr/local/sbin/servergy-poweroff`-Helper,
- ein im BIOS/UEFI und Betriebssystem aktiviertes WOL,
- idealerweise eine kabelgebundene Netzwerkkarte,
- ein Telefon im selben LAN oder ein korrekt eingerichtetes VPN.

Testreihenfolge:

1. Servergy öffnen und lokale Netzwerkfreigabe erteilen.
2. Server suchen oder Host/IP manuell eingeben.
3. SSH-Schlüssel importieren oder Passwort-Modus auswählen.
4. Den angezeigten Host-Key direkt am Server vergleichen.
5. Prüfen, dass das Passwort nach einem App-Neustart nicht erneut abgefragt wird.
6. WOL konfigurieren; der Server muss hierfür noch eingeschaltet sein.
7. Falls der Helper noch fehlt: **Einstellungen → Server später starten →
   Server vorbereiten** wählen, die angekündigten Änderungen bestätigen und
   ein einmaliges sudo-Passwort eingeben. Es darf nicht nach einem App-Neustart
   erneut abgefragt oder gespeichert angezeigt werden.
8. SSH-Test ausführen.
9. Servergy-Shutdown bestätigen und beobachten, dass der SSH-Port verschwindet.
10. Danach „Server starten“ verwenden und maximal 90 Sekunden auf SSH warten.

## Fehleranalyse

- `network_scope_unavailable`: Suche überspringen und Host/IP manuell eintragen.
- `local_network_permission_denied`: Android-Systemfreigabe für lokales Netz
  aktivieren oder manuelle VPN-Konfiguration nutzen.
- `host_key_changed`: Verbindung abbrechen und Fingerprint direkt am Server
  prüfen; nicht blind bestätigen.
- `password_missing`: Passwort-Modus öffnen und ein neues Passwort eingeben.
- `wol_not_configured`: MAC-Adresse und Broadcast-Adresse in Einstellungen
  ergänzen.
- `wake_timeout`: Server-WOL, Broadcast-Adresse, Switch und BIOS prüfen.
- `poweroff_not_acknowledged`: Helper-Rechte, sudoers und exakte Bestätigung
  `servergy-poweroff-accepted` prüfen.
- `provision_sudo_denied`: Der SSH-Benutzer darf keine einmalige
  Administratorinstallation ausführen; die manuelle Serveranleitung an der
  Serverkonsole verwenden.
- `provision_sudo_auth_failed`: Das temporär eingegebene sudo-Passwort wurde
  abgelehnt und wurde nicht gespeichert.

## Code-Konventionen

- Fachlogik bleibt in `lib/core` und wird über Interfaces injizierbar gehalten.
- Widgets enthalten Darstellung und Nutzerinteraktion, aber keine direkten
  SSH-/Socket-Aufrufe.
- Kommentare erklären besonders Sicherheitsgründe und nicht offensichtliche
  Plattformgrenzen.
- Keine Geheimnisse in Tests, Logs, Fixtures oder Screenshots committen.
- User-facing Fehler bleiben deutsch und nennen eine konkrete nächste Aktion.
