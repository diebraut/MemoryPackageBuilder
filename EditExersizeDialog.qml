import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

import ExersizeLoader 1.0

Dialog {
    id: root
    title: "Übung bearbeiten"
    modal: true
    standardButtons: Dialog.NoButton
    property var itemData: ({})
    signal save(var updatedData)

    width: 700
    height: 600

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

        FocusScope {
            id: keyHandlerArea
            focus: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    event.accepted = true
                    abbrechen.clicked()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 5

                Rectangle {
                    id: buttonArea
                    height: 60
                    color: "darkgray"
                    Layout.fillWidth: true

                    Row {
                        anchors.centerIn: parent
                        spacing: 10

                        Button {
                            text: "Ändern"
                            onClicked: {
                                // Auslesen & neue Kopie erzeugen
                                const cleanCopy = {}
                                for (let key in root.itemData) {
                                    cleanCopy[key] = root.itemData[key]
                                }
                                root.save(cleanCopy)
                                root.close()
                            }
                            font.bold: true
                            palette.text: "black"
                        }

                        Button {
                            id: abbrechen
                            text: "Abbrechen"
                            icon.name: "cancel"
                            onClicked: root.close()
                            font.bold: true
                            palette.text: "black"
                        }
                    }
                }

                ScrollView {
                    id: scrollArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Column {
                        id: formLayout
                        width: scrollArea.width - 35
                        spacing: 8
                        padding: 10

                        Repeater {
                            model: [
                                "frageSubjekt", "antwortSubjekt", "subjektPrefixFrage", "subjektPrefixAntwort",
                                "imagefileFrage", "imagefileAntwort", "infoURLFrage", "infoURLAntwort",
                                "imageFrageAuthor", "imageFrageLizenz", "imageAntwortAuthor", "imageAntwortLizenz",
                                "wikiPageFraVers", "wikiPageAntVers", "excludeAereaFra", "excludeAereaAnt"
                            ]

                            delegate: Column {
                                width: formLayout.width
                                spacing: 4

                                Label {
                                    text: modelData
                                    font.bold: true
                                    width: parent.width
                                }

                                TextField {
                                    text: root.itemData[modelData] || ""
                                    onTextChanged: root.itemData[modelData] = text
                                    width: parent.width
                                    height: 30
                                    font.pixelSize: 14
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


