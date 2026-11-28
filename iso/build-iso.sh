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

# Build from the same tested package snapshot the OS installs (system/os-snapshot), so the
# installer ISO contains the tested versions too and two builds of one release match.
# A full upgrade (-Syyuu) is used, never a partial one (-Sy), as Arch requires.
SNAP=$(grep -v '^#' "$ROOT/system/os-snapshot" 2>/dev/null | head -n1 | tr -d '[:space:]')
if [ -n "$SNAP" ]; then
	ok=0
	for try in 1 2 3; do
		if curl -fsI --max-time 30 "https://archive.archlinux.org/repos/$SNAP/core/os/x86_64/core.db" >/dev/null; then ok=1; break; fi
		echo "snapshot $SNAP not reachable (try $try/3), waiting..."; sleep 20
	done
	if [ "$ok" = 1 ]; then
		printf 'Server = https://archive.archlinux.org/repos/%s/$repo/os/$arch\n' "$SNAP" > /etc/pacman.d/mirrorlist
		echo "Building from the tested package snapshot $SNAP"
	elif [ "${FORGE_ALLOW_UNPINNED:-0}" = 1 ]; then
		echo "WARNING: snapshot $SNAP unreachable; building from current packages (FORGE_ALLOW_UNPINNED=1)"
	else
		echo "ERROR: the tested package snapshot $SNAP can't be reached (archive.archlinux.org)."
		echo "Run the build again later, or set FORGE_ALLOW_UNPINNED=1 to build from current packages."
		exit 1
	fi
fi
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
pacman -Syyuu --noconfirm --needed archiso git

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
for s in forge-session forge-inner forge-game forge-recovery forge-run forge-helper forge-drives forge-tune forge-fsr forge-system-install forge-display forge-pointer; do
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
