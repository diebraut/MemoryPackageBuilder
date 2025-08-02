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

    function toFileUrl(path) {
        if (path.startsWith("file://") || path.startsWith("qrc:/"))
            return path;
        return "file:///" + path.replace(/\\/g, "/");
    }

    function loadImageInCurrentMode(filePath) {
        console.log("\ud83d\udcc5 Lade Bild in Composer:", filePath);
        if (!filePath || filePath === "")
            return;

        const url = toFileUrl(filePath);

        switch (anzeigeZustand) {
            case 1:
                singleImage.source = url;
                break;
            case 2:
                if (twoSplitter)
                    twoSplitter.setImageForPart(selectedPartIndex, url);
                break;
            case 3:
                if (threeSplitter)
                    threeSplitter.setImageForPart(selectedPartIndex, url);
                break;
            default:
                console.warn("❗ Ungültiger Anzeigestatus:", anzeigeZustand);
        }
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
            Image {
                id: singleImage
                anchors.fill: parent

                visible: anzeigeZustand === 1
                fillMode: Image.PreserveAspectFit
            }

            TwoPaneSplitter {
                id: twoSplitter
                visible: anzeigeZustand === 2
                anchors.fill: parent

                isVertical: composerWindow.isVertical
                splitterRatio: composerWindow.splitterRatio
                selectedPartIndex: composerWindow.selectedPartIndex

                onPartClicked: (index) => composerWindow.selectedPartIndex = index
                onSplitterRatioChanged: composerWindow.splitterRatio = splitterRatio
            }
            ThreePanelSplitter {
                id: threeSplitter
                visible: anzeigeZustand === 3
                anchors.fill: parent

                layoutMode: composerWindow.layoutMode
                isVertical: composerWindow.isVertical
                splitterRatio1: composerWindow.splitterRatio1
                splitterRatio2: composerWindow.splitterRatio2
                layout1_splitX: composerWindow.layout1_splitX
                layout1_splitY: composerWindow.layout1_splitY
                layout2_splitX: composerWindow.layout2_splitX
                layout2_splitY: composerWindow.layout2_splitY
                selectedPartIndex: composerWindow.selectedPartIndex

                onPartClicked: (index) => composerWindow.selectedPartIndex = index
                onSplitterRatio1Changed: composerWindow.splitterRatio1 = splitterRatio1
                onSplitterRatio2Changed: composerWindow.splitterRatio2 = splitterRatio2
                onLayout1_splitXChanged: composerWindow.layout1_splitX = layout1_splitX
                onLayout1_splitYChanged: composerWindow.layout1_splitY = layout1_splitY
                onLayout2_splitXChanged: composerWindow.layout2_splitX = layout2_splitX
                onLayout2_splitYChanged: composerWindow.layout2_splitY = layout2_splitY
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
