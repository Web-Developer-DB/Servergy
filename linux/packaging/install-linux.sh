#!/usr/bin/env sh
# Installs one Servergy bundle for the current user only. No system path
# and no administrator privilege is modified.
set -eu

BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
APP_DIR="$DATA_HOME/servergy"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor"
DESKTOP_FILE="$APPLICATIONS_DIR/dev.servergy.servergy.desktop"

case "$HOME" in
  '' | /) echo "Der Installer darf nicht als root ausgeführt werden." >&2; exit 1 ;;
esac

case "$DATA_HOME" in
  "$HOME"/*) ;;
  *) echo "Unsicheres Datenverzeichnis: $DATA_HOME" >&2; exit 1 ;;
esac

if [ ! -x "$BUNDLE_DIR/servergy" ] || [ ! -d "$BUNDLE_DIR/data" ] || [ ! -d "$BUNDLE_DIR/lib" ] || [ ! -x "$BUNDLE_DIR/uninstall-linux.sh" ]; then
  echo "Dieses Verzeichnis enthält kein vollständiges Servergy-Bundle." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR" "$APPLICATIONS_DIR"
cp -R "$BUNDLE_DIR/servergy" "$BUNDLE_DIR/data" "$BUNDLE_DIR/lib" "$APP_DIR/"
cp "$BUNDLE_DIR/uninstall-linux.sh" "$APP_DIR/uninstall-linux.sh"

for source in "$BUNDLE_DIR"/share/icons/hicolor/*/apps/dev.servergy.servergy.*; do
  [ -f "$source" ] || continue
  relative=${source#"$BUNDLE_DIR/share/icons/hicolor/"}
  target="$ICONS_DIR/$relative"
  mkdir -p "$(dirname -- "$target")"
  cp "$source" "$target"
done

ESCAPED_APP_DIR=$(printf '%s' "$APP_DIR" | sed 's/[&|\\]/\\&/g')
sed "s|@APP_DIR@|$ESCAPED_APP_DIR|g" \
  "$BUNDLE_DIR/share/applications/dev.servergy.servergy.desktop.in" \
  > "$DESKTOP_FILE"

command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "$APPLICATIONS_DIR" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  gtk-update-icon-cache -f "$DATA_HOME/icons/hicolor" || true

echo "Servergy wurde für diesen Benutzer installiert."
echo "Starte Servergy über das Anwendungsmenü oder: $APP_DIR/servergy"
echo "Zum Entfernen: $APP_DIR/uninstall-linux.sh"
