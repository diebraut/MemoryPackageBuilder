// ThreePaneSplitter.qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property real splitterRatio1: 0.33
    property real splitterRatio2: 0.66
    property bool isVertical: true
    property int selectedPartIndex: 1

    property real borderMargin: 3
    property real gapToSplitter: 2

    signal partClicked(int index)

    // === PART 1 ===
    Item {
        id: part1Wrapper
        x: borderMargin
        y: borderMargin
        width: isVertical ?
               (root.width - 2 * borderMargin) * splitterRatio1 :
               root.width - 2 * borderMargin
        height: isVertical ?
                root.height - 2 * borderMargin :
                (root.height - 2 * borderMargin) * splitterRatio1

        Rectangle {
            anchors.fill: parent
            color: "#ffffff"

            MouseArea {
                anchors.fill: parent
                onClicked: root.partClicked(1)
            }

            Text {
                anchors.centerIn: parent
                text: "1"
                font.pixelSize: 48
                z: 0
            }

            Rectangle {
                anchors.fill: parent
                visible: selectedPartIndex === 1
                color: "transparent"
                border.color: "#0077ff"
                border.width: 3
                z: 1
                anchors.rightMargin: isVertical ? gapToSplitter : 0
                anchors.bottomMargin: isVertical ? 0 : gapToSplitter
            }
        }
    }

    // === PART 2 ===
    Item {
        id: part2Wrapper
        x: isVertical ?
           borderMargin + (root.width - 2 * borderMargin) * splitterRatio1 + splitter1.width :
           borderMargin
        y: isVertical ?
           borderMargin :
           borderMargin + (root.height - 2 * borderMargin) * splitterRatio1 + splitter1.height
        width: isVertical ?
               (root.width - 2 * borderMargin) * (splitterRatio2 - splitterRatio1) - splitter1.width :
               root.width - 2 * borderMargin
        height: isVertical ?
                root.height - 2 * borderMargin :
                (root.height - 2 * borderMargin) * (splitterRatio2 - splitterRatio1) - splitter1.height

        Rectangle {
            anchors.fill: parent
            color: "#ffffff"

            MouseArea {
                anchors.fill: parent
                onClicked: root.partClicked(2)
            }

            Text {
                anchors.centerIn: parent
                text: "2"
                font.pixelSize: 48
                z: 0
            }

            Rectangle {
                anchors.fill: parent
                visible: selectedPartIndex === 2
                color: "transparent"
                border.color: "#0077ff"
                border.width: 3
                z: 1
                anchors.leftMargin: isVertical ? gapToSplitter : 0
                anchors.rightMargin: isVertical ? gapToSplitter : 0
                anchors.topMargin: isVertical ? 0 : gapToSplitter
                anchors.bottomMargin: isVertical ? 0 : gapToSplitter
            }
        }
    }

    // === PART 3 ===
    Item {
        id: part3Wrapper
        x: isVertical ?
           borderMargin + (root.width - 2 * borderMargin) * splitterRatio2 + splitter2.width :
           borderMargin
        y: isVertical ?
           borderMargin :
           borderMargin + (root.height - 2 * borderMargin) * splitterRatio2 + splitter2.height
        width: isVertical ?
               root.width - x - borderMargin :
               root.width - 2 * borderMargin
        height: isVertical ?
                root.height - 2 * borderMargin :
                root.height - y - borderMargin

        Rectangle {
            anchors.fill: parent
            color: "#ffffff"

            MouseArea {
                anchors.fill: parent
                onClicked: root.partClicked(3)
            }

            Text {
                anchors.centerIn: parent
                text: "3"
                font.pixelSize: 48
                z: 0
            }

            Rectangle {
                anchors.fill: parent
                visible: selectedPartIndex === 3
                color: "transparent"
                border.color: "#0077ff"
                border.width: 3
                z: 1
                anchors.leftMargin: isVertical ? gapToSplitter : 0
                anchors.topMargin: isVertical ? 0 : gapToSplitter
            }
        }
    }

    // === SPLITTER 1 ===
    Rectangle {
        id: splitter1
        width: isVertical ? 4 : root.width - 2 * borderMargin
        height: isVertical ? root.height - 2 * borderMargin : 4
        x: isVertical ? borderMargin + (root.width - 2 * borderMargin) * splitterRatio1 : borderMargin
        y: isVertical ? borderMargin : borderMargin + (root.height - 2 * borderMargin) * splitterRatio1
        color: "black"
        z: 10

        MouseArea {
            anchors.fill: parent
            cursorShape: isVertical ? Qt.SplitHCursor : Qt.SplitVCursor
            drag.axis: isVertical ? Drag.XAxis : Drag.YAxis
            drag.target: parent
            drag.minimumX: borderMargin + 40
            drag.maximumX: root.width * splitterRatio2 - 40
            drag.minimumY: borderMargin + 40
            drag.maximumY: root.height * splitterRatio2 - 40

            onPositionChanged: {
                if (isVertical)
                    splitterRatio1 = (splitter1.x - borderMargin) / (root.width - 2 * borderMargin)
                else
                    splitterRatio1 = (splitter1.y - borderMargin) / (root.height - 2 * borderMargin)
            }
        }
    }

    // === SPLITTER 2 ===
    Rectangle {
        id: splitter2
        width: isVertical ? 4 : root.width - 2 * borderMargin
        height: isVertical ? root.height - 2 * borderMargin : 4
        x: isVertical ? borderMargin + (root.width - 2 * borderMargin) * splitterRatio2 : borderMargin
        y: isVertical ? borderMargin : borderMargin + (root.height - 2 * borderMargin) * splitterRatio2
        color: "black"
        z: 10

        MouseArea {
            anchors.fill: parent
            cursorShape: isVertical ? Qt.SplitHCursor : Qt.SplitVCursor
            drag.axis: isVertical ? Drag.XAxis : Drag.YAxis
            drag.target: parent
            drag.minimumX: borderMargin + (root.width - 2 * borderMargin) * splitterRatio1 + 40
            drag.maximumX: root.width - borderMargin - 40
            drag.minimumY: borderMargin + (root.height - 2 * borderMargin) * splitterRatio1 + 40
            drag.maximumY: root.height - borderMargin - 40

            onPositionChanged: {
                if (isVertical)
                    splitterRatio2 = (splitter2.x - borderMargin) / (root.width - 2 * borderMargin)
                else
                    splitterRatio2 = (splitter2.y - borderMargin) / (root.height - 2 * borderMargin)
            }
        }
    }
}
