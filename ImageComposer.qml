import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: composerWindow
    width: 600
    height: 300
    visible: true
    title: "ImageComposer"
    flags: Qt.FramelessWindowHint | Qt.Window

    property int anzeigeZustand: 3
    property int selectedPartIndex: 1  // Standard: Teil 1

    property int layoutMode: 0
    property bool isVertical: true

    property real splitterRatio: 0.5
    property real splitterRatio1: 0.33
    property real splitterRatio2: 0.66

    property real layout1_splitX: 0.5
    property real layout1_splitY: 0.5
    property real layout2_splitY: 0.5
    property real layout2_splitX: 0.5

    signal modeSelected(string type)

    FontMetrics { id: menuFont }

    property Window parentWindow
    property bool lastParentActive: false
    property bool wasPositioned: false

    Component.onCompleted: {
        Qt.callLater(() => {
            splitterRatio = 0.5;
            splitterRatio1 = 0.33;
            splitterRatio2 = 0.66;
        });
    }

    // Eigene minimalistische Titelzeile
    Rectangle {
        id: titleBar
        width: parent.width
        height: 32
        color: "#d6d6d6"
        border.color: "#bbb"
        border.width: 1

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            text: composerWindow.title
            color: "#222"
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    composerWindow.startSystemMove()
                }
            }
        }
    }
    // Sichtbarkeit an Hauptfenster-Zustand binden
    Connections {
        target: parentWindow
        function onVisibilityChanged() {
            if (parentWindow.visibility === Window.Minimized) {
                composerWindow.visible = false
            } else {
                composerWindow.visible = true
            }
        }
    }

    // Immer über dem Hauptfenster bleiben ohne Fokus zu stehlen
    Connections {
        target: parentWindow
        function onActiveChanged() {
            if (parentWindow.active) {
                // Bringt das Fenster nach vorne ohne Fokus zu stehlen
                composerWindow.raise()
            }
        }
    }

    Menu {
        id: customContextMenu
        property var dynamicItems: []
        property var custLength
        width: custLength
    }

    Component {
        id: dynamicMenuItem
        MenuItem { }
    }

    MouseArea {
        id: dragArea
        anchors.top: parent.top
        width: parent.width
        height: 40   // Höhe der "Titelleiste", die du greifen kannst
        drag.target: null
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                composerWindow.startSystemMove();
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton && anzeigeZustand > 1) {
                // 1. Vorherige Items entfernen
                for (let i = 0; i < customContextMenu.dynamicItems.length; ++i)
                    customContextMenu.dynamicItems[i].destroy();
                customContextMenu.dynamicItems = [];

                // 2. Kontextmenüeinträge bestimmen
                let texts = [];
                if (anzeigeZustand === 2) {
                    texts = ["Zweiteilung Vertikal", "Zweiteilung Horizontal"];
                } else if (anzeigeZustand === 3) {
                    texts = [
                        "Dreiteilung Vertikal",
                        "Dreiteilung Horizontal",
                        "Dreiteilung: 2 Oben, 1 Unten",
                        "Dreiteilung: 1 Unten, 2 Oben"
                    ];
                }

                // 3. Maximale Textbreite berechnen
                let maxTextWidth = 0;
                for (let y = 0; y < texts.length; ++y) {
                    const w = menuFont.boundingRect(texts[y]).width;
                    if (w > maxTextWidth) maxTextWidth = w;
                }
                customContextMenu.custLength = maxTextWidth + 20;

                // 4. Items hinzufügen
                function add(text, fn) {
                    const item = dynamicMenuItem.createObject(null, {
                        text: text
                        //implicitWidth: itemWidth
                    });
                    item.onTriggered.connect(fn);
                    customContextMenu.addItem(item);
                    customContextMenu.dynamicItems.push(item);
                }

                // 5. Items je nach Zustand hinzufügen
                if (anzeigeZustand === 2) {
                    add("Zweiteilung Vertikal", () => { isVertical = true; });
                    add("Zweiteilung Horizontal", () => { isVertical = false; });
                } else if (anzeigeZustand === 3) {
                    add("Dreiteilung Vertikal", () => { layoutMode = 0; isVertical = true; });
                    add("Dreiteilung Horizontal", () => { layoutMode = 0; isVertical = false; });
                    add("Dreiteilung: 2 Oben, 1 Unten", () => { layoutMode = 1; });
                    add("Dreiteilung: 1 Unten, 2 Oben", () => { layoutMode = 2; });
                }

                // 6. Menü anzeigen an Mausposition
                customContextMenu.popup(mouse.screenX, mouse.screenY);
            }
        }
    }

    // Inhalt unterhalb der Titelzeile
    Rectangle {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#f0f0f0"
        border.color: "#999"
        border.width: 1

        Rectangle {
            id: rootItem
            anchors.fill: parent
            color: "#f0f0f0"
            border.color: "#999"
            border.width: 1
            clip: false   // ⬅️ Wichtig! Damit Ränder sichtbar bleiben
            // ===================== ZWEITEILUNG =====================

            TwoPaneSplitter {
                visible: anzeigeZustand === 2
                anchors.fill: parent

                isVertical: composerWindow.isVertical
                splitterRatio: composerWindow.splitterRatio
                selectedPartIndex: composerWindow.selectedPartIndex

                onPartClicked: (index) => composerWindow.selectedPartIndex = index
                onSplitterRatioChanged: composerWindow.splitterRatio = splitterRatio
            }
            ThreePanelSplitter {
                visible: anzeigeZustand === 3 && layoutMode === 0
                anchors.fill: parent

                splitterRatio1: composerWindow.splitterRatio1
                splitterRatio2: composerWindow.splitterRatio2
                isVertical: composerWindow.isVertical
                selectedPartIndex: composerWindow.selectedPartIndex

                onPartClicked: (index) => composerWindow.selectedPartIndex = index

                onSplitterRatio1Changed: composerWindow.splitterRatio1 = splitterRatio1
                onSplitterRatio2Changed: composerWindow.splitterRatio2 = splitterRatio2
            }

            // ========== DREITEILUNG STANDARD (layoutMode = 0) ==========
            /*
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 0
                x: 0
                y: 0
                width: isVertical ? composerWindow.width * splitterRatio1 : parent.width
                height: isVertical ? parent.height : composerWindow.height * splitterRatio1
                color: "transparent"
                Text { anchors.centerIn: parent; text: "1"; font.pixelSize: 48 }
            }

            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 0
                x: isVertical ? composerWindow.width * splitterRatio1 + tripleSplitter1.width : 0
                y: isVertical ? 0 : composerWindow.height * splitterRatio1 + tripleSplitter1.height
                width: isVertical ? composerWindow.width * (splitterRatio2 - splitterRatio1) - tripleSplitter1.width : parent.width
                height: isVertical ? parent.height : composerWindow.height * (splitterRatio2 - splitterRatio1) - tripleSplitter1.height
                color: "transparent"
                Text { anchors.centerIn: parent; text: "2"; font.pixelSize: 48 }
            }

            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 0
                x: isVertical ? composerWindow.width * splitterRatio2 + tripleSplitter2.width : 0
                y: isVertical ? 0 : composerWindow.height * splitterRatio2 + tripleSplitter2.height
                width: isVertical ? composerWindow.width - x : parent.width
                height: isVertical ? parent.height : composerWindow.height - y
                color: "transparent"
                Text { anchors.centerIn: parent; text: "3"; font.pixelSize: 48 }
            }

            Rectangle {
                id: tripleSplitter1
                visible: anzeigeZustand === 3 && layoutMode === 0
                width: isVertical ? 4 : parent.width
                height: isVertical ? parent.height : 4
                x: isVertical ? composerWindow.width * splitterRatio1 : 0
                y: isVertical ? 0 : composerWindow.height * splitterRatio1
                color: "black"
                z: 10

                MouseArea {
                    anchors.fill: parent
                    cursorShape: isVertical ? Qt.SplitHCursor : Qt.SplitVCursor
                    drag.target: parent
                    drag.axis: isVertical ? Drag.XAxis : Drag.YAxis
                    drag.minimumX: 40
                    drag.maximumX: composerWindow.width * splitterRatio2 - 40
                    drag.minimumY: 40
                    drag.maximumY: composerWindow.height * splitterRatio2 - 40
                    onPositionChanged: {
                        if (isVertical)
                            splitterRatio1 = tripleSplitter1.x / composerWindow.width
                        else
                            splitterRatio1 = tripleSplitter1.y / composerWindow.height
                    }
                }
            }

            Rectangle {
                id: tripleSplitter2
                visible: anzeigeZustand === 3 && layoutMode === 0
                width: isVertical ? 4 : parent.width
                height: isVertical ? parent.height : 4
                x: isVertical ? composerWindow.width * splitterRatio2 : 0
                y: isVertical ? 0 : composerWindow.height * splitterRatio2
                color: "black"
                z: 10

                MouseArea {
                    anchors.fill: parent
                    cursorShape: isVertical ? Qt.SplitHCursor : Qt.SplitVCursor
                    drag.target: parent
                    drag.axis: isVertical ? Drag.XAxis : Drag.YAxis
                    drag.minimumX: composerWindow.width * splitterRatio1 + 40
                    drag.maximumX: composerWindow.width - 40
                    drag.minimumY: composerWindow.height * splitterRatio1 + 40
                    drag.maximumY: composerWindow.height - 40
                    onPositionChanged: {
                        if (isVertical)
                            splitterRatio2 = tripleSplitter2.x / composerWindow.width
                        else
                            splitterRatio2 = tripleSplitter2.y / composerWindow.height
                    }
                }
            }
            */
            // ========== DREITEILUNG layoutMode 1: 2 oben, 1 unten ==========
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 1
                width: composerWindow.width * layout1_splitX - 2
                height: composerWindow.height * layout1_splitY - 2
                x: 0
                y: 0
                color: "transparent"
                Text { anchors.centerIn: parent; text: "1"; font.pixelSize: 48 }
            }

            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 1
                width: composerWindow.width * (1 - layout1_splitX) - 2
                height: composerWindow.height * layout1_splitY - 2
                x: composerWindow.width * layout1_splitX + 2
                y: 0
                color: "transparent"
                Text { anchors.centerIn: parent; text: "2"; font.pixelSize: 48 }
            }

            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 1
                x: 0
                y: composerWindow.height * layout1_splitY + 2
                width: composerWindow.width
                height: composerWindow.height * (1 - layout1_splitY) - 4
                color: "transparent"
                Text { anchors.centerIn: parent; text: "3"; font.pixelSize: 48 }
            }

            // Vertikale Trennlinie oben
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 1
                x: composerWindow.width * layout1_splitX - 2
                y: 0
                width: 4
                height: composerWindow.height * layout1_splitY - 2
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 40
                    drag.maximumX: composerWindow.width - 40
                    onPositionChanged: layout1_splitX = parent.x / composerWindow.width
                }
            }

            // Horizontale Trennlinie
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 1
                x: 0
                y: composerWindow.height * layout1_splitY - 2
                width: composerWindow.width
                height: 4
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitVCursor
                    drag.target: parent
                    drag.axis: Drag.YAxis
                    drag.minimumY: 40
                    drag.maximumY: composerWindow.height - 40
                    onPositionChanged: layout1_splitY = parent.y / composerWindow.height
                }
            }

            // ========== DREITEILUNG layoutMode 2: 1 oben, 2 unten ==========
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 2
                x: 0
                y: 0
                width: composerWindow.width
                height: composerWindow.height * layout2_splitY - 2
                color: "transparent"
                Text { anchors.centerIn: parent; text: "1"; font.pixelSize: 48 }
            }

            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 2
                width: composerWindow.width * layout2_splitX - 2
                height: composerWindow.height * (1 - layout2_splitY) - 2
                x: 0
                y: composerWindow.height * layout2_splitY + 2
                color: "transparent"
                Text { anchors.centerIn: parent; text: "2"; font.pixelSize: 48 }
            }

            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 2
                width: composerWindow.width * (1 - layout2_splitX) - 2
                height: composerWindow.height * (1 - layout2_splitY) - 2
                x: composerWindow.width * layout2_splitX + 2
                y: composerWindow.height * layout2_splitY + 2
                color: "transparent"
                Text { anchors.centerIn: parent; text: "3"; font.pixelSize: 48 }
            }

            // Horizontale Trennlinie
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 2
                x: 0
                y: composerWindow.height * layout2_splitY - 2
                width: composerWindow.width
                height: 4
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitVCursor
                    drag.target: parent
                    drag.axis: Drag.YAxis
                    drag.minimumY: 40
                    drag.maximumY: composerWindow.height - 40
                    onPositionChanged: layout2_splitY = parent.y / composerWindow.height
                }
            }

            // Vertikale Trennlinie unten
            Rectangle {
                visible: anzeigeZustand === 3 && layoutMode === 2
                x: composerWindow.width * layout2_splitX - 2
                y: composerWindow.height * layout2_splitY + 2
                width: 4
                height: composerWindow.height * (1 - layout2_splitY) - 2
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor
                    drag.target: parent
                    drag.axis: Drag.XAxis
                    drag.minimumX: 40
                    drag.maximumX: composerWindow.width - 40
                    onPositionChanged: layout2_splitX = parent.x / composerWindow.width
                }
            }

            // Flackerfreier rechter Rand (systemeigenes Resizing)
            MouseArea {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 6
                cursorShape: Qt.SizeHorCursor
                z: 9999

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.RightEdge)
                }
            }

            // Zusätzliche Resize-Handler für andere Kanten/Ecken
            // Oben
            MouseArea {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                cursorShape: Qt.SizeVerCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.TopEdge)
                }
            }

            // Unten
            MouseArea {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 6
                cursorShape: Qt.SizeVerCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.BottomEdge)
                }
            }

            // Links
            MouseArea {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 6
                cursorShape: Qt.SizeHorCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.LeftEdge)
                }
            }

            // Ecken
            MouseArea { // Top-Left
                anchors.top: parent.top
                anchors.left: parent.left
                width: 10
                height: 10
                cursorShape: Qt.SizeFDiagCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.TopEdge | Qt.LeftEdge)
                }
            }

            MouseArea { // Top-Right
                anchors.top: parent.top
                anchors.right: parent.right
                width: 10
                height: 10
                cursorShape: Qt.SizeBDiagCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.TopEdge | Qt.RightEdge)
                }
            }

            MouseArea { // Bottom-Left
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: 10
                height: 10
                cursorShape: Qt.SizeBDiagCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.BottomEdge | Qt.LeftEdge)
                }
            }

            MouseArea { // Bottom-Right
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 10
                height: 10
                cursorShape: Qt.SizeFDiagCursor

                onPressed: function(mouse) {
                    if (mouse.button === Qt.LeftButton)
                        composerWindow.startSystemResize(Qt.BottomEdge | Qt.RightEdge)
                }
            }
        }
    }
}
