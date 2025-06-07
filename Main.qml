import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Package 1.0

Window {
    id: window
    visible: true
    width: 640
    height: 480
    title: "Package Builder"

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        anchors.margins: 10

        Label {
            text: "Übungspakete"
            font.bold: true
            font.pointSize: 16
            Layout.alignment: Qt.AlignHCenter
        }

        ListView {
            id: packageListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: packageModel
            clip: true
            currentIndex: -1
            interactive: true

            delegate: Rectangle {
                id: delegateRoot
                width: packageListView.width
                height: 40
                color: index === packageListView.currentIndex ? "#d0eaff" : "white"
                border.color: "gray"
                border.width: 1

                Text {
                    text: model.displayName
                    anchors.centerIn: parent
                    font.pixelSize: 16
                }
                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.WithinBounds

                    onTapped: {
                        packageListView.currentIndex = index
                    }

                    onDoubleTapped: {
                        console.log("🖱️ Doppel-Klick erkannt bei Index:", index)
                        packageListView.currentIndex = index
                        Qt.callLater(function() {
                            openDialog(packageModel.get(index))
                        })
                    }
                }
            }
        }

        RowLayout {
            spacing: 10
            Layout.alignment: Qt.AlignRight

            Button {
                text: "Neu anlegen"
                enabled: packageListView.currentIndex >= 0
                onClicked: {
                    let selected = packageModel.get(packageListView.currentIndex)
                    openDialog(selected)
                }
            }

            Button {
                text: "Bearbeiten"
                enabled: packageListView.currentIndex >= 0
                onClicked: {
                    let selected = packageModel.get(packageListView.currentIndex)
                    openDialog(selected)
                }
            }
        }
    }

    PackageModel {
        id: packageModel
    }

    Component.onCompleted: {
        console.log("📦 Lade Packages aus:", packagesFolder)
        packageModel.loadPackages(packagesFolder)
    }

    function openDialog(packageData) {
        console.log("🔍 Öffne Dialog für:", packageData.displayName)
        let component = Qt.createComponent("UebungenDialog.qml")
        if (component.status === Component.Ready) {
            let dialog = component.createObject(window, {
                packagePath: packageData.path  // 🔧 Hier übergeben wir den Pfad
            })
            if (dialog) {
                dialog.show()
            } else {
                console.error("❌ Dialog konnte nicht erzeugt werden.")
            }
        } else {
            console.error("❌ Fehler beim Laden des Dialogs:", component.errorString())
        }
    }

}
