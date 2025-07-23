import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Dialog {
    id: root
    title: "Übung bearbeiten"
    modal: true
    standardButtons: Dialog.NoButton

    property var itemData: ({})
    property var originalData: ({})
    signal save(var updatedData, int index)

    property var multiEditIndices: []
    property int multiEditCurrent: -1

    width: 700
    height: 600

    function isDataChanged() {
        var newData = root.itemData;
        var oldData = root.originalData;

        for (var key in newData) {
            if (newData[key] !== oldData[key]) {
                return true;
            }
        }
        for (let key in oldData) {
            if (!(key in newData)) {
                return true;
            }
        }
        return false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

        FocusScope {
            id: keyHandlerArea
            focus: true
            Layout.fillWidth: true
            Layout.fillHeight: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let activeItem = Qt.inputMethod.focusItem;

                    if (activeItem && activeItem.metaObject.className === "QQuickTextInput") {
                        if (root.multiEditIndices.length > 1) {
                            saveNextButton.clicked();
                        } else {
                            abbrechen.clicked();
                        }
                        event.accepted = true;
                        return;
                    }

                    if (root.multiEditIndices.length >= 1) {
                        saveNextButton.clicked();
                    } else {
                        abbrechen.clicked();
                    }
                    event.accepted = true;
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
                            id: saveNextButton
                            text: root.multiEditIndices.length > 1 ? "Weiter" : "Ändern"
                            font.bold: root.multiEditIndices.length >= 1
                            focus: root.multiEditIndices.length >= 1

                            onClicked: {
                                var updated = JSON.parse(JSON.stringify(root.itemData));
                                delete updated[""];

                                var indexToUpdate;

                                if (root.multiEditIndices.length > 1 && root.multiEditCurrent >= 0) {
                                    indexToUpdate = root.multiEditIndices[root.multiEditCurrent];
                                } else {
                                    indexToUpdate = listView.currentIndex;
                                }

                                if (isDataChanged()) {
                                    save(updated, indexToUpdate);
                                }

                                if (root.multiEditIndices.length > 1 && root.multiEditCurrent >= 0) {
                                    const nextIndex = root.multiEditCurrent + 1;
                                    if (nextIndex < root.multiEditIndices.length) {
                                        root.multiEditCurrent = nextIndex;
                                        const idx = root.multiEditIndices[root.multiEditCurrent];
                                        root.itemData = JSON.parse(JSON.stringify(uebungModel.get(idx)));
                                        root.originalData = JSON.parse(JSON.stringify(root.itemData));
                                    } else {
                                        root.multiEditIndices = [];
                                        root.multiEditCurrent = -1;
                                        root.close();
                                    }
                                } else {
                                    root.close();
                                }
                            }
                        }

                        Button {
                            id: abbrechen
                            text: "Abbrechen"
                            icon.name: "cancel"
                            palette.text: "black"
                            font.bold: root.multiEditIndices.length < 1
                            focus: root.multiEditIndices.length < 1
                            onClicked: root.close()
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
                                "imageFrageBildDescription", "imageAntwortBildDescription",
                                "wikiPageFraVers", "wikiPageAntVers",
                                "excludeAereaFra", "excludeAereaAnt"
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
                                    Keys.forwardTo: [keyHandlerArea]
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
