import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Window {
    id: composerWindow
    width: 600
    height: 300
    title: "ImageComposer"
    visible: true

    flags: Qt.Window | Qt.WindowTitleHint

    property int anzeigeZustand: 2   // 2 = Zwei Bereiche, 3 = Drei Bereiche
    property int layoutMode: 0       // 0 = Standard 3er-Layout, 1 = 2 oben / 1 unten, 2 = 1 oben / 2 unten
    property bool isVertical: true   // true = vertikal, false = horizontal

    property real splitterRatio: 0.5
    property real splitterRatio1: 0.33
    property real splitterRatio2: 0.66

    property real layout1_splitX: 0.5  // Mitte oben (zwischen Bereich 1 und 2)
    property real layout1_splitY: 0.5  // Mitte vertikal (zwischen oben und unten)

    property real layout2_splitY: 0.5  // Horizontale Trennlinie (zwischen 1 und 2/3)
    property real layout2_splitX: 0.5  // Vertikale Trennlinie (zwischen 2 und 3)


    signal modeSelected(string type)

    Menu {
        id: customContextMenu

        FontMetrics { id: menuFont }

        Component.onCompleted: adjustWidth()

        function adjustWidth() {
            let maxTextWidth = 0;
            const labels = [
                "Zweiteilung Vertikal", "Zweiteilung Horizontal",
                "Dreiteilung Vertikal", "Dreiteilung Horizontal",
                "Dreiteilung: 2 oben, 1 unten", "Dreiteilung: 1 oben, 2 unten"
            ];
            for (let label of labels) {
                const width = menuFont.boundingRect(label).width;
                if (width > maxTextWidth) maxTextWidth = width;
            }
            customContextMenu.width = maxTextWidth + 40;
        }

        MenuItem {
            text: "Zweiteilung Vertikal"
            width: customContextMenu.width
            onTriggered: {
                anzeigeZustand = 2;
                isVertical = true;
            }
        }

        MenuItem {
            text: "Zweiteilung Horizontal"
            width: customContextMenu.width
            onTriggered: {
                anzeigeZustand = 2;
                isVertical = false;
            }
        }

        MenuItem {
            text: "Dreiteilung Vertikal"
            width: customContextMenu.width
            onTriggered: {
                anzeigeZustand = 3;
                layoutMode = 0;
                isVertical = true;
            }
        }

        MenuItem {
            text: "Dreiteilung Horizontal"
            width: customContextMenu.width
            onTriggered: {
                anzeigeZustand = 3;
                layoutMode = 0;
                isVertical = false;
            }
        }

        MenuItem {
            text: "Dreiteilung: 2 oben, 1 unten"
            width: customContextMenu.width
            onTriggered: {
                anzeigeZustand = 3;
                layoutMode = 1;
            }
        }

        MenuItem {
            text: "Dreiteilung: 1 oben, 2 unten"
            width: customContextMenu.width
            onTriggered: {
                anzeigeZustand = 3;
                layoutMode = 2;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                customContextMenu.popup(mouse.x, mouse.y)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#f0f0f0"
        border.color: "#999"
        border.width: 1

        // ===================== ZWEITEILUNG =====================
        Rectangle {
            visible: anzeigeZustand === 2 && isVertical
            x: 0
            y: 0
            width: composerWindow.width * splitterRatio
            height: parent.height
            color: "transparent"
            Text { anchors.centerIn: parent; text: "1"; font.pixelSize: 48 }
        }

        Rectangle {
            visible: anzeigeZustand === 2 && isVertical
            x: composerWindow.width * splitterRatio + splitterLine.width
            y: 0
            width: composerWindow.width - x
            height: parent.height
            color: "transparent"
            Text { anchors.centerIn: parent; text: "2"; font.pixelSize: 48 }
        }

        Rectangle {
            id: splitterLine
            visible: anzeigeZustand === 2 && isVertical
            width: 4
            height: parent.height
            x: composerWindow.width * splitterRatio
            color: "black"
            z: 10

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SplitHCursor
                drag.target: parent
                drag.axis: Drag.XAxis
                drag.minimumX: 40
                drag.maximumX: composerWindow.width - 40
                onPositionChanged: splitterRatio = splitterLine.x / composerWindow.width
            }
        }

        Rectangle {
            visible: anzeigeZustand === 2 && !isVertical
            x: 0
            y: 0
            width: parent.width
            height: composerWindow.height * splitterRatio
            color: "transparent"
            Text { anchors.centerIn: parent; text: "1"; font.pixelSize: 48 }
        }

        Rectangle {
            visible: anzeigeZustand === 2 && !isVertical
            x: 0
            y: composerWindow.height * splitterRatio + hSplitterLine.height
            width: parent.width
            height: composerWindow.height - y
            color: "transparent"
            Text { anchors.centerIn: parent; text: "2"; font.pixelSize: 48 }
        }

        Rectangle {
            id: hSplitterLine
            visible: anzeigeZustand === 2 && !isVertical
            width: parent.width
            height: 4
            y: composerWindow.height * splitterRatio
            color: "black"
            z: 10

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.SplitVCursor
                drag.target: parent
                drag.axis: Drag.YAxis
                drag.minimumY: 40
                drag.maximumY: composerWindow.height - 40
                onPositionChanged: splitterRatio = hSplitterLine.y / composerWindow.height
            }
        }

        // ========== DREITEILUNG STANDARD (layoutMode = 0) ==========
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
    }
    Component.onCompleted: {
        Qt.callLater(() => {
            splitterRatio = 0.5;
            splitterRatio1 = 0.33;
            splitterRatio2 = 0.66;
        });
    }
}
