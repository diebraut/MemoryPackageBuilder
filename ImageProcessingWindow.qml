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

                    Rectangle {
                        id: rectItem
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

                        Rectangle {
                            id: innerArea
                            property alias rectItem: rectItem
                            anchors.verticalCenter: parent.verticalCenter
                            x: parent.width / 3
                            width: parent.width / 3
                            height: parent.height
                            color: "#80000000"
                            z: -1

                            MouseArea {
                                anchors.fill: parent
                                drag.target: null
                                property alias rectItem: innerArea.rectItem

                                onPressed: (mouse) => {
                                    rectItem.dragging = true
                                    rectItem.dragStartX = mouse.x
                                    rectItem.dragStartY = mouse.y
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
                            }
                        }

                        Rectangle {
                            width: 2
                            height: parent.height
                            x: parent.width / 3 - 1
                            y: 0
                            color: "red"
                        }

                        Rectangle {
                            width: 2
                            height: parent.height
                            x: 2 * parent.width / 3 - 1
                            y: 0
                            color: "red"
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
