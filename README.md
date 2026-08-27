# Servergy Alpha

Servergy ist eine lokale Flutter-App für genau einen Homeserver. Sie kann
einen laufenden Server über SSH prüfen, ihn kontrolliert herunterfahren und
ihn später über Wake-on-LAN wieder starten. Die App arbeitet ausschließlich im
Vordergrund; es gibt keinen Hintergrunddienst, keine Cloud und keine
Telemetrie.

> **Status: Alpha** — Der aktuelle Stand ist für Entwicklung und reale
> Funktionstests gedacht. Vor einer öffentlichen oder produktiven Verteilung
> müssen die in [docs/alpha.md](docs/alpha.md) genannten manuellen Tests,
> Signaturen und Release-Gates abgeschlossen werden.

## Was die Alpha kann

- geführte Einrichtung für einen Homeserver auf Android, Linux und Windows
- Suche nach möglichen SSH-Servern im aktuellen lokalen IPv4-Netz
- optionale mDNS-Suche nach `_ssh._tcp.local` und begrenzter SSH-Port-Scan
- manuelle Eingabe von Hostname, IP-Adresse, SSH-Port und Benutzername
- SSH-Schlüssel-Anmeldung mit OpenSSH-, RSA- und EC-Privatschlüsseln
- Passwort-Anmeldung mit sicherer Speicherung im Betriebssystem-Schlüsselspeicher
- Passphrase-Abfrage für verschlüsselte Schlüssel, ohne die Passphrase zu speichern
- SSH-Host-Key-Fingerprint mit manueller Erstbestätigung und Änderungsblockade
- Wake-on-LAN mit drei Magic Packets und anschließendem Erreichbarkeits-Polling
- kontrolliertes Ausschalten über einen festen, restriktiven sudoers-Helper
- abbrechbare Start-, Such- und Ausschaltvorgänge
- lokales, begrenztes und redigiertes Diagnoseprotokoll
- helle und dunkle Material-3-Oberfläche mit responsivem Onboarding

## Bewusste Grenzen

Servergy verwaltet in Version 1 genau einen Server. Der Server muss für die
Einrichtung eingeschaltet und per SSH erreichbar sein. Der Netzwerksucher
findet nur mögliche SSH-Ziele im aktuellen lokalen LAN; er kann keinen
ausgeschalteten Server und keine MAC-Adresse zuverlässig entdecken. Ein Ziel
über VPN wird manuell eingetragen, weil lokale IPv4-Suche und Broadcasts über
VPN nicht allgemein funktionieren.

Wake-on-LAN muss auf Mainboard, Serverbetriebssystem, Netzwerkkarte und
gegebenenfalls Router aktiviert sein. Die zuverlässigste Variante ist ein
kabelgebundener Serveradapter. Die vollständige Servereinrichtung steht in
[docs/server-setup.md](docs/server-setup.md).

## Schnellstart für Entwickler

Voraussetzungen:

- Flutter/Dart passend zur SDK-Angabe in `pubspec.yaml`
- Android Studio/JDK für Android-Builds
- Linux: `libsecret-1-dev` und `libsecret-1-0` für `flutter_secure_storage`
- ein Android-Gerät/Emulator, Linux-Desktop oder Windows-Entwicklungsrechner

Im Repository ausführen:

~~~bash
flutter pub get
flutter analyze
flutter test
flutter run
~~~

Plattform-Builds:

~~~bash
flutter build apk --debug
flutter build linux --debug
flutter build windows --debug
~~~

Eine ausführliche Entwicklungsroutine mit Emulator- und Realgerät-Tests steht
in [docs/development.md](docs/development.md).

## Bedienablauf

1. **Netzwerkgrenze:** Der Server ist eingeschaltet; Heimnetz und VPN-Hinweis
   werden erklärt.
2. **Server finden:** Die Suche prüft nur den erkannten lokalen Bereich. Ein
   Treffer wird erst nach einem SSH-Test und Host-Key-Vergleich vertrauenswürdig.
3. **SSH-Zugang:** Entweder importierter Schlüssel oder Passwort-Modus.
4. **Verbindung prüfen:** Der SSH-Test läuft vor dem Speichern neuer Zugangsdaten.
5. **Server später starten:** Wake-on-LAN kann jetzt konfiguriert oder später in
   den Einstellungen ergänzt werden.

Im Passwort-Modus wird ein nicht leeres SSH-Passwort nach erfolgreicher Prüfung
verschlüsselt gespeichert. In den Einstellungen wird es nie angezeigt; ein
leeres Feld bedeutet bei einem vorhandenen Profil „bestehendes Passwort
beibehalten“. Beim Wechsel auf Schlüssel-Anmeldung wird das Passwort gelöscht.

## Sicherheitsmodell

Nicht geheime Profildaten liegen in `shared_preferences`. Passwörter,
Privatschlüssel und Host-Key-Vertrauen liegen ausschließlich in
`flutter_secure_storage`. Passphrasen werden nur für die laufende Verbindung
verwendet. Der SSH-Fingerprint wird pro Host und Port gebunden; ein anderer
Fingerprint blockiert die Verbindung.

Der Shutdown ist kein frei formulierbarer Shell-Befehl. Die App ruft konstant
`sudo -n /usr/local/sbin/servergy-poweroff` auf. Der root-eigene Helper startet
eine feste systemd-Unit, bestätigt den angenommenen Auftrag und löst danach den
Poweroff aus. Die erlaubte sudoers-Regel und die Unit stehen in der
Serveranleitung.

Diagnoseexporte enthalten nur Zeitpunkt, Aktion, Ergebnis, Fehlercode und
Dauer. Es werden keine Passwörter, Schlüssel, Benutzernamen, vollständigen
Hostadressen oder MAC-Adressen exportiert. Siehe
[docs/privacy.md](docs/privacy.md).

## Servergy-Ausschalt-Helfer auf dem Homeserver

Nach einer erfolgreichen SSH-Einrichtung kann die App unter
**Einstellungen → Server später starten → Server vorbereiten** den sicheren
Ausschalt-Helfer einmalig auf einem Debian-System mit systemd einrichten. Die
Aktion ist immer bestätigt und verlangt ein **temporäres sudo-Passwort** des
konfigurierten SSH-Benutzers. Dieses Passwort wird nur über die laufende
SSH-Verbindung an `sudo` übergeben; es wird nicht in der App gespeichert,
protokolliert oder erneut angezeigt.

Der Assistent installiert ausschließlich diese drei Dateien:

| Datei | Eigentümer und Rechte | Zweck |
| --- | --- | --- |
| `/usr/local/sbin/servergy-poweroff` | `root:root`, `0755` | Argumentloser Helper. Er startet nur die unten genannte Unit und antwortet der App mit `servergy-poweroff-accepted`. |
| `/etc/systemd/system/servergy-poweroff.service` | `root:root`, `0644` | systemd-Oneshot-Unit. Sie wartet zwei Sekunden, damit die SSH-Antwort ankommt, und führt danach `systemctl poweroff --no-block` aus. |
| `/etc/sudoers.d/servergy` | `root:root`, `0440` | Erlaubt ausschließlich dem in Servergy eingetragenen SSH-Benutzer ohne Passwort den einen Helper-Aufruf. Sie erlaubt weder eine Shell noch `shutdown`, `systemctl` oder andere sudo-Befehle. |

Der Assistent prüft vor der Installation den SSH-Fingerprint, den festen
Payload per SHA-256, die sudoers-Syntax sowie die Rechte der installierten
Helper- und Unit-Datei. Er startet den Helper nicht während der Installation;
der Server bleibt eingeschaltet. Der erste über die App bestätigte Shutdown ist
der eigentliche Funktionsnachweis.

### Wo Entwickler die installierten Skripte im Projekt finden

Die Vorlagen liegen absichtlich als versionierte, unveränderliche Dart-Strings
im Quellcode und nicht als vom Nutzer auswählbare Dateien:

| Serverdatei | Quellstelle im Projekt |
| --- | --- |
| `/usr/local/sbin/servergy-poweroff` | `lib/core/services.dart` → `ServergyProvisioningPayload.helper` |
| `/etc/systemd/system/servergy-poweroff.service` | `lib/core/services.dart` → `ServergyProvisioningPayload.service` |
| `/etc/sudoers.d/servergy` | `lib/core/services.dart` → `ServergyProvisioningPayload.sudoersFor(...)` |

`SshService.provisionPoweroffHelper(...)` in derselben Datei steuert Upload,
temporäres Staging, sudo-Aufrufe, Rechteprüfung und Bereinigung. Die
Benutzerführung liegt in `lib/servergy_app.dart`; der koordinierende Ablauf mit
SSH- und Host-Key-Prüfung in `lib/core/controller.dart`.

**Wichtig bei Änderungen:** Helper und Unit haben in
`ServergyProvisioningPayload` feste SHA-256-Werte. Werden deren Inhalte
verändert, müssen die passenden Hash-Konstanten mitgeändert werden; andernfalls
bricht die App die Installation absichtlich vor dem Upload ab. Änderungen an
der sudoers-Vorlage müssen weiterhin auf genau den argumentlosen Helper
beschränkt bleiben. Danach mindestens `flutter analyze`, `flutter test` und
einen realen Debian-Test für Installation, Shutdown und Entfernung ausführen.

### Helper wieder entfernen

In der App steht dafür unter **Einstellungen → Server später starten →
Installierten Helper entfernen** eine bestätigte Aktion bereit. Sie prüft den
SSH-Fingerprint erneut, fordert ein einmaliges sudo-Passwort an und entfernt
genau die unten genannten Dateien. SSH, Wake-on-LAN und das lokale
Verbindungsprofil bleiben erhalten. Der SSH-Benutzer benötigt für die
Entfernung normale sudo-Administratorrechte; die absichtlich enge
Servergy-sudoers-Regel erlaubt nur das Herunterfahren und reicht dafür nicht.

Die folgenden Befehle müssen lokal am Server oder über einen **separat
berechtigten Administratorzugang** ausgeführt werden. Entferne zuerst die
sudoers-Regel: Danach kann die App den Server nicht mehr ausschalten, Wake-on-
LAN und die normale SSH-Verbindung bleiben aber unverändert.

~~~bash
sudo rm /etc/sudoers.d/servergy
sudo rm /usr/local/sbin/servergy-poweroff
sudo rm /etc/systemd/system/servergy-poweroff.service
sudo systemctl daemon-reload
sudo visudo -c
~~~

Diese Befehle entfernen nur die drei Servergy-Ausschaltdateien. Das Löschen der
Verbindung in der App entfernt dagegen ausschließlich lokale App-Daten wie
Profil, Schlüssel, SSH-Passwort und bestätigten Host-Key; es verändert nie den
Homeserver. Die ausführliche manuelle Einrichtung und Fehleranalyse steht in
[docs/server-setup.md](docs/server-setup.md).

## Repository-Struktur

~~~text
lib/
  core/models.dart       Domänenmodelle, Validierung und Profilmigration
  core/services.dart     Preferences, Secure Storage, WOL, Discovery und SSH
  core/controller.dart   Riverpod-Zustände und abbrechbare Abläufe
  servergy_app.dart      Dashboard, Onboarding, Einstellungen und Diagnose
  main.dart              Flutter-Einstiegspunkt
android/                 Android-Manifest und lokale Netzwerk-MethodChannel
docs/server-setup.md     Server- und sudoers-Einrichtung
docs/architecture.md     Datenfluss, Sicherheits- und Komponentenmodell
docs/development.md      Lokale Entwicklung, Tests und Debugging
docs/alpha.md            Alpha-Status, bekannte Grenzen und Abnahme
docs/privacy.md          Lokale Datenverarbeitung
test/                    Unit- und Fachlogiktests
~~~

## Beiträge und Branches

`Dev` ist der Integrationsbranch für die Alpha-Entwicklung. `main` bleibt der
stabile Zielbranch für spätere Releases. Änderungen sollen klein, kommentiert
und mit `flutter analyze` sowie `flutter test` geprüft sein. Neue Netzwerk- oder
SSH-Funktionen benötigen zusätzlich Fake-/Fehlerpfadtests und eine manuelle
Abnahme auf mindestens einem echten Gerät.

## Lizenz und Verteilung

Die Lizenz und die produktiven Distributionsbedingungen müssen vor dem ersten
öffentlichen Release ergänzt beziehungsweise bestätigt werden. Für Alpha-
Artefakte ist GitHub auf dem Entwicklungsbranch vorgesehen; signierte
Android-, Linux- und Windows-Releases gehören erst zur späteren Release-
Pipeline.
