#!/bin/bash -e
#
# Fetches the vendored upstream pi-gen (a git submodule pinned to a known-
# good tag, not a fork) and applies our small build fixes on top of it,
# then copies in our own build config and custom stage. Run this once after
# cloning, and again after any `git submodule update` that moves the pinned
# commit, or after editing stage-kalender/ or config.
#
# config and stage-kalender are COPIED, not symlinked: build-docker.sh's
# Docker build context is the pi-gen/ directory alone, so a symlink
# pointing outside it (e.g. stage-kalender -> ../stage-kalender) gets
# copied into the image as a dangling link that resolves to a path that
# doesn't exist in the container, breaking the build.

cd "$(dirname "$0")"

git submodule update --init pi-gen

cd pi-gen

if git apply --check ../patches/pi-gen-fixes.patch 2>/dev/null; then
	git apply ../patches/pi-gen-fixes.patch
	echo "Applied patches/pi-gen-fixes.patch"
else
	echo "patches/pi-gen-fixes.patch already applied, skipping"
fi

rm -rf stage-kalender config
cp -a ../stage-kalender stage-kalender
cp -a ../config config

echo "Setup complete. Build with: cd pi-gen && ./build-docker.sh"
