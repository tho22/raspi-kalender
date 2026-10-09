#!/bin/bash -e
#
# Fetches the vendored upstream pi-gen (a git submodule pinned to a known-
# good tag, not a fork) and applies our small build fixes on top of it,
# then links in our own build config and custom stage. Run this once after
# cloning, and again after any `git submodule update` that moves the pinned
# commit.

cd "$(dirname "$0")"

git submodule update --init pi-gen

cd pi-gen

if git apply --check ../patches/pi-gen-fixes.patch 2>/dev/null; then
	git apply ../patches/pi-gen-fixes.patch
	echo "Applied patches/pi-gen-fixes.patch"
else
	echo "patches/pi-gen-fixes.patch already applied, skipping"
fi

ln -sfn ../stage-kalender stage-kalender
ln -sfn ../config config

echo "Setup complete. Build with: cd pi-gen && ./build-docker.sh"
