#!/bin/bash -e
#
# Runs at each boot (via sudo, from .bash_profile, before wayfire) to pick
# hardware-specific wlroots/Wayland display quirks for whichever Raspberry Pi
# model this SD card currently boots on. The dtoverlay choice (fkms vs kms)
# is handled separately, at build time, via Raspberry Pi's own
# [pi02]/[pi4]/[pi5] model filters in config.txt (see README) -- that part is
# evaluated by the firmware from the real hardware, so it's correct
# regardless of which Pi the card ends up in and doesn't need a runtime
# script.

ENV_FILE="/etc/kalender-display-env"
: > "${ENV_FILE}"

MODEL="$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || true)"

case "${MODEL}" in
*"Raspberry Pi 5"*)
	# The Pi 5 exposes two DRM devices (the RP1 display controller and the
	# separate v3d-only 3D GPU). Xorg's autodetection picked the wrong one
	# on this hardware ("no primary bus or device found") and needed to be
	# pinned explicitly; wlroots may or may not have the same problem (not
	# yet confirmed on real Pi 5 hardware -- see README), so pin it the
	# same defensive way just in case: whichever card is actually driven
	# by vc4-drm.
	for card in /sys/class/drm/card*; do
		[ -e "${card}/device/uevent" ] || continue
		if grep -q '^DRIVER=vc4-drm$' "${card}/device/uevent" 2>/dev/null; then
			echo "export WLR_DRM_DEVICES=/dev/dri/$(basename "${card}")" >> "${ENV_FILE}"
			break
		fi
	done
	;;
*)
	;;
esac
