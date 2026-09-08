<p align="center">
  <img src="assets/branding/servergy-icon.png" width="128" alt="Servergy – Homeserver-Steuerung" />
</p>

<h1 align="center">Servergy</h1>

<p align="center">
  <strong>Dein Homeserver. Sicher erreichbar. Einfach steuerbar.</strong><br />
  Eine lokale Flutter-App für Wake-on-LAN und kontrollierte SSH-Steuerung.
</p>

## 🎯 Für bestehende Debian-Homeserver

Servergy ist eine **mobile-first Ergänzung** für einen bereits eingerichteten
Homeserver mit Debian oder einem Debian-basierten System wie Ubuntu. Die App
ersetzt weder das Betriebssystem noch ein vollwertiges Server-Control-Panel und
führt keine frei formulierten Fernbefehle aus.

Stattdessen gibt sie dir die wenigen Werkzeuge, die bei einem gelegentlich
genutzten Server wirklich zählen: Er lässt sich bei vorhandener
Wake-on-LAN-Unterstützung bequem starten, über SSH sicher prüfen und nach der
Nutzung kontrolliert wieder herunterfahren. So muss der Homeserver nicht
dauerhaft laufen und bleibt dennoch ohne komplizierte Verwaltungsoberfläche
alltagstauglich.

<p align="center">
  <strong>🇩🇪 Deutsch</strong> ·
  <a href="README.en.md">🇬🇧 English</a>
</p>

<p align="center">
  <a href="https://github.com/Web-Developer-DB/Servergy/actions/workflows/quality.yml">
    <img src="https://github.com/Web-Developer-DB/Servergy/actions/workflows/quality.yml/badge.svg?branch=main" alt="Qualitätsprüfung für main" />
  </a>
  <a href="docs/release-readiness.md">
    <img src="https://img.shields.io/badge/Status-Aktive%20Entwicklung-D97706?style=flat-square" alt="Status: Aktive Entwicklung" />
  </a>
  <a href="https://github.com/Web-Developer-DB/Servergy/releases">
    <img src="https://img.shields.io/badge/Version-0.1.0-0F4C81?style=flat-square" alt="Version 0.1.0" />
  </a>
  <a href="docs/privacy.md">
    <img src="https://img.shields.io/badge/Datenschutz-lokal%20%26%20ohne%20Telemetrie-0B7A43?style=flat-square" alt="Lokale Datenverarbeitung ohne Telemetrie" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/Lizenz-MIT-5B21B6?style=flat-square" alt="MIT-Lizenz" />
  </a>
</p>

<p align="center">
  <a href="#-für-bestehende-debian-homeserver">Zielgruppe</a> ·
  <a href="#-auf-einen-blick">Überblick</a> ·
  <a href="#-die-app-auf-einen-blick">App ansehen</a> ·
  <a href="#-erste-schritte">Erste Schritte</a> ·
  <a href="#-sicherheit-als-standard">Sicherheit</a> ·
  <a href="#-qualität-und-release">Qualität &amp; Release</a> ·
  <a href="#-dokumentation">Dokumentation</a>
</p>

> [!NOTE]
> **Servergy befindet sich in aktiver Entwicklung; ein GitHub-Release ist noch
> nicht verfügbar.** Die App ist für einen eigenen Homeserver gedacht. Vor der
> ersten Veröffentlichung müssen die Realtests, Signaturen und
> Freigabekriterien in
> [docs/release-readiness.md](docs/release-readiness.md) erfüllt sein.

## 📱 Die App auf einen Blick

<p align="center">
  <img src="assets/screenshots/app-showcase.png" width="720" alt="Farbige Servergy-App-Vorschau mit dem Dashboard im dunklen Design links und den Einstellungen rechts" />
</p>

<p align="center">
  <em>Dashboard und Einstellungen: kompakt, klar und auf Android, Linux und Windows gleich bedienbar.</em>
</p>

## ✨ Auf einen Blick

|  | Servergy bedeutet |
| --- | --- |
| 🏠 **Ein klarer Fokus** | Eine lokale App für **genau einen** Homeserver – ohne Cloud-Konto und ohne komplizierte Serververwaltung. |
| 🔐 **Sicher steuern** | SSH-Zugang, Host-Key-Prüfung und ein enger, fest definierter Shutdown-Helper statt frei formulierbarer Shell-Befehle. |
| ⚡ **Wieder starten** | Wake-on-LAN mit Statusprüfung, sobald dein Server ausgeschaltet ist. |
| 🧭 **Geführt einrichten** | Ein fokussierter Assistent führt durch Netzwerk, Server, SSH, Verbindungsprüfung und optionales Wake-on-LAN. |
| 🕶️ **Privat bleiben** | Keine Cloud, keine Telemetrie, kein Tracking und kein Hintergrunddienst. Alle Daten bleiben auf deinem Gerät. |

Servergy steuert ausschließlich Aktionen, die du bewusst auslöst. Die App läuft
im Vordergrund und verbindet sich nur mit dem Homeserver, den du einrichtest.

## 🧩 Funktionen

| Bereich | Was Servergy erledigt | Dein Vorteil |
| --- | --- | --- |
| 🔎 **Server finden** | Sucht optionale mDNS-Ankündigungen und prüft kurz mögliche SSH-Ziele im lokalen IPv4-Netz; Host oder IP können immer manuell eingetragen werden. | Schneller Einstieg im Heimnetz, volle Kontrolle bei VPN oder festen Adressen. |
| 🔑 **SSH-Zugang** | Unterstützt Passwort-Anmeldung sowie OpenSSH-, RSA- und EC-Schlüssel; verschlüsselte Schlüssel fragen ihre Passphrase nur für die aktuelle Aktion ab. | Zugangsdaten werden nicht unnötig erneut eingegeben oder angezeigt. |
| 🪪 **Host-Key-Schutz** | Der SHA-256-Fingerprint wird beim ersten Kontakt bewusst bestätigt. Ein geänderter Key blockiert weitere Aktionen. | Schutz vor einem versehentlich oder böswillig ausgetauschten Ziel. |
| ⚡ **Wake-on-LAN** | Sendet Wake-on-LAN und prüft anschließend, ob der SSH-Port wieder erreichbar wird. | Ein ausgeschalteter Server kann bequem gestartet werden. |
| ⏻ **Sicher herunterfahren** | Nutzt einen eingeschränkten, root-eigenen Servergy-Helper mit einer festen systemd-Unit. | Kein allgemeines `sudo`, keine frei wählbaren Fernbefehle. |
| 🧾 **Ereignisse** | Hält ein lokales, begrenztes und redigiertes Aktivitätsprotokoll bereit. | Hilfreiche Diagnose ohne Profil- oder Netzwerkdaten im Export. |
| 🎨 **Plattformgerecht** | Systemstandard sowie helle oder dunkle Material-3-Oberfläche, große Interaktionsflächen und native Launcher- und Startmenü-Icons. | Eine ruhige, verständliche Bedienung auf Android, Linux und Windows. |
| 🌐 **Zweisprachig** | Systemstandard, Deutsch oder English; deutsche Systemsprachen wählen Deutsch, alle anderen Englisch. | Die Sprache kann jederzeit direkt in den Einstellungen geändert werden. |

### 🌐 Sprache

Servergy unterstützt Deutsch und Englisch. Die Voreinstellung **Systemstandard**
folgt deinem Betriebssystem: Bei `de`, `de-DE`, `de-AT` und weiteren deutschen
Sprachvarianten erscheint die App auf Deutsch; jede andere Systemsprache führt
automatisch zu Englisch. Unter **Einstellungen → Sprache** kannst du dauerhaft
**Deutsch** oder **English** wählen oder zum Systemstandard zurückkehren. Die
Auswahl gilt sofort in der gesamten App und bleibt nach einem Neustart erhalten.

### 🎨 Marke und App-Icons

Das Servergy-Symbol verbindet den Homeserver mit den beiden klaren Aktionen:
grün steht für Start bzw. Erreichbarkeit, blau für das sichere Herunterfahren.
Die Wortmarke wird für GitHub, Website und Fenstertitel verwendet; Launcher
bleiben auf dem quadratischen Symbol ohne Text.

| Plattform | Auslieferung | Varianten |
| --- | --- | --- |
| 🤖 Android | Adaptive Launcher-Ressource | Vollfarbe, Vordergrund und Monochrom für moderne Launcher |
| 🪟 Windows | `app_icon.ico` | Mehrgrößiges Icon bis 256 px für Fenster und Startmenü |
| 🐧 Ubuntu/Linux | Hicolor-Theme | PNGs von 16 bis 512 px plus skalierbares SVG |

Alle Varianten werden aus der freigegebenen Vorlage mit
[`tool/generate_launcher_icons.dart`](tool/generate_launcher_icons.dart)
reproduzierbar erzeugt.

## 🗺️ So funktioniert der Ablauf

| Schritt | In der App | Sicherheitsentscheidung |
| :---: | --- | --- |
| `1` | 🌐 **Netzwerkgrenze verstehen** | Servergy erklärt, wann Heimnetz oder VPN sinnvoll ist. |
| `2` | 🔎 **Server finden oder eintragen** | Ein Fund ist nur ein Kandidat – noch kein vertrauenswürdiger Server. |
| `3` | 🔑 **SSH-Zugang wählen** | Schlüssel werden bevorzugt unterstützt; Passwörter bleiben im System-Schlüsselspeicher. |
| `4` | 🪪 **Verbindung und Host-Key prüfen** | Erst nach erfolgreichem SSH-Test werden neue Zugangsdaten gespeichert. |
| `5` | ⚡ **Wake-on-LAN ergänzen** | MAC- und Broadcast-Daten können geprüft, gespeichert oder später ergänzt werden. |

Danach wird die Startseite zum Dashboard: Erreichbarkeit, letzter Check und die
passende nächste Aktion stehen im Vordergrund; technische Details bleiben in
den Ereignissen und Einstellungen erreichbar.

## 🚀 Erste Schritte

### Für Anwender

Der erste Download wird erst nach der Release-Abnahme veröffentlicht. Danach
erscheinen Release-Artefakte als signierte GitHub-Releases mit SHA-256-Prüfsummen.
Prüfe immer die Release-Notizen und die Prüfsumme, bevor du ein Artefakt
installierst.

| Plattform | Release-Artefakt | Start |
| --- | --- | --- |
| 🤖 **Android 12+** | Signiertes APK | APK aus dem GitHub-Release installieren und die lokale Netzwerkfreigabe bei Bedarf bewusst erlauben. |
| 🐧 **Linux** | Nutzer-Bundle (`.tar.gz`) | Archiv entpacken, `./install-linux.sh` ausführen und Servergy anschließend über das Anwendungsmenü starten. Die Installation bleibt unter `~/.local/share/servergy`. |
| 🪟 **Windows 11** | Signiertes ZIP | ZIP entpacken, Windows-Signatur prüfen und `servergy.exe` starten. |

> [!NOTE]
> Ein echter Wake-on-LAN-Test benötigt ein passendes Heimnetz. Android-Emulatoren
> und VPN-Verbindungen ersetzen keinen Broadcast-Test im lokalen Netzwerk.

### Für deinen Homeserver

1. Aktiviere Wake-on-LAN im BIOS/UEFI, Betriebssystem und – falls nötig – im
   Netzwerk.
2. Richte einen eigenen SSH-Benutzer ein und verwende nach Möglichkeit einen
   privaten Schlüssel.
3. Vergleiche den Host-Key-Fingerprint direkt am Server, bevor du ihn in der
   App bestätigst.
4. Richte den eingeschränkten Shutdown-Helper über **Einstellungen → Sicheres
   Herunterfahren → Server vorbereiten** oder anhand der Anleitung ein.

Die vollständige, sichere Einrichtung für Debian/Ubuntu mit systemd steht in
[docs/server-setup.md](docs/server-setup.md).

<details>
<summary><strong>Entwicklung lokal starten</strong></summary>

<br />

**Voraussetzungen**

- Flutter/Dart passend zu `pubspec.yaml`
- Android Studio/JDK für Android-Builds
- unter Linux: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`,
  `libsecret-1-dev` und `libsecret-1-0`
- ein Android-Gerät/Emulator, Linux-Desktop oder Windows-Entwicklungsrechner

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

**Plattform-Builds**

```bash
flutter build apk --debug
flutter build linux --debug
flutter build windows --debug
```

Die vollständige Entwicklungs-, Emulator- und Realgeräte-Anleitung findest du
in [docs/development.md](docs/development.md).

</details>

## 🛡️ Sicherheit als Standard

Servergy soll nicht nur bequem sein, sondern den Zugriff auf einen Homeserver
bewusst klein halten.

| Schutzmaßnahme | Umsetzung in Servergy |
| --- | --- |
| **Keine Cloud** | Servergy überträgt keine Profil-, Diagnose- oder Nutzungsdaten an einen Backend-Dienst. |
| **Getrennte Datenspeicher** | Nicht geheime Profildaten liegen lokal in App-Einstellungen; Passwörter, private Schlüssel und bestätigte Host-Keys liegen im Betriebssystem-Schlüsselspeicher. |
| **Kein Passwort-Fallback** | Beim Wechsel auf Schlüssel-Anmeldung wird ein gespeichertes Passwort entfernt. Ein leeres Passwortfeld bedeutet bewusst „beibehalten“. |
| **Fingerprints statt Vertrauen auf Namen** | Das Vertrauen gilt für Host und Port. Eine Schlüsseländerung muss außerhalb der App geprüft werden. |
| **Kein Remote-Terminal** | Die App bietet keine Eingabe für frei gewählte Remote-Kommandos. |
| **Enger Shutdown-Pfad** | Die App ruft ausschließlich `sudo -n /usr/local/sbin/servergy-poweroff` auf. Der Helper startet nur die fest definierte systemd-Unit. |
| **Redigierte Diagnose** | Der Export enthält Zeitpunkt, Aktion, Ergebnis, Fehlercode und Dauer – keine Passwörter, Schlüssel, Benutzernamen, vollständigen Hostadressen oder MAC-Adressen. |

### Der Shutdown-Helper im Überblick

Beim optionalen Server-Setup werden ausschließlich diese Dateien verwaltet:

| Serverdatei | Eigentümer & Rechte | Zweck |
| --- | --- | --- |
| `/usr/local/sbin/servergy-poweroff` | `root:root` · `0755` | Argumentloser Helper; bestätigt den Auftrag und startet nur die Servergy-systemd-Unit. |
| `/etc/systemd/system/servergy-poweroff.service` | `root:root` · `0644` | Oneshot-Unit, die den Server erst nach erfolgreicher SSH-Antwort herunterfährt. |
| `/etc/sudoers.d/servergy` | `root:root` · `0440` | Erlaubt dem konfigurierten SSH-Benutzer ausschließlich diesen einen Helper-Aufruf. |

Die konkreten Schritte, Rechteprüfungen, der manuelle Fallback und die sichere
Entfernung stehen in der [Serveranleitung](docs/server-setup.md).

## ⚠️ Bewusste Grenzen

| Thema | Was du wissen solltest |
| --- | --- |
| 🏠 **Ein Server** | Version 1 verwaltet bewusst nur einen Homeserver. |
| 🌙 **Ausgeschaltete Geräte** | Ein ausgeschalteter Server kann nicht gesucht werden; für den Start braucht er vorab korrekt eingerichtetes Wake-on-LAN. |
| 📡 **Netzwerksuche** | Die Suche findet SSH-Kandidaten im aktuellen lokalen Netz, aber keine zuverlässigen MAC-Adressen und keine allgemeinen VPN-Ziele. |
| 🔌 **Wake-on-LAN** | Broadcasts über VPN funktionieren nicht zuverlässig und werden nicht von Servergy eingerichtet. Eine kabelgebundene Netzwerkkarte ist die robuste Wahl. |
| 🐧 **Shutdown-Helper** | Der dokumentierte komfortable Setup-Weg setzt Debian/Ubuntu mit systemd voraus. |
| 📱 **Android 17** | Lokale Netzwerkaktionen benötigen die vom System abgefragte Freigabe; ohne sie bleiben manuelle VPN-Konfigurationen möglich. |

## 🧪 Qualität und Release

Der stabile Release trennt automatisierbare Prüfungen klar von den
unverzichtbaren Tests in echter Hardware und echten Heimnetzen.

| Prüfung | Automatisiert | Vor dem Release zusätzlich nötig |
| --- | :---: | --- |
| Formatierung, statische Analyse und Tests | ✅ | — |
| Android-, Linux- und Windows-Debug-Build | ✅ | Sichtprüfung auf Zielgeräten |
| Icon-Konsistenz und Linux-Nutzer-Installer | ✅ | Startmenü-, Deinstallations- und Speicherprüfung auf Linux |
| Android- und Windows-Signatur | ✅ im Tag-Workflow | Produktive Signatursecrets in GitHub hinterlegen |
| WOL, SSH, Shutdown und VPN | — | ✅ Mit einem echten Homeserver dokumentieren |
| Datenschutz und Diagnoseexport | Teilweise | ✅ Export vor dem Senden kontrollieren |

Die verbindliche Testmatrix und Release-Entscheidung stehen in
[docs/release-readiness.md](docs/release-readiness.md); die frühere
[Beta-Dokumentation](docs/beta.md) bleibt als Archiv erhalten.

## 💬 Feedback und Fehler melden

Rückmeldungen helfen besonders bei echten Netzwerk-, Router-, VPN- und
Wake-on-LAN-Konstellationen. In der App führt **Einstellungen → Feedback geben**
direkt zu den GitHub-Issue-Vorlagen.

| Melden | Vorlage | Bitte nicht einreichen |
| --- | --- | --- |
| 🐛 Reproduzierbarer Fehler | [Fehler melden](https://github.com/Web-Developer-DB/Servergy/issues/new?template=bug_report.yml) | Passwörter, private Schlüssel, vollständige IP-Adressen, MAC-Adressen oder ungeschwärzte Screenshots |
| 💡 Bedienbarkeit oder Wunsch | [Feedback geben](https://github.com/Web-Developer-DB/Servergy/issues/new?template=feedback.yml) | Zugangsdaten oder nicht bewusst kontrollierte Diagnoseinhalte |

Ein Diagnoseexport ist optional und bereits redigiert. Lies ihn trotzdem vor
dem Hochladen noch einmal durch.

## 📚 Dokumentation

| Dokument | Inhalt |
| --- | --- |
| [Release-Readiness](docs/release-readiness.md) | Realtest-Matrix, Signaturen, Release-Gates und Feedback-Regeln |
| [Serveranleitung](docs/server-setup.md) | Wake-on-LAN, SSH-Benutzer, eingeschränkter sudoers-Helper und manueller Fallback |
| [Architektur](docs/architecture.md) | Datenfluss, Komponenten, Grenzen und Sicherheitsentscheidungen |
| [Entwicklung & Tests](docs/development.md) | Lokale Entwicklungsumgebung, Builds, Qualität und Realgeräte-Tests |
| [Datenschutz](docs/privacy.md) | Lokale Datenverarbeitung und redigierte Diagnoseexporte |
| [Release-Checkliste](docs/release-checklist.md) | Letzte Prüfungen vor einem stabilen oder vorab gekennzeichneten Release |

## 🤝 Mitwirken

`main` ist der gemeinsame Integrations- und Release-Branch. Erstelle für
Änderungen einen kurzen Themenbranch, halte ihn aktuell gegenüber `main` und
öffne anschließend einen Pull Request nach `main`.

Bevor du einen Pull Request öffnest:

```bash
dart format lib test tool
flutter analyze
flutter test
dart run tool/generate_launcher_icons.dart
```

Neue Netzwerk- oder SSH-Funktionen benötigen neben Tests immer eine bewusste
Prüfung von Fehlerpfaden, Abbrüchen und realen Geräten. Zugangsdaten, private
Schlüssel, persönliche Netzwerkdaten und echte Diagnosen gehören niemals in
Commits, Tests oder Screenshots.

## 📄 Lizenz

Servergy steht unter der [MIT-Lizenz](LICENSE).

---

<p align="center">
  Entwickelt für einen ruhigeren, sichereren Homeserver-Alltag. 🏠
</p>
