import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property int layoutMode: 0           // 0: vert/horz | 1: 2 oben | 2: 2 unten
    property bool isVertical: true

    // Layout 0 (klassisch)
    property real splitterRatio1: 0.33
    property real splitterRatio2: 0.66

    // Layout 1 (2 oben, 1 unten)
    property real layout1_splitX: 0.5
    property real layout1_splitY: 0.5

    // Layout 2 (1 oben, 2 unten)
    property real layout2_splitX: 0.5
    property real layout2_splitY: 0.5

    property int selectedPartIndex: 1
    property real borderMargin: 3
    property real gapToSplitter: 2

    signal partClicked(int index)

    // === Loader je nach Layout-Mode ===
    Loader {
        anchors.fill: parent
        active: layoutMode === 0
        sourceComponent: layout0Component
    }

    Loader {
        anchors.fill: parent
        active: layoutMode === 1
        sourceComponent: layout1Component
    }

    Loader {
        anchors.fill: parent
        active: layoutMode === 2
        sourceComponent: layout2Component
    }

    // === Layout 0: klassisch vert/horiz Dreiteilung ===
    Component {
        id: layout0Component
        Item {
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
    }

    // === Layout 1: 2 oben, 1 unten ===
    Component {
        id: layout1Component
        Item {
            // === PART 1 (oben links) ===
            Item {
                id: part1
                x: borderMargin
                y: borderMargin
                width: (root.width - 2 * borderMargin) * layout1_splitX - 2
                height: (root.height - 2 * borderMargin) * layout1_splitY - 2

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
                        visible: selectedPartIndex === 1
                        color: "transparent"
                        border.color: "#0077ff"
                        border.width: 3
                        z: 1
                        anchors.rightMargin: gapToSplitter
                        anchors.bottomMargin: gapToSplitter
                    }
                }
            }

            // === PART 2 (oben rechts) ===
            Item {
                id: part2
                x: borderMargin + part1.width + splitter1.width
                y: borderMargin
                width: (root.width - 2 * borderMargin) * (1 - layout1_splitX) - 2
                height: part1.height

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
                        visible: selectedPartIndex === 2
                        color: "transparent"
                        border.color: "#0077ff"
                        border.width: 3
                        z: 1
                        anchors.leftMargin: gapToSplitter
                        anchors.bottomMargin: gapToSplitter
                    }
                }
            }

            // === PART 3 (unten) ===
            Item {
                id: part3
                x: borderMargin
                y: borderMargin + part1.height + splitter2.height
                width: root.width - 2 * borderMargin
                height: root.height - y - borderMargin

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
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: selectedPartIndex === 3
                        color: "transparent"
                        border.color: "#0077ff"
                        border.width: 3
                        z: 1
                        anchors.topMargin: gapToSplitter
                    }
                }
            }

            // === SPLITTER horizontal oben ===
            Rectangle {
                id: splitter1
                x: borderMargin + part1.width
                y: borderMargin
                width: 4
                height: part1.height
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor
                    drag.axis: Drag.XAxis
                    drag.target: parent
                    onPositionChanged: layout1_splitX = (parent.x - borderMargin) / (root.width - 2 * borderMargin)
                }
            }

            // === SPLITTER vertikal ===
            Rectangle {
                id: splitter2
                x: borderMargin
                y: borderMargin + part1.height
                width: root.width - 2 * borderMargin
                height: 4
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitVCursor
                    drag.axis: Drag.YAxis
                    drag.target: parent
                    onPositionChanged: layout1_splitY = (parent.y - borderMargin) / (root.height - 2 * borderMargin)
                }
            }
        }
    }

    // === Layout 2: 1 oben, 2 unten ===
    Component {
        id: layout2Component
        Item {
            // === PART 1 (oben) ===
            Item {
                id: part1
                x: borderMargin
                y: borderMargin
                width: root.width - 2 * borderMargin
                height: (root.height - 2 * borderMargin) * layout2_splitY - 2

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
                        visible: selectedPartIndex === 1
                        color: "transparent"
                        border.color: "#0077ff"
                        border.width: 3
                        z: 1
                        anchors.bottomMargin: gapToSplitter
                    }
                }
            }

            // === PART 2 (unten links) ===
            Item {
                id: part2
                x: borderMargin
                y: borderMargin + part1.height + splitter1.height
                width: (root.width - 2 * borderMargin) * layout2_splitX - 2
                height: root.height - y - borderMargin

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
                        visible: selectedPartIndex === 2
                        color: "transparent"
                        border.color: "#0077ff"
                        border.width: 3
                        z: 1
                        anchors.rightMargin: gapToSplitter
                        anchors.topMargin: gapToSplitter
                    }
                }
            }

            // === PART 3 (unten rechts) ===
            Item {
                id: part3
                x: borderMargin + part2.width + splitter2.width
                y: part2.y
                width: root.width - x - borderMargin
                height: part2.height

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
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: selectedPartIndex === 3
                        color: "transparent"
                        border.color: "#0077ff"
                        border.width: 3
                        z: 1
                        anchors.leftMargin: gapToSplitter
                        anchors.topMargin: gapToSplitter
                    }
                }
            }

            // === SPLITTER horizontal ===
            Rectangle {
                id: splitter1
                x: borderMargin
                y: borderMargin + part1.height
                width: root.width - 2 * borderMargin
                height: 4
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitVCursor
                    drag.axis: Drag.YAxis
                    drag.target: parent
                    onPositionChanged: layout2_splitY = (parent.y - borderMargin) / (root.height - 2 * borderMargin)
                }
            }

            // === SPLITTER vertikal unten ===
            Rectangle {
                id: splitter2
                x: borderMargin + part2.width
                y: part2.y
                width: 4
                height: part2.height
                color: "black"
                z: 10
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.SplitHCursor
                    drag.axis: Drag.XAxis
                    drag.target: parent
                    onPositionChanged: layout2_splitX = (parent.x - borderMargin) / (root.width - 2 * borderMargin)
                }
            }
        }
    }
}
