# Servergy-Architektur

Dieses Dokument beschreibt die technische Struktur der Beta. Ziel ist, dass
auch neue Entwickler nachvollziehen können, welche Schicht für welche Aufgabe
verantwortlich ist und wo Sicherheitsentscheidungen umgesetzt werden.

## Leitlinien

Servergy hat drei feste Leitlinien:

1. Die App steuert genau einen Homeserver.
2. Jede Netzwerkaktion ist eine Vordergrundaktion mit sichtbarem Zustand und
   Abbruchmöglichkeit.
3. Geheimnisse werden nie als Teil des öffentlichen Profils behandelt.

Die Benutzeroberfläche kennt keine SSH-Shell und nimmt keine freien Befehle vom
Benutzer entgegen. Die beiden Remote-Kommandos sind im SSH-Dienst konstant:
`printf servergy-ok` für den Test und der feste sudo-Helper für den Poweroff.

## Einmalige Servervorbereitung

Die optionale Servervorbereitung ist vom normalen `SshGateway` getrennt. Sie
akzeptiert keine Dateien, Pfade oder Befehle aus der Oberfläche, sondern
verwendet drei versionierte App-Payloads: den Helper, die systemd-Unit und eine
validierte, eng begrenzte sudoers-Datei. Die beiden statischen Dateien werden
vor dem Upload per SHA-256 geprüft. Der SSH-Benutzername muss einem strikten
Linux-Namen entsprechen, bevor er in sudoers geschrieben werden darf.

Das einmal eingegebene sudo-Passwort gelangt ausschließlich über stdin einer
kurzlebigen SSH-Session zu `sudo -S`; es ist weder Teil eines Remote-Befehls
noch Teil von Profil, Secure Storage oder Diagnose. Die Einrichtung startet
den Helper nie selbst und fährt den Server daher nicht versehentlich herunter.

## Schichten und Datenfluss

~~~text
Flutter Widgets
    │  Events, Dialoge, sichtbare Statuswerte
    ▼
Riverpod Controller
    │  Busy-Sperre, Polling, Abbruch-Token, Fehlertexte
    ▼
Fachliche Gateways
    ├── NetworkGateway       TCP-Erreichbarkeit und Wake-on-LAN
    ├── DiscoveryGateway     Netzbereich, mDNS und SSH-Port-Suche
    ├── SshGateway           SSH-Handshake, Authentifizierung, Befehle
    ├── ServerProvisioningGateway  Einmalige, bestätigte Helper-Installation
    └── ProfileStore         Profil, Secure Storage, Diagnose
    ▼
Betriebssystem / Netzwerk / Homeserver
~~~

`lib/core/models.dart` enthält keine Flutter-Abhängigkeiten. Dadurch können
Validierung, Profilmigration und Diagnoseformat unabhängig von Widgets getestet
werden. `lib/core/services.dart` enthält I/O und wird in Controller-Tests durch
Fakes ersetzt. `lib/core/controller.dart` koordiniert die zeitlichen Abläufe.

## Profilformat V3

Das öffentliche Profil enthält keine Zugangsdaten:

~~~json
{
  "version": 3,
  "name": "Homeserver",
  "host": "server.lan",
  "sshPort": 22,
  "username": "servergy",
  "authenticationMode": "keyPreferred",
  "wakeOnLan": {
    "mac": "AA:BB:CC:DD:EE:FF",
    "broadcast": "192.168.178.255",
    "port": 9
  }
}
~~~

`wakeOnLan` ist optional. V1-Profile werden weiterhin eingelesen; die alten
WOL-Felder werden in das verschachtelte V3-Modell übernommen. Unlesbare Daten
führen zu einem leeren Einrichtungszustand und nicht zu einem App-Absturz.

Im Secure Storage liegen getrennt:

- `servergy.password.v1`: gespeichertes SSH-Passwort
- `servergy.private-key.v1`: importierter privater Schlüssel
- `servergy.host-key.v3`: Host-/Port-Scope, Algorithmus und SHA-256-Fingerprint

Der Schreibvorgang für Passwörter verwendet `SecretUpdate.keep`, `replace` oder
`delete`. So muss ein vorhandenes Passwort niemals aus der UI gelesen oder
angezeigt werden.

## SSH-Vertrauen

`dartssh2` liefert den SHA-256-Fingerprint bereits im OpenSSH-Format
`SHA256:<base64-ohne-padding>`. Servergy zeigt diesen Text zusammen mit dem
Algorithmus an. Beim ersten Kontakt entscheidet der Nutzer; bei einem bereits
gespeicherten Scope müssen Algorithmus und Fingerprint exakt übereinstimmen.

Eine Änderung von Hostname/IP oder SSH-Port erzeugt einen anderen Scope. Ein
alter Host-Key wird deshalb nicht für das neue Ziel wiederverwendet.

## Geführte Serversuche

Die Suche startet nur nach einem sichtbaren Klick:

1. Android prüft bei Ziel-API 37 die Freigabe für lokales Netzwerk.
2. `network_info_plus` liefert lokale IPv4-Adresse, Netzmaske und Broadcast.
3. Große Netze werden auf den lokalen `/24`-Ausschnitt begrenzt.
4. `multicast_dns` sucht `_ssh._tcp.local`.
5. Bis zu 24 TCP-Verbindungen prüfen den ausgewählten SSH-Port mit kurzem Timeout.
6. Nur Kandidaten mit einer `SSH-`-Identifikationszeile erscheinen.
7. Ergebnisse werden im Speicher dedupliziert und nach der Einrichtung verworfen.

Die Suche beweist nicht die Identität des Geräts. Erst SSH-Authentifizierung
und Host-Key-Bestätigung machen einen Kandidaten zum vertrauenswürdigen Server.

## SSH-Einrichtung und automatische WOL-Erkennung

Der Assistent speichert das Profil erst nach einem erfolgreichen SSH-Test. Auf
einem neuen Steuergerät zeigt er bei der ersten Verbindung Schlüsseltyp und
kanonischen SHA-256-Fingerprint; der Nutzer bestätigt diesen bewusst. Ein
importierter privater Schlüssel ersetzt diese Prüfung nicht. Passwort und
privater Schlüssel werden erst nach diesem Test im Secure Storage abgelegt;
eine Schlüssel-Passphrase bleibt nur im Arbeitsspeicher.

Danach kann die optionale WOL-Erkennung einen festen Debian-Befehl über die
bereits vertraute SSH-Verbindung ausführen. Er bestimmt den Adapter der
Standardroute und liest ausschließlich dessen MAC-Adresse aus `/sys/class/net`.
Die lokale Broadcast-Adresse kommt aus demselben `NetworkScope`, den auch die
Serversuche nutzt. Adaptername und Vorschlag werden nur angezeigt; persistent
bleiben nach einer sichtbaren Nutzerentscheidung allein MAC, Broadcast und
UDP-Port.

## Start- und Shutdown-Abläufe

### Start

1. Wenn der SSH-Port schon erreichbar ist, bleibt der Server online und es wird
   kein WOL gesendet.
2. Sonst werden drei Magic Packets an die konfigurierte IPv4-Broadcast-Adresse
   und den UDP-Port gesendet.
3. Danach prüft die App höchstens 90 Sekunden lang alle zwei Sekunden den SSH-Port.
4. Jede laufende Phase kann abgebrochen werden; ein Operation-Token verhindert,
   dass eine alte Polling-Runde später den neuen UI-Zustand überschreibt.

### Shutdown

1. Ist der SSH-Port nicht erreichbar, wird der Server als bereits offline erkannt.
2. Die App authentifiziert sich und ruft den konstanten sudo-Helper auf.
3. Der Helper startet die feste systemd-Unit nicht blockierend und gibt
   `servergy-poweroff-accepted` zurück.
4. Erst nach dieser Bestätigung prüft die App höchstens 60 Sekunden lang, ob der
   SSH-Port verschwunden ist.

## Diagnose

Ein Diagnoseereignis enthält nur Zeitpunkt, Aktion, Erfolg, technischen Code und
Dauer. Es gibt maximal 50 Einträge. Host, Port, Benutzername, MAC, Passwort,
Schlüssel und mDNS-Ergebnisse gehören nicht in Diagnoseobjekte.

## Erweiterungspunkte

Neue Infrastruktur wird über ein Gateway eingebunden. Controller sollten nie
`Socket`, `SSHClient` oder Secure Storage direkt in Widgets aufrufen. Neue
Aktionen brauchen:

- einen eindeutigen Domänentyp oder Fehlercode,
- einen Fake für Controller-Tests,
- Abbruch- und Timeoutverhalten,
- eine redigierte Diagnoseklasse,
- eine verständliche deutsche Fehlermeldung mit nächster Aktion.
