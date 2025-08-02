// Splitter.qml
import QtQuick 2.15

Rectangle {
    id: splitter

    property bool isVertical: true           // Ausrichtung
    property real value: 0.5                 // Verhältnis (0–1), muss von außen verarbeitet werden
    property var valueChangedHandler: function(val) {}

    width: isVertical ? 4 : parent.width
    height: isVertical ? parent.height : 4
    color: Qt.rgba(0.2, 0.2, 0.2, 0.9)
    z: 10

    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: isVertical ? Qt.SplitHCursor : Qt.SplitVCursor
        drag.target: parent
        drag.axis: isVertical ? Drag.XAxis : Drag.YAxis

        onPositionChanged: {
            const size = isVertical ? parent.parent.width : parent.parent.height
            const pos = isVertical ? parent.x : parent.y
            const min = 40
            const max = size - 40
            const clamped = Math.max(min, Math.min(max, pos))
            splitter.value = (clamped - 0) / size  // falls du Offset brauchst, passe hier an

            if (valueChangedHandler) valueChangedHandler(splitter.value)
        }
    }
}
