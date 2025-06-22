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
    signal accepted(string excludeData)
    signal rejected()

    property int maxDialogWidth: Screen.width * 0.9
    property int maxDialogHeight: Screen.height * 0.9

    function openWithImage(path, screenW, screenH, excludeRect) {
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

                // Fallback, falls sourceSize nicht funktioniert
                if (imgW <= 0 || imgH <= 0) {
                    imgW = imagePreview.paintedWidth
                    imgH = imagePreview.paintedHeight
                }

                // Falls immer noch nicht sicher: Standardwerte setzen
                if (imgW <= 0 || imgH <= 0) {
                    imgW = 400
                    imgH = 300
                }

                // Setze Original-Bildgrößen für skalierungsberechnungen
                imagePreview.originalImageWidth = imagePreview.sourceSize.width
                imagePreview.originalImageHeight = imagePreview.sourceSize.height
                console.log("Original image size:", imagePreview.sourceSize.width, imagePreview.sourceSize.height)
                console.log("Painted size:", imagePreview.paintedWidth, imagePreview.paintedHeight)


                const availableWidth = screenW || Screen.desktopAvailableWidth
                const availableHeight = screenH || Screen.desktopAvailableHeight
                const buttonsHeight = buttonsRow.implicitHeight + layout.spacing
                const windowMargin = 40

                const targetW = Math.min(imgW * 1.1 + windowMargin, availableWidth * 0.95)
                const targetH = Math.min(imgH * 1.1 + buttonsHeight + windowMargin, availableHeight * 0.95)

                imageWindow.width = targetW
                imageWindow.height = targetH
                imageWindow.x = (availableWidth - targetW) / 2
                imageWindow.y = (availableHeight - targetH) / 2

                if (excludeRect && typeof excludeRect === "string") {
                    const rectStrings = excludeRect.split("|")
                    for (let i = 0; i < rectStrings.length; ++i) {
                        const parts = rectStrings[i].split(",")
                        if (parts.length >= 5) {
                            const startX = parseFloat(parts[0])
                            const startY = parseFloat(parts[1])
                            const width = parseFloat(parts[2])
                            const height = parseFloat(parts[3])
                            const rotationAngle = parseFloat(parts[4])

                            if (!isNaN(startX) && !isNaN(startY) &&
                                !isNaN(width) && !isNaN(height) &&
                                !isNaN(rotationAngle)) {

                                rectanglesModel.append({
                                    startX: startX,
                                    startY: startY,
                                    endX: startX + width,
                                    endY: startY + height,
                                    rotationAngle: rotationAngle
                                })
                            } else {
                                console.warn("Ungültige Werte in excludeRect:", rectStrings[i])
                            }
                        } else {
                            console.warn("Unvollständiges Rechteck:", rectStrings[i])
                        }
                    }
                }
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
            z: 2000

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

                    const newCenterX = (newStartX + newEndX) / 2 * scaleX + drawLayer.offsetX
                    const newCenterY = (newStartY + newEndY) / 2 * scaleY + drawLayer.offsetY
                    const newWidth = Math.abs(newEndX - newStartX) * scaleX
                    const newHeight = Math.abs(newEndY - newStartY) * scaleY

                    const rotation = rectanglesModel.get(modelIndex).rotationAngle || 0

                    if (drawLayer.allCornersInside(newCenterX, newCenterY, newWidth, newHeight, rotation)) {
                        rectanglesModel.setProperty(modelIndex, "startX", newStartX)
                        rectanglesModel.setProperty(modelIndex, "startY", newStartY)
                        rectanglesModel.setProperty(modelIndex, "endX", newEndX)
                        rectanglesModel.setProperty(modelIndex, "endY", newEndY)
                    }
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
                    property int originalImageWidth: 0
                    property int originalImageHeight: 0

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
                    property real scaleX: imagePreview.paintedWidth / imagePreview.originalImageWidth
                    property real scaleY: imagePreview.paintedHeight / imagePreview.originalImageHeight

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

                    ListModel {
                        id: arrowModel
                    }


                    function imageOffsetX() {
                        return (imagePreview.width - imagePreview.paintedWidth) / 2
                    }

                    function imageOffsetY() {
                        return (imagePreview.height - imagePreview.paintedHeight) / 2
                    }

                    function pointInRotatedRect(x, y, rect) {
                        const cx = (rect.startX + rect.endX) / 2
                        const cy = (rect.startY + rect.endY) / 2

                        const angle = - (rect.rotationAngle || 0) * Math.PI / 180

                        const dx = x - cx
                        const dy = y - cy

                        // Inverse Rotation (um Mittelpunkt)
                        const rx = dx * Math.cos(angle) - dy * Math.sin(angle)
                        const ry = dx * Math.sin(angle) + dy * Math.cos(angle)

                        const hw = Math.abs(rect.endX - rect.startX) / 2
                        const hh = Math.abs(rect.endY - rect.startY) / 2

                        return rx >= -hw && rx <= hw && ry >= -hh && ry <= hh
                    }

                    function pointInExistingRect(x, y) {
                        for (let i = 0; i < rectanglesModel.count; ++i) {
                            const r = rectanglesModel.get(i)
                            if (pointInRotatedRect(x, y, r)) return true
                        }
                        return false
                    }
                    function isPointInImage(px, py) {
                        return px >= offsetX &&
                               px <= offsetX + imagePreview.paintedWidth &&
                               py >= offsetY &&
                               py <= offsetY + imagePreview.paintedHeight
                    }

                    function allCornersInside(rotCenterX, rotCenterY, width, height, angleDeg) {
                        const angle = angleDeg * Math.PI / 180

                        const cosA = Math.cos(angle)
                        const sinA = Math.sin(angle)

                        const corners = [
                            [-width/2, -height/2],
                            [ width/2, -height/2],
                            [ width/2,  height/2],
                            [-width/2,  height/2]
                        ]

                        for (let i = 0; i < 4; ++i) {
                            const localX = corners[i][0]
                            const localY = corners[i][1]

                            const rotatedX = localX * cosA - localY * sinA
                            const rotatedY = localX * sinA + localY * cosA

                            const screenX = rotCenterX + rotatedX
                            const screenY = rotCenterY + rotatedY

                            if (!isPointInImage(screenX, screenY)) {
                                return false
                            }
                        }
                        return true
                    }

                    Repeater {
                        id: rectRepeater
                        model: rectanglesModel
                        z: 100

                        Rectangle {
                            id: rectItem

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

                            property var handles: []

                            property real rotationAngle: model.rotationAngle !== undefined ? model.rotationAngle : 0

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
                                    rectItem.handles.push(item)
                                }
                            }
                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
                                    item.mode = "topRight"
                                    item.cursor = "SizeBDiagCursor"
                                    item.modelIndex = rectItem.modelIndex
                                    item.targetRectItem = rectItem
                                    rectItem.handles.push(item)
                                }
                            }
                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
                                    item.mode = "bottomLeft"
                                    item.cursor = "SizeBDiagCursor"
                                    item.modelIndex = rectItem.modelIndex
                                    item.targetRectItem = rectItem
                                    rectItem.handles.push(item)
                                }
                            }
                            Loader {
                                sourceComponent: resizeHandleComponent
                                onLoaded: {
                                    item.mode = "bottomRight"
                                    item.cursor = "SizeFDiagCursor"
                                    item.modelIndex = rectItem.modelIndex
                                    item.targetRectItem = rectItem
                                    rectItem.handles.push(item)
                                }
                            }
                            Rectangle {
                                id: innerArea
                                anchors.verticalCenter: parent.verticalCenter
                                x: parent.width / 3
                                width: parent.width / 3
                                height: parent.height
                                color: "#80000000"
                                z: 1001
                                property real lastGlobalMouseX: 0
                                property real lastGlobalMouseY: 0
                                property point  globalNow

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    drag.target: null
                                    hoverEnabled: true
                                    z: 9999

                                    onPressed: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            rectItem.dragging = true
                                            rectItem.dragStartX = mouse.x
                                            rectItem.dragStartY = mouse.y

                                            innerArea.globalNow = mapToGlobal(Qt.point(mouse.x, mouse.y))
                                            innerArea.lastGlobalMouseX = innerArea.globalNow.x
                                            innerArea.lastGlobalMouseY = innerArea.globalNow.y
                                            mouse.accepted = true
                                        } else if (mouse.button === Qt.RightButton) {
                                            mouse.accepted = true  // ❗ Wichtig: akzeptieren, damit onClicked ausgelöst wird
                                        }
                                    }

                                    onPositionChanged: (mouse) => {

                                        if (!rectItem.dragging) return
                                        innerArea.globalNow = mapToGlobal(Qt.point(mouse.x, mouse.y))

                                        const dx = innerArea.globalNow.x - innerArea.lastGlobalMouseX
                                        const dy = innerArea.globalNow.y - innerArea.lastGlobalMouseY

                                        let newX = rectItem.x + dx
                                        let newY = rectItem.y + dy

                                        let offsetX = drawLayer.imageOffsetX()
                                        let offsetY = drawLayer.imageOffsetY()
                                        let scaleX = imagePreview.paintedWidth / imagePreview.implicitWidth
                                        let scaleY = imagePreview.paintedHeight / imagePreview.implicitHeight

                                        let model = rectanglesModel.get(rectItem.modelIndex)
                                        let modelWidth = Math.abs(model.endX - model.startX)
                                        let modelHeight = Math.abs(model.endY - model.startY)

                                        let viewWidth = modelWidth * scaleX
                                        let viewHeight = modelHeight * scaleY

                                        let centerX = newX + viewWidth / 2
                                        let centerY = newY + viewHeight / 2

                                        if (!drawLayer.allCornersInside(centerX, centerY, viewWidth, viewHeight, rectItem.rotationAngle))
                                          return

                                        let newStartX = (newX - offsetX) / scaleX
                                        let newStartY = (newY - offsetY) / scaleY
                                        let newEndX = newStartX + modelWidth
                                        let newEndY = newStartY + modelHeight

                                        // Optional: Kollision mit anderen Rechtecken verhindern
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
                                        innerArea.lastGlobalMouseX = innerArea.globalNow.x
                                        innerArea.lastGlobalMouseY = innerArea.globalNow.y
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
                                propagateComposedEvents: false
                                preventStealing: true

                                property real dragStartAngle: 0
                                property real dragInitialRotation: 0
                                property real centerGlobalX: 0
                                property real centerGlobalY: 0

                                onPressed: (mouse) => {
                                       console.log("outer pressed")

                                       if (innerArea.containsMouse) {
                                           mouse.accepted = false
                                           return
                                       }                                  for (let i = 0; i < rectItem.handles.length; ++i) {
                                       const handle = rectItem.handles[i]
                                       const pos = handle.mapToItem(outerMouseArea, Qt.point(0, 0))

                                       const clickX = mouse.x
                                       const clickY = mouse.y

                                       if (clickX >= pos.x && clickX <= pos.x + handle.width &&
                                           clickY >= pos.y && clickY <= pos.y + handle.height) {
                                           mouse.accepted = false
                                           return
                                       }
                                   }

                                    // Check ob irgendein Resize-Handle die Maus hat
                                    const clickPoint = Qt.point(mouse.x, mouse.y)
                                    const mapped = outerMouseArea.mapToItem(innerArea, Qt.point(mouse.x, mouse.y))
                                    if (mapped.x < 0 || mapped.x > innerArea.width || mapped.y < 0 || mapped.y > innerArea.height) {                                        // Mittelpunkt des Rechtecks → Canvas-Koordinaten
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
                                            rectanglesModel.setProperty(rectItem.modelIndex, "rotationAngle", rectItem.rotationAngle)
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
                                    endY: drawLayer.currentY,
                                    rotationAngle: 0
                                })
                            }
                        }
                    }
                    QtObject {
                        id: rotationHelper
                        property real centerX: 0
                        property real centerY: 0
                        property real startAngle: 0
                        property real initialAngle: 0
                        property bool active: false

                        function startRotation(mouseArea, mouse, center, currentAngle) {
                            const pos = mouseArea.mapToItem(globalCircleCanvas, Qt.point(mouse.x, mouse.y))
                            centerX = center.x
                            centerY = center.y
                            const dx = pos.x - center.x
                            const dy = pos.y - center.y
                            startAngle = Math.atan2(dy, dx)
                            initialAngle = currentAngle
                            active = true
                        }

                        function updateAngle(mouseArea, mouse) {
                            const pos = mouseArea.mapToItem(globalCircleCanvas, Qt.point(mouse.x, mouse.y))
                            const dx = pos.x - centerX
                            const dy = pos.y - centerY
                            const current = Math.atan2(dy, dx)
                            const delta = current - startAngle
                            return initialAngle + delta * 180 / Math.PI
                        }
                    }

                    Component {
                        id: arrowPrototype
                        Image {
                            source: "qrc:/icons/arrow-right.png"
                            width: 96
                            height: 96
                            opacity: 0.6
                            z: 3100
                            layer.enabled: true
                        }
                    }

                    Image {
                        id: arrowPlaceholder
                        source: "qrc:/icons/arrow-right.png"
                        width: 48
                        height: 48
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 16
                        opacity: 0.5
                        z: 3000

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor

                            property var tempArrow: null

                            onPressed: (mouse) => {
                                if (tempArrow === null) {
                                    tempArrow = arrowPrototype.createObject(drawLayer, {
                                        x: mouse.x + arrowPlaceholder.x,
                                        y: mouse.y + arrowPlaceholder.y
                                    });
                                }
                            }

                            onPositionChanged: (mouse) => {
                                if (tempArrow) {
                                    tempArrow.x = mouse.x + arrowPlaceholder.x;
                                    tempArrow.y = mouse.y + arrowPlaceholder.y;
                                }
                            }

                            onReleased: (mouse) => {
                                if (tempArrow) {
                                    const imgX = (tempArrow.x - drawLayer.offsetX) / drawLayer.scaleX
                                    const imgY = (tempArrow.y - drawLayer.offsetY) / drawLayer.scaleY

                                    arrowModel.append({
                                        x: imgX,
                                        y: imgY,
                                        rotationAngle: 0
                                    });
                                    tempArrow.destroy();
                                    tempArrow = null;
                                }
                            }
                        }
                    }

                    Repeater {
                        model: arrowModel
                        delegate: Item {
                            id: arrowItem
                            width: 96
                            height: 96
                            x: drawLayer.offsetX + model.x * drawLayer.scaleX
                            y: drawLayer.offsetY + model.y * drawLayer.scaleY
                            z: 2100

                            property int modelIndex: index
                            property real rotationAngle: model.rotationAngle || 0
                            property real centerX: width / 2
                            property real centerY: height / 2

                            transform: Rotation {
                                origin.x: centerX
                                origin.y: centerY
                                angle: rotationAngle
                            }

                            Image {
                                anchors.fill: parent
                                source: "qrc:/icons/arrow-right.png"
                                opacity: 0.9
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                cursorShape: Qt.OpenHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                hoverEnabled: true
                                propagateComposedEvents: true

                                onPressed: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        mouse.accepted = true
                                    }
                                }

                                onReleased: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        const imgX = (parent.x - drawLayer.offsetX) / drawLayer.scaleX
                                        const imgY = (parent.y - drawLayer.offsetY) / drawLayer.scaleY
                                        arrowModel.setProperty(modelIndex, "x", imgX)
                                        arrowModel.setProperty(modelIndex, "y", imgY)
                                    }
                                }

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        arrowModel.remove(modelIndex)
                                        mouse.accepted = true
                                    }
                                }
                            }

                            // Rotation über Pfeilspitze
                            Rectangle {
                                id: tipTarget
                                width: 24
                                height: 24
                                color: "transparent"
                                x: parent.width - width
                                y: (parent.height - height) / 2
                                z: 999

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.CrossCursor

                                    onPressed: (mouse) => {
                                        const globalCenter = arrowItem.mapToItem(globalCircleCanvas, Qt.point(arrowItem.width / 2, arrowItem.height / 2))
                                        rotationHelper.startRotation(this, mouse, globalCenter, rotationAngle)
                                        drawLayer.showGlobalCircles = true
                                        drawLayer.circleCenterX = globalCenter.x
                                        drawLayer.circleCenterY = globalCenter.y
                                        drawLayer.circleInnerRadius = 10
                                        drawLayer.circleOuterRadius = 60
                                        globalCircleCanvas.requestPaint()
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!rotationHelper.active) return
                                        const newAngle = rotationHelper.updateAngle(this, mouse)
                                        rotationAngle = newAngle
                                        arrowModel.setProperty(modelIndex, "rotationAngle", newAngle)
                                    }

                                    onReleased: {
                                        rotationHelper.active = false
                                        drawLayer.showGlobalCircles = false
                                        globalCircleCanvas.requestPaint()
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Math.round(rotationAngle) + "°"
                                font.pixelSize: 14
                                color: "white"
                                visible: drawLayer.showGlobalCircles
                                z: 9999
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
                    const rects = [];

                    for (let i = 0; i < rectanglesModel.count; ++i) {
                        const r = rectanglesModel.get(i);

                        const x = parseInt(Math.min(r.startX, r.endX));
                        const y = parseInt(Math.min(r.startY, r.endY));
                        const width = parseInt(Math.abs(r.endX - r.startX));
                        const height = parseInt(Math.abs(r.endY - r.startY));
                        const angle = parseInt(r.rotationAngle || 0);

                        rects.push(`${x},${y},${width},${height},${angle}`);
                    }

                    const excludeString = rects.join("|");

                    accepted(excludeString);
                    imageWindow.visible = false;
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
