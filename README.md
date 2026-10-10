# kalender-claude

Ein Raspberry Pi OS Lite (Bookworm), das nach dem Boot automatisch einen
Chromium-Kiosk mit einem freigegebenen Google-Kalender zeigt – inklusive
Bildschirmtastatur für den einmaligen Google-Login per Touch, und so gebaut,
dass dieselbe SD-Karte unverändert auf einem Pi Zero 2 W, Pi 4 oder Pi 5
bootet.

## Basiert auf pi-gen

Das Image wird mit **[pi-gen](https://github.com/RPi-Distro/pi-gen)** gebaut
– dem offiziellen Raspberry-Pi-Tool, mit dem auch die Standard-Raspberry-Pi-OS-
Images entstehen. Dieses Repo bringt nur eine zusätzliche, eigene Stage
(`stage-kalender/`) sowie eine Build-Konfiguration (`config`) mit; pi-gen
selbst liegt unverändert als Git-Submodule vor (gepinnt auf einen bestimmten
Tag, **kein Fork**) – siehe [Repo-Struktur](#repo-struktur) weiter unten für
Details.

## Architektur

**Wayland (wayfire) statt X11/Openbox.** Auf der Zielhardware (generische
HDMI/LVDS-Touch-Ansteuerplatinen) ließ sich unter X11 zwar Chromium
zuverlässig darstellen, aber keine zweite Overlay-Anwendung (eine
Bildschirmtastatur) – ein GTK3/Cairo-Rendering-Problem in Kombination mit dem
dort nötigen `fkms`-Grafiktreiber, bestätigt über mehrere unabhängige
Tastatur-Implementierungen (onboard, squeekboard) hinweg. Unter Wayland tritt
das Problem nicht auf. Der aktuelle Stack:

- **wayfire** als Compositor
- **Chromium** mit `--ozone-platform=wayland`
- **wvkbd**, Tag `v0.18` aus Quellcode gebaut (`stage-kalender/00-kiosk/files/wvkbd-src/`) –
  bewusst nicht die Raspbian-Paketversion (0.12, veraltet) oder der aktuelle
  Git-`HEAD` (verlangt `wl_compositor` Version 6, die weder `wayfire` noch
  `sway` bieten). v0.18 ist der Sweet Spot: nur Version 3 nötig, `overlay`-
  Layer-Shell-Ebene bereits Standard.
- **kbd-toggle** (`stage-kalender/00-kiosk/files/kbd-toggle.c`), ein
  selbstgeschriebener, ca. 250 Zeilen kleiner Wayland-Layer-Shell-Client: ein
  dauerhaft sichtbarer Button oben rechts, der `wvkbd` per `SIGRTMIN`-Signal
  ein-/ausblendet. Nötig, weil automatisches Ein-/Ausblenden bei Fokus auf ein
  Eingabefeld mit Chromium nicht zuverlässig funktioniert
  (`text-input-v3`-Unterstützung zu unvollständig) und es für Wayfire keine
  fertigen, für armhf gepackten Toggle-Tools gibt.

## Mehrere Pi-Modelle, eine SD-Karte

Pi Zero 2 W, Pi 4 und Pi 5 brauchen unterschiedliche Display-Overlays:

- **Pi Zero 2 W** (mit den hier verwendeten generischen HDMI/LVDS-Panels):
  `dtoverlay=vc4-fkms-v3d` statt des Standards `vc4-kms-v3d`.
- **Pi 4**: der raspi-firmware-Standard (`vc4-kms-v3d`) passt unverändert.
- **Pi 5**: unterstützt `fkms` gar nicht (eigene Display-Architektur über den
  RP1-Chip) und exponiert zusätzlich **zwei** DRM-Geräte gleichzeitig (ein
  `vc4-drm`-Gerät mit dem tatsächlichen Ausgang, ein reines `v3d`-GPU-Gerät
  ohne Display) – die Zuordnung `card0`/`card1` ist nicht modellübergreifend
  stabil.

Damit dieselbe Karte unverändert auf allen drei Modellen bootet:

- **`config.txt`**: die `dtoverlay`-Zeile wird über Raspberry Pis eigene
  Modell-Filter (`[pi02]`/`[pi4]`/`[pi5]`/`[all]`) ausgewählt – das wertet die
  Firmware selbst anhand der echten Hardware aus.
- **`/usr/local/sbin/kalender-configure-display.sh`**: läuft bei jedem Boot
  (aus `.bash_profile`, vor `wayfire`, via passwortlosem `sudo` – siehe
  `/etc/sudoers.d/kalender-display`, exakt auf dieses eine Skript beschränkt)
  und ermittelt auf dem Pi 5 dynamisch über
  `/sys/class/drm/card*/device/uevent` das `vc4-drm`-Gerät, statt eine
  Kartennummer hart zu kodieren.

  ⚠️ **Nicht verifiziert:** dieser Stack wurde bisher nur auf dem Pi Zero 2 W
  real getestet, nicht auf dem Pi 5. Die Pi-5-Geräteerkennung ist eine
  Vorsichtsmaßnahme, aber unerprobt – vor einem echten Pi-5-Einsatz einmal mit
  angeschlossenem Bildschirm testen.

**Touch-Hinweis:** Auf dem Pi Zero 2 W gibt es zwei optisch identische
Micro-USB-Buchsen; nur die mit `USB` beschriftete (näher am HDMI-Port) ist der
Daten-/OTG-Port für den Touch-Digitizer, die andere liefert nur Strom. Wird
das Touch-Kabel erst nachträglich (während der Pi schon läuft) angesteckt,
erkennt udev das Gerät zwar, liefert aber keine Events – ein sauberer Reboot
bei bereits angeschlossenem Kabel behebt das zuverlässig.

## Repo-Struktur

- `pi-gen/` – **Git-Submodule** auf das originale
  https://github.com/RPi-Distro/pi-gen (kein Fork), gepinnt auf Tag
  `2025-05-13-raspios-bookworm-armhf` (letzter von Raspberry Pi gepflegter
  Bookworm-armhf-Stand; `master` zielt inzwischen auf Trixie). Der
  Submodule-Checkout bleibt unverändert; Anpassungen daran liegen als Patch
  separat vor.
- `patches/pi-gen-fixes.patch` – Korrekturen an pi-gen selbst: kaputter
  Standard-Apt-Mirror in `stage0`, zu knappe Image-Größen-Marge in
  `export-image` (reicht sonst nicht für das abschließende Chromium-Upgrade),
  Deaktivierung des doppelten Stock-„lite“-Image-Exports aus `stage2`. Wird
  von `setup.sh` auf den Submodule-Checkout angewendet, nie direkt committet.
- `config` – Build-Konfiguration (Locale, Zeitzone, Tastatur, Nutzer,
  `KIOSK_URL`, Stage-Liste); wird von `setup.sh` nach `pi-gen/config`
  **kopiert** (nicht verlinkt: `pi-gen/` ist der Docker-Build-Kontext, ein
  nach außen zeigender Symlink würde im Container ins Leere laufen).
- `stage-kalender/` – eigene pi-gen-Stage, die nach `stage2` (fertiges
  Lite-Image) angehängt wird; wird von `setup.sh` nach `pi-gen/stage-kalender`
  kopiert:
  - `00-kiosk/00-packages-nr` – `wayfire`, `chromium-browser`, Build-Deps für
    `wvkbd`/`kbd-toggle`
  - `00-kiosk/00-run.sh` – Autologin, `.bash_profile`, Wayfire-Config,
    modellabhängige `config.txt`-Overlays, kompiliert `wvkbd`/`kbd-toggle`
  - `00-kiosk/files/wayfire.ini` – Compositor-Autostart (Tastatur,
    Toggle-Button, Chromium-Kiosk)
  - `00-kiosk/files/kalender-autologin-getty` – löst den tatsächlichen Nutzer
    (UID 1000) zur Boot-Zeit dynamisch auf, statt einen Namen fest
    einzubrennen (siehe nächster Abschnitt)
  - `00-kiosk/files/kalender-configure-display.sh` – Hardware-Erkennung für
    die Display-Overlays (siehe oben)
  - `00-kiosk/files/kbd-toggle.c`, `00-kiosk/files/wvkbd-src/` – Tastatur und
    Toggle-Button (siehe „Architektur")
  - `00-kiosk/files/51kalender-unattended-upgrades` – automatische Updates,
    wöchentlich, mit nächtlichem Reboot um 04:00 Uhr (Raspbian hat keine
    separate Security-Quelle wie Debian, daher werden alle Updates aus den
    konfigurierten Paketquellen eingespielt, nicht nur ein „Security"-Subset)
  - `EXPORT_IMAGE` – exportiert diese Stage als `.img`

## Setup & Build

```
git clone --recurse-submodules <repo-url>
cd kalender-claude
./setup.sh
cd pi-gen
./build-docker.sh
```

`setup.sh` holt den pi-gen-Submodule (falls noch nicht geschehen), wendet
`patches/pi-gen-fixes.patch` darauf an und kopiert `config` sowie
`stage-kalender` hinein. Nach jedem `git submodule update` **und nach jeder
Änderung an `stage-kalender/` oder `config`** muss `setup.sh` erneut laufen.

Ergebnis landet in `pi-gen/deploy/`. Der Build läuft privilegiert in Docker
und dauert i.d.R. 30–90+ Minuten (debootstrap, Paketinstallation,
`wvkbd`/`kbd-toggle`-Kompilierung im chroot per QEMU, Image-Export).

Zum Aufspielen des fertigen `.img` auf eine SD-Karte samt WLAN/SSH/
Benutzername-Einrichtung über den [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
siehe [INSTALL.md](INSTALL.md).

### Build via GitHub Actions

Alternativ lässt sich das Image auch ohne lokalen Docker/QEMU-Aufbau bauen:
Workflow [`.github/workflows/build-image.yml`](.github/workflows/build-image.yml)
im Actions-Tab manuell starten ("Run workflow" – kein automatischer Trigger
bei Push, da ein Durchlauf 45–90+ Minuten dauert). Das Ergebnis landet
`xz`-komprimiert (≈720 MB statt 3,6 GB roh – der Imager liest `.xz` direkt,
kein Entpacken nötig) als Asset an einem neuen GitHub-Release. Nach jedem
erfolgreichen Lauf werden automatisch nur die `keep_releases`
(Workflow-Eingabe, Default 3) neuesten Releases behalten, ältere werden samt
Tag gelöscht – Releases verfallen sonst nicht von selbst.

pi-gens Arbeitsverzeichnis (stage0–stage2/stage-kalender-Rootfs) wird über
`actions/cache` zwischen Läufen wiederverwendet (via `PIGEN_DOCKER_OPTS` auf
ein Cache-Verzeichnis statt eines anonymen Docker-Volumes gemountet), analog
zum lokalen `CONTINUE=1`. Dadurch entfällt bei unveränderten frühen Stages
das erneute `debootstrap` und Herunterladen der Basispakete – nur
tatsächlich geänderte Stages laufen neu (pi-gens eigene Erkennung entscheidet
das, nicht der Cache selbst). `export-image` wird nie gecacht, da es ohnehin
bei jedem Lauf frisch entsteht.

## Vor dem Build unbedingt anpassen

**`FIRST_USER_PASS` in `config`** steht auf dem Platzhalter `changeme`. Da
`DISABLE_FIRST_BOOT_USER_RENAME=1` gesetzt ist (damit pi-gens eigener
interaktiver Umbenennungs-Dialog nicht mit der Imager-gesteuerten
Umbenennung – siehe unten – kollidiert), muss hier ein echtes Passwort rein,
sonst ist das Gerät mit Standard-Zugangsdaten und aktiviertem SSH
erreichbar.

WLAN, SSH-Key und optional ein anderer Benutzername/Passwort werden bewusst
**nicht** im Image gebacken, sondern beim Flashen über den Raspberry Pi
Imager gesetzt (siehe [INSTALL.md](INSTALL.md)) – damit landen keine
WLAN-Zugangsdaten im Image oder im Git-Repo.

### Benutzername ändern

Der Imager kann den Standardnutzer (`kalender`) beim Flashen umbenennen
(`custom.toml`, verarbeitet von `userconf-pi`, das bereits installiert ist).
Autologin löst dazu den tatsächlichen Nutzer über dessen UID (1000) zur
Boot-Zeit dynamisch auf (`kalender-autologin-getty`), und die Sudoers-Regel
für die Display-Erkennung ist ebenfalls per UID (`#1000`) statt per Name
gebunden – beides bleibt also unabhängig vom gewählten Namen funktionsfähig.
Nur die Home-Verzeichnis-Pfade sind beim Build auf `kalender` gemünzt; das ist
unproblematisch, da `userconf-pi` das Home-Verzeichnis samt Inhalt bei der
Umbenennung mitverschiebt.

## Bekannte Einschränkungen

- **Kein Bild auf Geräten mit <1GB RAM** (z.B. Pi Zero 2 W): Der
  `chromium-browser`-Wrapper zeigt dort sonst einen blockierenden
  Bestätigungsdialog vor dem Start. Behoben durch `--no-memcheck` in
  `wayfire.ini`. Auf einem Pi Zero 2 W (512 MB RAM) ist Chromium generell
  knapp bemessen (~230–300 MB belegt im Betrieb, Swap wird genutzt), läuft
  aber stabil.
- **Pi 5 unverifiziert** (siehe oben).
- **Kein automatisierter Google-Login**: 2FA und Googles
  Automatisierungsschutz lassen sich nicht in den Image-Build integrieren
  (siehe nächster Abschnitt).

## Google-Kalender-Login

`KIOSK_URL` zeigt standardmäßig auf die eingeloggte Ansicht
`calendar.google.com/calendar/u/0/r`, setzt also eine bestehende
Chromium-Session voraus. Nach dem ersten Boot daher **einmalig manuell,
direkt per Touch**:

1. Auf den kleinen blauen Button oben rechts tippen – blendet die
   Bildschirmtastatur ein.
2. Mit dem Google-Konto anmelden, dem der Kalender freigegeben ist.
3. Auf den Button tippen, um die Tastatur wieder auszublenden (optional).

Die Session bleibt danach im Chromium-Profil auf der SD-Karte erhalten – der
Login wird nie wieder gebraucht.

Alternative, falls der Kalender in den Google-Freigabeeinstellungen auf
„öffentlich verfügbar machen" gestellt werden kann: `KIOSK_URL` in `config`
auf `https://calendar.google.com/calendar/embed?src=<calendar-id>&ctz=Europe%2FBerlin`
ändern – dann ist kein Login nötig und das Image läuft vollständig
unbeaufsichtigt.

Die Chromium-Oberfläche selbst bleibt dabei Englisch (kein deutsches
Sprachpaket installiert); für die **Seiteninhalte** sorgt
`--accept-lang=de-DE,de` in `wayfire.ini` dafür, dass Google eine deutsche
Kalenderansicht ausliefert.

## Sicherheitshinweis

Das Standardpasswort des Nutzers `kalender` (`changeme` in `config`) und SSH
sind aktiv. **Vor produktivem Einsatz unbedingt ändern** – entweder
`FIRST_USER_PASS` in `config` vor dem nächsten Build, oder direkt beim
Flashen über den Imager (siehe [INSTALL.md](INSTALL.md)), oder nachträglich
per `passwd` auf dem Gerät.
