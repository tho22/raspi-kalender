# Kalender-Pi einrichten (Anleitung für Windows)

Diese Anleitung zeigt Schritt für Schritt, wie du eine SD-Karte vorbereitest,
damit dein Raspberry Pi nach dem Einschalten automatisch deinen
Google-Kalender anzeigt. Du musst dafür nichts programmieren oder bauen –
das fertige Image kommt direkt von GitHub.

## Was du brauchst

- Einen Windows-PC mit SD-Kartenleser (eingebaut oder als USB-Adapter)
- Eine SD-Karte (mindestens 8 GB)
- Den Namen (SSID) und das Passwort deines WLANs
- Einen Raspberry Pi (Zero 2 W, 4 oder 5) mit Netzteil

## Schritt 1: Raspberry Pi Imager installieren

Lade den **[Raspberry Pi Imager](https://www.raspberrypi.com/software/)**
herunter (offizielle Software von Raspberry Pi, kostenlos) und installiere
ihn wie gewohnt.

## Schritt 2: Image-Datei herunterladen

Gehe zur **[Releases-Seite des Projekts](https://github.com/tho22/raspi-kalender/releases)**
und lade bei der neuesten Version die Datei mit der Endung `.img.xz`
herunter (z. B. `kalender-build-2026-10-11-5.img.xz`). Sie landet normalerweise
im Ordner „Downloads". Die Datei muss **nicht** entpackt werden.

## Schritt 3: Imager öffnen und Image auswählen

1. Raspberry Pi Imager starten.
2. Unter **„Operating System"** ganz nach unten scrollen und **„Use custom"**
   auswählen.
3. Die gerade heruntergeladene `.img.xz`-Datei auswählen.

## Schritt 4: SD-Karte auswählen

Unter **„Storage"** die SD-Karte auswählen, die beschrieben werden soll.

> ⚠️ **Achtung:** Der gesamte Inhalt der Karte wird dabei gelöscht. Prüfe
> vor dem nächsten Schritt sicherheitshalber, ob wirklich die richtige Karte
> ausgewählt ist (Größe vergleichen).

## Schritt 5: Einstellungen öffnen

Noch **nicht** auf „Next" klicken! Stattdessen unten rechts auf das
**Zahnrad-Symbol** klicken. Dort werden WLAN und ein paar weitere Dinge
eingestellt, bevor die Karte beschrieben wird.

## Schritt 6: WLAN einrichten

Im Reiter **„General"** den Haken bei **„Configure wireless LAN"** setzen
und ausfüllen:

| Feld                 | Wert           |
|----------------------|----------------|
| SSID                 | Name deines WLANs |
| Password             | Dein WLAN-Passwort |
| Wireless LAN country | `DE`           |

## Schritt 7: Zeitzone und Tastatur prüfen

Im selben Reiter unter **„Set locale settings"**:

- Zeitzone: `Europe/Berlin`
- Tastaturlayout: `de`

(Diese Werte sind im Image schon richtig voreingestellt – schadet aber
nicht, sie hier nochmal zu bestätigen.)

## Schritt 8: Eigenen Benutzernamen festlegen (empfohlen)

Ebenfalls im Reiter **„General"**, unter **„Set username and password"**:
Trage hier einen eigenen Benutzernamen und ein eigenes, sicheres Passwort
ein. Das ersetzt den voreingestellten Zugang (`kalender` / `changeme`).

> Lässt du dieses Feld leer, bleibt der voreingestellte Nutzername
> `kalender` mit dem Passwort `changeme` aktiv – das sollte dann möglichst
> bald geändert werden (siehe Hinweis ganz unten).

## Schritt 9 (optional): Fernzugriff per SSH einrichten

Falls du später vom PC aus auf den Pi zugreifen möchtest (z. B. um etwas
nachzuschauen), kannst du das im Reiter **„Services"** aktivieren:

- Haken bei **„Enable SSH"** setzen
- **„Use password authentication"** auswählen (einfachste Variante – nutzt
  den Benutzernamen/Passwort aus Schritt 8)

Das ist komplett optional und wird für den normalen Betrieb des
Kalender-Bildschirms nicht gebraucht.

## Schritt 10: Speichern und schreiben

Unten auf **„Save"** klicken, dann **„Next"** bzw. **„Write"**, um das
Schreiben zu starten. Die Sicherheitsabfrage bestätigen – der Karteninhalt
wird jetzt überschrieben. Je nach SD-Karte dauert das einige Minuten.

## Schritt 11: Karte einsetzen und starten

1. SD-Karte aus dem PC entnehmen und in den Raspberry Pi stecken.
2. Den Pi mit Strom versorgen.

Der erste Start dauert etwas länger als gewohnt (die WLAN- und sonstigen
Einstellungen werden im Hintergrund übernommen, danach startet das Gerät
einmal automatisch neu). Anschließend zeigt der Bildschirm direkt den
Kalender im Vollbild.

### Erster Login bei Google

Beim allerersten Start ist noch kein Google-Konto hinterlegt. Auf den
kleinen blauen Punkt oben rechts auf dem Bildschirm tippen, um die
Bildschirmtastatur einzublenden, und dich mit dem Google-Konto anmelden,
dem der Kalender freigegeben wurde. Das muss nur **einmal** gemacht werden.

### Zugriff per SSH (falls in Schritt 9 eingerichtet)

Die IP-Adresse des Pi findest du z. B. in der Geräteliste deines
WLAN-Routers (oft über eine Web-Adresse wie `192.168.0.1` oder
`192.168.1.1` erreichbar – steht meist auf der Rückseite des Routers).

Danach auf dem Windows-PC eine Eingabeaufforderung oder PowerShell öffnen
und eintippen (eigenen Benutzernamen und IP-Adresse einsetzen):

```
ssh kalender@<ip-adresse>
```

---

**Sicherheitshinweis:** Falls in Schritt 8 kein eigener Benutzername
vergeben wurde, ist das voreingestellte Passwort (`changeme`) öffentlich
bekannt (es steht in diesem Projekt auf GitHub). Für den Einsatz im eigenen
Zuhause meist unkritisch, da nur Geräte im eigenen WLAN zugreifen können –
für mehr Sicherheit aber trotzdem bald ein eigenes Passwort setzen (z. B.
nachträglich per SSH mit dem Befehl `passwd`).
