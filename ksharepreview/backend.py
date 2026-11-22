"""Backend Qt6/QObject assíncrono para o KSharePreview."""

from __future__ import annotations

import json
import threading
from pathlib import Path
from typing import Any

import requests
from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices, QGuiApplication

from .metadata import DEFAULT_USER_AGENT, fetch_link_metadata


class SharePreviewBackend(QObject):
    """Ponte QML para buscar metadados, copiar valores e salvar imagens."""

    loadingChanged = Signal()
    metadataChanged = Signal()
    statusMessage = Signal(str, bool)  # msg, is_error
    _fetchDone = Signal(bool, object, str)  # ok, data_dict, err_msg

    def __init__(self, initial_url: str = "", parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._loading = False
        self._has_data = False
        self._metadata: dict[str, Any] = {}
        self._history: list[str] = []
        self._initial_url = initial_url
        self._fetchDone.connect(self._on_fetch_done)

    @Property(bool, notify=loadingChanged)
    def loading(self) -> bool:
        return self._loading

    @Property(bool, notify=metadataChanged)
    def hasData(self) -> bool:
        return self._has_data

    @Property("QVariantMap", notify=metadataChanged)
    def metadata(self) -> dict[str, Any]:
        return self._metadata

    @Property("QStringList", notify=metadataChanged)
    def recentUrls(self) -> list[str]:
        return self._history

    @Property(str, constant=True)
    def initialUrl(self) -> str:
        return self._initial_url

    @Slot(str)
    def fetchUrl(self, raw_url: str) -> None:
        url = (raw_url or "").strip()
        if not url:
            self.statusMessage.emit("Informe uma URL para analisar.", True)
            return
        if self._loading:
            return

        self._loading = True
        self.loadingChanged.emit()

        def _worker() -> None:
            try:
                meta = fetch_link_metadata(url)
                self._fetchDone.emit(True, meta.to_dict(), "")
            except Exception as exc:
                self._fetchDone.emit(False, {}, str(exc))

        threading.Thread(target=_worker, daemon=True).start()

    @Slot(bool, object, str)
    def _on_fetch_done(self, ok: bool, data: Any, err_msg: str) -> None:
        self._loading = False
        self.loadingChanged.emit()
        if ok and isinstance(data, dict):
            self._metadata = data
            self._has_data = True
            final_u = str(data.get("final_url") or "")
            if final_u:
                self._history = [final_u] + [u for u in self._history if u != final_u][:7]
            self.metadataChanged.emit()
            self.statusMessage.emit(f"Metadados carregados ({len(data.get('tags', []))} tags).", False)
        else:
            self.statusMessage.emit(f"Erro ao buscar URL: {err_msg}", True)

    @Slot(result=str)
    def pasteFromClipboard(self) -> str:
        cb = QGuiApplication.clipboard()
        return (cb.text() if cb else "").strip()

    @Slot(str, str)
    def copyText(self, text: str, label: str = "Texto") -> None:
        cb = QGuiApplication.clipboard()
        if cb:
            cb.setText(text or "")
            self.statusMessage.emit(f"{label} copiado para a área de transferência.", False)

    @Slot()
    def copyMetadataJson(self) -> None:
        if not self._has_data:
            return
        cb = QGuiApplication.clipboard()
        if cb:
            cb.setText(json.dumps(self._metadata, ensure_ascii=False, indent=2))
            self.statusMessage.emit("JSON de metadados copiado.", False)

    @Slot(str)
    def openExternalUrl(self, url_str: str) -> None:
        if url_str:
            QDesktopServices.openUrl(QUrl(url_str))

    @Slot(str, str)
    def saveImageToFile(self, image_url: str, dest_url_or_path: str) -> None:
        if not image_url or not dest_url_or_path:
            return
        dest = Path(QUrl(dest_url_or_path).toLocalFile()) if dest_url_or_path.startswith("file://") else Path(dest_url_or_path)
        try:
            resp = requests.get(
                image_url,
                headers={"User-Agent": DEFAULT_USER_AGENT},
                timeout=15,
            )
            resp.raise_for_status()
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(resp.content)
            self.statusMessage.emit(f"Imagem salva em {dest.name}", False)
        except Exception as exc:
            self.statusMessage.emit(f"Erro ao salvar imagem: {exc}", True)
