# kalender-claude

pi-gen-Setup, das den Zustand der vorhandenen SD-Karte (`/dev/mmcblk1p2`,
Hostname `kalender`) reproduzierbar nachbaut: ein Raspberry Pi OS Lite
(Bookworm), das nach dem Boot automatisch einen Chromium-Kiosk mit dem
freigegebenen Google-Kalender anzeigt – inklusive Bildschirmtastatur für den
einmaligen Google-Login per Touch.

## Was auf der Original-SD-Karte gefunden wurde

- Raspbian/Raspberry Pi OS Lite, Bookworm (armhf), ursprünglich selbst mit
  pi-gen gebaut (stage2-Export laut `/etc/rpi-issue`).
- Benutzer `kalender`, Autologin auf tty1 (`agetty --autologin kalender`,
  systemd-Drop-in unter `/etc/systemd/system/getty@tty1.service.d/`).
- `~/.bash_profile` startete auf tty1 `startx -- -nocursor`, mit schlankem
  X11 + Openbox (`xserver-xorg x11-xserver-utils xinit openbox xdotool`) statt
  einem Display-Manager.
- `/etc/xdg/openbox/autostart` startete
  `chromium-browser --kiosk --noerrdialogs --disable-infobars $KIOSK_URL`.
- `KIOSK_URL=https://calendar.google.com/calendar/u/0/r` – das ist die
  **eingeloggte** Kalenderansicht, kein öffentliches Embed. Die Chromium-
  Session (Cookies/Login) liegt im Profil unter `~/.config/chromium/Default`,
  wurde also einmalig manuell im Browser mit einem Google-Konto angemeldet,
  dem der Kalender freigegeben wurde.
- Eine Chrome-Web-Store-Erweiterung für eine Bildschirmtastatur war
  installiert (Details und warum sie hier nicht wiederverwendet wird: siehe
  unten).
- Locale `en_GB.UTF-8`, Zeitzone `Europe/Berlin`, Tastatur `de`.
- WLAN-Regulatory-Domain `DE` (`cfg80211.ieee80211_regdom=DE`), Zugangsdaten
  liegen als NetworkManager-Connection-Profil vor (nicht ausgelesen/übernommen
  – siehe unten).
- SSH ist aktiviert.

## Architektur dieser Nachbildung: Wayland statt X11/Openbox

Die Original-Karte nutzt X11 + Openbox. Diese Nachbildung **nicht** – nach
ausführlichem Test (siehe Abschnitt "Bildschirmtastatur" weiter unten) stellte
sich heraus, dass sich unter X11 auf diesem Gerät zwar Chromium, aber keine
zweite Overlay-Anwendung (eine Bildschirmtastatur) zuverlässig sichtbar
darstellen ließ – ein Grafik-Stack-Problem, das mit einem Wechsel auf Wayland
gelöst werden konnte. Der aktuelle Stack:

- **wayfire** (Wayland-Compositor) statt X11 + Openbox
- **Chromium** mit `--ozone-platform=wayland` statt X11-Ozone-Backend
- **wvkbd** (Version 0.18, aus Quellcode gebaut – siehe unten) als
  Bildschirmtastatur, standardmäßig versteckt
- **kbd-toggle**, ein selbst geschriebener, ca. 250 Zeilen kleiner
  Wayland-Layer-Shell-Client (`stage-kalender/00-kiosk/files/kbd-toggle.c`):
  ein kleiner, dauerhaft sichtbarer Button oben rechts, der per Touch/Klick
  `wvkbd-mobintl` per `SIGRTMIN`-Signal ein-/ausblendet

## Struktur

- `pi-gen/` – **Git-Submodule** auf das originale
  https://github.com/RPi-Distro/pi-gen (kein Fork), gepinnt auf Tag
  `2025-05-13-raspios-bookworm-armhf` (letzter von Raspberry Pi gepflegter
  Bookworm-armhf-Stand; `master` zielt inzwischen auf Trixie und hat
  inkompatible Paketlisten). Der Submodule-Checkout bleibt unverändert;
  unsere Anpassungen daran liegen als Patch separat vor (siehe unten).
- `patches/pi-gen-fixes.patch` – kleine Korrekturen an pi-gen selbst (kaputter
  Standard-Apt-Mirror in `stage0`, zu knappe Image-Größen-Marge in
  `export-image`, Deaktivierung des doppelten Stock-„lite“-Image-Exports aus
  `stage2`). Wird von `setup.sh` auf den Submodule-Checkout angewendet,
  niemals direkt committet.
- `config` – Build-Konfiguration (Locale, Zeitzone, Tastatur, Nutzer,
  `KIOSK_URL`, Stage-Liste); wird von `setup.sh` nach `pi-gen/config`
  kopiert (nicht verlinkt: `pi-gen/` ist der Docker-Build-Kontext, ein nach
  außen zeigender Symlink würde im Container ins Leere laufen)
- `stage-kalender/` – eigene Stage, die nach `stage2` (fertiges Lite-Image)
  angehängt wird; wird von `setup.sh` nach `pi-gen/stage-kalender` kopiert:
  - `00-kiosk/00-packages-nr` – `wayfire`, `chromium-browser`, plus Build-Deps
    für `wvkbd`/`kbd-toggle` (`--no-install-recommends`)
  - `00-kiosk/00-run.sh` – Autologin-Drop-ins, `.bash_profile`, Wayfire-Config,
    modellabhängige `config.txt`-Overlays, baut `wvkbd`/`kbd-toggle` aus
    vendortem Quellcode
  - `00-kiosk/files/wayfire.ini` – Compositor-Autostart (Tastatur, Toggle-
    Button, Chromium-Kiosk)
  - `00-kiosk/files/bash_profile` – startet `wayfire` statt `startx`
  - `00-kiosk/files/kalender-configure-display.sh` – Boot-Zeit-Hardware-
    Erkennung für Wayland-Display-Quirks (Pi 5)
  - `00-kiosk/files/kbd-toggle.c` – der Toggle-Button-Client
  - `00-kiosk/files/wvkbd-src/` – vendorter `wvkbd`-Quellcode (Tag v0.18)
  - `00-kiosk/files/51kalender-unattended-upgrades` – automatische
    Updates (wöchentlich, nächtlicher Reboot um 04:00 Uhr)
  - `EXPORT_IMAGE` – exportiert diese Stage als `.img` (das Stock-„lite“-
    Image aus `stage2` wird per Patch nicht mehr zusätzlich exportiert)

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
`stage-kalender` hinein. Nach jedem `git submodule update` (z.B. nach einem
Pull, der den gepinnten Commit ändert) **und nach jeder Änderung an
`stage-kalender/` oder `config`** muss `setup.sh` erneut laufen.

Ergebnis landet in `pi-gen/deploy/` (ein `.img`, keine zwei mehr). Der Build
läuft privilegiert in Docker und dauert i.d.R. 30–90+ Minuten (debootstrap,
Paketinstallation, `wvkbd`/`kbd-toggle`-Kompilierung im chroot per QEMU,
Image-Export).

Zum Aufspielen des fertigen `.img` auf eine SD-Karte samt WLAN/SSH-Ersteinrichtung
über den Raspberry Pi Imager siehe [INSTALL.md](INSTALL.md).

### Build via GitHub Actions

Alternativ lässt sich das Image auch ohne lokalen Docker/QEMU-Aufbau bauen:
Workflow [`.github/workflows/build-image.yml`](.github/workflows/build-image.yml)
im Actions-Tab manuell starten ("Run workflow" – kein automatischer Trigger
bei Push, da ein Durchlauf 45–90+ Minuten dauert). Das Ergebnis landet
`xz`-komprimiert (≈720 MB statt 3,6 GB roh) als Asset an einem neuen
GitHub-Release. Nach jedem erfolgreichen Lauf werden automatisch nur die
`keep_releases` (Workflow-Eingabe, Default 3) neuesten Releases behalten,
ältere werden samt Tag gelöscht – Releases verfallen sonst nicht von
selbst und würden sich sonst unbegrenzt ansammeln.

pi-gens Arbeitsverzeichnis (stage0–stage2/stage-kalender-Rootfs) wird über
`actions/cache` zwischen Läufen wiederverwendet (via `PIGEN_DOCKER_OPTS`
auf ein Cache-Verzeichnis statt eines anonymen Docker-Volumes gemountet),
analog zum lokalen `CONTINUE=1`. Dadurch entfällt bei unveränderten frühen
Stages das erneute `debootstrap` und Herunterladen der Basispakete – nur
tatsächlich geänderte Stages laufen neu (pi-gens eigene Erkennung
entscheidet das, nicht der Cache selbst). `export-image` wird nie
gecacht, da es ohnehin bei jedem Lauf frisch entsteht.

## Vor dem Build unbedingt anpassen

- **`FIRST_USER_PASS` in `config`** – steht aktuell auf dem Platzhalter
  `changeme`. Da `DISABLE_FIRST_BOOT_USER_RENAME=1` gesetzt ist (damit der
  Nutzername fest `kalender` bleibt), muss hier ein echtes Passwort rein,
  sonst ist das Gerät mit Standard-Zugangsdaten und aktiviertem SSH
  erreichbar.
- **WLAN**: bewusst nicht in `config`/Image gebacken, da das Original-Profil
  den WLAN-Schlüssel im Klartext enthält. Entweder nach dem ersten Boot per
  SSH/Konsole einrichten, oder über `nmcli`/`wpa_supplicant`-Snippet in einer
  eigenen Stage ergänzen – dann aber nicht ins Git-Repo committen.

## Bekanntes Problem: kein Bild auf Geräten mit <1GB RAM (z.B. Pi Zero 2 W)

`chromium-browser` (der Wrapper-Skript, nicht der Browser selbst) zeigt auf
Geräten mit weniger als 1 GB RAM einen Bestätigungsdialog
("It is not recommended to run Chromium on devices with less than 1GB of
RAM... Launch anyway / Cancel") und **wartet auf eine Antwort**, bevor
Chromium überhaupt startet. Behoben durch `--no-memcheck` in
`stage-kalender/00-kiosk/files/wayfire.ini` (bereits im Repo enthalten).

Auf einem Pi Zero 2 W (512 MB RAM) ist Chromium generell knapp bemessen
(im Test ~230–300 MB belegt, Swap wird genutzt). Läuft stabil, aber ohne
große Reserven.

## Mehrere Pi-Modelle mit derselben Karte: automatische Hardware-Erkennung

Dieselbe SD-Karte wurde im Lauf der Entwicklung auf einem Pi Zero 2 W, zwei
unterschiedlichen Pi 5 und (mit einem älteren, separaten Build) getestet –
jedes Modell braucht andere Display-Einstellungen:

- **Pi Zero 2 W** + ein bestimmtes generisches HDMI/LVDS-Panel: braucht
  `dtoverlay=vc4-fkms-v3d` (legacy/fake-KMS) statt des Standards
  `vc4-kms-v3d`. Mit vollem KMS + dem alten X11-Setup blieb der Bildschirm
  schwarz, obwohl Xorg/Chromium nachweislich korrekt liefen (Screenshot per
  SSH zeigte die richtige Seite, HDMI galt als "connected" mit passendem
  EDID) – ein Xorg/Treiber-Kombinationsproblem auf diesem Panel, bestätigt
  durch ein offizielles Raspberry-Pi-OS-Image, das auf demselben Gerät
  problemlos lief (das nutzt allerdings auch bereits Wayland). Mit dem
  aktuellen Wayland/wayfire-Stack läuft es unter `fkms` weiterhin
  einwandfrei; ein Zurückwechseln auf `vc4-kms-v3d` wurde nicht erneut
  getestet, da kein Bedarf bestand.
- **Pi 4**: der raspi-firmware-Standard (`vc4-kms-v3d`) passt unverändert.
- **Pi 5**: unterstützt `vc4-fkms-v3d` gar nicht (komplett andere
  Display-Architektur über den separaten RP1-Chip) – braucht zwingend
  `vc4-kms-v3d`. Zusätzlich hat der Pi 5 **zwei** DRM-Geräte gleichzeitig
  (ein `vc4-drm`-Gerät mit dem tatsächlichen HDMI-Ausgang und ein reines
  `v3d`-GPU-Gerät ohne Display); unter X11 wählte Xorgs Autoerkennung hier
  ohne Hilfe gelegentlich das falsche Gerät ("no primary bus or device
  found"), bestätigt auf zwei verschiedenen Pi-5-Einheiten mit vertauschter
  `card0`/`card1`-Zuordnung.

  ⚠️ **Nicht erneut verifiziert:** Der aktuelle Wayland/wayfire-Stack wurde
  bisher nur auf dem Pi Zero 2 W getestet, nicht auf dem Pi 5. Ob `wlroots`
  (der Compositor-Unterbau von wayfire) dasselbe Zwei-Geräte-Problem hat wie
  Xorg, ist unbekannt. Als Vorsichtsmaßnahme setzt
  `kalender-configure-display.sh` auf dem Pi 5 vorsorglich
  `WLR_DRM_DEVICES` auf das per `vc4-drm`-Treiber ermittelte Gerät (siehe
  unten) – das ist aber unerprobt. Vor einem echten Pi-5-Einsatz mit diesem
  Image: einmal mit angeschlossenem Bildschirm testen.

Damit dieselbe Karte unverändert auf allen drei Modellen bootet, statt bei
jedem Gerätewechsel manuell nachgebessert zu werden:

- **`config.txt`**: Die `dtoverlay`-Zeile wird nicht mehr unbedingt gesetzt,
  sondern über Raspberry Pis eigene Modell-Filter
  (`[pi02]`/`[pi4]`/`[pi5]`/`[all]`) ausgewählt – das wertet die Firmware
  selbst anhand der echten Hardware aus, unabhängig davon, in welchem Gerät
  die Karte gerade steckt.
- **`/usr/local/sbin/kalender-configure-display.sh`**: läuft bei jedem Boot
  (aus `.bash_profile`, vor `wayfire`, via passwortlosem `sudo` – siehe
  `/etc/sudoers.d/kalender-display`, exakt auf dieses eine Skript beschränkt)
  und schreibt bei Bedarf `export WLR_DRM_DEVICES=...` nach
  `/etc/kalender-display-env` (von `.bash_profile` vor dem Start von
  `wayfire` eingelesen). Das richtige `cardN` wird nicht hartkodiert, sondern
  bei jedem Boot dynamisch über `/sys/class/drm/card*/device/uevent`
  (Treiber `vc4-drm`) ermittelt.

**Touch nach Hotplug:** Wurde das USB-Kabel des Touch-Digitizers erst
angesteckt, *nachdem* der Pi schon lief, wird das Gerät zwar von udev/libinput
erkannt, liefert aber keine tatsächlichen Events (bestätigt bis auf Kernel-/
`evtest`-Ebene unter X11 – ein allgemeines Linux-/udev-Verhalten, nicht
X11-spezifisch, vermutlich auch unter Wayland relevant). Ein sauberer Reboot
bei bereits angeschlossenem Kabel behebt das zuverlässig.

## Touchscreen-Panels: separates USB-Kabel nicht vergessen

Bei HDMI/LVDS-Ansteuerplatinen mit Touch (wie hier) läuft der Touch-Digitizer
als eigenes USB-HID-Gerät, unabhängig von HDMI und Stromversorgung. Auf dem
**Pi Zero 2 W** gibt es zwei optisch identische Micro-USB-Buchsen – nur die
mit `USB` beschriftete (näher am HDMI-Port) ist der Daten-/OTG-Port, die
andere (`PWR IN`) liefert nur Strom. Steckt das Touch-Kabel in der falschen
Buchse oder fehlt es ganz, taucht in `lsusb`/`/proc/bus/input/devices`
schlicht kein Gerät auf. Sobald es an der richtigen Buchse steckt, erkennt
udev/libinput es automatisch (kein zusätzliches Setup in der pi-gen-Stage
nötig).

## Google-Kalender-Login

`KIOSK_URL` zeigt auf die eingeloggte Ansicht `calendar.google.com/calendar/u/0/r`,
exakt wie auf der Original-SD-Karte. Das setzt eine bestehende Chromium-Session
voraus. Ein automatisierter Google-Login lässt sich (2FA, Google-
Automatisierungsschutz) nicht in den Image-Build integrieren. Nach dem ersten
Boot des neuen Images daher **einmalig manuell, direkt per Touch**:

1. Auf den kleinen blauen Button oben rechts tippen – blendet die
   Bildschirmtastatur ein.
2. Mit dem Google-Konto anmelden, dem der Kalender freigegeben ist.
3. Auf den Button tippen, um die Tastatur wieder auszublenden (optional).

Die Session bleibt danach im Chromium-Profil auf der SD-Karte erhalten, genau
wie beim Vorbild – der Login wird nie wieder gebraucht.

Alternative, falls der Kalender in den Google-Freigabeeinstellungen auf
"öffentlich verfügbar machen" gestellt werden kann: `KIOSK_URL` in
`config` auf
`https://calendar.google.com/calendar/embed?src=<calendar-id>&ctz=Europe%2FBerlin`
ändern – dann ist kein Login nötig und das Image ist vollständig
unbeaufsichtigt lauffähig.

## Bildschirmtastatur: wie wir hingekommen sind

Auf der Original-SD-Karte war eine Chrome-Web-Store-Erweiterung installiert
(`gkiknnlmdgcmhmncldcmmnhhdiakielc`, "On Screen Virtual Keyboard", Manifest
V2) – vermutlich einmalig genutzt, um den Google-Login per Touch einzugeben.

**Diese Erweiterung funktioniert mit aktuellem Chromium nicht mehr:**
Chromium hat die Unterstützung für Manifest-V2-Erweiterungen inzwischen
entfernt – auch die offizielle Übergangs-Policy
(`ExtensionManifestV2Availability`) zeigt keine Wirkung mehr, die Erweiterung
erscheint nicht einmal in `chrome://extensions`. Bestätigt an einer älteren,
separaten SD-Karte (Chromium 116 statt 153): dort funktioniert dieselbe
Erweiterung noch einwandfrei – bringt aber nichts für neue Builds, da
`RELEASE=bookworm` ein rollendes Repository ist und ein heutiger Build
ebenso aktuelles (MV2-loses) Chromium zieht.

⚠️ **Zusätzlicher Grund, sie nicht wiederzubeleben:** Diese Erweiterung hat in
ihrer minifizierten `lib/dist/bg.js` (1,7 MB) das **Mellowtel-SDK**
vollständig eingebaut (`mellow.tel`-Endpunkte, AWS-Lambda-/S3-URLs) – ein
bekanntes Monetarisierungs-SDK, das die Bandbreite/den Browser der Nutzer als
Proxy für Web-Requests Dritter mitnutzt. Auf einem Gerät mit einer echten
Google-Session sollte man das nicht laufen lassen, unabhängig vom
MV2-Problem.

**Getestete Alternativen unter X11 (verworfen):**

- **Chromiums eingebaute virtuelle Tastatur** – im Binary vorhanden, aber
  laut Extension-API-Schema explizit auf `"platforms":["chromeos"]`
  beschränkt. Braucht die ChromeOS-Ash-Shell: funktioniert unter Linux/X11
  *und* Linux/Wayland grundsätzlich nicht.
- **matchbox-keyboard** – rendert, aber ohne Auto-Show (dauerhaft sichtbar)
  und wurde vom Chromium-Kiosk-Vollbild optisch verdeckt.
- **onboard mit Auto-Show (AT-SPI)** – die Fokus-Erkennung funktionierte
  nachweislich korrekt (Chromium meldet Textfelder sauber als
  `role=entry, editable=True` über AT-SPI), aber das GTK3-Fenster von onboard
  **rendert in dieser Umgebung nie sichtbare Pixel** – weder mit noch ohne
  Docking, weder mit noch ohne Compositor (`xcompmgr`), weder im echten
  Vollbild-Kiosk noch im maximierten Fenstermodus. Ein einfaches `xmessage`-
  Testfenster wurde dagegen einwandfrei sichtbar dargestellt – das Problem
  war spezifisch auf onboards (sehr altes, ca. 2016er) GTK3/Cairo-Rendering
  in Kombination mit dem `fkms`/`AccelMethod none`-Setup beschränkt.
- Ein Zwischenschritt, Chromium von `--kiosk` auf `--app=$KIOSK_URL`
  umzustellen (kein echtes EWMH-Vollbild, stattdessen maximiertes randloses
  Fenster), behob das Tastatur-Problem ebenfalls nicht – brachte aber eine
  echte Verschlechterung: Chromiums App-Modus zeigt bei jedem Domain-Wechsel
  (z.B. beim Login) automatisch eine Navigationsleiste (Phishing-Schutz).

**Die Lösung: Wayland statt X11.** Unter `wayfire` (Wayland-Compositor)
rendert eine zweite Overlay-Anwendung zuverlässig, über das
`wlr-layer-shell`-Protokoll:

- **wvkbd** (C, minimal) rendert korrekt, wo `onboard`/`squeekboard`
  scheiterten – bestätigt per isoliertem Test (`xclock` als Vergleich zeigte
  dasselbe X11-Rendering-Problem; unter Wayland trat es nicht auf).
- Die Raspbian-Paketversion von `wvkbd` (0.12) verlangt vom Compositor nur
  `wl_compositor`-Version 3 und nutzt bereits standardmäßig die
  `overlay`-Layer-Shell-Ebene – **aber** sie zeigte den `top`-statt-`overlay`-
  Fehler in einer Zwischenversion. Der aktuelle Git-`HEAD` von `wvkbd`
  verlangt hingegen `wl_compositor`-Version 6, die weder `wayfire` (v5) noch
  `sway` (v4) bieten. **Tag `v0.18`** ist der Sweet Spot: `overlay` bereits
  Standard, nur `wl_compositor`-Version 3 nötig – deshalb wird dieser Tag
  vendort und im chroot gebaut, nicht die Paketversion oder `HEAD`.
- **squeekboard** (GTK4-basiert) wurde ebenfalls getestet und zeigte
  überhaupt kein sichtbares Rendering – vermutlich dasselbe
  GPU/Mesa/GTK-Problem wie `onboard`, nur unter Wayland statt X11.
- Automatisches Ein-/Ausblenden bei Fokus auf ein Eingabefeld ist mit
  Chromium nicht zuverlässig möglich (`text-input-v3`-Unterstützung zu
  unvollständig) – deshalb der manuelle Toggle-Button `kbd-toggle` statt
  Auto-Show.
- Für den Toggle-Button gibt es keine fertigen, für Raspbian/armhf
  gepackten Tools (`waybar`, `yambar` u.ä. nicht verfügbar); Wayfires
  eigenes Touch-Gesten-Binding ist zwar vorhanden, aber die genaue Syntax für
  generische Kommandos ist nicht dokumentiert. Daher: ein eigener, sehr
  kleiner (`kbd-toggle.c`) Wayland-Client mit derselben Layer-Shell-Technik,
  die bei `wvkbd` bereits nachweislich funktioniert.

## Sicherheitshinweis: Standardpasswort war während der gesamten Fehlersuche aktiv

Im Zuge der Diagnose musste mehrfach per SSH auf Testgeräte zugegriffen
werden; dabei bestätigt: Das Passwort für `kalender` steht auf den
Testgeräten noch auf dem Platzhalter `changeme` aus `config`
(`FIRST_USER_PASS`). SSH ist aktiv. **Das unbedingt vor produktivem Einsatz
ändern** (`passwd` auf dem Gerät, oder `FIRST_USER_PASS` in `config`
vor dem nächsten Image-Build).
