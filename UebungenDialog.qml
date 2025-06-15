import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Fusion 2.15

import ExersizeLoader 1.0

Window {
    id: dialogWindow
    width: 900
    height: 600
    title: "Übungen bearbeiten"
    visible: true
    modality: Qt.ApplicationModal

    // Eigenschaften
    property string packagePath
    property bool sequentiell: sequentiellCheckBox.checked
    property bool umgekehrt: umgekehrtCheckBox.checked
    property string frageText: frageTextField.text
    property string frageTextUmgekehrt: frageTextUmgekehrtField.text
    property string uebungenName: uebungenNameField.text

    property var uebungenData
    property int labelWidth: 120

    // Anzahl der Spalten
    property int columnCount: 8
    // Zwischenraum zwischen den Spalten (Row.spacing)
    property int columnSpacing: 5

    EditExersizeDialog {
        id: editExersizeDialog

        onSave: function(updatedData) {
            if (listView.currentIndex >= 0) {
                uebungModel.set(listView.currentIndex, updatedData)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: listView.forceActiveFocus()
        enabled: !listView.activeFocus
    }

    Component {
        id: imageProcessingWindowComponent

        ImageProcessingWindow {
            onAccepted: {
                console.log("Bildbearbeitung bestätigt.")
            }
            onRejected: {
                console.log("Bildbearbeitung abgebrochen.")
            }

            onVisibleChanged: {
                if (!visible)
                    destroy()
            }
        }
    }

    Menu {
        id: imageContextMenu
        property string roleName
        property int rowIndex

        // Funktion zum sicheren Zugriff auf den Wert
        function getCurrentValue() {
            if (rowIndex >= 0 && rowIndex < uebungModel.count) {
                return uebungModel.get(rowIndex)[roleName] || ""
            }
            return ""
        }

        function openFileDialog() {
            console.log("FileDialog öffnen für:", roleName, "bei Zeile:", rowIndex)
            // Hier FileDialog implementieren
        }

        // Dynamische Erstellung der Menüeinträge
        function buildMenu() {
            // Alte Einträge entfernen
            while (count > 0) {
                removeItem(itemAt(0))
            }

            // Aktuellen Wert abfragen
            var currentVal = getCurrentValue()

            // Nur relevante Einträge hinzufügen
            if (currentVal) {
                addItem(createMenuItem(
                    "Bild '" + currentVal + "' entfernen",
                    "uebungModel.setProperty(rowIndex, roleName, \"\")"
                ))

                addItem(createMenuItem(
                    "Bild '" + currentVal + "' austauschen",
                    "openFileDialog()"
                ))

                addItem(createMenuItem(
                    "Bild '" + currentVal + "' bearbeiten",
                    "imageContextMenu.openImageProcessingDialog('" + roleName + "', '" + rowIndex + "')"
                ))
            } else {
                addItem(createMenuItem(
                    "Bild hinzufügen",
                    "openFileDialog()"
                ))
            }
        }

        function createMenuItem(text, action) {
            return Qt.createQmlObject(`
                import QtQuick.Controls 2.15
                MenuItem {
                    text: "${text}"
                    onTriggered: {
                        ${action}
                    }
                }
            `, imageContextMenu)
        }

        function openImageProcessingDialog(role, index) {
            if (index >= 0 && index < uebungModel.count) {
                const fileName = uebungModel.get(index)[role];
                if (fileName && fileName.trim() !== "") {
                    const fullPath = packagePath + "/" + fileName;
                    const sanitizedPath = fullPath.replace(/\\/g, '/');

                    const win = imageProcessingWindowComponent.createObject(dialogWindow);

                    // Bildschirmgröße ermitteln für korrekte Positionierung
                    const screenW = Screen.desktopAvailableWidth;
                    const screenH = Screen.desktopAvailableHeight;

                    win.openWithImage("file:///" + sanitizedPath, screenW, screenH);
                } else {
                    console.log("Kein Bild für diese Zelle vorhanden");
                }
            }
        }
    }

    Item {
        id: windowContent
        anchors.fill: parent
    }

    Canvas {
        id: circleCanvas
        anchors.fill: parent
        visible: showCircles
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!showCircles) return;

            ctx.strokeStyle = "red";
            ctx.lineWidth = 2;

            ctx.beginPath();
            ctx.arc(centerX, centerY, innerRadius, 0, 2 * Math.PI);
            ctx.stroke();

            ctx.beginPath();
            ctx.arc(centerX, centerY, outerRadius, 0, 2 * Math.PI);
            ctx.stroke();
        }

        property bool showCircles: false
        property real centerX: 0
        property real centerY: 0
        property real innerRadius: 0
        property real outerRadius: 0
    }


    Component {
        id: columnEditor
        Item {
            property string roleName
            property int rowIndex
            property string initialText
            property int colWidth

            width: colWidth
            height: 40

            TextField {
                id: textField
                anchors.centerIn: parent
                width: colWidth * 0.8
                height: parent.height * 0.8
                text: initialText

                activeFocusOnPress: true
                onPressed: {
                    listView.currentIndex = rowIndex;
                    forceActiveFocus()
                }
                onTextChanged: {
                    if (text !== uebungModel.get(rowIndex)[roleName]) {
                        uebungModel.setProperty(rowIndex, roleName, text)
                    }
                }

                background: Rectangle {
                    color: "white"
                    border.color: textField.activeFocus ? "blue" : "#ccc"
                    radius: 3
                }

                // MouseArea für Right-Click im Textfeld
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    enabled: true
                    propagateComposedEvents: true

                    onPressed: function(mouse) {
                        // KORREKTUR: Direkter Zugriff auf die Eigenschaften des umgebenden Items
                        var currentRole = textField.parent.roleName;

                        if (mouse.button === Qt.RightButton &&
                            (currentRole === "imagefileFrage" ||
                             currentRole === "imagefileAntwort")) {

                            imageContextMenu.roleName = currentRole;
                            imageContextMenu.rowIndex = textField.parent.rowIndex;

                            var globalPos = mapToItem(windowContent, mouse.x, mouse.y);
                            imageContextMenu.x = globalPos.x;
                            imageContextMenu.y = globalPos.y;

                            imageContextMenu.buildMenu();
                            imageContextMenu.open();
                            mouse.accepted = true;
                        } else {
                            mouse.accepted = false;
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: uebungModel
    }

    Component.onCompleted: {
        if (packagePath) {
            uebungenData = ExersizeLoader.loadPackage(packagePath);
            uebungenNameField.text = uebungenData.name;
            frageTextField.text = uebungenData.frageText;
            frageTextUmgekehrtField.text = uebungenData.frageTextUmgekehrt;
            sequentiellCheckBox.checked = uebungenData.sequentiell;
            umgekehrtCheckBox.checked = uebungenData.umgekehrt;
            uebungModel.clear();
            for (var i = 0; i < uebungenData.uebungsliste.length; ++i) {
                uebungModel.append(uebungenData.uebungsliste[i]);
            }
        }
        listView.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Obere Eingabefelder
        GroupBox {
            title: "Uebungen Eigenschaften"
            Layout.fillWidth: true
            padding: 10

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                RowLayout {
                    Label { text: "Name:"; Layout.preferredWidth: labelWidth }
                    TextField { id: uebungenNameField; Layout.preferredWidth: 300 }
                }

                RowLayout {
                    Label { text: "Fragetext:"; Layout.preferredWidth: labelWidth }
                    TextField { id: frageTextField; Layout.preferredWidth: 600 }
                }

                RowLayout {
                    Label { text: "Fragetext umgekehrt:"; Layout.preferredWidth: labelWidth }
                    TextField { id: frageTextUmgekehrtField; Layout.fillWidth: true }
                }

                RowLayout {
                    Label { text: "Sequentiell:"; Layout.preferredWidth: labelWidth }
                    CheckBox { id: sequentiellCheckBox }
                }

                RowLayout {
                    Label { text: "Umgekehrt:"; Layout.preferredWidth: labelWidth }
                    CheckBox { id: umgekehrtCheckBox }
                }
            }
        }

        // Listenbereich
        GroupBox {
            title: "Übungsliste"
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                anchors.fill: parent
                id: listArea

                property real columnWidth: 150
                property real totalContentWidth: 150 * columnCount + (columnCount - 1) * columnSpacing

                onWidthChanged: {
                    columnWidth = Math.max(150, (width - (columnCount - 1) * columnSpacing) / columnCount)
                    totalContentWidth = columnWidth * columnCount + (columnCount - 1) * columnSpacing
                }

                Component.onCompleted: {
                    columnWidth = Math.max(150, (width - (columnCount - 1) * columnSpacing) / columnCount)
                    totalContentWidth = columnWidth * columnCount + (columnCount - 1) * columnSpacing
                }

                // Kopfzeile
                Rectangle {
                    id: header
                    height: 40
                    width: parent.width
                    anchors.top: parent.top
                    color: "#dddddd"

                    Row {
                        anchors.fill: parent
                        spacing: columnSpacing

                        Repeater {
                            model: ["FrageSubjekt", "AntwortSubjekt", "SubjektPrefixFrage",
                                   "SubjektPrefixAntwort", "ImagefileFrage", "ImagefileAntwort",
                                   "InfoURLFrage", "InfoURLAntwort"]

                            Item {
                                width: listArea.columnWidth
                                height: parent.height

                                Label {
                                    width: listArea.columnWidth * 0.8
                                    height: parent.height * 0.8
                                    anchors.centerIn: parent
                                    text: modelData
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    font.bold: true
                                    color: "#333"
                                }
                            }
                        }
                    }
                }

                // Liste
                ListView {
                    id: listView
                    anchors.top: header.bottom
                    anchors.left: parent.left
                    width: listArea.totalContentWidth
                    anchors.bottom: parent.bottom
                    clip: true
                    model: uebungModel
                    currentIndex: -1
                    interactive: true
                    focus: true
                    spacing: 0
                    flickableDirection: Flickable.VerticalFlick | Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.horizontal: ScrollBar {}
                    ScrollBar.vertical: ScrollBar {}

                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Up && currentIndex > 0) {
                            currentIndex--;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down && currentIndex < model.count - 1) {
                            currentIndex++;
                            event.accepted = true;
                        }
                        scrollToItem();
                    }

                    function scrollToItem() {
                        if (currentIndex === -1) return;
                        listView.positionViewAtIndex(currentIndex, ListView.Contain);
                    }

                    Component.onCompleted: forceActiveFocus()

                    delegate: Rectangle {
                        property int indexOutside: index
                        id: delegateRoot
                        width: listArea.totalContentWidth
                        height: 40

                        color: listView.currentIndex === indexOutside
                               ? "lightblue"
                               : (indexOutside % 2 === 0 ? "#f9f9f9" : "#ffffff")
                        border.color: listView.currentIndex === indexOutside ? "blue" : "transparent"
                        border.width: 1

                        // Funktion zum Öffnen des Dialogs
                        function handleDoubleClick(index) {
                            console.log("Doubleclick für Zeile:", index)
                            listView.currentIndex = index
                            if (listView.currentIndex >= 0) {
                                editExersizeDialog.itemData = JSON.parse(JSON.stringify(uebungModel.get(listView.currentIndex)))
                                editExersizeDialog.open()
                            }
                        }

                        // MouseArea für Zeilen-Double-Click
                        MouseArea {
                            id: rowMouseArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            propagateComposedEvents: true

                            onDoubleClicked: function(mouse) {
                                handleDoubleClick(indexOutside)
                                mouse.accepted = true
                            }

                            onClicked: function(mouse) {
                                listView.currentIndex = indexOutside
                                listView.forceActiveFocus()
                                mouse.accepted = false
                            }
                        }

                        // Textfelder
                        Row {
                            anchors.fill: parent
                            spacing: columnSpacing

                            Repeater {
                                model: [
                                    "frageSubjekt", "antwortSubjekt", "subjektPrefixFrage", "subjektPrefixAntwort",
                                    "imagefileFrage", "imagefileAntwort", "infoURLFrage", "infoURLAntwort"
                                ]
                                Loader {
                                    property string roleName: modelData
                                    property int rowIndex: indexOutside
                                    property int colWidth: listArea.columnWidth

                                    sourceComponent: columnEditor
                                    Binding { target: item; property: "roleName"; value: roleName }
                                    Binding { target: item; property: "colWidth"; value: colWidth }
                                    Binding { target: item; property: "rowIndex"; value: rowIndex }
                                    Binding { target: item; property: "initialText"; value: uebungModel.get(rowIndex)[roleName] }
                                }
                            }
                        }
                    }

                }
            }
        }
        // Button-Zeile
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Linksbündige Buttons
            RowLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 10

                Button {
                    text: "Bearbeiten"
                    icon.name: "edit"
                    onClicked: {
                        if (listView.currentIndex >= 0) {
                            editExersizeDialog.itemData = JSON.parse(JSON.stringify(uebungModel.get(listView.currentIndex)))
                            editExersizeDialog.open()
                        }
                    }
                }

                Button {
                    text: "Hinzufügen"
                    onClicked: uebungModel.append({})
                }

                Button {
                    text: "Löschen"
                    onClicked: if (listView.currentIndex >= 0) uebungModel.remove(listView.currentIndex)
                }
            }

            // Spacer in der Mitte
            Item { Layout.fillWidth: true }

            // Rechtsbündiger Abbrechen-Button
            Button {
                text: "Abbrechen"
                onClicked: dialogWindow.close()
            }
        }
    }
}
