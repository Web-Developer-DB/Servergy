#!/usr/bin/env sh
# Removes only the files installed by install-linux.sh for the current user.
set -eu

DATA_HOME=${XDG_DATA_HOME:-"$HOME/.local/share"}
APP_DIR="$DATA_HOME/servergy"
APPLICATIONS_DIR="$DATA_HOME/applications"
ICONS_DIR="$DATA_HOME/icons/hicolor"

case "$HOME" in
  '' | /) echo "Der Deinstaller darf nicht als root ausgeführt werden." >&2; exit 1 ;;
esac

case "$DATA_HOME" in
  "$HOME"/*) ;;
  *) echo "Unsicheres Datenverzeichnis: $DATA_HOME" >&2; exit 1 ;;
esac

rm -rf "$APP_DIR"
rm -f "$APPLICATIONS_DIR/dev.servergy.servergy.desktop"
find "$ICONS_DIR" -type f -name 'dev.servergy.servergy.png' -delete 2>/dev/null || true
find "$ICONS_DIR" -type f -name 'dev.servergy.servergy.svg' -delete 2>/dev/null || true

command -v update-desktop-database >/dev/null 2>&1 && \
  update-desktop-database "$APPLICATIONS_DIR" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && \
  gtk-update-icon-cache -f "$DATA_HOME/icons/hicolor" || true

echo "Servergy wurde für diesen Benutzer deinstalliert."
