# Datenschutz und lokale Daten

Servergy arbeitet ohne Cloud, Benutzerkonto, Tracking oder Telemetrie. Die App
stellt ausschließlich lokale Netzwerk- und SSH-Verbindungen zu dem von dir
eingerichteten Homeserver her.

Die optionale Funktion **„Server im Netzwerk suchen“** wird nur nach einem
aktiven Tastendruck ausgeführt. Sie prüft für wenige Sekunden mögliche
SSH-Server im aktuell verbundenen lokalen IPv4-Netz und kann lokale mDNS-
Ankündigungen lesen. Gefundene IP-Adressen, Server-Banner und Gerätenamen
werden weder gespeichert noch übertragen. Auf Android 17 fragt die App dafür
die Systemfreigabe für das lokale Netzwerk an.

Nicht geheime Profildaten (Name, Host, Ports, MAC- und Broadcast-Adresse)
liegen lokal in den App-Einstellungen. Passwörter, importierte private
SSH-Schlüssel und bestätigte SSH-Host-Keys liegen ausschließlich im
Schlüsselspeicher des Betriebssystems. Passphrasen für verschlüsselte Schlüssel
werden nur für die laufende Verbindung verwendet.

Das optionale Diagnoseprotokoll bleibt lokal. Es enthält Zeit, Aktion,
Ergebnis, Fehlercode und Dauer, aber keine Zugangsdaten, Schlüssel,
Benutzernamen, vollständigen Hostadressen oder MAC-Adressen. Ein Export erfolgt
nur nach einer ausdrücklichen Auswahl im Diagnose-Bildschirm.
