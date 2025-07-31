import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property real splitterRatio: 0.5
    property bool isVertical: true
    property int selectedPartIndex: 1
    property real totalWidth: width
    property real totalHeight: height

    property real borderMargin: 3
    property real gapToSplitter: 2

    signal partClicked(int index)

    // === PART 1 ===
    Item {
        id: part1Wrapper
        x: borderMargin
        y: borderMargin
        width: root.isVertical ?
               (root.totalWidth - 2*borderMargin) * root.splitterRatio :
               root.totalWidth - 2*borderMargin
        height: root.isVertical ?
                root.totalHeight - 2*borderMargin :
                (root.totalHeight - 2*borderMargin) * root.splitterRatio

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
            }

            Rectangle {
                anchors.fill: parent
                visible: root.selectedPartIndex === 1
                color: "transparent"
                border.color: "#0077ff"
                border.width: 3
                anchors.rightMargin: root.isVertical ? gapToSplitter : 0
                anchors.bottomMargin: root.isVertical ? 0 : gapToSplitter
            }
        }
    }

    // === PART 2 ===
    Item {
        id: part2Wrapper
        x: root.isVertical ?
           (part1Wrapper.x + part1Wrapper.width + splitter.width) :
           borderMargin
        y: root.isVertical ?
           borderMargin :
           (part1Wrapper.y + part1Wrapper.height + splitter.height)
        width: root.isVertical ?
               root.totalWidth - x - borderMargin :
               root.totalWidth - 2*borderMargin
        height: root.isVertical ?
                root.totalHeight - 2*borderMargin :
                root.totalHeight - y - borderMargin

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
            }

            Rectangle {
                anchors.fill: parent
                visible: root.selectedPartIndex === 2
                color: "transparent"
                border.color: "#0077ff"
                border.width: 3
                anchors.leftMargin: root.isVertical ? gapToSplitter : 0
                anchors.topMargin: root.isVertical ? 0 : gapToSplitter
            }
        }
    }

    // === SPLITTER ===
    Rectangle {
        id: splitter
        width: root.isVertical ? 4 : root.totalWidth - 2*borderMargin
        height: root.isVertical ? root.totalHeight - 2*borderMargin : 4
        x: root.isVertical ?
           (part1Wrapper.x + part1Wrapper.width) :
           borderMargin
        y: root.isVertical ?
           borderMargin :
           (part1Wrapper.y + part1Wrapper.height)
        color: Qt.rgba(0.2, 0.2, 0.2, 0.8)  // 💡 leicht transparenter Splitter
        z: 10

        MouseArea {
            anchors.fill: parent
            cursorShape: root.isVertical ? Qt.SplitHCursor : Qt.SplitVCursor
            drag.target: parent
            drag.axis: root.isVertical ? Drag.XAxis : Drag.YAxis
            drag.minimumX: part1Wrapper.x + 40
            drag.maximumX: root.width - part1Wrapper.x - 40
            drag.minimumY: part1Wrapper.y + 40
            drag.maximumY: root.height - part1Wrapper.y - 40
            onPositionChanged: {
                if (root.isVertical)
                    root.splitterRatio = (splitter.x - borderMargin) / (root.totalWidth - 2*borderMargin)
                else
                    root.splitterRatio = (splitter.y - borderMargin) / (root.totalHeight - 2*borderMargin)
            }
        }
    }
}
