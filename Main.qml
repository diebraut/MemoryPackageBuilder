import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Package 1.0
import ExerciseIO 1.0

import FileHelper 1.0

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

    function openDialog(packageData) {
        console.log("🔍 Öffne Dialog für:", packageData.displayName)

        // --- 1) Anzahl der package-XML-Dateien bestimmen ---
        let count = 1    // Standardwert falls nur package.xml existiert
        try {
            let folder = packageData.path
            let files = Qt.openUrlExternally ? [] : []  // Dummy, wird gleich ersetzt

            // Qt.labs.platform FileDialog kann nicht lesen – aber FileHelper kann es!
            // Falls du schon ein C++-FileHelper hast, ersetzen wir das durch:
            if (typeof FileHelper !== "undefined" && FileHelper.directoryEntries) {
                let entries = FileHelper.directoryEntries(folder)
                count = entries.filter(
                    f => /^package(_\d+)?\.xml$/i.test(f)
                ).length
            } else {
                // Fallback: nur package.xml → count = 1
                count = 1
            }

            if (count < 1)
                count = 1

            console.log("📦 Anzahl package-XML-Dateien im Ordner:", count)
        } catch (e) {
            console.error("❌ Fehler beim Prüfen der XML-Dateien:", e)
            count = 1
        }

        // --- 2) Dialog laden + neue Property übergeben ---
        let component = Qt.createComponent("UebungenDialog.qml")
        if (component.status === Component.Ready) {
            let dialog = component.createObject(window, {
                packagePath: packageData.path,
                package_count: count,          // <<<<<<<<<< NEUE PROPERTY
                io: buildExercize
            })
            if (dialog) dialog.show()
        } else {
            console.error("❌ Fehler beim Laden des Dialogs:", component.errorString())
        }
    }

    function openCheckExportDialog(packageData) {
        let component = Qt.createComponent("CheckExportDialog.qml")
        if (component.status === Component.Ready) {
            let dialog = component.createObject(window, {
                packageName: packageData.displayName,
                packagePath: packageData.path
            })
            if (dialog) dialog.open()
        } else {
            console.error("Fehler beim Laden des Pruefen/Exportieren-Dialogs:", component.errorString())
        }
    }

    function startImageCompression(packageData) {
        imageCompressionWindow.packageName = packageData.displayName
        imageCompressionWindow.processed = 0
        imageCompressionWindow.total = 0
        imageCompressionWindow.fileName = "Bilder werden gesucht …"
        imageCompressionWindow.resultText = ""
        completedCompressionFiles.clear()
        compressionNotice.text = ""
        compressionNoticeTimer.stop()
        imageCompressionWindow.show()
        if (!FileHelper.compressPackageImages(packageData.path))
            imageCompressionWindow.resultText = "Die Komprimierung konnte nicht gestartet werden. Bitte den Paketordner prüfen."
    }

    onClosing: function(event) {
        if (FileHelper.imageCompressionRunning) event.accepted = false
    }

    ListModel { id: completedCompressionFiles }

    Window {
        id: imageCompressionWindow
        transientParent: window
        modality: Qt.ApplicationModal
        title: "Bilder verlustfrei komprimieren"
        width: 480
        height: 310
        minimumWidth: 440
        minimumHeight: 280
        color: "#f5f7fa"
        property string packageName: ""
        property int processed: 0
        property int total: 0
        property string fileName: ""
        property string resultText: ""
        onClosing: function(event) {
            if (FileHelper.imageCompressionRunning) event.accepted = false
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            Label {
                text: imageCompressionWindow.packageName
                font.bold: true
                font.pixelSize: 15
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: imageCompressionWindow.total > 0
                        ? imageCompressionWindow.processed + " von " + imageCompressionWindow.total + " Dateien bearbeitet"
                        : "Bilddateien werden gesucht …"
                    Layout.fillWidth: true
                }
                Label {
                    text: imageCompressionWindow.total > 0
                        ? Math.round(100 * imageCompressionWindow.processed / imageCompressionWindow.total) + " %" : ""
                    font.bold: true
                    color: "#2867aa"
                }
            }
            ProgressBar {
                id: compressionProgressBar
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, imageCompressionWindow.total)
                value: imageCompressionWindow.processed
                visible: imageCompressionWindow.total > 0
                background: Rectangle { implicitHeight: 10; radius: 5; color: "#dce4ed" }
                contentItem: Item {
                    implicitHeight: 10
                    Rectangle {
                        width: compressionProgressBar.visualPosition * parent.width
                        height: parent.height
                        radius: 5
                        color: "#387fca"
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: imageCompressionWindow.resultText || "Aktuell: " + imageCompressionWindow.fileName
                elide: Text.ElideMiddle
                color: imageCompressionWindow.resultText ? "#a02020" : "#526175"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "white"
                radius: 5
                border.color: "#dce4ed"
                ListView {
                    id: completedCompressionList
                    anchors.fill: parent
                    anchors.margins: 8
                    clip: true
                    model: completedCompressionFiles
                    spacing: 4
                    ScrollBar.vertical: ScrollBar { }
                    delegate: RowLayout {
                        width: completedCompressionList.width
                        spacing: 8
                        Label { text: model.status; color: model.statusColor; font.pixelSize: 11 }
                        Label { text: model.fileName; Layout.fillWidth: true; elide: Text.ElideMiddle; font.pixelSize: 12 }
                    }
                }
                Label {
                    anchors.centerIn: parent
                    visible: completedCompressionFiles.count === 0
                    text: "Fertig bearbeitete Dateien erscheinen hier."
                    color: "#778394"
                    font.pixelSize: 12
                }
            }
            Button {
                text: "Schließen"
                Layout.alignment: Qt.AlignRight
                visible: !FileHelper.imageCompressionRunning && imageCompressionWindow.resultText !== ""
                onClicked: imageCompressionWindow.close()
            }
        }
    }

    Rectangle {
        id: compressionNotice
        property string text: ""
        property string details: ""
        visible: text !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: Math.min(window.width - 24, 620)
        height: compressionNoticeLabel.implicitHeight + 20
        z: 1000
        color: "#edf4fc"
        border.color: "#a9c4e2"
        radius: 6
        Label {
            id: compressionNoticeLabel
            anchors.centerIn: parent
            width: parent.width - 24
            text: compressionNotice.text
            wrapMode: Text.WordWrap
        }
        MouseArea { anchors.fill: parent; onClicked: compressionNotice.text = "" }
        ToolTip.visible: compressionNoticeHover.hovered && compressionNotice.details !== ""
        ToolTip.text: compressionNotice.details
        HoverHandler { id: compressionNoticeHover }
    }
    Timer {
        id: compressionNoticeTimer
        interval: 8000
        onTriggered: compressionNotice.text = ""
    }

    Connections {
        target: FileHelper
        function onImageCompressionProgress(processed, total, fileName) {
            imageCompressionWindow.processed = processed
            imageCompressionWindow.total = total
            imageCompressionWindow.fileName = fileName
        }
        function onImageCompressionFileFinished(fileName, result) {
            let status = "Fehler"
            let color = "#b42318"
            if (result.state === "compressed") { status = "Komprimiert"; color = "#237343" }
            else if (result.state === "ready") { status = "Bereits optimal"; color = "#526175" }
            else if (result.state === "unsupported") { status = "Übersprungen"; color = "#936519" }
            completedCompressionFiles.append({ fileName: fileName, status: status, statusColor: color })
            completedCompressionList.positionViewAtEnd()
        }
        function onImageCompressionFinished(result) {
            imageCompressionWindow.total = result.total
            imageCompressionWindow.processed = result.total
            imageCompressionWindow.close()
            compressionNotice.text = result.total + " Dateien bearbeitet: " + result.compressed
                + " komprimiert, " + result.unchanged + " ohne weitere Ersparnis, "
                + result.unsupported + " übersprungen, " + result.errorCount + " Fehler. Eingespart: "
                + (Number(result.savedBytes) / 1024).toLocaleString(Qt.locale(), "f", 1) + " KB."
            compressionNotice.details = result.errorCount > 0 ? result.errors.join("\n") : ""
            if (result.errorCount > 0) console.warn("Bildkomprimierung:", compressionNotice.details)
            compressionNoticeTimer.restart()
        }
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

                Menu {
                    id: packageContextMenu

                    MenuItem {
                        text: "Bilder verlustfrei komprimieren"
                        enabled: !FileHelper.imageCompressionRunning
                        onTriggered: {
                            packageListView.currentIndex = index
                            window.startImageCompression(packageModel.get(index))
                        }
                    }

                    MenuItem {
                        text: "Pr\u00fcfen/Exportieren"
                        onTriggered: {
                            packageListView.currentIndex = index
                            openCheckExportDialog(packageModel.get(index))
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    propagateComposedEvents: true
                    onPressed: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            packageListView.currentIndex = index
                            packageContextMenu.x = mouse.x
                            packageContextMenu.y = mouse.y
                            packageContextMenu.open()
                            mouse.accepted = true
                        }
                    }
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

}
