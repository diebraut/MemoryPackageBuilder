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
            const idx = listView.currentIndex;
            if (idx >= 0) {
                const keys = Object.keys(updatedData);
                for (let key of keys) {
                    uebungModel.setProperty(idx, key, updatedData[key]);
                }
                // Manuelles Refresh der ListView
                listView.model = null;
                listView.model = uebungModel;
            }
        }
    }


    MouseArea {
        anchors.fill: parent
        onClicked: listView.forceActiveFocus()
        enabled: !listView.activeFocus
    }

    Component {
        id: imageProcessingComponent

        ImageProcessing {
            onAccepted: {
                console.log("Bildbearbeitung bestätigt.");
            }
            onRejected: {
                console.log("Bildbearbeitung abgebrochen.");
            }

            onVisibleChanged: {
                if (!visible)
                    destroy();
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
                return uebungModel.get(rowIndex)[roleName] || "";
            }
            return "";
        }

        function openFileDialog() {
            console.log("FileDialog öffnen für:", roleName, "bei Zeile:", rowIndex);
            // Hier FileDialog implementieren
        }

        // Dynamische Erstellung der Menüeinträge
        function buildMenu() {
            // Alte Einträge entfernen
            while (count > 0) {
                removeItem(itemAt(0));
            }

            // Aktuellen Wert abfragen
            var currentVal = getCurrentValue();

            // Nur relevante Einträge hinzufügen
            if (currentVal) {
                addItem(createMenuItem(
                    "Bild '" + currentVal + "' entfernen",
                    "uebungModel.setProperty(rowIndex, roleName, \"\")"
                ));

                addItem(createMenuItem(
                    "Bild '" + currentVal + "' austauschen",
                    "openFileDialog()"
                ));

                addItem(createMenuItem(
                    "Bild '" + currentVal + "' bearbeiten",
                    "imageContextMenu.openImageProcessingDialog('" + roleName + "', '" + rowIndex + "')"
                ));
            } else {
                addItem(createMenuItem(
                    "Bild hinzufügen",
                    "openFileDialog()"
                ));
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
            `, imageContextMenu);
        }

        function openImageProcessingDialog(role, index) {
            if (index >= 0 && index < uebungModel.count) {
                const fileName = uebungModel.get(index)[role];
                if (fileName && fileName.trim() !== "") {
                    const fullPath = packagePath + "/" + fileName;
                    const sanitizedPath = fullPath.replace(/\\/g, '/');

                    const win = imageProcessingComponent.createObject(dialogWindow);

                    // Rechteckdaten vorbereiten
                    let excludeRect = null;
                    if (role === "imagefileFrage")
                        excludeRect = uebungModel.get(index).excludeAereaFra;
                    else if (role === "imagefileAntwort")
                        excludeRect = uebungModel.get(index).excludeAereaAnt;

                    // Fenster öffnen mit Bild und evtl. vorhandenen Rechtecken
                    let arrowData = null;
                    if (role === "imagefileFrage")
                        arrowData = uebungModel.get(index).arrowDescFra;
                    else if (role === "imagefileAntwort")
                        arrowData = uebungModel.get(index).arrowDescAnt;

                    win.openWithImage("file:///" + sanitizedPath,
                                      Screen.desktopAvailableWidth,
                                      Screen.desktopAvailableHeight,
                                      excludeRect,
                                      arrowData);

                    win.accepted.connect(function(resultJson) {
                        const result = JSON.parse(resultJson);
                        const excludeData = result.excludeData;
                        const arrowData = result.arrowData;
                        const arrowKey = result.arrowKey;

                        if (role === "imagefileFrage") {
                            uebungModel.setProperty(index, "excludeAereaFra", excludeData);
                            uebungModel.setProperty(index, "arrowDescFra", arrowData);  // NEU
                        } else if (role === "imagefileAntwort") {
                            uebungModel.setProperty(index, "excludeAereaAnt", excludeData);
                            uebungModel.setProperty(index, "arrowDescAnt", arrowData);  // NEU
                        }
                    });
                    saveCurrentModelToXml();
                    win.rejected.connect(function() {
                        console.log("❌ Bearbeitung abgebrochen");
                    });
                } else {
                    console.log("⚠️ Kein Bild für diese Zelle vorhanden");
                }
            }
        }
    }
    Menu {
        id: urlContextMenu
        property string roleName
        property int rowIndex

        MenuItem {
            text: "Webseite anzeigen"
            onTriggered: {
                const row = urlContextMenu.rowIndex;
                const role = urlContextMenu.roleName;
                const extraProp = (role === "infoURLFrage")
                                  ? uebungModel.get(row).frageSubjekt
                                  : uebungModel.get(row).antwortSubjekt;

                const url = uebungModel.get(row)[role] || "";
                const component = Qt.createComponent("qrc:/MemoryPackagesBuilder/URLComponentProcessing.qml");

                if (component.status === Component.Ready) {
                    const win = component.createObject(null, {
                        urlString: url,
                        subjektnamen: extraProp,
                        packagePath: packagePath
                    });

                    win.accepted.connect(function(newUrl, licenceInfo, savedFileExtension) {
                        const row = urlContextMenu.rowIndex;
                        const role = urlContextMenu.roleName;

                        // 1. URL setzen
                        uebungModel.setProperty(row, role, newUrl);

                        if (licenceInfo) {
                            const prefix = (role === "infoURLFrage")
                                           ? "imageFrage"
                                           : (role === "infoURLAntwort")
                                           ? "imageAntwort"
                                           : null;

                            if (prefix) {
                                // 2. Lizenzdaten setzen
                                uebungModel.setProperty(row, prefix + "Author",
                                    licenceInfo.authorName + "[" + licenceInfo.authorUrl + "]");

                                uebungModel.setProperty(row, prefix + "Lizenz",
                                    licenceInfo.licenceName + "[" + licenceInfo.licenceUrl + "]");

                                uebungModel.setProperty(row, prefix + "BildDescription",
                                    licenceInfo.imageDescriptionUrl);

                                // 3. Bilddatei setzen oder anpassen
                                const imageFileKey = (prefix === "imageFrage") ? "imagefileFrage" : "imagefileAntwort";
                                let currentFileName = uebungModel.get(row)[imageFileKey];
                                const subjectKey = (prefix === "imageFrage") ? "frageSubjekt" : "antwortSubjekt";
                                const subjectValue = uebungModel.get(row)[subjectKey] || "";

                                if (currentFileName && currentFileName.trim() !== "") {
                                    const baseName = currentFileName.substring(0, currentFileName.lastIndexOf("."));  // ohne Endung
                                    const currentExt = currentFileName.split(".").pop().toLowerCase();

                                    if (currentExt !== savedFileExtension.toLowerCase()) {
                                        const newName = baseName + "." + savedFileExtension;
                                        uebungModel.setProperty(row, imageFileKey, newName);
                                        console.log("🔁 Dateiendung angepasst für", imageFileKey, "→", newName);
                                    }
                                } else {
                                    // 💡 Neuer Name auf Basis des Subjekts
                                    const newName = subjectValue.trim() + "." + savedFileExtension;
                                    uebungModel.setProperty(row, imageFileKey, newName);
                                    console.log("🆕 Neuer Bildname gesetzt:", imageFileKey, "→", newName);
                                }

                                console.log("✅ Lizenzinfos gespeichert für", prefix);
                            }
                        }

                        // 4. XML sofort speichern
                        saveCurrentModelToXml();
                        listView.model = null;
                        listView.model = uebungModel;

                    });

                    win.show();
                } else {
                    console.warn("❌ Fehler beim Laden:", component.errorString());
                }
            }
        }
        MenuItem {
            text: "Check Website"
            onTriggered: {
                const url = uebungModel.get(urlContextMenu.rowIndex)[urlContextMenu.roleName];
                checkWebsite(url, urlContextMenu.rowIndex, urlContextMenu.roleName);
            }
        }

    }

    function checkWebsite(url, rowIndex, roleName) {
        // Prüfen ob die Zeile noch existiert
        if (rowIndex < 0 || rowIndex >= uebungModel.count) {
            console.warn("Ungültiger Index:", rowIndex);
            return;
        }

        // Temporäre Kopie für die Closure erstellen
        let currentRow = rowIndex;
        let currentRole = roleName;
        // 🔶 Status: Gelb für "wird geprüft"
        const colorKey = roleName + "_bgcolor";
        uebungModel.setProperty(rowIndex, colorKey, "yellow");

        let xhr = new XMLHttpRequest();
        xhr.open("HEAD", url, true);
        xhr.timeout = 5000;

        xhr.onreadystatechange = function() {
            // Prüfen ob Zeile noch existiert
            if (currentRow >= uebungModel.count) return;
            console.log("xhr.readyState",xhr.readyState)
            if (xhr.readyState === XMLHttpRequest.DONE) {
                let success = (xhr.status >= 200 && xhr.status < 400);
                let color = success ? "#ccffcc" : "#ffcccc";  // hellgrün / hellrot
                uebungModel.setProperty(currentRow, colorKey, color);
                console.log(success ? "✅ erreichbar:" : "❌ nicht erreichbar:", url);
            }
        };

        xhr.onerror = function() {
            if (currentRow < uebungModel.count) {
                console.warn("⚠️ Fehler beim Prüfen:", url);
                uebungModel.setProperty(currentRow, colorKey, "#ffdddd");
            }
        };

        xhr.ontimeout = function() {
            if (currentRow < uebungModel.count) {
                console.warn("⏰ Timeout bei:", url);
                uebungModel.setProperty(currentRow, colorKey, "#ffdddd");
            }
        };

        try {
            xhr.send();
        } catch (e) {
            if (currentRow < uebungModel.count) {
                console.warn("❌ Ausnahme bei:", url, e);
                uebungModel.setProperty(currentRow, colorKey, "#ffdddd");
            }
        }
    }

    function saveCurrentModelToXml() {
        var data = {
            name: uebungenNameField.text,
            frageText: frageTextField.text,
            frageTextUmgekehrt: frageTextUmgekehrtField.text,
            sequentiell: sequentiellCheckBox.checked,
            umgekehrt: umgekehrtCheckBox.checked,
            uebungsliste: []
        };

        for (var i = 0; i < uebungModel.count; ++i) {
            let eintrag = JSON.parse(JSON.stringify(uebungModel.get(i)));
            delete eintrag[""];
            data.uebungsliste.push(eintrag);
        }

        const result = ExersizeLoader.savePackage(packagePath, data);
        if (result) {
            console.log("💾 Änderungen in XML gespeichert.");
        } else {
            console.warn("❌ Fehler beim Speichern.");
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
            id: columnItemId
            property string roleName
            property int rowIndex
            property int colWidth

            width: colWidth
            height: 40

            // Eigenschaften zur Bindung
            property string currentRole: roleName
            property int currentIndex: rowIndex
            property string colorKey: currentRole + "_bgcolor"
            property string bgColor: "white"  // neu

            TextField {
                id: textField
                anchors.centerIn: parent
                width: colWidth * 0.8
                height: parent.height * 0.8


                // Direkte Bindung an Modelwert
                text: {
                    if (currentIndex >= 0 && currentIndex < uebungModel.count) {
                        return uebungModel.get(currentIndex)[currentRole] || "";
                    }
                    return "";
                }

                activeFocusOnPress: true

                onPressed: {
                    listView.currentIndex = rowIndex;
                    forceActiveFocus();
                }

                onTextChanged: {
                    if (currentIndex >= 0 && currentIndex < uebungModel.count) {
                        if (text !== uebungModel.get(currentIndex)[currentRole]) {
                            uebungModel.setProperty(currentIndex, currentRole, text);

                            // Reset Hintergrundfarbe bei URL-Änderung
                            if (currentRole === "infoURLFrage" || currentRole === "infoURLAntwort") {
                                uebungModel.setProperty(currentIndex, colorKey, "white");
                            }
                        }
                    }
                }

                // ✅ Zuverlässige Farbbindung direkt im Rectangle
                background: Rectangle {
                    radius: 3
                    border.color: textField.activeFocus ? "blue" : "#ccc"
                    color: bgColor
                }

                // Kontextmenü für rechte Maustaste
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    enabled: true
                    propagateComposedEvents: true

                    onPressed: function(mouse) {
                        if (mouse.button !== Qt.RightButton) {
                            mouse.accepted = false;
                            return;
                        }

                        var currentRole = textField.parent.roleName;

                        if (currentRole === "infoURLFrage" || currentRole === "infoURLAntwort") {
                            openContextMenu(urlContextMenu, currentRole, textField.parent.rowIndex, mouse);
                        } else if (currentRole === "imagefileFrage" || currentRole === "imagefileAntwort") {
                            openContextMenu(imageContextMenu, currentRole, textField.parent.rowIndex, mouse, true);
                        } else {
                            mouse.accepted = false;
                        }
                    }

                    function openContextMenu(menu, roleName, rowIndex, mouse, isImage) {
                        menu.roleName = roleName;
                        menu.rowIndex = rowIndex;

                        var globalPos = mapToItem(windowContent, mouse.x, mouse.y);
                        menu.x = globalPos.x;
                        menu.y = globalPos.y;

                        if (isImage) {
                            menu.buildMenu();
                        }

                        menu.open();
                        mouse.accepted = true;
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
                let eintrag = JSON.parse(JSON.stringify(uebungenData.uebungsliste[i]));
                // ✅ Neue Farb-Properties hinzufügen, falls nicht vorhanden

                if (!("infoURLFrage_bgcolor" in eintrag)) {
                    eintrag.infoURLFrage_bgcolor = "white"; // oder dein Standard
                }
                if (!("infoURLAntwort_bgcolor" in eintrag)) {
                    eintrag.infoURLAntwort_bgcolor = "white";
                }

                uebungModel.append(eintrag);
            }
        }

        // Dynamische Breite berechnen (mindestens 900px)
        const colWidth = 150;
        const spacing = columnSpacing;
        const total = columnCount * colWidth + (columnCount - 1) * spacing;

        dialogWindow.width = Math.max(total + 60, 900);  // etwas Puffer für Ränder
        dialogWindow.height = 600;

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
                    columnWidth = Math.max(150, (width - (columnCount - 1) * columnSpacing) / columnCount);
                    totalContentWidth = columnWidth * columnCount + (columnCount - 1) * columnSpacing;
                }

                Component.onCompleted: {
                    columnWidth = Math.max(150, (width - (columnCount - 1) * columnSpacing) / columnCount);
                    totalContentWidth = columnWidth * columnCount + (columnCount - 1) * columnSpacing;
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
                            console.log("Doubleclick für Zeile:", index);
                            listView.currentIndex = index;
                            if (listView.currentIndex >= 0) {
                                editExersizeDialog.itemData = JSON.parse(JSON.stringify(uebungModel.get(listView.currentIndex)));
                                editExersizeDialog.open();
                            }
                        }

                        // MouseArea für Zeilen-Double-Click
                        MouseArea {
                            id: rowMouseArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            propagateComposedEvents: true

                            onDoubleClicked: function(mouse) {
                                handleDoubleClick(indexOutside);
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                listView.currentIndex = indexOutside;
                                listView.forceActiveFocus();
                                mouse.accepted = false;
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

                                    onLoaded: {
                                        const bgKey = roleName + "_bgcolor";
                                        item.roleName = roleName;
                                        item.rowIndex = rowIndex;
                                        item.colWidth = colWidth;
                                        item.bgColor = uebungModel.get(rowIndex)[bgKey] || "white";
                                    }

                                    Connections {
                                        target: uebungModel

                                        // 🔧 Diese beiden musst du lokal speichern
                                        property string roleNameCopy: roleName
                                        property int rowIndexCopy: rowIndex

                                        function onDataChanged(index, roles) {
                                            const realIndex = (typeof index === "object" && typeof index.row === "number") ? index.row : index;

                                            if (realIndex === rowIndexCopy && item) {
                                                const bgKey = roleNameCopy + "_bgcolor";
                                                item.bgColor = uebungModel.get(rowIndexCopy)[bgKey] || "white";
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
                            editExersizeDialog.itemData = JSON.parse(JSON.stringify(uebungModel.get(listView.currentIndex)));
                            editExersizeDialog.open();
                        }
                    }
                }

                Button {
                    text: "Hinzufügen"
                    onClicked: uebungModel.append({})
                }

                Button {
                    text: "Löschen"
                    onClicked: {
                        if (listView.currentIndex >= 0) {
                            uebungModel.remove(listView.currentIndex);
                            // Aktualisiere die ListView
                            listView.model = null;
                            listView.model = uebungModel;
                        }
                    }
                }
                Button {
                    text: "Check Websites"
                    onClicked: {
                        for (let i = 0; i < uebungModel.count; i++) {
                            ["infoURLFrage", "infoURLAntwort"].forEach(function(role) {
                                let url = uebungModel.get(i)[role];
                                if (url && url.trim() !== "") {
                                    checkWebsite(url, i, role);
                                }
                            });
                        }
                    }
                }
            }

            // Spacer in der Mitte
            Item { Layout.fillWidth: true }

            // Rechtsbündige Buttons
            Button {
                text: "Speichern"
                icon.name: "save"
                onClicked: {
                    var data = {
                        name: uebungenNameField.text,
                        frageText: frageTextField.text,
                        frageTextUmgekehrt: frageTextUmgekehrtField.text,
                        sequentiell: sequentiellCheckBox.checked,
                        umgekehrt: umgekehrtCheckBox.checked,
                        uebungsliste: []
                    }

                    for (var i = 0; i < uebungModel.count; ++i) {
                        let eintrag = JSON.parse(JSON.stringify(uebungModel.get(i)));
                        delete eintrag[""];
                        data.uebungsliste.push(eintrag);
                    }

                    console.log("📦 Zu speichernde Daten:", JSON.stringify(data, null, 2));

                    const result = ExersizeLoader.savePackage(packagePath, data);
                    if (!result) {
                        console.warn("❌ Speichern fehlgeschlagen!");
                    } else {
                        console.log("✅ Speichern erfolgreich.");
                        dialogWindow.close();
                    }
                }
            }

            Button {
                enabled: true
                text: "Neu anlegen"
                onClicked: csvFileDialog.open()
            }
        }
    }

}
