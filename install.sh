#!/usr/bin/env bash
set -euo pipefail

APP_ID="io.github.marleys439.ksharepreview"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Instalando KSharePreview (${APP_ID})..."

if ! command -v python3 >/dev/null 2>&1; then
  echo "Erro: python3 não encontrado." >&2
  exit 1
fi

mkdir -p "${HOME}/.local/bin" \
         "${HOME}/.local/share/applications" \
         "${HOME}/.local/share/icons/hicolor/scalable/apps" \
         "${HOME}/.local/share/metainfo"

if command -v pipx >/dev/null 2>&1; then
  pipx install --system-site-packages --force "${SCRIPT_DIR}"
elif python3 -m pip --version >/dev/null 2>&1; then
  python3 -m pip install --user --break-system-packages --upgrade "${SCRIPT_DIR}" \
    || python3 -m pip install --user --upgrade "${SCRIPT_DIR}"
else
  DEST_APP="${HOME}/.local/share/ksharepreview"
  rm -rf "${DEST_APP}"
  mkdir -p "${DEST_APP}"
  cp -r "${SCRIPT_DIR}/ksharepreview" "${SCRIPT_DIR}/data" "${DEST_APP}/"
  cat > "${HOME}/.local/bin/ksharepreview" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="${DEST_APP}\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -m ksharepreview.main "\$@"
EOF
  chmod +x "${HOME}/.local/bin/ksharepreview"
fi

# Garante que Exec no .desktop aponte para o binário instalado mesmo se ~/.local/bin não estiver no PATH do ambiente gráfico
BIN_PATH="${HOME}/.local/bin/ksharepreview"
sed "s|^Exec=ksharepreview|Exec=${BIN_PATH}|" \
  "${SCRIPT_DIR}/data/${APP_ID}.desktop" \
  > "${HOME}/.local/share/applications/${APP_ID}.desktop"

cp "${SCRIPT_DIR}/data/ksharepreview.svg" \
  "${HOME}/.local/share/icons/hicolor/scalable/apps/${APP_ID}.svg"

cp "${SCRIPT_DIR}/data/${APP_ID}.metainfo.xml" \
  "${HOME}/.local/share/metainfo/${APP_ID}.metainfo.xml"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "${HOME}/.local/share/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" || true
command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 --noincremental || true

echo "==> KSharePreview instalado com sucesso!"
echo "    Execute com: ${BIN_PATH} (ou abra pelo menu do KDE Plasma)"
