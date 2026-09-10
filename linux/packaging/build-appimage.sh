#!/usr/bin/env sh
# Creates a portable x86_64 AppImage from the Flutter Linux release bundle.
# Requires appimagetool (https://github.com/AppImage/appimagetool/releases).
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
BUILD_DIR="$PROJECT_DIR/build/linux/x64/release"
BUNDLE_DIR="$BUILD_DIR/bundle"
APPDIR="$BUILD_DIR/Servergy.AppDir"
DIST_DIR="$PROJECT_DIR/dist"
VERSION=$(sed -n 's/^version: \([0-9][0-9A-Za-z.-]*\)+[0-9][0-9]*$/\1/p' "$PROJECT_DIR/pubspec.yaml" | head -n 1)
ARCH=$(uname -m)
APPIMAGETOOL=${APPIMAGETOOL:-appimagetool}

if [ "$ARCH" != "x86_64" ]; then
  echo "Dieses Skript erzeugt derzeit nur ein x86_64-AppImage (gefunden: $ARCH)." >&2
  exit 1
fi

if [ -z "$VERSION" ]; then
  echo "Die App-Version konnte nicht aus pubspec.yaml gelesen werden." >&2
  exit 1
fi

if ! command -v "$APPIMAGETOOL" >/dev/null 2>&1; then
  echo "appimagetool fehlt. Installiere es oder setze APPIMAGETOOL auf seinen Pfad." >&2
  exit 1
fi

cd "$PROJECT_DIR"
flutter build linux --release

rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Flutter resolves data/ and lib/ relative to its executable, so retain this
# directory layout under usr/bin inside the AppImage.
cp -R "$BUNDLE_DIR/servergy" "$BUNDLE_DIR/data" "$BUNDLE_DIR/lib" "$APPDIR/usr/bin/"
cp "$PROJECT_DIR/linux/packaging/icons/hicolor/256x256/apps/dev.servergy.servergy.png" \
  "$APPDIR/usr/share/icons/hicolor/256x256/apps/dev.servergy.servergy.png"

sed \
  -e 's|^Exec=.*|Exec=servergy|' \
  -e 's|^Icon=.*|Icon=dev.servergy.servergy|' \
  "$PROJECT_DIR/linux/packaging/dev.servergy.servergy.desktop.in" \
  > "$APPDIR/usr/share/applications/dev.servergy.servergy.desktop"

ln -s "usr/share/applications/dev.servergy.servergy.desktop" \
  "$APPDIR/dev.servergy.servergy.desktop"
ln -s "usr/share/icons/hicolor/256x256/apps/dev.servergy.servergy.png" \
  "$APPDIR/.DirIcon"
ln -s "usr/share/icons/hicolor/256x256/apps/dev.servergy.servergy.png" \
  "$APPDIR/dev.servergy.servergy.png"

cat > "$APPDIR/AppRun" <<'EOF'
#!/usr/bin/env sh
exec "$APPDIR/usr/bin/servergy" "$@"
EOF
chmod +x "$APPDIR/AppRun"

mkdir -p "$DIST_DIR"
OUTPUT="$DIST_DIR/Servergy-${VERSION}-${ARCH}.AppImage"
rm -f "$OUTPUT"
VERSION="$VERSION" ARCH="$ARCH" "$APPIMAGETOOL" "$APPDIR" "$OUTPUT"

echo "AppImage erstellt: $OUTPUT"
