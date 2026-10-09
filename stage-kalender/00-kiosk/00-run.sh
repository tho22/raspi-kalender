#!/bin/bash -e

KIOSK_URL="${KIOSK_URL:-https://calendar.google.com/calendar/u/0/r}"

# Console autologin for the kiosk user (equivalent to raspi-config's
# "Console Autologin" boot option, but pinned to FIRST_USER_NAME).
install -v -d "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d"
cat > "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${FIRST_USER_NAME} --noclear %I \$TERM
EOF
cat > "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/noclear.conf" <<EOF
[Service]
TTYVTDisallocate=no
EOF

# Start the Wayland session automatically when the autologin session lands
# on tty1. Kiosk mode uses wayfire (compositor) + wvkbd (on-screen keyboard,
# built from source below) + a tiny custom show/hide button instead of
# X11/Openbox: the X11 stack rendered a second overlay window (a keyboard)
# either not at all or hidden behind Chromium's kiosk fullscreen on this
# hardware, in a way that turned out to be a dead end -- see README for the
# full story. Wayland's layer-shell protocol solves this properly.
install -v -m 644 files/bash_profile "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.bash_profile"

install -v -d "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config"
install -v -m 644 files/wayfire.ini "${ROOTFS_DIR}/home/${FIRST_USER_NAME}/.config/wayfire.ini"

cat > "${ROOTFS_DIR}/etc/kalender-kiosk-env" <<EOF
export KIOSK_URL=${KIOSK_URL}
EOF

# Automatic updates: the unattended-upgrades package itself already enables
# APT::Periodic::Update-Package-Lists/Unattended-Upgrade via its own
# /etc/apt/apt.conf.d/20auto-upgrades default. We only need to add our own
# Origins-Pattern (see file comment -- Raspbian has no separate "security"
# suite, unlike Debian) and enable an automatic nightly reboot, since this
# kiosk has no interactive user to approve one.
install -v -m 644 files/51kalender-unattended-upgrades "${ROOTFS_DIR}/etc/apt/apt.conf.d/51kalender-unattended-upgrades"

on_chroot << EOF
chown ${FIRST_USER_NAME}:${FIRST_USER_NAME} /home/${FIRST_USER_NAME}/.bash_profile
chown -R ${FIRST_USER_NAME}:${FIRST_USER_NAME} /home/${FIRST_USER_NAME}/.config
EOF

# This image is meant to boot unmodified on a Pi Zero 2 W, a Pi 4 or a Pi 5,
# and each needs a different vc4 display overlay:
#
# - Pi Zero 2 W + some generic HDMI/LVDS panels: the full-KMS vc4 overlay
#   combined with Xorg's "modesetting" driver used to keep HDMI sync but
#   never actually show a picture (a problem specific to that old X11 setup,
#   see README); switching to fkms restored a working picture there. It also
#   works fine with the current Wayland/wayfire setup, so it's kept as-is
#   rather than re-testing vc4-kms-v3d now that the original reason for the
#   switch no longer applies.
# - Pi 5: does not support vc4-fkms-v3d at all (different display
#   architecture via the separate RP1 chip) and exposes two DRM devices
#   (vc4-drm for the actual display, v3d for the GPU only) that display
#   servers can mix up.
# - Pi 4: the raspi-firmware default (vc4-kms-v3d) is fine as-is.
#
# The dtoverlay choice is handled here at build time via Raspberry Pi's own
# per-model config.txt filters (evaluated by the firmware from the real
# hardware, so it's correct regardless of which Pi the card ends up in).
sed -i '/^dtoverlay=vc4-kms-v3d$/d' "${ROOTFS_DIR}/boot/firmware/config.txt"
cat >> "${ROOTFS_DIR}/boot/firmware/config.txt" <<'EOF'

[pi02]
dtoverlay=vc4-fkms-v3d

[pi4]
dtoverlay=vc4-kms-v3d

[pi5]
dtoverlay=vc4-kms-v3d

[all]
EOF

install -v -m 755 files/kalender-configure-display.sh "${ROOTFS_DIR}/usr/local/sbin/kalender-configure-display.sh"

install -v -d "${ROOTFS_DIR}/etc/sudoers.d"
cat > "${ROOTFS_DIR}/etc/sudoers.d/kalender-display" <<EOF
# Allow the kiosk user to run the boot-time hardware display detection
# script (and only that script) as root without a password, so it can run
# non-interactively from .bash_profile before wayfire starts.
${FIRST_USER_NAME} ALL=(root) NOPASSWD: /usr/local/sbin/kalender-configure-display.sh
EOF
chmod 440 "${ROOTFS_DIR}/etc/sudoers.d/kalender-display"

# wvkbd 0.18 (vendored source, not the outdated 0.12 in Raspbian's apt
# archive -- see README): defaults to the "overlay" layer-shell layer, so it
# stays visible above Chromium's fullscreen kiosk window, and only needs
# wl_compositor v3 (compatible with both wayfire and sway, unlike current
# upstream wvkbd which needs v6). Started with --hidden; kbd-toggle (a ~150
# line custom Wayland client, source below) is a small always-on-top button
# that sends it SIGRTMIN to show/hide, since Chromium's text-input-v3
# support is too incomplete for reliable focus-based auto-show.
rm -rf "${ROOTFS_DIR}/usr/src/wvkbd"
install -v -d "${ROOTFS_DIR}/usr/src/wvkbd"
cp -a files/wvkbd-src/. "${ROOTFS_DIR}/usr/src/wvkbd/"
# kbd-toggle.c is intentionally NOT copied into the wvkbd source tree yet:
# wvkbd's Makefile collects its own sources via `wildcard *.c` in that same
# directory, so if kbd-toggle.c were already there it gets swept into the
# wvkbd-mobintl build too (and fails, since it relies on our own -Iproto
# flag below rather than wvkbd's own include layout). Copy it in only after
# wvkbd-mobintl has been built.
install -v -m 644 files/kbd-toggle.c "${ROOTFS_DIR}/usr/src/kbd-toggle.c"

on_chroot << 'EOF'
set -e
cd /usr/src/wvkbd
make -j"$(nproc)" wvkbd-mobintl
install -m 755 wvkbd-mobintl /usr/local/bin/wvkbd-mobintl
cp /usr/src/kbd-toggle.c kbd-toggle.c
cc -I. -Iproto -o kbd-toggle kbd-toggle.c \
	proto/wlr-layer-shell-unstable-v1-client-protocol.o \
	proto/xdg-shell-client-protocol.o \
	-lwayland-client
install -m 755 kbd-toggle /usr/local/bin/kbd-toggle
EOF

rm -rf "${ROOTFS_DIR}/usr/src/wvkbd" "${ROOTFS_DIR}/usr/src/kbd-toggle.c"

# Drop the packages only needed to build the above; keep the *-dev libraries
# themselves installed rather than only partially purging them, since apt
# has no record that our manually-built binaries above depend on their
# runtime counterparts and could otherwise remove those too.
on_chroot << 'EOF'
apt-get purge -y --auto-remove git build-essential pkg-config wayland-protocols
EOF
