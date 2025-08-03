import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: composerWindow
    width: 1000
    height: 1000
    visible: true
    title: "ImageComposer"
    flags: Qt.FramelessWindowHint | Qt.Window

    property int anzeigeZustand: 1
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

    // Kann z. B. ganz oben im QML stehen
    QtObject {
        id: resizeConfigHelper
        property var edgeConfigs: [
            { pos: "right",  edge: Qt.RightEdge,  w: 6,  h: -1, cursor: Qt.SizeHorCursor },
            { pos: "left",   edge: Qt.LeftEdge,   w: 6,  h: -1, cursor: Qt.SizeHorCursor },
            { pos: "top",    edge: Qt.TopEdge,    w: -1, h: 6,  cursor: Qt.SizeVerCursor },
            { pos: "bottom", edge: Qt.BottomEdge, w: -1, h: 6,  cursor: Qt.SizeVerCursor },
            { pos: "topLeft",     edge: Qt.TopEdge | Qt.LeftEdge,    w: 10, h: 10, cursor: Qt.SizeFDiagCursor },
            { pos: "topRight",    edge: Qt.TopEdge | Qt.RightEdge,   w: 10, h: 10, cursor: Qt.SizeBDiagCursor },
            { pos: "bottomLeft",  edge: Qt.BottomEdge | Qt.LeftEdge, w: 10, h: 10, cursor: Qt.SizeBDiagCursor },
            { pos: "bottomRight", edge: Qt.BottomEdge | Qt.RightEdge,w: 10, h: 10, cursor: Qt.SizeFDiagCursor }
        ]
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
                singleImage.source = ""; // Reset
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
                cache: false  // 👈 wichtig

                visible: anzeigeZustand === 1
                fillMode: Image.PreserveAspectFit
            }

            TwoPanel {
                id: twoSplitter
                visible: anzeigeZustand === 2
                anchors.fill: parent

                isVertical: composerWindow.isVertical
                splitterRatio: composerWindow.splitterRatio
                selectedPartIndex: composerWindow.selectedPartIndex

                onPartClicked: (index) => composerWindow.selectedPartIndex = index
                onSplitterRatioChanged: composerWindow.splitterRatio = splitterRatio
            }
            ThreePanel {
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
            Repeater {
                model: resizeConfigHelper.edgeConfigs.length
                delegate: MouseArea {
                    property var conf: resizeConfigHelper.edgeConfigs[index]
                    width: conf.w > 0 ? conf.w : parent.width
                    height: conf.h > 0 ? conf.h : parent.height
                    cursorShape: conf.cursor

                    anchors {
                        top: conf.pos.indexOf("top") !== -1 ? parent.top : undefined
                        bottom: conf.pos.indexOf("bottom") !== -1 ? parent.bottom : undefined
                        left: conf.pos.indexOf("left") !== -1 ? parent.left : undefined
                        right: conf.pos.indexOf("right") !== -1 ? parent.right : undefined
                    }

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton) composerWindow.startSystemResize(conf.edge)
                    }
                }
            }
        }
    }
}
