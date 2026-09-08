import 'package:flutter/material.dart';

import 'generated/app_localizations.dart';

/// A compatibility catalog for the existing, string-based UI. New UI should
/// prefer generated ARB accessors; the catalog keeps every current visible
/// message localizable while the domain layer continues to expose safe codes.
extension ServergyStrings on BuildContext {
  bool get usesEnglish {
    final localized = Localizations.of<AppLocalizations>(
      this,
      AppLocalizations,
    );
    return localized != null && localized.localeName != 'de';
  }

  String tr(String value) {
    final localized = Localizations.of<AppLocalizations>(
      this,
      AppLocalizations,
    );
    // Focused widget tests can render individual screens without a root
    // MaterialApp localization delegate. Keep their established German
    // baseline while production always provides AppLocalizations.
    if (localized == null) return value;
    final locale = localized.localeName;
    if (locale.toLowerCase().startsWith('de')) return value;
    return _english[value] ?? _dynamicEnglish(value) ?? value;
  }
}

String? _dynamicEnglish(String value) {
  if (value.startsWith('Zuletzt geprüft: ')) {
    return 'Last checked: ${value.substring('Zuletzt geprüft: '.length)}';
  }
  if (value.endsWith(' ist erforderlich.')) {
    final field = value.substring(
      0,
      value.length - ' ist erforderlich.'.length,
    );
    return '${_english[field] ?? field} is required.';
  }
  if (value.startsWith('Geprüfter Bereich: ')) {
    return 'Checked range: ${value.substring('Geprüfter Bereich: '.length)}';
  }
  return null;
}

const _english = <String, String>{
  'Ereignisse': 'Events',
  'Einstellungen': 'Settings',
  'Dein Homeserver.': 'Your home server.',
  'Guten Tag.': 'Welcome back.',
  'Lokal steuern – im Heimnetz oder über dein VPN.':
      'Control it locally — on your home network or through your VPN.',
  'Deine Verbindung auf einen Blick.': 'Your connection at a glance.',
  'Server ist erreichbar': 'Server is reachable',
  'Bereit für deine Dienste': 'Ready for your services',
  'Server ist ausgeschaltet': 'Server is powered off',
  'Start jederzeit per Wake-on-LAN': 'Start it anytime with Wake-on-LAN',
  'Startsignal wurde gesendet': 'Wake signal was sent',
  'Warte, bis der Server erreichbar ist':
      'Waiting for the server to become reachable',
  'Server wird heruntergefahren': 'Server is shutting down',
  'Die Verbindung wird gleich getrennt': 'The connection will close shortly',
  'Serverstatus wird geprüft': 'Checking server status',
  'Einen Moment bitte': 'One moment, please',
  'Status noch nicht geprüft': 'Status has not been checked yet',
  'Aktualisiere, um den Status zu sehen': 'Refresh to see the status',
  'Homeserver einrichten': 'Set up home server',
  'Homeserver': 'Home server',
  'Status aktualisieren': 'Refresh status',
  'Noch nicht geprüft': 'Not checked yet',
  'Verbindungsdetails': 'Connection details',
  'Adresse und SSH-Port': 'Address and SSH port',
  'Aktion abbrechen': 'Cancel action',
  'Einmal einrichten': 'Set up once',
  'Der Assistent prüft deine Verbindungsdaten und erklärt die sichere Einrichtung.':
      'The assistant checks your connection details and explains the secure setup.',
  'Schnellaktionen': 'Quick actions',
  'Steuere deinen Server sicher von diesem Gerät.':
      'Control your server securely from this device.',
  'Server starten': 'Start server',
  'Wake-on-LAN noch einrichten': 'Set up Wake-on-LAN',
  'Hinterlege MAC-Adresse und Broadcast-Adresse in den Einstellungen, um den ausgeschalteten Server starten zu können.':
      'Add the MAC and broadcast address in Settings to start the powered-off server.',
  'SSH-Verbindung testen': 'Test SSH connection',
  'Zugang und Serveridentität prüfen': 'Check access and server identity',
  'Server herunterfahren': 'Shut down server',
  'Server herunterfahren?': 'Shut down server?',
  'Aktive Dienste können unterbrochen werden. Der Server wird über den eingeschränkten Servergy-Helper ausgeschaltet.':
      'Active services may be interrupted. The server is shut down through the restricted Servergy helper.',
  'Abbrechen': 'Cancel',
  'Herunterfahren': 'Shut down',
  'Server für sicheres Herunterfahren vorbereiten?':
      'Prepare server for safe shutdown?',
  'Servergy installiert einmalig einen root-eigenen Ausschalt-Helper, eine systemd-Unit und eine eng begrenzte sudoers-Regel für deinen SSH-Benutzer. Dafür wird jetzt einmalig dein sudo-Passwort benötigt. Es wird nicht gespeichert. Der Server wird dabei nicht heruntergefahren.':
      'Servergy installs a root-owned shutdown helper, a systemd unit, and a narrowly scoped sudoers rule for your SSH user once. Your sudo password is needed once now and is never saved. The server is not shut down during this step.',
  'Manuell einrichten': 'Set up manually',
  'Server vorbereiten': 'Prepare server',
  'Servergy-Ausschalt-Helper entfernen?':
      'Remove the Servergy shutdown helper?',
  'Dadurch werden der Servergy-Helper, seine systemd-Unit und die dazugehörige sudoers-Regel vom Server entfernt. SSH, Wake-on-LAN und deine gespeicherte Verbindung bleiben erhalten. Danach kann Servergy den Server erst nach einer erneuten Vorbereitung wieder herunterfahren.':
      'This removes the Servergy helper, its systemd unit, and its sudoers rule from the server. SSH, Wake-on-LAN, and your saved connection remain. Servergy can shut the server down again only after preparing it again.',
  'Vom Server entfernen': 'Remove from server',
  'Manuelle Debian-Einrichtung': 'Manual Debian setup',
  'Führe diesen festen Ablauf an der Serverkonsole aus. Ersetze ausschließlich SSH-BENUTZER; gib keine eigenen Befehle in Servergy ein.':
      'Run this fixed sequence at the server console. Replace only SSH-USER; do not enter your own commands in Servergy.',
  'Anleitung wurde kopiert.': 'Instructions copied.',
  'Kopieren': 'Copy',
  'Fertig': 'Done',
  'SSH-Server bestätigen': 'Confirm SSH server',
  'Vergleiche ihn mit dem Homeserver, bevor du vertraust.':
      'Compare it with the home server before trusting it.',
  'Vertrauen': 'Trust',
  'Passphrase für SSH-Schlüssel': 'SSH key passphrase',
  'SSH-Passwort': 'SSH password',
  'Geheimnis': 'Secret',
  'Fortfahren': 'Continue',
  'Einmaliges sudo-Passwort': 'One-time sudo password',
  'sudo-Passwort': 'sudo password',
  'Wird nur für diese Servervorbereitung verwendet.':
      'Used only for this server preparation.',
  'Vorbereiten': 'Prepare',
  'Dein Servergy': 'Your Servergy',
  'Verbindung, Steuerung und Produktinformationen.':
      'Connection, controls, and product information.',
  'Darstellung': 'Appearance',
  'System': 'System default',
  'Hell': 'Light',
  'Dunkel': 'Dark',
  'Systemstandard': 'System default',
  'Sprache': 'Language',
  'Verbindung': 'Connection',
  'Steuerung': 'Controls',
  'Für diesen Server eingerichtet': 'Configured for this server',
  'Noch nicht eingerichtet': 'Not configured yet',
  'Sicheres Herunterfahren': 'Safe shutdown',
  'Servergy-Helper auf dem Server verwalten':
      'Manage the Servergy helper on the server',
  'Datenschutz & Diagnose': 'Privacy & diagnostics',
  'Lokales, redigiertes Aktivitätsprotokoll': 'Local, redacted activity log',
  'Feedback geben': 'Give feedback',
  'Öffnet die Servergy-Issue-Vorlagen auf GitHub':
      'Opens the Servergy issue templates on GitHub',
  'Gefahrenbereich': 'Danger zone',
  'Verbindung löschen': 'Delete connection',
  'Profil und lokale Zugangsdaten entfernen':
      'Remove the profile and local credentials',
  'Feedback sicher senden': 'Send feedback safely',
  'GitHub wird in deinem Browser geöffnet. Reiche keine Passwörter, privaten Schlüssel, vollständigen IP-Adressen oder MAC-Adressen ein. Ein Diagnoseexport ist bereits redigiert und kann bei Bedarf bewusst angehängt werden.':
      'GitHub will open in your browser. Do not submit passwords, private keys, complete IP addresses, or MAC addresses. A diagnostic export is already redacted and can be attached deliberately if needed.',
  'GitHub öffnen': 'Open GitHub',
  'GitHub konnte nicht geöffnet werden. Prüfe deine Browser-Einstellungen.':
      'GitHub could not be opened. Check your browser settings.',
  'Der eingeschränkte Servergy-Helper erlaubt ausschließlich das sichere Herunterfahren. Das sudo-Passwort wird nie gespeichert.':
      'The restricted Servergy helper allows only safe shutdown. The sudo password is never saved.',
  'Installierten Helper entfernen': 'Remove installed helper',
  'Über Servergy': 'About Servergy',
  'Produktinformationen werden geladen': 'Loading product information',
  'Produktinformationen nicht verfügbar': 'Product information is unavailable',
  'Stabil': 'Stable',
  'Entwicklung': 'Development',
  'Nicht verfügbar': 'Unavailable',
  'Wake-on-LAN und sichere SSH-Steuerung für deinen Homeserver.':
      'Wake-on-LAN and secure SSH control for your home server.',
  'Datenschutz': 'Privacy',
  'Serveranleitung': 'Server guide',
  'Versionsinformationen kopiert.': 'Version information copied.',
  'Versionsinformationen kopieren': 'Copy version information',
  'Dieses Dokument konnte nicht geladen werden.':
      'This document could not be loaded.',
  'Verbindung bearbeiten': 'Edit connection',
  'Dein Netzwerk': 'Your network',
  'Lege zuerst die sichere Grundlage für die Verbindung.':
      'First establish a secure basis for the connection.',
  'Für die Ersteinrichtung muss dein Homeserver eingeschaltet und im Heimnetz erreichbar sein. Servergy arbeitet im Heimnetz oder über ein vorhandenes VPN. Die automatische Suche prüft nur dein aktuelles lokales Netz; VPN-Ziele trägst du manuell ein.':
      'For initial setup, your home server must be powered on and reachable on the home network. Servergy works on the home network or through an existing VPN. Automatic discovery checks only your current local network; enter VPN targets manually.',
  'Server finden': 'Find server',
  'Suche im Heimnetz oder trage deine Daten manuell ein.':
      'Search the home network or enter your details manually.',
  'Anzeigename': 'Display name',
  'SSH-Port': 'SSH port',
  'Hostname oder IP-Adresse': 'Hostname or IP address',
  'SSH-Benutzername': 'SSH username',
  'SSH-Zugang': 'SSH access',
  'Wähle, wie Servergy sich sicher anmelden soll.':
      'Choose how Servergy should authenticate securely.',
  'Verbindung prüfen': 'Check connection',
  'Bestätige die Identität deines Servers vor dem Speichern.':
      'Confirm your server identity before saving.',
  'Server später starten': 'Start server later',
  'Wake-on-LAN ist optional und kann jederzeit geändert werden.':
      'Wake-on-LAN is optional and can be changed at any time.',
  'Verbindung prüfen und speichern': 'Check and save connection',
  'Einrichtung abschließen': 'Finish setup',
  'Weiter': 'Continue',
  'Zurück': 'Back',
  'Dieser Schritt wird nach dem vorherigen Schritt freigeschaltet.':
      'This step is unlocked after the previous step.',
  'SSH-Schlüssel (empfohlen)': 'SSH key (recommended)',
  'Importiere einen privaten OpenSSH-, RSA- oder EC-Schlüssel.':
      'Import a private OpenSSH, RSA, or EC key.',
  'Schlüssel ist für den Import ausgewählt.': 'A key is selected for import.',
  'Schlüsseldatei auswählen': 'Choose key file',
  'Schlüsseldatei ändern': 'Change key file',
  'Passwort': 'Password',
  'Das Passwort wird nach dem Speichern sicher auf diesem Gerät hinterlegt.':
      'The password is securely stored on this device after saving.',
  'Leer: vorhandenes gespeichertes Passwort beibehalten.':
      'Empty: keep the existing saved password.',
  'Nach der sicheren SSH-Prüfung kann Servergy den aktiven Debian-Netzwerkadapter erkennen und passende WOL-Werte vorschlagen.':
      'After secure SSH verification, Servergy can identify the active Debian network adapter and suggest matching WOL values.',
  'WOL automatisch erkennen': 'Detect WOL automatically',
  'Prüfe und speichere zuerst die SSH-Verbindung im vorherigen Schritt.':
      'First check and save the SSH connection in the previous step.',
  'Automatisch erkannt': 'Detected automatically',
  'Netzwerkadapter': 'Network adapter',
  'Broadcast': 'Broadcast',
  'Wake-on-LAN jetzt einrichten': 'Set up Wake-on-LAN now',
  'Du kannst Werte prüfen oder manuell ergänzen. Dieser Schritt bleibt optional.':
      'You can check values or add them manually. This step remains optional.',
  'MAC-Adresse': 'MAC address',
  'Broadcast-Adresse': 'Broadcast address',
  'UDP-Port': 'UDP port',
  'Kein Problem: Wake-on-LAN kannst du später in den Einstellungen ergänzen.':
      'No problem: you can add Wake-on-LAN later in Settings.',
  'Serveradresse übernommen': 'Server address applied',
  'Ändern': 'Change',
  'Server im Netzwerk suchen': 'Search for server on network',
  'Sucht nur mögliche SSH-Server im aktuellen Heimnetz. Ein Treffer ist noch keine Identitätsbestätigung.':
      'Searches only for possible SSH servers on the current home network. A result is not yet an identity confirmation.',
  'Suche abbrechen': 'Cancel search',
  'Server suchen': 'Find server',
  'Keine SSH-Server gefunden. Gib Hostname oder IP-Adresse manuell ein.':
      'No SSH servers found. Enter a hostname or IP address manually.',
  'Serveradresse und SSH-Port wurden übernommen.':
      'Server address and SSH port were applied.',
  'Übernommen': 'Applied',
  'Übernehmen': 'Apply',
  'Die Datei enthält keinen unterstützten privaten SSH-Schlüssel.':
      'The file does not contain a supported private SSH key.',
  'Gib ein SSH-Passwort ein.': 'Enter an SSH password.',
  'Wähle einen privaten SSH-Schlüssel aus.': 'Choose a private SSH key.',
  'Prüfe und speichere zuerst die SSH-Verbindung.':
      'First check and save the SSH connection.',
  'Netzwerk': 'Network',
  'Server': 'Server',
  'Zugang': 'Access',
  'Prüfung': 'Check',
  'Starten': 'Start',
  'Verbindung löschen?': 'Delete connection?',
  'Das Serverprofil, das gespeicherte SSH-Passwort oder der importierte Schlüssel sowie der bestätigte SSH-Fingerprint werden von diesem Gerät gelöscht. Dieser Schritt kann nicht rückgängig gemacht werden. Das redigierte Diagnoseprotokoll bleibt erhalten.':
      'The server profile, saved SSH password or imported key, and confirmed SSH fingerprint will be deleted from this device. This cannot be undone. The redacted diagnostic log remains.',
  'Löschen': 'Delete',
  'Aktivität': 'Activity',
  'Lokale Ereignisse ohne sensible Verbindungsdaten.':
      'Local events without sensitive connection data.',
  'Redigierte Diagnose exportieren': 'Export redacted diagnostics',
  'Noch keine Ereignisse vorhanden. Aktionen und Prüfungen erscheinen hier automatisch.':
      'No events yet. Actions and checks appear here automatically.',
  'Diagnose exportiert.': 'Diagnostics exported.',
  'Noch keine Aktivität': 'No activity yet',
  'Letzte Aktion erfolgreich': 'Latest action succeeded',
  'Letzte Aktion braucht Aufmerksamkeit': 'Latest action needs attention',
  'Starte eine Prüfung oder richte deinen Server ein.':
      'Start a check or set up your server.',
  'Erfolgreich': 'Successful',
  'Nicht erfolgreich': 'Unsuccessful',
  'Ereignisdetails': 'Event details',
  'Die Aktion wurde erfolgreich abgeschlossen.':
      'The action completed successfully.',
  'Die Aktion konnte nicht abgeschlossen werden.':
      'The action could not be completed.',
  'Zeitpunkt': 'Time',
  'Dauer': 'Duration',
  'Ergebnis': 'Result',
  'Technische Kennung': 'Technical identifier',
  'Heute': 'Today',
  'Gestern': 'Yesterday',
  'App-Status geladen': 'App status loaded',
  'Serverstatus geprüft': 'Server status checked',
  'Startsignal gesendet': 'Wake signal sent',
  'SSH-Verbindung geprüft': 'SSH connection checked',
  'Herunterfahren angefordert': 'Shutdown requested',
  'Server vorbereitet': 'Server prepared',
  'Servergy-Helper entfernt': 'Servergy helper removed',
  'Einstellungen gespeichert': 'Settings saved',
  'Server im Netzwerk gesucht': 'Searched for server on network',
  'Darstellung konnte nicht gespeichert werden.':
      'The appearance preference could not be saved.',
  'Die Sprache konnte nicht gespeichert werden.':
      'The language could not be saved.',
  'Die MAC-Adresse ist ungültig.': 'The MAC address is invalid.',
  'Die MAC-Adresse muss eine eindeutige Unicast-Adresse sein.':
      'The MAC address must be a unique unicast address.',
  'Bitte gib nur einen Hostnamen oder eine IP-Adresse ein.':
      'Enter only a hostname or an IP address.',
  'Die Broadcast-Adresse muss eine IPv4-Adresse sein.':
      'The broadcast address must be an IPv4 address.',
  'Der SSH-Benutzername kann nicht sicher in eine sudoers-Regel übernommen werden. Richte den Helper mit der manuellen Anleitung ein.':
      'The SSH username cannot safely be used in a sudoers rule. Set up the helper with the manual instructions.',
  'Das SSH-Passwort darf nicht leer sein.':
      'The SSH password must not be empty.',
  'Wake-on-LAN ist noch nicht eingerichtet. Ergänze MAC-Adresse und Broadcast-Adresse in den Einstellungen.':
      'Wake-on-LAN is not configured yet. Add the MAC and broadcast address in Settings.',
  'Die Broadcast-Adresse ist ungültig. Prüfe die Einstellungen.':
      'The broadcast address is invalid. Check Settings.',
  'Wake-on-LAN konnte nicht gesendet werden. Prüfe das Heimnetz.':
      'Wake-on-LAN could not be sent. Check the home network.',
  'Das lokale Netzwerk ist nicht erreichbar. Verbinde dich mit Heimnetz oder VPN.':
      'The local network is unreachable. Connect to the home network or VPN.',
  'Das aktuelle lokale IPv4-Netz konnte nicht bestimmt werden. Gib Hostname oder IP-Adresse manuell ein.':
      'The current local IPv4 network could not be determined. Enter a hostname or IP address manually.',
  'Die Netzmaske ist ungültig. Gib Hostname oder IP-Adresse manuell ein.':
      'The network mask is invalid. Enter a hostname or IP address manually.',
  'Der SSH-Test lieferte keine erwartete Antwort.':
      'The SSH test did not return the expected response.',
  'Die integrierten Servergy-Dateien konnten nicht geprüft werden. Aktualisiere die App und versuche es erneut.':
      'The bundled Servergy files could not be verified. Update the app and try again.',
  'Gib das sudo-Passwort für die einmalige Servervorbereitung ein.':
      'Enter the sudo password for the one-time server preparation.',
  'Die Servervorbereitung konnte nicht vollständig abgeschlossen werden. Prüfe die manuelle Anleitung auf dem Server.':
      'Server preparation could not be completed. Check the manual instructions on the server.',
  'Gib das sudo-Passwort ein, um die Servergy-Ausschaltdateien zu entfernen.':
      'Enter the sudo password to remove the Servergy shutdown files.',
  'Die Servergy-Ausschaltdateien konnten nicht vollständig entfernt werden. Prüfe die manuelle Anleitung auf dem Server.':
      'The Servergy shutdown files could not be fully removed. Check the manual instructions on the server.',
  'Der aktive Netzwerkadapter des Servers konnte nicht bestimmt werden. Richte Wake-on-LAN manuell ein.':
      'The server’s active network adapter could not be determined. Set up Wake-on-LAN manually.',
  'Die installierten Servergy-Dateien konnten nicht sicher geprüft werden. Nutze die manuelle Anleitung auf dem Server.':
      'The installed Servergy files could not be verified safely. Use the manual instructions on the server.',
  'Die Servervorbereitung wurde abgebrochen. Prüfe bei Bedarf die manuelle Anleitung.':
      'Server preparation was cancelled. Check the manual instructions if needed.',
  'Der SSH-Schlüssel konnte nicht gelesen werden. Prüfe Format oder Passphrase.':
      'The SSH key could not be read. Check its format or passphrase.',
  'Der SSH-Host-Key hat sich geändert. Verbindung blockiert; vergleiche den Fingerprint.':
      'The SSH host key changed. Connection blocked; compare the fingerprint.',
  'Das sudo-Passwort wurde abgelehnt. Es wurde nicht gespeichert. Prüfe es und versuche die Servervorbereitung erneut.':
      'The sudo password was rejected and was not saved. Check it and try server preparation again.',
  'Der SSH-Benutzer darf keine Administratorbefehle ausführen. Führe die manuelle Servergy-Anleitung an der Serverkonsole aus.':
      'The SSH user may not run administrator commands. Follow the manual Servergy guide at the server console.',
  'Der Server verlangt für sudo ein Terminal. Passe die sudo-Konfiguration manuell an und richte den Helper anschließend ein.':
      'The server requires a terminal for sudo. Adjust the sudo configuration manually, then set up the helper.',
  'Auf dem Server fehlt sudo. Installiere sudo über die Serverkonsole und nutze danach die manuelle Anleitung.':
      'sudo is missing on the server. Install it at the server console, then use the manual guide.',
  'Dieses System verwendet kein unterstütztes systemd. Richte das Herunterfahren manuell ein.':
      'This system does not use supported systemd. Set up shutdown manually.',
  'Die Servervorbereitung wurde vom Server abgelehnt. Prüfe sudo, systemd und die manuelle Anleitung.':
      'Server preparation was rejected by the server. Check sudo, systemd, and the manual guide.',
  'Das sudo-Passwort wurde abgelehnt. Die Servergy-Dateien wurden nicht entfernt.':
      'The sudo password was rejected. The Servergy files were not removed.',
  'Der SSH-Benutzer darf die Servergy-Dateien nicht entfernen. Nutze einen separat berechtigten Administratorzugang oder die Anleitung im README.':
      'The SSH user may not remove the Servergy files. Use a separately authorized administrator account or the guide in the README.',
  'Der Server verlangt für sudo ein Terminal. Entferne die Dateien über einen Administratorzugang an der Serverkonsole.':
      'The server requires a terminal for sudo. Remove the files through an administrator account at the server console.',
  'Die Servergy-Dateien konnten nicht vollständig entfernt werden. Prüfe die Anleitung im README.':
      'The Servergy files could not be fully removed. Check the guide in the README.',
  'Auf dem Server fehlt sudo. Installiere sudo und richte danach den Servergy-Helper ein.':
      'sudo is missing on the server. Install it, then set up the Servergy helper.',
  'Der SSH-Benutzer darf den Servergy-Helper nicht ausführen. Prüfe die sudoers-Regel in der Serveranleitung.':
      'The SSH user may not run the Servergy helper. Check the sudoers rule in the server guide.',
  'Die sudoers-Regel verlangt noch ein Passwort. Erlaube ausschließlich den Servergy-Helper mit NOPASSWD.':
      'The sudoers rule still requires a password. Allow only the Servergy helper with NOPASSWD.',
  'Der Servergy-Ausschalt-Helper fehlt auf dem Server. Richte ihn nach der Serveranleitung ein.':
      'The Servergy shutdown helper is missing on the server. Set it up using the server guide.',
  'Der Server verwendete keinen gültigen Servergy-Ausschalt-Helper. Prüfe dessen Ausgabe und die systemd-Unit.':
      'The server did not use a valid Servergy shutdown helper. Check its output and the systemd unit.',
  'Der Server hat den Ausschaltbefehl nicht bestätigt. Prüfe den Servergy-Helper, die systemd-Unit und die sudoers-Regel.':
      'The server did not confirm the shutdown command. Check the Servergy helper, systemd unit, and sudoers rule.',
  'Der Server lieferte keine verwertbaren Wake-on-LAN-Daten. Richte Wake-on-LAN manuell ein.':
      'The server did not return usable Wake-on-LAN data. Set up Wake-on-LAN manually.',
  'Der Server lieferte einen ungültigen Netzwerkadapter. Richte Wake-on-LAN manuell ein.':
      'The server returned an invalid network adapter. Set up Wake-on-LAN manually.',
  'Der Server lieferte keine gültige Wake-on-LAN-MAC-Adresse. Richte Wake-on-LAN manuell ein.':
      'The server did not return a valid Wake-on-LAN MAC address. Set up Wake-on-LAN manually.',
  'Die Freigabe für das lokale Netzwerk wurde nicht erteilt. Du kannst den Server weiterhin manuell eintragen.':
      'Local network permission was not granted. You can still enter the server manually.',
  'Lege ein SSH-Passwort fest, damit die App die Verbindung später herstellen kann.':
      'Set an SSH password so the app can connect later.',
  'Einstellungen gespeichert. Teste jetzt die SSH-Verbindung.':
      'Settings saved. Test the SSH connection now.',
  'Die Verbindung wurde von diesem Gerät gelöscht.':
      'The connection was deleted from this device.',
  'Die Verbindung konnte nicht vollständig gelöscht werden. Versuche es erneut.':
      'The connection could not be fully deleted. Try again.',
  'Die Freigabe für das lokale Netzwerk fehlt. Wake-on-LAN kann weiterhin manuell eingerichtet werden.':
      'Local network permission is missing. Wake-on-LAN can still be configured manually.',
  'Die SSH-Anmeldung wurde abgelehnt. Prüfe Schlüssel oder Passwort.':
      'SSH authentication was rejected. Check the key or password.',
  'Der Server ist über SSH nicht erreichbar. Wake-on-LAN kann manuell eingerichtet werden.':
      'The server cannot be reached over SSH. Wake-on-LAN can be configured manually.',
  'Die Wake-on-LAN-Daten konnten nicht erkannt werden. Richte sie manuell ein.':
      'Wake-on-LAN data could not be detected. Set it up manually.',
  'Die SSH-Anmeldung wurde abgelehnt. Prüfe Benutzername und Passwort oder Schlüssel.':
      'SSH authentication was rejected. Check the username, password, or key.',
  'Die SSH-Verbindung konnte nicht geprüft werden. Prüfe Heimnetz, VPN und Serveradresse.':
      'The SSH connection could not be checked. Check the home network, VPN, and server address.',
  'Aktion abgebrochen. Aktualisiere den Status bei Bedarf.':
      'Action cancelled. Refresh the status if needed.',
  'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und versuche den Start erneut.':
      'Local network permission is missing. Allow it in Android and try starting again.',
  'Der Server läuft bereits.': 'The server is already running.',
  'Startsignal gesendet – warte auf den Server …':
      'Wake signal sent — waiting for the server …',
  'Server ist erreichbar.': 'Server is reachable.',
  'Startsignal gesendet, aber der Server ist nach 90 Sekunden nicht erreichbar. Prüfe Broadcast-Adresse und WOL.':
      'Wake signal was sent, but the server is not reachable after 90 seconds. Check the broadcast address and WOL.',
  'Die Freigabe für das lokale Netzwerk fehlt. Erlaube sie in Android und versuche die Servervorbereitung erneut.':
      'Local network permission is missing. Allow it in Android and try server preparation again.',
  'Die SSH-Anmeldung wurde abgelehnt. Die Servervorbereitung wurde nicht gestartet.':
      'SSH authentication was rejected. Server preparation was not started.',
  'Der Server ist über SSH nicht erreichbar. Verbinde dich mit Heimnetz oder VPN und versuche es erneut.':
      'The server cannot be reached over SSH. Connect to the home network or VPN and try again.',
  'Die Servervorbereitung ist fehlgeschlagen. Öffne die manuelle Serveranleitung für Details.':
      'Server preparation failed. Open the manual server guide for details.',
  'Der Server ist weiterhin erreichbar. Prüfe ihn manuell und die sudoers-Regel.':
      'The server is still reachable. Check it manually and review the sudoers rule.',
  'Der gespeicherte SSH-Schlüssel fehlt. Importiere ihn erneut in den Einstellungen.':
      'The saved SSH key is missing. Import it again in Settings.',
  'Das gespeicherte SSH-Passwort fehlt. Hinterlege es erneut in den Einstellungen.':
      'The saved SSH password is missing. Add it again in Settings.',
  'Gib ein SSH-Passwort ein, damit die Verbindung geprüft werden kann.':
      'Enter an SSH password so the connection can be checked.',
};
