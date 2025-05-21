import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Dialog {
    id: root
    title: "Übung bearbeiten"
    modal: true
    standardButtons: Dialog.NoButton
    property var itemData: ({})

    signal save(var updatedData)

    width: 700
    height: 600

    ScrollView {
        anchors.fill: parent

        ColumnLayout {
            spacing: 12
            Repeater {
                model: [
                    "frageSubjekt", "antwortSubjekt", "subjektPrefixFrage", "subjektPrefixAntwort",
                    "imagefileFrage", "imagefileAntwort", "infoURLFrage", "infoURLAntwort",
                    "imageFrageAuthor", "imageFrageLizenz", "imageAntwortAuthor", "imageAntwortLizenz",
                    "wikiPageFraVers", "wikiPageAntVers", "excludeAereaFra", "excludeAereaAnt"
                ]

                ColumnLayout {
                    Label {
                        text: modelData
                        font.bold: true
                    }
                    TextField {
                        text: root.itemData[modelData] || ""
                        onTextChanged: root.itemData[modelData] = text
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Speichern"
                    icon.name: "check"
                    onClicked: {
                        root.save(root.itemData)
                        root.close()
                    }
                }

                Button {
                    text: "Abbrechen"
                    icon.name: "cancel"
                    onClicked: root.close()
                }
            }
        }
    }
}
