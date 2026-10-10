# SD-Karte mit dem Raspberry Pi Imager einrichten

So spielst du ein fertig gebautes Kalender-Image (aus `pi-gen/deploy/`) auf
eine SD-Karte und richtest WLAN sowie SSH-Zugang direkt über die
Konfiguration im Raspberry Pi Imager ein — ohne Monitor, Tastatur oder
manuelle Einrichtung am Gerät selbst.

## Voraussetzungen

- Ein Rechner mit installiertem **Raspberry Pi Imager** (offizielle Software
  von Raspberry Pi) und einem SD-Kartenleser
- Eine SD-Karte (mind. 8 GB)
- Die Image-Datei des Kalender-Builds aus `pi-gen/deploy/` (z. B.
  `2026-10-08-kalender.img`)
- SSID und Passwort des WLANs, mit dem sich der Pi verbinden soll
- Optional: der eigene SSH-Public-Key, für späteren SSH-Zugriff auf das Gerät

## 1. Imager öffnen und eigenes Image wählen

Raspberry Pi Imager starten und unter **„Operating System"** ganz unten
**„Use custom"** (bzw. „Eigenes Image verwenden") auswählen. Dort die
`.img`-Datei des Kalender-Builds auswählen — **nicht** ein offizielles
Raspberry Pi OS Image, da dieses Image bereits den fertigen Kiosk-Aufbau
enthält.

## 2. Speicherziel (SD-Karte) wählen

Unter **„Storage"** die richtige SD-Karte auswählen.

> **Achtung:** Der gesamte Inhalt der gewählten Karte wird überschrieben. Im
> Zweifel Kartengröße und Modellbezeichnung im Imager mit der physischen
> Karte abgleichen, bevor es weitergeht.

## 3. Betriebssystem anpassen (OS Customisation) öffnen

Noch **nicht** auf „Next"/„Schreiben" klicken. Stattdessen über das
Zahnrad-Symbol unten rechts — oder mit <kbd>Strg</kbd>+<kbd>Umschalt</kbd>+<kbd>X</kbd>
— die erweiterten Einstellungen öffnen. Dort werden WLAN und SSH
eingerichtet, **bevor** die Karte beschrieben wird.

## 4. Benutzername und Passwort ändern (optional)

Im Reiter **„General"** unter „Set username and password" lassen sich
Login-Name und Passwort des Standardnutzers (im Image: `kalender` /
`changeme`) direkt beim Flashen ändern — ein eigener Image-Build ist dafür
nicht nötig. Autologin und die Kiosk-Rechte sind so eingerichtet, dass sie
den tatsächlichen Nutzer zur Boot-Zeit ermitteln, nicht den Namen `kalender`
fest annehmen.

## 5. WLAN konfigurieren

Im Reiter **„General"** (bzw. Allgemein) den Haken bei „Configure wireless
LAN" setzen und ausfüllen:

| Feld                   | Wert              |
|------------------------|-------------------|
| SSID                   | Name des WLANs    |
| Password               | WLAN-Passwort     |
| Wireless LAN country   | `DE`              |

## 6. SSH aktivieren (optional, aber empfohlen)

Im Reiter **„Services"** SSH aktivieren:

- **„Allow public-key authentication only"** wählen
- Den eigenen Public Key einfügen (Inhalt der `.pub`-Datei, z. B.
  `~/.ssh/id_ecdsa.pub`)

Passwort-Login für SSH bewusst deaktiviert lassen, solange am Gerät noch das
Standardpasswort des Benutzers `kalender` gesetzt ist (siehe
Sicherheitshinweis in [README.md](README.md)).

## 7. Gebietsschema prüfen

Im Reiter **„General"** unter „Set locale settings":

- Zeitzone: `Europe/Berlin`
- Tastaturlayout: `de`

Diese Werte stecken zwar schon im Image selbst (siehe `config`), eine
Übereinstimmung schadet aber nicht.

## 8. Speichern, schreiben, bestätigen

Einstellungen mit „Save" übernehmen, dann den Schreibvorgang starten und die
Sicherheitsabfrage (Karteninhalt wird gelöscht) bestätigen. Je nach
Kartengeschwindigkeit dauert das Schreiben einige Minuten.

## 9. Karte einsetzen und ersten Boot abwarten

Karte in den Raspberry Pi stecken und Strom anschließen. Der erste Start
dauert länger als gewohnt: Im Hintergrund werden WLAN, SSH-Schlüssel und
weitere Einstellungen aus der Konfiguration übernommen, danach startet das
Gerät automatisch neu und zeigt anschließend direkt den Kalender im
Kiosk-Modus.

> **Erreichbarkeit testen:** Sobald das WLAN verbunden ist, lässt sich das
> Gerät per `ssh kalender@<ip-adresse>` erreichen (IP-Adresse z. B. über die
> Router-Oberfläche ermitteln).

---

Das Standardpasswort des Benutzers `kalender` ist bekannt (`changeme`) — am
Gerät sollte es nach der Ersteinrichtung geändert werden, sofern SSH-
Passwort-Login je aktiviert wird.
