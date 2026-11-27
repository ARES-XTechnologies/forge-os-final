#!/bin/bash
# FORGE OS — builds the installer ISO.
# Must run on Arch Linux as root (the GitHub Action does this for you in a container).
#   sudo bash iso/build-iso.sh            -> out/forge-os-<date>-x86_64.iso
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="${WORK:-/tmp/forge-iso-work}"
PROFILE="${PROFILE:-/tmp/forge-iso-profile}"
OUT="${OUT:-$ROOT/out}"

pacman -Sy --noconfirm --needed archiso git

rm -rf "$PROFILE" "$WORK"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# Extra packages for the live installer
cat "$HERE/packages.extra" >> "$PROFILE/packages.x86_64"
sort -u "$PROFILE/packages.x86_64" -o "$PROFILE/packages.x86_64"

# Branding
sed -i 's/^iso_name=.*/iso_name="forge-os"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_label=.*/iso_label="FORGE_OS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_publisher=.*/iso_publisher="Blacksmith Games"/' "$PROFILE/profiledef.sh"
sed -i 's/^iso_application=.*/iso_application="FORGE OS Installer"/' "$PROFILE/profiledef.sh"
# Make the installer executable inside the image
sed -i 's|^file_permissions=(|file_permissions=(\n  ["/usr/local/bin/forge-install"]="0:0:755"|' "$PROFILE/profiledef.sh"
# FORGE system scripts keep their run permission on the USB too (Windows git drops it).
for s in forge-session forge-inner forge-game forge-recovery forge-run forge-helper forge-drives forge-tune forge-fsr forge-system-install; do
	sed -i "s|^file_permissions=(|file_permissions=(\\n  [\"/opt/forge/system/$s\"]=\"0:0:755\"|" "$PROFILE/profiledef.sh"
done

# Live system overlay: auto-start the installer on tty1
cp -r "$HERE/airootfs/." "$PROFILE/airootfs/"
install -Dm755 "$ROOT/installer/forge-install" "$PROFILE/airootfs/usr/local/bin/forge-install"

# FORGE files the installer copies onto the new system
mkdir -p "$PROFILE/airootfs/opt/forge"
cp -r "$ROOT/shell" "$ROOT/system" "$PROFILE/airootfs/opt/forge/"
rm -rf "$PROFILE/airootfs/opt/forge/shell/.godot"
# Tell consoles where to look for FORGE updates (this GitHub repository).
REPO="${GITHUB_REPOSITORY:-${FORGE_REPO:-}}"
printf '{"repo": "%s"}\n' "$REPO" > "$PROFILE/airootfs/opt/forge/channel.json"

# Shorter boot menu timeout + friendly names
for f in "$PROFILE"/syslinux/*.cfg "$PROFILE"/efiboot/loader/entries/*.conf "$PROFILE"/grub/*.cfg; do
	[ -f "$f" ] && sed -i 's/Arch Linux install medium/FORGE OS Installer/g' "$f"
done
[ -f "$PROFILE/efiboot/loader/loader.conf" ] && sed -i 's/^timeout.*/timeout 3/' "$PROFILE/efiboot/loader/loader.conf"

mkdir -p "$OUT"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"
ls -lh "$OUT"
