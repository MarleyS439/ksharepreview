# Contributing to KSharePreview

Contributions, bug reports, and UI/UX suggestions following KDE Human Interface Guidelines (HIG) and Kirigami are welcome.

## Development Setup

```bash
git clone https://github.com/MarleyS439/ksharepreview.git
cd ksharepreview
python3 -m unittest discover -s tests -v
python3 -m ksharepreview.main
```

## Guidelines

- Keep dependencies minimal (`PySide6`, `requests`).
- Follow KDE Plasma / Breeze / Kirigami visual conventions (`org.kde.desktop` style).
- Include unit tests in `tests/` for metadata parsing changes.
