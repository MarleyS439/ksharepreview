import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: root
    title: "KSharePreview — Prévia de Links & Metadados"
    width: 620
    height: 680
    minimumWidth: 500
    minimumHeight: 460

    property int currentTab: 0
    property string tagQuery: ""
    property string pendingSaveImageUrl: ""

    Connections {
        target: backend
        function onStatusMessage(msg, isError) {
            root.showPassiveNotification(msg, isError ? "long" : "short");
        }
    }

    FileDialog {
        id: saveImgDialog
        title: "Salvar Imagem"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "png"
        nameFilters: ["Imagens (*.png *.jpg *.jpeg *.webp *.ico)", "Todos (*)"]
        onAccepted: backend.saveImageToFile(root.pendingSaveImageUrl, selectedFile.toString())
    }

    pageStack.initialPage: Kirigami.Page {
        title: "KSharePreview"
        padding: Kirigami.Units.largeSpacing

        actions: [
            Kirigami.Action {
                text: "Copiar JSON"
                icon.name: "edit-copy"
                enabled: backend.hasData
                onTriggered: backend.copyMetadataJson()
            },
            Kirigami.Action {
                text: "Abrir Link"
                icon.name: "internet-web-browser"
                enabled: backend.hasData
                onTriggered: backend.openExternalUrl(backend.metadata.final_url || "")
            }
        ]

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.mediumSpacing

            // Barra de entrada de URL
            Kirigami.AbstractCard {
                Layout.fillWidth: true
                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Controls.TextField {
                            id: urlField
                            Layout.fillWidth: true
                            text: backend.initialUrl
                            placeholderText: "Cole ou digite uma URL (ex: https://github.com/KDE)"
                            selectByMouse: true
                            onAccepted: backend.fetchUrl(text)
                        }

                        Controls.Button {
                            text: "Colar"
                            icon.name: "edit-paste"
                            onClicked: {
                                var txt = backend.pasteFromClipboard();
                                if (txt.length > 0) {
                                    urlField.text = txt;
                                    backend.fetchUrl(txt);
                                }
                            }
                        }

                        Controls.Button {
                            text: backend.loading ? "Buscando..." : "Analisar"
                            icon.name: "edit-find"
                            highlighted: true
                            enabled: !backend.loading
                            onClicked: backend.fetchUrl(urlField.text)
                        }

                        Controls.BusyIndicator {
                            running: backend.loading
                            visible: backend.loading
                            implicitWidth: 24
                            implicitHeight: 24
                        }
                    }

                    RowLayout {
                        visible: backend.recentUrls.length > 0
                        Layout.fillWidth: true
                        spacing: 6
                        Controls.Label {
                            text: "Recentes:"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.7
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: 6
                            Repeater {
                                model: backend.recentUrls
                                delegate: Controls.ToolButton {
                                    text: modelData.replace(/^https?:\/\//, "").slice(0, 34) + (modelData.length > 42 ? "…" : "")
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    onClicked: {
                                        urlField.text = modelData;
                                        backend.fetchUrl(modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Abas principais
            Controls.TabBar {
                id: mainTabs
                Layout.fillWidth: true
                currentIndex: root.currentTab
                onCurrentIndexChanged: root.currentTab = currentIndex
                Controls.TabButton { text: "Pré-visualização" }
                Controls.TabButton { text: "Banners & Imagens (" + ((backend.metadata.images || []).length) + ")" }
                Controls.TabButton { text: "Metadados (" + ((backend.metadata.tags || []).length) + ")" }
            }

            // Estado vazio
            Kirigami.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !backend.hasData && !backend.loading
                icon.name: "globe"
                text: "Cole um link acima para visualizar"
                explanation: "Veja como o link aparece ao compartilhar (OpenGraph, Twitter/X Cards) e baixe os banners e metadados."
            }

            // Conteúdo
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: backend.hasData
                currentIndex: root.currentTab

                // ABA 0: Pré-visualização (Card Grande + Card Compacto)
                Controls.ScrollView {
                    id: previewScroll
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: previewScroll.availableWidth
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Heading { level: 3; text: "Card Grande (X / Discord / Telegram)" }

                        Kirigami.AbstractCard {
                            Layout.fillWidth: true
                            contentItem: ColumnLayout {
                                spacing: Kirigami.Units.smallSpacing

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 240
                                    radius: 6
                                    clip: true
                                    color: Kirigami.Theme.alternateBackgroundColor

                                    Image {
                                        id: largeBannerImg
                                        anchors.fill: parent
                                        source: backend.metadata.banner_url || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }

                                    Controls.Label {
                                        anchors.centerIn: parent
                                        visible: !backend.metadata.banner_url || largeBannerImg.status === Image.Error
                                        text: "Sem imagem de banner (og:image / twitter:image)"
                                        opacity: 0.65
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    Image {
                                        source: backend.metadata.favicon_url || ""
                                        Layout.preferredWidth: 16
                                        Layout.preferredHeight: 16
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        visible: status === Image.Ready
                                    }
                                    Controls.Label {
                                        text: (backend.metadata.site_name || backend.metadata.domain || "").toUpperCase()
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        font.bold: true
                                        opacity: 0.7
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Controls.Label {
                                        visible: !!(backend.metadata.card_type)
                                        text: backend.metadata.card_type || ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.6
                                    }
                                }

                                Kirigami.Heading {
                                    level: 3
                                    text: backend.metadata.title || ""
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Controls.Label {
                                    visible: !!(backend.metadata.description)
                                    text: backend.metadata.description || ""
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    opacity: 0.85
                                    Layout.fillWidth: true
                                }

                                Controls.Label {
                                    text: backend.metadata.final_url || ""
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    color: Kirigami.Theme.linkColor
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                        }

                        Kirigami.Heading { level: 3; text: "Card Compacto (WhatsApp / Slack / LinkedIn)" }

                        Kirigami.AbstractCard {
                            Layout.fillWidth: true
                            contentItem: RowLayout {
                                spacing: Kirigami.Units.mediumSpacing

                                Rectangle {
                                    visible: !!(backend.metadata.theme_color)
                                    Layout.preferredWidth: 4
                                    Layout.fillHeight: true
                                    radius: 2
                                    color: backend.metadata.theme_color || Kirigami.Theme.highlightColor
                                }

                                Rectangle {
                                    Layout.preferredWidth: 96
                                    Layout.preferredHeight: 96
                                    radius: 6
                                    clip: true
                                    color: Kirigami.Theme.alternateBackgroundColor
                                    Image {
                                        anchors.fill: parent
                                        source: backend.metadata.banner_url || backend.metadata.favicon_url || ""
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Controls.Label {
                                        text: backend.metadata.domain || ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        opacity: 0.7
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Controls.Label {
                                        text: backend.metadata.title || ""
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Controls.Label {
                                        visible: !!(backend.metadata.description)
                                        text: backend.metadata.description || ""
                                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        opacity: 0.8
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }

                // ABA 1: Banners & Imagens
                Controls.ScrollView {
                    id: imagesScroll
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: imagesScroll.availableWidth
                        spacing: Kirigami.Units.mediumSpacing

                        Kirigami.PlaceholderMessage {
                            Layout.fillWidth: true
                            visible: (backend.metadata.images || []).length === 0
                            text: "Nenhuma imagem encontrada nesta URL"
                        }

                        Repeater {
                            model: backend.metadata.images || []
                            delegate: Kirigami.AbstractCard {
                                Layout.fillWidth: true
                                contentItem: RowLayout {
                                    spacing: Kirigami.Units.mediumSpacing

                                    Rectangle {
                                        Layout.preferredWidth: 160
                                        Layout.preferredHeight: 96
                                        radius: 6
                                        clip: true
                                        color: Kirigami.Theme.alternateBackgroundColor
                                        Image {
                                            id: itemImg
                                            anchors.fill: parent
                                            source: modelData.url
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Controls.Label {
                                            text: modelData.label + " (" + modelData.tag + ")"
                                            font.bold: true
                                        }
                                        Controls.Label {
                                            text: itemImg.sourceSize.width > 0 ? (itemImg.sourceSize.width + " × " + itemImg.sourceSize.height + " px") : "Carregando dimensões..."
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            opacity: 0.75
                                        }
                                        Controls.Label {
                                            text: modelData.url
                                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                                            elide: Text.ElideMiddle
                                            opacity: 0.8
                                            Layout.fillWidth: true
                                        }
                                        RowLayout {
                                            spacing: 6
                                            Controls.Button {
                                                text: "Copiar URL"
                                                icon.name: "edit-copy"
                                                flat: true
                                                onClicked: backend.copyText(modelData.url, "URL da imagem")
                                            }
                                            Controls.Button {
                                                text: "Salvar Imagem..."
                                                icon.name: "document-save"
                                                flat: true
                                                onClicked: {
                                                    root.pendingSaveImageUrl = modelData.url;
                                                    saveImgDialog.open();
                                                }
                                            }
                                            Controls.Button {
                                                text: "Abrir"
                                                icon.name: "internet-web-browser"
                                                flat: true
                                                onClicked: backend.openExternalUrl(modelData.url)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ABA 2: Metadados
                ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Controls.TextField {
                        Layout.fillWidth: true
                        placeholderText: "Filtrar metadados (ex: og:, twitter:, title, description)..."
                        onTextChanged: root.tagQuery = text.trim().toLowerCase()
                    }

                    Controls.ScrollView {
                        id: metaScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth

                        ColumnLayout {
                            width: metaScroll.availableWidth
                            spacing: 6

                            Repeater {
                                model: (backend.metadata.tags || []).filter(function(t) {
                                    if (!root.tagQuery) return true;
                                    return (t.key + " " + t.value + " " + t.group).toLowerCase().indexOf(root.tagQuery) >= 0;
                                })
                                delegate: Kirigami.AbstractCard {
                                    Layout.fillWidth: true
                                    contentItem: RowLayout {
                                        spacing: Kirigami.Units.mediumSpacing
                                        ColumnLayout {
                                            Layout.preferredWidth: 190
                                            spacing: 2
                                            Controls.Label {
                                                text: modelData.group
                                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                                color: Kirigami.Theme.highlightColor
                                                font.bold: true
                                            }
                                            Controls.Label {
                                                text: modelData.key
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                        Controls.Label {
                                            Layout.fillWidth: true
                                            text: modelData.value
                                            wrapMode: Text.WordWrap
                                            opacity: 0.9
                                        }
                                        Controls.ToolButton {
                                            icon.name: "edit-copy"
                                            Controls.ToolTip.visible: hovered
                                            Controls.ToolTip.text: "Copiar valor"
                                            onClicked: backend.copyText(modelData.value, modelData.key)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
