import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Package 1.0
import ExerciseIO 1.0

import Qt.labs.platform 1.1
import QtQuick.Controls.Fusion 2.15

Window {
    id: window
    visible: true
    width: 640
    height: 480
    title: "Package Builder"

    property string selectedCsvFileName: ""
    property string selectedCsvBaseName: ""

    PackageModel {
        id: packageModel
    }

    BuildExercisePackage {
        id: buildExercize;
    }

    FileDialog {
        id: csvFileDialog
        title: "CSV-Datei auswählen"
        folder: "file:///" + buildSourcenFolder  // ← wichtig
        nameFilters: ["CSV-Dateien (*.csv)"]
        fileMode: FileDialog.OpenFile  // ← wichtig!
        onAccepted: {
            const filePath = file.toString()
            const fileName = filePath.split("/").pop()
            const baseName = fileName.split(".").slice(0, -1).join(".")

            exerciseCreationDialog.selectedCsvFileName = fileName
            exerciseCreationDialog.proposedExerciseName = baseName
            newExerciseNameField.text = baseName
            exerciseCreationDialog.open()
        }
        onRejected: {
            console.log("❌ Auswahl abgebrochen.")
        }
    }

    // Modal-Overlay zum Blockieren des Hauptfensters
    Item {
        id: modalOverlay
        anchors.fill: parent
        visible: exerciseCreationDialog.visible || overwriteDialog.visible
        z: 99

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.4
        }

        MouseArea {
            anchors.fill: parent
            enabled: true
            z: 100
        }
    }

    // Dialog zur Eingabe neuer Übung
    Popup {
        id: exerciseCreationDialog
        width: 400
        height: 200
        modal: true
        closePolicy: Popup.NoAutoClose
        focus: true
        z: 101
        anchors.centerIn: parent

        property string selectedCsvFileName: ""     // z. B. "beispiel.csv"
        property string proposedExerciseName: ""    // z. B. "beispiel"

        // Titelzeile am oberen Rand
        Label {
            text: "Exercise-Datei erzeugen"
            font.bold: true
            font.pointSize: 14
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // Inhalt mit Abstand nach oben
        Item {
            id: colId
            anchors.top: parent.top
            anchors.topMargin: 55     // Platz unter dem Titel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 20
            //spacing: 10

            Label {
                id:selectedFileLabelId
                text: "Gewählte Eingabedatei:"
                font.bold: true
            }

            Label {
                id:selectedFileNameId
                anchors.top: selectedFileLabelId.top
                anchors.left: selectedFileLabelId.right
                anchors.leftMargin: 5
                text: "<"+ exerciseCreationDialog.proposedExerciseName + ">"
                visible: exerciseCreationDialog.proposedExerciseName !== ""
            }

            Label {
                id: exerciseNameId
                anchors.top: selectedFileNameId.bottom
                anchors.topMargin: 20
                anchors.left: selectedFileLabelId.left
                text: "Name der Übung"
                font.bold: true
            }

            TextField {
                id: newExerciseNameField
                anchors.top: exerciseNameId.bottom
                anchors.topMargin: 5
                anchors.left: exerciseNameId.left
                text: exerciseCreationDialog.proposedExerciseName
                width : colId.width / 2
            }

            Button {
                id: createId
                anchors.top: cancelId.top
                anchors.right: cancelId.left
                anchors.rightMargin: 5
                text: "Übung erstellen"

                onClicked: {
                    const name = newExerciseNameField.text.trim()
                    const exists = exerciseExists(name)

                    if (exists) {
                        overwriteDialog.exerciseName = name
                        overwriteDialog.open()
                    } else {
                        console.log("✅ Erzeuge neue Übung:", name)

                        const csvPath = buildSourcenFolder + "/" + exerciseCreationDialog.selectedCsvFileName
                        const ok = buildExercize.buildPackage(csvPath, name, packagesFolder)
                        if (ok) {
                            console.log("✅ Paket erfolgreich erstellt.")
                            packageModel.loadPackages(packagesFolder)
                        } else {
                            console.error("❌ Fehler beim Erstellen des Pakets.")
                        }

                        exerciseCreationDialog.close()
                    }
                }

                function exerciseExists(name) {
                    const normalizedInput = name.toLowerCase().replace(/\s+/g, "")

                    console.log("🔍 Suche nach Übung:", normalizedInput)
                    const count = packageModel.rowCount()
                    console.log("📦 Anzahl Übungen:", count)

                    for (let i = 0; i < count; i++) {
                        const modelName = packageModel.get(i).displayName
                        const normalizedModelName = modelName.toLowerCase().replace(/\s+/g, "")

                        console.log("➡️ Vergleiche mit:", normalizedModelName)
                        if (normalizedInput === normalizedModelName) {
                            return true
                        }
                    }

                    return false
                }
            }

            Button {
                id:cancelId
                anchors.bottom: colId.bottom
                anchors.bottomMargin: -15
                anchors.right: colId.right
                anchors.rightMargin: -15
                text: "Abbrechen"
                onClicked: exerciseCreationDialog.close()
            }

        }
    }

    // Warnung bei bereits existierender Übung
    Popup {
        id: overwriteDialog
        width: 300
        height: 140
        modal: true
        closePolicy: Popup.NoAutoClose
        focus: true
        z: 101
        anchors.centerIn: parent

        property string exerciseName: ""

        // Hintergrund mit weißem Rahmen
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "white"     // ← weißer Rahmen
            border.width: 2
            radius: 8

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 10

                Label {
                    text: "⚠️ Übung '" + overwriteDialog.exerciseName + "' existiert bereits."
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 10

                    Button {
                        text: "Überschreiben"
                        onClicked: {
                            console.log("⚠️ Überschreibe Übung:", overwriteDialog.exerciseName)
                            overwriteDialog.close()
                            exerciseCreationDialog.close()
                            // TODO: Übung überschreiben
                        }
                    }

                    Button {
                        text: "Vorgang abbrechen"
                        onClicked: overwriteDialog.close()
                    }
                }
            }
        }
    }

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
                enabled: true
                text: "Neu anlegen"
                onClicked: {
                    console.log("🖱️ Öffne Vorlage Verzeichnis:", buildSourcenFolder)
                    csvFileDialog.open()
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
