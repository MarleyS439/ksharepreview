"""Ponto de entrada da aplicação KDE Plasma KSharePreview."""

from __future__ import annotations

import os
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuickControls2 import QQuickStyle
from PySide6.QtWidgets import QApplication

from .backend import SharePreviewBackend


def main() -> int:
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
    QQuickStyle.setStyle(os.environ["QT_QUICK_CONTROLS_STYLE"])

    app = QApplication(sys.argv)
    app.setApplicationName("KSharePreview")
    app.setOrganizationName("MarleyS439")
    app.setDesktopFileName("io.github.marleys439.ksharepreview")

    local_icon = Path(__file__).resolve().parent.parent / "data" / "ksharepreview.svg"
    app.setWindowIcon(QIcon.fromTheme("io.github.marleys439.ksharepreview", QIcon(str(local_icon))))

    initial_url = sys.argv[1] if len(sys.argv) > 1 else ""
    backend = SharePreviewBackend(initial_url=initial_url)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)

    qml_file = Path(__file__).resolve().parent / "qml" / "Main.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))
    if not engine.rootObjects():
        return 1

    if initial_url:
        QTimer.singleShot(100, lambda: backend.fetchUrl(initial_url))

    return app.exec()


if __name__ == "__main__":
    raise SystemExit(main())
