// RefactoredMultiLayout.qml
// RefactoredMultiLayout.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import "." // For PartView and Splitter

Item {
    id: root

    property int layoutMode: 0 // 0: vert/horiz | 1: 2 oben | 2: 2 unten
    property bool isVertical: true

    property real splitterRatio1: 0.33
    property real splitterRatio2: 0.66
    property real layout1_splitX: 0.5
    property real layout1_splitY: 0.5
    property real layout2_splitX: 0.5
    property real layout2_splitY: 0.5

    property int selectedPartIndex: 1
    property real borderMargin: 3
    property real gapToSplitter: 2
    property real splitterSize: 4 // Splitter width/height

    signal partClicked(int index)

    function setImageForPart(index, filePath) {
        if (layoutLoader.item && layoutLoader.item.setImageForPart)
            layoutLoader.item.setImageForPart(index, filePath)
        else
            console.warn("setImageForPart not available for current layout")
    }

    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: layoutMode === 0 ? layout0Component
                          : layoutMode === 1 ? layout1Component
                          : layout2Component
    }

    // === Layout 0 ===
    Component {
        id: layout0Component
        Item {
            id: layout0

            function setImageForPart(index, filePath) {
                if (index === 1) part1View.image.source = filePath;
                else if (index === 2) part2View.image.source = filePath;
                else if (index === 3) part3View.image.source = filePath;
            }

            // Common calculations for vertical and horizontal layouts
            readonly property real totalContentWidth: parent.width - 2 * root.borderMargin - 2 * root.splitterSize
            readonly property real totalContentHeight: parent.height - 2 * root.borderMargin - 2 * root.splitterSize

            PartView {
                id: part1View
                index: 1
                label: "1"
                selected: root.selectedPartIndex === 1
                onClicked: (idx) => root.partClicked(idx)
                x: root.borderMargin
                y: root.borderMargin
                width: isVertical ? totalContentWidth * root.splitterRatio1 : parent.width - 2 * root.borderMargin
                height: isVertical ? parent.height - 2 * root.borderMargin : totalContentHeight * root.splitterRatio1

                // Apply consistent margins based on position
                marginRight: isVertical ? root.gapToSplitter : 0
                marginBottom: isVertical ? 0 : root.gapToSplitter
            }

            Splitter {
                id: splitter1
                isVertical: root.isVertical
                value: root.splitterRatio1
                valueChangedHandler: (val) => root.splitterRatio1 = val
                x: isVertical ? part1View.x + part1View.width : root.borderMargin
                y: isVertical ? root.borderMargin : part1View.y + part1View.height
                width: isVertical ? root.splitterSize : parent.width - 2 * root.borderMargin
                height: isVertical ? parent.height - 2 * root.borderMargin : root.splitterSize
            }

            PartView {
                id: part2View
                index: 2
                label: "2"
                selected: root.selectedPartIndex === 2
                onClicked: (idx) => root.partClicked(idx)
                x: isVertical ? splitter1.x + splitter1.width : root.borderMargin
                y: isVertical ? root.borderMargin : splitter1.y + splitter1.height
                width: isVertical ? totalContentWidth * (root.splitterRatio2 - root.splitterRatio1) : parent.width - 2 * root.borderMargin
                height: isVertical ? parent.height - 2 * root.borderMargin : totalContentHeight * (root.splitterRatio2 - root.splitterRatio1)

                // Apply consistent margins based on position
                marginLeft: isVertical ? root.gapToSplitter : 0
                marginRight: isVertical ? root.gapToSplitter : 0
                marginBottom: isVertical ? 0 : root.gapToSplitter
            }

            Splitter {
                id: splitter2
                isVertical: root.isVertical
                value: root.splitterRatio2
                valueChangedHandler: (val) => root.splitterRatio2 = val
                x: isVertical ? part2View.x + part2View.width : root.borderMargin
                y: isVertical ? root.borderMargin : part2View.y + part2View.height
                width: isVertical ? root.splitterSize : parent.width - 2 * root.borderMargin
                height: isVertical ? parent.height - 2 * root.borderMargin : root.splitterSize
            }

            PartView {
                id: part3View
                index: 3
                label: "3"
                selected: root.selectedPartIndex === 3
                onClicked: (idx) => root.partClicked(idx)
                x: isVertical ? splitter2.x + splitter2.width : root.borderMargin
                y: isVertical ? root.borderMargin : splitter2.y + splitter2.height
                width: isVertical ? totalContentWidth * (1 - root.splitterRatio2) : parent.width - 2 * root.borderMargin
                height: isVertical ? parent.height - 2 * root.borderMargin : totalContentHeight * (1 - root.splitterRatio2)

                // Apply consistent margins based on position
                marginLeft: isVertical ? root.gapToSplitter : 0
                marginTop: isVertical ? 0 : root.gapToSplitter
            }
        }
    }

    // Layout 1 and 2 remain unchanged...
    // Rest des Codes (Layout 1 und 2) unverändert lassen...
    Component {
        id: layout1Component
        Item {
            function setImageForPart(index, filePath) {}

            PartView {
                id: part1L1
                index: 1
                label: "1"
                selected: root.selectedPartIndex === 1
                onClicked: (idx) => root.partClicked(idx)
                x: root.borderMargin
                y: root.borderMargin
                width: (parent.width - 2 * root.borderMargin) * root.layout1_splitX - 2
                height: (parent.height - 2 * root.borderMargin) * root.layout1_splitY - 2
                marginRight: root.gapToSplitter
                marginBottom: root.gapToSplitter
            }

            PartView {
                id: part2L1
                index: 2
                label: "2"
                selected: root.selectedPartIndex === 2
                onClicked: (idx) => root.partClicked(idx)
                x: part1L1.x + part1L1.width + 4
                y: root.borderMargin
                width: (parent.width - 2 * root.borderMargin) * (1 - root.layout1_splitX) - 2
                height: part1L1.height
                marginLeft: root.gapToSplitter
                marginBottom: root.gapToSplitter
            }

            PartView {
                id: part3L1
                index: 3
                label: "3"
                selected: root.selectedPartIndex === 3
                onClicked: (idx) => root.partClicked(idx)
                x: root.borderMargin
                y: part1L1.y + part1L1.height + 4
                width: parent.width - 2 * root.borderMargin
                height: parent.height - y - root.borderMargin
                marginTop: root.gapToSplitter
            }

            Splitter {
                id: splitter1L1
                isVertical: true
                value: root.layout1_splitX
                valueChangedHandler: (val) => root.layout1_splitX = val
                x: part1L1.x + part1L1.width
                y: part1L1.y
                height: part1L1.height
            }

            Splitter {
                id: splitter2L1
                isVertical: false
                value: root.layout1_splitY
                valueChangedHandler: (val) => root.layout1_splitY = val
                x: root.borderMargin
                y: part1L1.y + part1L1.height
                width: parent.width - 2 * root.borderMargin
            }
        }
    }

    // === Layout 2 ===
    Component {
        id: layout2Component
        Item {
            function setImageForPart(index, filePath) {}

            PartView {
                id: part1L2
                index: 1
                label: "1"
                selected: root.selectedPartIndex === 1
                onClicked: (idx) => root.partClicked(idx)
                x: root.borderMargin
                y: root.borderMargin
                width: parent.width - 2 * root.borderMargin
                height: (parent.height - 2 * root.borderMargin) * root.layout2_splitY - 2
                marginBottom: root.gapToSplitter
            }

            PartView {
                id: part2L2
                index: 2
                label: "2"
                selected: root.selectedPartIndex === 2
                onClicked: (idx) => root.partClicked(idx)
                x: root.borderMargin
                y: part1L2.y + part1L2.height + 4
                width: (parent.width - 2 * root.borderMargin) * root.layout2_splitX - 2
                height: parent.height - y - root.borderMargin
                marginRight: root.gapToSplitter
                marginTop: root.gapToSplitter
            }

            PartView {
                id: part3L2
                index: 3
                label: "3"
                selected: root.selectedPartIndex === 3
                onClicked: (idx) => root.partClicked(idx)
                x: part2L2.x + part2L2.width + 4
                y: part2L2.y
                width: parent.width - x - root.borderMargin
                height: part2L2.height
                marginLeft: root.gapToSplitter
                marginTop: root.gapToSplitter
            }

            Splitter {
                id: splitter1L2
                isVertical: false
                value: root.layout2_splitY
                valueChangedHandler: (val) => root.layout2_splitY = val
                x: root.borderMargin
                y: part1L2.y + part1L2.height
                width: parent.width - 2 * root.borderMargin
            }

            Splitter {
                id: splitter2L2
                isVertical: true
                value: root.layout2_splitX
                valueChangedHandler: (val) => root.layout2_splitX = val
                x: part2L2.x + part2L2.width
                y: part2L2.y
                height: part2L2.height
            }
        }
    }
}
