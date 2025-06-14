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
        rectanglesModel.clear()

        imagePreview.source = ""
        imageWindow.visible = false

        Qt.callLater(() => {
            imagePreview.source = path
        })

        imagePreview.statusChanged.connect(function handler() {
            if (imagePreview.status === Image.Ready) {
                imagePreview.statusChanged.disconnect(handler)

                let imgW = imagePreview.sourceSize.width
                let imgH = imagePreview.sourceSize.height

                if (imgW <= 0 || imgH <= 0) {
                    imgW = imagePreview.implicitWidth
                    imgH = imagePreview.implicitHeight
                }

                // Sicherheitsmaßnahme: Fallback falls immer noch 0
                if (imgW <= 0 || imgH <= 0) {
                    imgW = 400
                    imgH = 300
                }

                const buttonsHeight = buttonsRow.implicitHeight + layout.spacing
                const windowMargin = 40

                const targetW = Math.min(imgW * 1.1 + windowMargin, maxDialogWidth)
                const targetH = Math.min(imgH * 1.1 + buttonsHeight + windowMargin, maxDialogHeight)

                imageWindow.width = targetW
                imageWindow.height = targetH

                imageWindow.visible = true
            }
        })
    }

    Item {
        id: globalHelper
        anchors.fill: parent
    }

    Component {
        id: resizeHandleComponent

        Rectangle {
            width: Math.max(12, targetRectItem.height * 0.2)
            height: width
            color: "#80FFFFFF"
            //border.color: "red"
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
                        return targetRectItem.width - width;
                    case "topLeft":
                    case "bottomLeft":
                    default:
                        return 0;
                }
            }
            y: {
                switch(mode) {
                    case "bottomLeft":
                    case "bottomRight":
                        return targetRectItem.height - height;
                    case "topLeft":
                    case "topRight":
                    default:
                        return 0;
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

                    const scaleX = imagePreview.paintedWidth / imagePreview.implicitWidth
                    const scaleY = imagePreview.paintedHeight / imagePreview.implicitHeight
                    const maxX = imagePreview.implicitWidth
                    const maxY = imagePreview.implicitHeight

                    let newStartX = originalStartX
                    let newStartY = originalStartY
                    let newEndX = originalEndX
                    let newEndY = originalEndY

                    switch (mode) {
                    case "topLeft":
                        newStartX = Math.max(0, Math.min(originalStartX + dx, originalEndX));
                        newStartY = Math.max(0, Math.min(originalStartY + dy, originalEndY));
                        break
                    case "topRight":
                        newEndX = Math.min(maxX, Math.max(originalEndX + dx, originalStartX));
                        newStartY = Math.max(0, Math.min(originalStartY + dy, originalEndY));
                        break
                    case "bottomLeft":
                        newStartX = Math.max(0, Math.min(originalStartX + dx, originalEndX));
                        newEndY = Math.min(maxY, Math.max(originalEndY + dy, originalStartY));
                        break
                    case "bottomRight":
                        newEndX = Math.min(maxX, Math.max(originalEndX + dx, originalStartX));
                        newEndY = Math.min(maxY, Math.max(originalEndY + dy, originalStartY));
                        break
                    }

                    rectanglesModel.setProperty(modelIndex, "startX", newStartX)
                    rectanglesModel.setProperty(modelIndex, "startY", newStartY)
                    rectanglesModel.setProperty(modelIndex, "endX", newEndX)
                    rectanglesModel.setProperty(modelIndex, "endY", newEndY)
                }
            }
            Image {
                anchors.fill: parent
                fillMode: Image.Stretch
                source: {
                    switch (mode) {
                        case "topLeft": return "qrc:/icons/arrow_to_left_top_and_right_bottom.png"
                        case "topRight": return "qrc:/icons/arrow_to_left_bottom_and_right_top.png"
                        case "bottomLeft": return "qrc:/icons/arrow_to_left_bottom_and_right_top.png"
                        case "bottomRight": return "qrc:/icons/arrow_to_left_top_and_right_bottom.png"
                        default: return ""
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

            Rectangle {
                id: imageFrame
                anchors.fill: parent  // füllt den verfügbaren Platz
                color: "transparent"
                border.color: "green"
                border.width: 1

                Image {
                    id: imagePreview
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    source: ""

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            console.log("Image loaded:", sourceSize.width, sourceSize.height)
                        }
                    }
                }

                Item {
                    id: drawLayer
                    anchors.fill: parent
                    z: 2

                    property real offsetX: (width - imagePreview.paintedWidth) / 2
                    property real offsetY: (height - imagePreview.paintedHeight) / 2
                    property real scaleX: imagePreview.paintedWidth / imagePreview.implicitWidth
                    property real scaleY: imagePreview.paintedHeight / imagePreview.implicitHeight

                    property bool drawing: false
                    property real startX: 0
                    property real startY: 0
                    property real currentX: 0
                    property real currentY: 0

                    property bool showGlobalCircles: false
                    property real circleCenterX: 0
                    property real circleCenterY: 0
                    property real circleInnerRadius: 0
                    property real circleOuterRadius: 0


                    ListModel {
                        id: rectanglesModel
                    }

                    function imageOffsetX() {
                        return (imagePreview.width - imagePreview.paintedWidth) / 2
                    }

                    function imageOffsetY() {
                        return (imagePreview.height - imagePreview.paintedHeight) / 2
                    }

                    function pointInExistingRect(x, y) {
                        // Korrektur: Verwende Bildkoordinaten ohne Offset
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
                            id: rectItem
                            Behavior on x { NumberAnimation { duration: 50 } }
                            Behavior on y { NumberAnimation { duration: 50 } }
                            Behavior on width { NumberAnimation { duration: 50 } }
                            Behavior on height { NumberAnimation { duration: 50 } }

                            clip: false
                            x: drawLayer.imageOffsetX() + Math.min(model.startX, model.endX) * drawLayer.scaleX
                            y: drawLayer.imageOffsetY() + Math.min(model.startY, model.endY) * drawLayer.scaleY
                            width: Math.abs(model.endX - model.startX) * drawLayer.scaleX
                            height: Math.abs(model.endY - model.startY) * drawLayer.scaleY

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

                            property real rotationAngle: 0

                            transform: Rotation {
                                origin.x: rectItem.width / 2
                                origin.y: rectItem.height / 2
                                angle: rectItem.rotationAngle
                            }


                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
                                    item.mode = "topLeft"
                                    item.cursor = "SizeFDiagCursor"
                                    item.modelIndex = rectItem.modelIndex
                                    item.targetRectItem = rectItem
                                }
                            }
                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
                                    item.mode = "topRight"
                                    item.cursor = "SizeBDiagCursor"
                                    item.modelIndex = rectItem.modelIndex
                                    item.targetRectItem = rectItem
                                }
                            }
                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
                                    item.mode = "bottomLeft"
                                    item.cursor = "SizeBDiagCursor"
                                    item.modelIndex = rectItem.modelIndex
                                    item.targetRectItem = rectItem
                                }
                            }
                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
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

                                        // Bewegung
                                        let dx = mouse.x - rectItem.dragStartX
                                        let dy = mouse.y - rectItem.dragStartY

                                        // Neue Bildschirmposition
                                        let newX = rectItem.x + dx
                                        let newY = rectItem.y + dy

                                        // Bild-Offsets und Skalierung
                                        let offsetX = drawLayer.imageOffsetX()
                                        let offsetY = drawLayer.imageOffsetY()
                                        let scaleX = imagePreview.paintedWidth / imagePreview.implicitWidth
                                        let scaleY = imagePreview.paintedHeight / imagePreview.implicitHeight

                                        // Modellabmessungen (Bild-Koordinaten)
                                        let model = rectanglesModel.get(rectItem.modelIndex)
                                        let modelWidth = Math.abs(model.endX - model.startX)
                                        let modelHeight = Math.abs(model.endY - model.startY)

                                        // Rechteckgröße in View-Koordinaten
                                        let viewWidth = modelWidth * scaleX
                                        let viewHeight = modelHeight * scaleY

                                        // Grenzen (View-Koordinaten)
                                        let minX = offsetX
                                        let minY = offsetY
                                        let maxX = offsetX + imagePreview.paintedWidth - viewWidth
                                        let maxY = offsetY + imagePreview.paintedHeight - viewHeight

                                        // Begrenzung anwenden
                                        newX = Math.max(minX, Math.min(newX, maxX))
                                        newY = Math.max(minY, Math.min(newY, maxY))

                                        // Rückumrechnung zu Bildkoordinaten
                                        let newStartX = (newX - offsetX) / scaleX
                                        let newStartY = (newY - offsetY) / scaleY
                                        let newEndX = newStartX + modelWidth
                                        let newEndY = newStartY + modelHeight

                                        // Überschneidungen prüfen
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

                                        // Wenn nicht blockiert, ins Modell schreiben
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
                            MouseArea {
                                id: outerMouseArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                hoverEnabled: true
                                propagateComposedEvents: true

                                property real dragStartAngle: 0
                                property real dragInitialRotation: 0
                                property real centerGlobalX: 0
                                property real centerGlobalY: 0

                                onPressed: (mouse) => {
                                    const localPoint = Qt.point(mouse.x, mouse.y)
                                    if (!innerArea.contains(localPoint)) {
                                        // Mittelpunkt des Rechtecks → Canvas-Koordinaten
                                        const center = rectItem.mapToItem(globalCircleCanvas, Qt.point(rectItem.width / 2, rectItem.height / 2))
                                        centerGlobalX = center.x
                                        centerGlobalY = center.y

                                        const canvasMouse = outerMouseArea.mapToItem(globalCircleCanvas, Qt.point(mouse.x, mouse.y))
                                        const dx = canvasMouse.x - centerGlobalX
                                        const dy = canvasMouse.y - centerGlobalY
                                        dragStartAngle = Math.atan2(dy, dx)
                                        dragInitialRotation = rectItem.rotationAngle

                                        // Äußerer Kreis: Diagonale des Rechtecks
                                        const outerRadius = Math.sqrt((rectItem.width / 2) ** 2 + (rectItem.height / 2) ** 2)
                                        drawLayer.circleOuterRadius = outerRadius

                                        // Innerer Kreis: Abstand zu Ecke von innerArea (oben links)
                                        const innerCorner = innerArea.mapToItem(globalCircleCanvas, Qt.point(0, 0))
                                        const ix = centerGlobalX - innerCorner.x
                                        const iy = centerGlobalY - innerCorner.y
                                        const innerRadius = Math.sqrt(ix * ix + iy * iy)
                                        drawLayer.circleInnerRadius = innerRadius

                                        // Kreise aktivieren
                                        drawLayer.circleCenterX = centerGlobalX
                                        drawLayer.circleCenterY = centerGlobalY
                                        drawLayer.showGlobalCircles = true
                                        globalCircleCanvas.requestPaint()

                                        mouse.accepted = true
                                    } else {
                                        mouse.accepted = false
                                    }
                                }

                                onPositionChanged: (mouse) => {
                                    if (drawLayer.showGlobalCircles) {
                                        // Mausposition relativ zum Canvas
                                        const canvasPos = outerMouseArea.mapToItem(globalCircleCanvas, Qt.point(mouse.x, mouse.y))
                                        const dx = canvasPos.x - centerGlobalX
                                        const dy = canvasPos.y - centerGlobalY

                                        const angle = Math.atan2(dy, dx)
                                        const delta = angle - dragStartAngle

                                        const threshold = 0.003  // ca. 0.17°
                                        if (Math.abs(delta) > threshold) {
                                            rectItem.rotationAngle = dragInitialRotation + delta * 180 / Math.PI
                                        }
                                    }
                                }

                                onReleased: {
                                    drawLayer.showGlobalCircles = false
                                    globalCircleCanvas.requestPaint()
                                }
                            }
                            Item {
                                id: angleOverlay
                                width: angleText.implicitWidth + 12
                                height: angleText.implicitHeight + 8
                                x: (rectItem.width - width) / 2
                                y: (rectItem.height - height) / 2
                                z: 1000
                                visible: drawLayer.showGlobalCircles

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: "black"
                                    opacity: 0.6
                                }

                                Text {
                                    id: angleText
                                    anchors.centerIn: parent
                                    font.pixelSize: 14
                                    color: "white"
                                    text: Math.round(rectItem.rotationAngle) + "°"
                                }
                            }
                        }
                    }
                    Rectangle {
                        visible: drawLayer.drawing
                        color: "transparent"
                        border.color: "blue"
                        border.width: 2

                        x: drawLayer.offsetX + Math.min(drawLayer.startX, drawLayer.currentX) * drawLayer.scaleX
                        y: drawLayer.offsetY + Math.min(drawLayer.startY, drawLayer.currentY) * drawLayer.scaleY
                        width: Math.abs(drawLayer.currentX - drawLayer.startX) * drawLayer.scaleX
                        height: Math.abs(drawLayer.currentY - drawLayer.startY) * drawLayer.scaleY
                    }

                    // ... vorheriger Code unverändert ...

                    MouseArea {
                        id: drawArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton

                        onPressed: (mouse) => {
                            // Umrechnung von Mausposition in Bildkoordinaten
                            var imgX = (mouse.x - drawLayer.offsetX) / drawLayer.scaleX
                            var imgY = (mouse.y - drawLayer.offsetY) / drawLayer.scaleY

                            // Prüfen, ob bereits ein Rechteck dort existiert
                            if (drawLayer.pointInExistingRect(imgX, imgY)) {
                                mouse.accepted = false
                                return
                            }

                            drawLayer.startX = imgX
                            drawLayer.startY = imgY
                            drawLayer.currentX = imgX
                            drawLayer.currentY = imgY
                            drawLayer.drawing = true
                        }

                        onPositionChanged: (mouse) => {
                            if (drawLayer.drawing) {
                                drawLayer.currentX = (mouse.x - drawLayer.offsetX) / drawLayer.scaleX
                                drawLayer.currentY = (mouse.y - drawLayer.offsetY) / drawLayer.scaleY
                            }
                        }

                        onReleased: (mouse) => {
                            if (!drawLayer.drawing)
                                return

                            drawLayer.drawing = false

                            // Letzte Position in Bildkoordinaten
                            drawLayer.currentX = (mouse.x - drawLayer.offsetX) / drawLayer.scaleX
                            drawLayer.currentY = (mouse.y - drawLayer.offsetY) / drawLayer.scaleY

                            // Nur sinnvolle Rechtecke speichern
                            if (Math.abs(drawLayer.currentX - drawLayer.startX) >= 1 &&
                                Math.abs(drawLayer.currentY - drawLayer.startY) >= 1) {
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
                Canvas {
                    id: globalCircleCanvas
                    anchors.fill: parent
                    visible: drawLayer.showGlobalCircles
                    z: 999

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        if (!drawLayer.showGlobalCircles)
                            return

                        ctx.strokeStyle = "rgba(0, 150, 255, 0.7)"
                        ctx.lineWidth = 2

                        ctx.beginPath()
                        ctx.arc(drawLayer.circleCenterX, drawLayer.circleCenterY, drawLayer.circleInnerRadius, 0, 2 * Math.PI)
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.arc(drawLayer.circleCenterX, drawLayer.circleCenterY, drawLayer.circleOuterRadius, 0, 2 * Math.PI)
                        ctx.stroke()
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
