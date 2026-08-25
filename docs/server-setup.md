# Homeserver für Servergy einrichten

Diese Anleitung richtet den Homeserver so ein, dass Servergy ihn kontrolliert
und mit möglichst kleinen Rechten herunterfahren kann.

## 1. Wake-on-LAN aktivieren

Aktiviere im BIOS/UEFI des Servers eine Option wie **Wake on LAN**, **Power on
by PCI-E** oder **Resume by LAN**. Die Bezeichnung ist vom Mainboard abhängig.

Unter Ubuntu/Debian kann der Adapterzustand geprüft werden:

~~~bash
sudo apt install ethtool
ip link
sudo ethtool <netzwerk-interface>
~~~

In der Ausgabe soll Wake-on: g stehen. Falls der Adapter das unterstützt,
wird es so aktiviert:

~~~bash
sudo ethtool -s <netzwerk-interface> wol g
~~~

Der Zustand kann nach einem Neustart verloren gehen. Richte deshalb bei Bedarf
einen systemd-Dienst ein, der den Befehl beim Start ausführt.

Notiere die MAC-Adresse des kabelgebundenen Netzwerkadapters:

~~~bash
ip link show <netzwerk-interface>
~~~

Wake-on-LAN über WLAN wird nur von wenigen Adaptern zuverlässig unterstützt.
Eine kabelgebundene Verbindung ist die robuste Wahl.

## 2. SSH-Benutzer anlegen

Auf Ubuntu/Debian:

~~~bash
sudo adduser servergy
~~~

**Füge diesen Benutzer nicht zur Gruppe `sudo` hinzu.** Servergy darf nur den
explizit freigegebenen Ausschalt-Helper aufrufen; eine Gruppenmitgliedschaft
wäre deutlich weitergehender Zugriff als nötig.

Die App unterstützt zwei getrennte SSH-Anmeldemethoden: einen privaten
Schlüssel (empfohlen) oder Passwort-Anmeldung. Im Passwort-Modus speichert die
App das Passwort nach erfolgreichem Verbindungstest sicher im
Betriebssystem-Schlüsselspeicher, damit es später nicht erneut eingegeben
werden muss. Ein Passwort wird nicht als Fallback neben einem Schlüssel
gespeichert. Lege für den empfohlenen Zugriff einen eigenen Schlüssel an:

~~~bash
ssh-keygen -t ed25519 -f ~/.ssh/servergy_ed25519 -C 'Servergy homeserver control'
sudo install -d -o servergy -g servergy -m 0700 /home/servergy/.ssh
sudo install -o servergy -g servergy -m 0600 ~/.ssh/servergy_ed25519.pub /home/servergy/.ssh/authorized_keys
~~~

Importiere anschließend die **private** Datei `servergy_ed25519` in Servergy.
Die Datei bleibt im System-Schlüsselspeicher des Steuergeräts. Ist sie mit
einer Passphrase geschützt, fragt die App diese bei jeder Verwendung ab und
speichert sie nicht.

Stelle sicher, dass sshd läuft:

~~~bash
sudo systemctl enable --now ssh
sudo systemctl status ssh
~~~

## 3. Ausschalt-Unit und engen Helper erstellen

Die Unit nimmt den Auftrag zuerst entgegen und wartet kurz, bevor der Rechner
wirklich ausgeschaltet wird. Dadurch kann Servergy den bestätigten Auftrag noch
über SSH empfangen, statt einen gelungenen Shutdown wegen einer früh getrennten
Netzwerkverbindung fälschlich als Fehler zu melden.

Erstelle die Unit als root:

~~~bash
sudo install -o root -g root -m 0644 /dev/stdin /etc/systemd/system/servergy-poweroff.service
~~~

Füge diesen Inhalt ein und beende die Eingabe mit Ctrl-D:

~~~ini
[Unit]
Description=Power off this host after a Servergy request

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 2
ExecStart=/usr/bin/systemctl poweroff --no-block
~~~

Aktiviere die geänderte Unit-Datei:

~~~bash
sudo systemctl daemon-reload
~~~

Erstelle genau diesen Helper als root:

~~~bash
sudo install -o root -g root -m 0755 /dev/stdin /usr/local/sbin/servergy-poweroff
~~~

Der Befehl wartet auf die Eingabe. Füge diese zwei Zeilen ein und beende die
Eingabe mit Ctrl-D:

~~~sh
#!/bin/sh
set -eu
/usr/bin/systemctl start --no-block servergy-poweroff.service
printf '%s\n' 'servergy-poweroff-accepted'
~~~

Prüfe den Inhalt:

~~~bash
sudo cat /usr/local/sbin/servergy-poweroff
sudo stat -c '%U %G %a %n' /usr/local/sbin/servergy-poweroff
~~~

Erwartet werden Eigentümer root root und Rechte 755.

## 4. Nur diesen Helper ohne Passwort erlauben

Öffne die sudoers-Konfiguration sicher mit visudo:

~~~bash
sudo visudo -f /etc/sudoers.d/servergy
~~~

Füge diese Zeile ein. Ersetze servergy, wenn du einen anderen SSH-Benutzer
angelegt hast:

~~~sudoers
servergy ALL=(root) NOPASSWD: /usr/local/sbin/servergy-poweroff
~~~

Setze die korrekten Dateirechte:

~~~bash
sudo chmod 0440 /etc/sudoers.d/servergy
~~~

Es ist absichtlich **nicht** erlaubt, in sudoers shutdown, eine Shell oder
einen frei wählbaren Befehl freizugeben.

## 5. Vom anderen Rechner testen

Teste zunächst die SSH-Anmeldung:

~~~bash
ssh servergy@<server-ip>
~~~

Dann den eingeschränkten Helper:

~~~bash
ssh servergy@<server-ip> 'sudo -n /usr/local/sbin/servergy-poweroff'
~~~

Dieser Befehl bestätigt zuerst `servergy-poweroff-accepted` und fährt den
Server anschließend wirklich herunter. Nach dem Wiederstart kann der
Host-Key-Fingerprint angezeigt werden:

~~~bash
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub -E sha256
~~~

Vergleiche ihn beim ersten Verbindungsaufbau in Servergy mit dem angezeigten
Fingerprint. Akzeptiere keinen unbekannten oder geänderten Key ohne diesen
Vergleich.

## 6. Daten in Servergy eintragen

1. Starte den Server für die Ersteinrichtung und wähle in Servergy
   **„Server im Netzwerk suchen“** oder trage seine Adresse manuell ein.
2. Prüfe die SSH-Verbindung und vergleiche den angezeigten SHA-256-Fingerprint.
3. Richte Wake-on-LAN danach ein oder überspringe den Schritt zunächst.

- **Hostname oder IP-Adresse:** lokale IP oder fester lokaler DNS-Name
- **SSH-Port:** normalerweise 22
- **SSH-Benutzername:** zum Beispiel servergy
- **MAC-Adresse:** MAC des WOL-fähigen, kabelgebundenen Adapters
- **Broadcast-Adresse:** meist die Broadcast-Adresse des Subnetzes, etwa
  192.168.178.255; 255.255.255.255 funktioniert nicht in jedem Netzwerk
- **UDP-Port:** meist 9

Danach zuerst **SSH-Verbindung testen**, dann das Ausschalten erproben und
abschließend Wake-on-LAN testen.

## Fehlerdiagnose und VPN

- Wake-on-LAN benötigt einen Weg für IPv4-Broadcast-Pakete. Viele VPNs leiten
  solche Pakete nicht weiter. Verbinde dich zum Starten in diesem Fall mit dem
  Heimnetz oder richte einen geeigneten WOL-Relay im eigenen Netz ein.
- Erscheint ein neuer SSH-Fingerprint, brich die Verbindung ab und vergleiche
  ihn direkt am Server mit `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
  -E sha256`. Akzeptiere einen geänderten Key nicht blind.
- Bei „Ausschaltbefehl abgelehnt“ prüfe mit `sudo -l -U servergy`, dass nur
  `/usr/local/sbin/servergy-poweroff` freigegeben ist.
- Das Diagnoseprotokoll der App enthält nur Zeit, Aktion, Fehlercode und Dauer;
  es exportiert nie Zugangsdaten, Schlüssel, Hostadressen oder MAC-Adressen.
