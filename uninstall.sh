#!/usr/bin/env bash
set -euo pipefail

APP_ID="io.github.marleys439.ksharepreview"

echo "==> Removendo KSharePreview (${APP_ID})..."

if command -v pipx >/dev/null 2>&1; then
  pipx uninstall ksharepreview >/dev/null 2>&1 || true
fi
if python3 -m pip --version >/dev/null 2>&1; then
  python3 -m pip uninstall -y ksharepreview >/dev/null 2>&1 || true
fi

rm -rf "${HOME}/.local/share/ksharepreview" \
       "${HOME}/.local/bin/ksharepreview" \
       "${HOME}/.local/share/applications/${APP_ID}.desktop" \
       "${HOME}/.local/share/icons/hicolor/scalable/apps/${APP_ID}.svg" \
       "${HOME}/.local/share/metainfo/${APP_ID}.metainfo.xml"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "${HOME}/.local/share/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" || true
command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental || true

echo "==> KSharePreview removido."
