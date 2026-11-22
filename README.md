# KSharePreview

Visualizador leve e nativo para **KDE Plasma (Qt6 / Kirigami)** inspirado no *Share Preview*.

Informe qualquer URL para inspecionar:
- **Pré-visualização social** (Card Grande para X/Discord/Telegram e Card Compacto para WhatsApp/Slack/LinkedIn)
- **Banners e Imagens** (`og:image`, `twitter:image`, `apple-touch-icon`, `favicon`), com dimensões, cópia de URL e download
- **Metadados completos** (`og:*`, `twitter:*`, `<title>`, `<meta>`, `canonical`), com filtro e exportação em JSON

## Instalação (Linux / KDE Plasma)

Baixe o pacote da última [Release](https://github.com/MarleyS439/ksharepreview/releases) ou clone o repositório e execute o instalador:

```bash
chmod +x install.sh
./install.sh
```

Para remover:

```bash
./uninstall.sh
```

### Dependências
- Python 3.11+
- `PySide6` (Qt6 + Kirigami / `org.kde.desktop`)
- `requests`

## Executar sem instalar

```bash
python3 -m ksharepreview.main
# ou passando uma URL diretamente:
python3 -m ksharepreview.main https://kde.org
```

## Mantenedor
- **MarleyS439** — <https://github.com/MarleyS439>

## Licença
Distribuído sob a licença [MIT](LICENSE).
