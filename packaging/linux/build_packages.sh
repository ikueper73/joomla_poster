#!/usr/bin/env bash
# Packs the Linux release build into dist/:
#   joomla-poster-<version>-linux-x64.tar.gz   (any distribution)
#   joomla-poster_<version>_amd64.deb          (Debian, Ubuntu, derivatives)
#   SHA256SUMS
#
# Usage (from anywhere):
#   flutter build linux --release
#   packaging/linux/build_packages.sh [version]
# The version defaults to the one in pubspec.yaml (without the +build part).
set -euo pipefail

cd "$(dirname "$0")/../.."

APP_ID=io.github.ikueper73.joomla_poster
PACKAGE=joomla-poster
BINARY=joomla_poster
MAINTAINER="Ingo Kueper <ik@kueper.cloud>"
HOMEPAGE=https://github.com/ikueper73/joomla_poster

VERSION="${1:-$(sed -n 's/^version: *\([0-9][0-9.]*\).*/\1/p' pubspec.yaml)}"
BUNDLE=build/linux/x64/release/bundle
DIST=dist

if [[ -z "$VERSION" ]]; then
  echo "Could not determine the version." >&2
  exit 1
fi
if [[ ! -x "$BUNDLE/$BINARY" ]]; then
  echo "No release build found. Run: flutter build linux --release" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$DIST"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

# --- tar.gz -----------------------------------------------------------------
tar_dir="$PACKAGE-$VERSION-linux-x64"
cp -r "$BUNDLE" "$staging/$tar_dir"
# Desktop entry and icon, for users who want to add a menu entry themselves.
cp "packaging/linux/$APP_ID.desktop" "packaging/linux/$APP_ID.svg" \
  "$staging/$tar_dir/"
tar -C "$staging" -czf "$DIST/$tar_dir.tar.gz" "$tar_dir"

# --- .deb -------------------------------------------------------------------
root="$staging/deb"
install -d "$root/DEBIAN" "$root/opt/$PACKAGE" "$root/usr/bin" \
  "$root/usr/share/applications" \
  "$root/usr/share/icons/hicolor/scalable/apps"
cp -r "$BUNDLE/." "$root/opt/$PACKAGE/"
chmod -R u=rwX,go=rX "$root/opt/$PACKAGE"
chmod 755 "$root/opt/$PACKAGE/$BINARY"
# Flutter finds its data/ and lib/ next to the real executable, so a
# symlink in /usr/bin works.
ln -s "/opt/$PACKAGE/$BINARY" "$root/usr/bin/$PACKAGE"
install -m 644 "packaging/linux/$APP_ID.desktop" "$root/usr/share/applications/"
install -m 644 "packaging/linux/$APP_ID.svg" \
  "$root/usr/share/icons/hicolor/scalable/apps/"

installed_size="$(du -sk --exclude=DEBIAN "$root" | cut -f1)"
cat > "$root/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: $VERSION
Section: web
Priority: optional
Architecture: amd64
Maintainer: $MAINTAINER
Installed-Size: $installed_size
Depends: libgtk-3-0 | libgtk-3-0t64, libsecret-1-0, zenity | kdialog
Recommends: gnome-keyring | kwalletmanager
Homepage: $HOMEPAGE
Description: Post articles with images to a Joomla 5 site
 Small desktop app that creates articles in one fixed category of a
 Joomla 5 site via the Joomla Web Services API. Supports an intro image,
 inline images (resized, EXIF removed) and Markdown text.
EOF

dpkg-deb --build --root-owner-group "$root" \
  "$DIST/${PACKAGE}_${VERSION}_amd64.deb" >/dev/null

(cd "$DIST" && sha256sum -- * > SHA256SUMS)
echo "Packages in $DIST/:"
ls -l "$DIST"
