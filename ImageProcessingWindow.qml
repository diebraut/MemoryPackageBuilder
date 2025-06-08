import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Window {
    id: imageWindow
    title: "Bildbearbeitung"
    modality: Qt.ApplicationModal
    visible: false
    flags: Qt.Window | Qt.WindowTitleHint | Qt.WindowMinimizeButtonHint | Qt.WindowMaximizeButtonHint | Qt.WindowCloseButtonHint

    property alias imagePath: imagePreview.source
    signal accepted()
    signal rejected()

    property int maxDialogWidth: Screen.width * 0.9
    property int maxDialogHeight: Screen.height * 0.9

    function openWithImage(path) {
        imagePreview.source = path
        rectanglesModel.clear()

        imagePreview.statusChanged.connect(function handler() {
            if (imagePreview.status === Image.Ready) {
                var imgW = imagePreview.implicitWidth
                var imgH = imagePreview.implicitHeight

                var targetWidth = imgW * 1.1
                var targetHeight = imgH * 1.1 + buttonsRow.implicitHeight + layout.spacing

                imageWindow.width = Math.min(targetWidth, maxDialogWidth)
                imageWindow.height = Math.min(targetHeight, maxDialogHeight)

                imagePreview.statusChanged.disconnect(handler)
            }
        })

        visible = true
    }

    Component {
        id: resizeHandleComponent

        Rectangle {
            width: 16
            height: 16
            color: "white"
            border.color: "red"
            radius: 3
            z: 1000

            property string mode: ""
            property int modelIndex: -1
            property string cursor: "ArrowCursor"
            property Item targetRectItem: parent

            x: {
                switch(mode) {
                    case "topRight":
                    case "bottomRight":
                        return targetRectItem.width - width / 2;
                    case "topLeft":
                    case "bottomLeft":
                    default:
                        return -width / 2;
                }
            }

            y: {
                switch(mode) {
                    case "bottomLeft":
                    case "bottomRight":
                        return targetRectItem.height - height / 2;
                    case "topLeft":
                    case "topRight":
                    default:
                        return -height / 2;
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt[cursor]

                property real startMouseX: 0
                property real startMouseY: 0
                property real originalStartX: 0
                property real originalStartY: 0
                property real originalEndX: 0
                property real originalEndY: 0

                onPressed: (mouse) => {
                    startMouseX = mouse.x
                    startMouseY = mouse.y

                    const r = rectanglesModel.get(modelIndex)
                    if (r !== undefined) {
                        originalStartX = r.startX
                        originalStartY = r.startY
                        originalEndX = r.endX
                        originalEndY = r.endY
                    }
                }

                onPositionChanged: (mouse) => {
                    const dx = mouse.x - startMouseX
                    const dy = mouse.y - startMouseY

                    if (modelIndex < 0 || modelIndex >= rectanglesModel.count)
                        return

                    switch (mode) {
                    case "topLeft":
                        rectanglesModel.setProperty(modelIndex, "startX", Math.max(0, originalStartX + dx))
                        rectanglesModel.setProperty(modelIndex, "startY", Math.max(0, originalStartY + dy))
                        break
                    case "topRight":
                        rectanglesModel.setProperty(modelIndex, "endX", Math.max(0, originalEndX + dx))
                        rectanglesModel.setProperty(modelIndex, "startY", Math.max(0, originalStartY + dy))
                        break
                    case "bottomLeft":
                        rectanglesModel.setProperty(modelIndex, "startX", Math.max(0, originalStartX + dx))
                        rectanglesModel.setProperty(modelIndex, "endY", Math.max(0, originalEndY + dy))
                        break
                    case "bottomRight":
                        rectanglesModel.setProperty(modelIndex, "endX", Math.max(0, originalEndX + dx))
                        rectanglesModel.setProperty(modelIndex, "endY", Math.max(0, originalEndY + dy))
                        break
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Item {
            id: imageContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignHCenter

            Image {
                id: imagePreview
                anchors.centerIn: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                source: ""
            }

            Item {
                id: drawLayer
                anchors.fill: parent
                z: 2

                property bool drawing: false
                property real startX: 0
                property real startY: 0
                property real currentX: 0
                property real currentY: 0

                ListModel {
                    id: rectanglesModel
                }

                function pointInExistingRect(x, y) {
                    for (let i = 0; i < rectanglesModel.count; ++i) {
                        const rect = rectanglesModel.get(i)
                        const rx = Math.min(rect.startX, rect.endX)
                        const ry = Math.min(rect.startY, rect.endY)
                        const rw = Math.abs(rect.endX - rect.startX)
                        const rh = Math.abs(rect.endY - rect.startY)
                        if (x >= rx && x <= rx + rw && y >= ry && y <= ry + rh) {
                            return true
                        }
                    }
                    return false
                }

                Repeater {
                    id: rectRepeater
                    model: rectanglesModel
                    z: 100

                    Rectangle {
                        Behavior on x { NumberAnimation { duration: 50 } }
                        Behavior on y { NumberAnimation { duration: 50 } }
                        Behavior on width { NumberAnimation { duration: 50 } }
                        Behavior on height { NumberAnimation { duration: 50 } }
                        id: rectItem

                        clip: true
                        x: Math.min(model.startX, model.endX)
                        y: Math.min(model.startY, model.endY)
                        width: Math.abs(model.endX - model.startX)
                        height: Math.abs(model.endY - model.startY)
                        color: "transparent"
                        border.color: "red"
                        border.width: 2

                        property bool dragging: false
                        property real dragStartX: 0
                        property real dragStartY: 0
                        property int modelIndex: index

                        // NEUE Eigenschaften für Resizing
                        property bool resizing: false
                        property string activeHandle: ""
                        property real originalX: 0
                        property real originalY: 0
                        property real originalWidth: 0
                        property real originalHeight: 0
                        property real resizeStartX: 0
                        property real resizeStartY: 0

                        Loader {
                            sourceComponent: resizeHandleComponent
                            onLoaded: {
                                item.color = "green"
                                item.mode = "topLeft"
                                item.cursor = "SizeFDiagCursor"
                                item.modelIndex = rectItem.modelIndex
                                item.targetRectItem = rectItem
                            }
                        }
                        Loader {
                            sourceComponent: resizeHandleComponent
                            onLoaded: {
                                item.color = "red"
                                item.mode = "topRight"
                                item.cursor = "SizeBDiagCursor"
                                item.modelIndex = rectItem.modelIndex
                                item.targetRectItem = rectItem
                            }
                        }
                        Loader {
                            sourceComponent: resizeHandleComponent
                            onLoaded: {
                                item.color = "black"
                                item.mode = "bottomLeft"
                                item.cursor = "SizeBDiagCursor"
                                item.modelIndex = rectItem.modelIndex
                                item.targetRectItem = rectItem
                            }
                        }
                        Loader {
                            sourceComponent: resizeHandleComponent
                            onLoaded: {
                                item.color = "yellow"
                                item.mode = "bottomRight"
                                item.cursor = "SizeFDiagCursor"
                                item.modelIndex = rectItem.modelIndex
                                item.targetRectItem = rectItem
                            }
                        }
                        Rectangle {
                            id: innerArea
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width / 3
                            width: parent.width / 3
                            height: parent.height
                            color: "#80000000"
                            z: -1

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                drag.target: null

                                onPressed: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        rectItem.dragging = true
                                        rectItem.dragStartX = mouse.x
                                        rectItem.dragStartY = mouse.y
                                    }
                                }

                                onPositionChanged: (mouse) => {
                                    if (!rectItem.dragging) return

                                    let dx = mouse.x - rectItem.dragStartX
                                    let dy = mouse.y - rectItem.dragStartY

                                    let newX = rectItem.x + dx
                                    let newY = rectItem.y + dy
                                    let width = rectItem.width
                                    let height = rectItem.height

                                    newX = Math.max(0, Math.min(newX, imagePreview.width - width))
                                    newY = Math.max(0, Math.min(newY, imagePreview.height - height))

                                    function snap(val) {
                                        const grid = 10
                                        return Math.round(val / grid) * grid
                                    }

                                    let newStartX = snap(newX)
                                    let newStartY = snap(newY)
                                    let newEndX = snap(newStartX + width)
                                    let newEndY = snap(newStartY + height)

                                    let blocked = false
                                    for (let i = 0; i < rectanglesModel.count; ++i) {
                                        if (i === rectItem.modelIndex) continue
                                        const other = rectanglesModel.get(i)
                                        const ox = Math.min(other.startX, other.endX)
                                        const oy = Math.min(other.startY, other.endY)
                                        const ow = Math.abs(other.endX - other.startX)
                                        const oh = Math.abs(other.endY - other.startY)

                                        if (!(newEndX <= ox || newStartX >= ox + ow ||
                                              newEndY <= oy || newStartY >= oy + oh)) {
                                            blocked = true
                                            break
                                        }
                                    }

                                    if (!blocked) {
                                        rectanglesModel.setProperty(rectItem.modelIndex, "startX", newStartX)
                                        rectanglesModel.setProperty(rectItem.modelIndex, "startY", newStartY)
                                        rectanglesModel.setProperty(rectItem.modelIndex, "endX", newEndX)
                                        rectanglesModel.setProperty(rectItem.modelIndex, "endY", newEndY)
                                    }
                                }

                                onReleased: {
                                    rectItem.dragging = false
                                }

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        rectanglesModel.remove(rectItem.modelIndex)
                                        mouse.accepted = true
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: drawLayer.drawing
                    color: "transparent"
                    border.color: "blue"
                    border.width: 2
                    x: Math.min(drawLayer.startX, drawLayer.currentX)
                    y: Math.min(drawLayer.startY, drawLayer.currentY)
                    width: Math.abs(drawLayer.currentX - drawLayer.startX)
                    height: Math.abs(drawLayer.currentY - drawLayer.startY)
                }

                // ... vorheriger Code unverändert ...

                MouseArea {
                    id: drawArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton

                    onPressed: (mouse) => {
                        // Prüfen, ob ein Rechteck angeklickt wurde
                        if (drawLayer.pointInExistingRect(mouse.x, mouse.y)) {
                            // Ereignis weitergeben an Kindelemente
                            mouse.accepted = false
                            return
                        }

                        // Neues Rechteck zeichnen
                        drawLayer.drawing = true
                        drawLayer.startX = mouse.x
                        drawLayer.startY = mouse.y
                        drawLayer.currentX = mouse.x
                        drawLayer.currentY = mouse.y
                    }

                    onPositionChanged: (mouse) => {
                        if (drawLayer.drawing) {
                            drawLayer.currentX = mouse.x
                            drawLayer.currentY = mouse.y
                        }
                    }

                    onReleased: (mouse) => {
                        if (!drawLayer.drawing) return

                        drawLayer.drawing = false
                        drawLayer.currentX = mouse.x
                        drawLayer.currentY = mouse.y

                        rectanglesModel.append({
                            startX: drawLayer.startX,
                            startY: drawLayer.startY,
                            endX: drawLayer.currentX,
                            endY: drawLayer.currentY
                        })
                    }
                }
            }
        }

        RowLayout {
            id: buttonsRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Button {
                text: "OK"
                onClicked: {
                    imageWindow.accepted()
                    imageWindow.visible = false
                }
            }

            Button {
                text: "Abbrechen"
                onClicked: {
                    imageWindow.rejected()
                    imageWindow.visible = false
                }
            }
        }
    }
}
