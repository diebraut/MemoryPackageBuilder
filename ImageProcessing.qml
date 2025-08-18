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

    function openWithImage(path, screenW, screenH, excludeRect, arrowDesc) {
        rectanglesModel.clear();
        arrowModel.clear();
        imagePreview.source = "";
        imageWindow.visible = false;

        Qt.callLater(() => {
            imagePreview.source = path;
        });

        imagePreview.statusChanged.connect(function handler() {
            if (imagePreview.status === Image.Ready) {
                imagePreview.statusChanged.disconnect(handler);

                let imgW = imagePreview.sourceSize.width;
                let imgH = imagePreview.sourceSize.height;

                if (imgW <= 0 || imgH <= 0) {
                    imgW = imagePreview.paintedWidth;
                    imgH = imagePreview.paintedHeight;
                }

                if (imgW <= 0 || imgH <= 0) {
                    imgW = 400;
                    imgH = 300;
                }

                imagePreview.originalImageWidth = imagePreview.sourceSize.width;
                imagePreview.originalImageHeight = imagePreview.sourceSize.height;

                const availableWidth = screenW || Screen.desktopAvailableWidth;
                const availableHeight = screenH || Screen.desktopAvailableHeight;
                const buttonsHeight = buttonsRow.implicitHeight + layout.spacing;
                const windowMargin = 40;

                const targetW = Math.min(imgW * 1.1 + windowMargin, availableWidth * 0.95);
                const targetH = Math.min(imgH * 1.1 + buttonsHeight + windowMargin, availableHeight * 0.95);

                imageWindow.width = targetW;
                imageWindow.height = targetH;
                imageWindow.x = (availableWidth - targetW) / 2;
                imageWindow.y = (availableHeight - targetH) / 2;

                loadRectanglesFromString(excludeRect);
                loadArrowsFromString(arrowDesc);

                imageWindow.visible = true;
            }
        });
    }

    function loadRectanglesFromString(excludeRect) {
        rectanglesModel.clear();
        if (!excludeRect || typeof excludeRect !== "string") return;

        const entries = excludeRect.split("|");
        for (let i = 0; i < entries.length; ++i) {
            const parts = entries[i].split(",");
            if (parts.length >= 5) {
                const startX = parseFloat(parts[0]);
                const startY = parseFloat(parts[1]);
                const width = parseFloat(parts[2]);
                const height = parseFloat(parts[3]);
                const rotationAngle = parseFloat(parts[4]);
                const color = (parts.length >= 6 && parts[5]) ? parts[5] : "red"; // ✅ neu: farbe optional

                if (!isNaN(startX) && !isNaN(startY) &&
                    !isNaN(width) && !isNaN(height) &&
                    !isNaN(rotationAngle)) {
                    rectanglesModel.append({
                        startX: startX,
                        startY: startY,
                        endX: startX + width,
                        endY: startY + height,
                        rotationAngle: rotationAngle,
                        color: color                             // ✅ neu
                    });
                } else {
                    console.warn("❌ Ungültige Rechteckdaten:", entries[i]);
                }
            } else {
                console.warn("❌ Unvollständige Rechteckbeschreibung:", entries[i]);
            }
        }
    }

    function loadArrowsFromString(arrowDesc) {
        arrowModel.clear()
        if (!arrowDesc || typeof arrowDesc !== "string") return

        const entries = arrowDesc.split("|")
        for (let j = 0; j < entries.length; ++j) {
            const parts = entries[j].split(",")
            if (parts.length >= 5) {
                const x = parseFloat(parts[0])
                const y = parseFloat(parts[1])
                const angle = parseFloat(parts[2])
                const color = parts[3]
                const scale = parseFloat(parts[4])
                if (!isNaN(x) && !isNaN(y)) {
                    arrowModel.append({
                        x: x,
                        y: y,
                        rotationAngle: angle,
                        color: color,
                        scaleFactor: isNaN(scale) ? 1.0 : scale
                    })
                }
            }
        }
    }

    Item {
        id: globalHelper
        anchors.fill: parent
    }

    Component {
        id: resizeHandleComponent
        Rectangle {
            id: handleRect
            width: Math.max(12, targetRectItem.height * 0.2)
            height: width
            color: "#80FFFFFF"
            radius: 3
            z: 3000

            property string mode: ""
            property int modelIndex: -1
            property Item targetRectItem: parent

            // ✅ Cursor als Enum (kein String)
            property int cursorShapeValue: Qt.ArrowCursor

            x: (mode === "topRight" || mode === "bottomRight") ? (targetRectItem.width - width) : 0
            y: (mode === "bottomLeft" || mode === "bottomRight") ? (targetRectItem.height - height) : 0

            MouseArea {
                id: handleMA
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                cursorShape: handleRect.cursorShapeValue   // bleibt als Fallback beim Drag

                property real originalStartX: 0
                property real originalStartY: 0
                property real originalEndX: 0
                property real originalEndY: 0
                property real startMouseGX: 0
                property real startMouseGY: 0

                onEntered:  cursorShape = handleRect.cursorShapeValue
                onExited:   cursorShape = Qt.ArrowCursor

                onPressed: (mouse) => {
                    const g = parent.mapToItem(drawLayer, Qt.point(mouse.x, mouse.y))
                    startMouseGX = g.x
                    startMouseGY = g.y

                    const r = rectanglesModel.get(modelIndex)
                    if (r) {
                        originalStartX = r.startX
                        originalStartY = r.startY
                        originalEndX   = r.endX
                        originalEndY   = r.endY
                    }
                    mouse.accepted = true
                    cursorShape = handleRect.cursorShapeValue
                }

                onPositionChanged: (mouse) => {
                    if (modelIndex < 0 || modelIndex >= rectanglesModel.count) return

                    const nowG = parent.mapToItem(drawLayer, Qt.point(mouse.x, mouse.y))
                    const dx = nowG.x - startMouseGX
                    const dy = nowG.y - startMouseGY

                    let newStartX = originalStartX
                    let newStartY = originalStartY
                    let newEndX   = originalEndX
                    let newEndY   = originalEndY

                    switch (handleRect.mode) {
                    case "topLeft":
                        newStartX = Math.min(originalStartX + dx, originalEndX)
                        newStartY = Math.min(originalStartY + dy, originalEndY)
                        break
                    case "topRight":
                        newEndX   = Math.max(originalEndX + dx, originalStartX)
                        newStartY = Math.min(originalStartY + dy, originalEndY)
                        break
                    case "bottomLeft":
                        newStartX = Math.min(originalStartX + dx, originalEndX)
                        newEndY   = Math.max(originalEndY + dy, originalStartY)
                        break
                    case "bottomRight":
                        newEndX   = Math.max(originalEndX + dx, originalStartX)
                        newEndY   = Math.max(originalEndY + dy, originalStartY)
                        break
                    }

                    rectanglesModel.setProperty(modelIndex, "startX", newStartX)
                    rectanglesModel.setProperty(modelIndex, "startY", newStartY)
                    rectanglesModel.setProperty(modelIndex, "endX",   newEndX)
                    rectanglesModel.setProperty(modelIndex, "endY",   newEndY)
                }
            }

            Image {
                anchors.fill: parent
                fillMode: Image.Stretch
                source: {
                    switch (mode) {
                        case "topLeft":     return "qrc:/icons/arrow_to_left_top_and_right_bottom.png"
                        case "topRight":    return "qrc:/icons/arrow_to_left_bottom_and_right_top.png"
                        case "bottomLeft":  return "qrc:/icons/arrow_to_left_bottom_and_right_top.png"
                        case "bottomRight": return "qrc:/icons/arrow_to_left_top_and_right_bottom.png"
                        default:            return ""
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
                anchors.fill: parent
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

                    onStatusChanged: if (status === Image.Ready) {
                        console.log("Image loaded:", sourceSize.width, sourceSize.height)
                    }
                }

                // =======================
                //  drawLayer – Overlays nur über dem Bild (geclippt)
                // =======================
                Item {
                    id: drawLayer
                    anchors.fill: parent
                    z: 2

                    // ---- Geometrie & Status ----
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
                    property int  rotatingIndex: -1          // Index des aktuell rotierenden Objekts
                    property string rotatingKind: ""         // "rect" oder "arrow"

                    property real circleCenterX: 0
                    property real circleCenterY: 0
                    property real circleInnerRadius: 0
                    property real circleOuterRadius: 0

                    property string defaultRectColor: "black"
                    property string defaultArrowColor: "red"

                    // ---- Daten ----
                    ListModel { id: rectanglesModel }
                    ListModel { id: arrowModel }

                    // ---- Helper ----
                    function imageOffsetX() { return (imagePreview.width - imagePreview.paintedWidth) / 2 }
                    function imageOffsetY() { return (imagePreview.height - imagePreview.paintedHeight) / 2 }

                    function pointInRotatedRect(x, y, rect) {
                        const cx = (rect.startX + rect.endX) / 2
                        const cy = (rect.startY + rect.endY) / 2
                        const angle = - (rect.rotationAngle || 0) * Math.PI / 180
                        const dx = x - cx, dy = y - cy
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
                        const cosA = Math.cos(angle), sinA = Math.sin(angle)
                        const corners = [[-width/2,-height/2],[width/2,-height/2],[width/2,height/2],[-width/2,height/2]]
                        for (let i = 0; i < 4; ++i) {
                            const localX = corners[i][0], localY = corners[i][1]
                            const rotatedX = localX * cosA - localY * sinA
                            const rotatedY = localX * sinA + localY * cosA
                            const screenX = rotCenterX + rotatedX
                            const screenY = rotCenterY + rotatedY
                            if (!isPointInImage(screenX, screenY)) return false
                        }
                        return true
                    }

                    // =======================
                    //  Clip-Container NUR über dem Bild
                    // =======================
                    Item {
                        id: imageClip
                        x: drawLayer.offsetX
                        y: drawLayer.offsetY
                        width: imagePreview.paintedWidth
                        height: imagePreview.paintedHeight
                        clip: true
                        z: 2

                        // --- Rechtecke ---
                        Repeater {
                            id: rectRepeater
                            model: rectanglesModel
                            z: 100

                            Rectangle {
                                id: rectItem
                                clip: false

                                Behavior on width { NumberAnimation { duration: 50 } }
                                Behavior on height { NumberAnimation { duration: 50 } }

                                x: Math.min(model.startX, model.endX) * drawLayer.scaleX
                                y: Math.min(model.startY, model.endY) * drawLayer.scaleY
                                width: Math.abs(model.endX - model.startX) * drawLayer.scaleX
                                height: Math.abs(model.endY - model.startY) * drawLayer.scaleY

                                color: "transparent"
                                border.color: model.color || "red"   // ✅ neu: farbe aus model
                                border.width: 2

                                property bool dragging: false
                                property int modelIndex: index
                                property var handles: []
                                property real rotationAngle: model.rotationAngle !== undefined ? model.rotationAngle : 0

                                transform: Rotation {
                                    origin.x: rectItem.width / 2
                                    origin.y: rectItem.height / 2
                                    angle: rectItem.rotationAngle
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(rectItem.rotationAngle) + "°"
                                    font.pixelSize: 14
                                    color: "white"
                                    z: 4000
                                    visible: drawLayer.showGlobalCircles
                                             && drawLayer.rotatingKind === "rect"
                                             && drawLayer.rotatingIndex === rectItem.modelIndex
                                }

                                // ---- Resize-Handles (erwarte vorhandenes resizeHandleComponent) ----
                                Loader {
                                    sourceComponent: resizeHandleComponent
                                    onLoaded: {
                                        item.mode = "topLeft"
                                        item.cursorShapeValue = Qt.SizeFDiagCursor
                                        item.modelIndex = rectItem.modelIndex
                                        item.targetRectItem = rectItem
                                        item.z = 3000
                                        rectItem.handles.push(item)
                                    }
                                }
                                Loader {
                                    sourceComponent: resizeHandleComponent
                                    onLoaded: {
                                        item.mode = "topRight"
                                        item.cursorShapeValue = Qt.SizeBDiagCursor
                                        item.modelIndex = rectItem.modelIndex
                                        item.targetRectItem = rectItem
                                        item.z = 3000
                                        rectItem.handles.push(item)
                                    }
                                }
                                Loader {
                                    sourceComponent: resizeHandleComponent
                                    onLoaded: {
                                        item.mode = "bottomLeft"
                                        item.cursorShapeValue = Qt.SizeBDiagCursor
                                        item.modelIndex = rectItem.modelIndex
                                        item.targetRectItem = rectItem
                                        item.z = 3000
                                        rectItem.handles.push(item)
                                    }
                                }
                                Loader {
                                    sourceComponent: resizeHandleComponent
                                    onLoaded: {
                                        item.mode = "bottomRight"
                                        item.cursorShapeValue = Qt.SizeFDiagCursor
                                        item.modelIndex = rectItem.modelIndex
                                        item.targetRectItem = rectItem
                                        item.z = 3000
                                        rectItem.handles.push(item)
                                    }
                                }

                                // ---- Move-Zone (mittleres Drittel) ----
                                Rectangle {
                                    id: innerArea
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: parent.width / 3
                                    width: parent.width / 3
                                    height: parent.height
                                    color: "#80000000"
                                    z: 1001

                                    MouseArea {
                                        id: moveMA
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        preventStealing: true
                                        hoverEnabled: true
                                        propagateComposedEvents: true
                                        cursorShape: rectItem.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                        // Drag-Hilfsvariablen
                                        property real startGX: 0
                                        property real startGY: 0
                                        property real origStartX: 0
                                        property real origStartY: 0
                                        property real origEndX: 0
                                        property real origEndY: 0

                                        onPressed: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                // Drag vorbereiten
                                                const g = moveMA.mapToItem(drawLayer, Qt.point(mouse.x, mouse.y))
                                                startGX = g.x
                                                startGY = g.y

                                                const r = rectanglesModel.get(rectItem.modelIndex)
                                                if (r) {
                                                    origStartX = r.startX
                                                    origStartY = r.startY
                                                    origEndX   = r.endX
                                                    origEndY   = r.endY
                                                }
                                                rectItem.dragging = true
                                                cursorShape = Qt.ClosedHandCursor
                                                mouse.accepted = true
                                            } else if (mouse.button === Qt.RightButton) {
                                                // Rechtsklick akzeptieren; Menü wird in onClicked geöffnet
                                                mouse.accepted = true
                                            }
                                        }

                                        onPositionChanged: (mouse) => {
                                            if (!rectItem.dragging) return

                                            const g = moveMA.mapToItem(drawLayer, Qt.point(mouse.x, mouse.y))
                                            const dx = (g.x - startGX) / drawLayer.scaleX
                                            const dy = (g.y - startGY) / drawLayer.scaleY

                                            rectanglesModel.setProperty(rectItem.modelIndex, "startX", origStartX + dx)
                                            rectanglesModel.setProperty(rectItem.modelIndex, "startY", origStartY + dy)
                                            rectanglesModel.setProperty(rectItem.modelIndex, "endX",   origEndX   + dx)
                                            rectanglesModel.setProperty(rectItem.modelIndex, "endY",   origEndY   + dy)
                                        }

                                        onReleased: {
                                            rectItem.dragging = false
                                            cursorShape = Qt.OpenHandCursor
                                        }

                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                rectMenu.popup(mouse.screenX, mouse.screenY) // Kontextmenü nur bei Rechtsklick
                                                mouse.accepted = true
                                            } else {
                                                // Linksklick: keine Sonderbehandlung – Drag läuft über onPressed/onPositionChanged
                                                mouse.accepted = false
                                            }
                                        }

                                        // Kontextmenü (wie bei den Pfeilen)
                                        Menu {
                                            id: rectMenu
                                            function choose(c) {
                                                rectanglesModel.setProperty(rectItem.modelIndex, "color", c)  // Rahmen einfärben
                                                drawLayer.defaultRectColor = c                                // ← neuen Default merken
                                            }

                                            MenuItem { text: "Schwarz"; checkable: true; checked: drawLayer.defaultRectColor === "black"; onTriggered: rectMenu.choose("black") }
                                            MenuItem { text: "Weiß";   checkable: true; checked: drawLayer.defaultRectColor === "white"; onTriggered: rectMenu.choose("white") }
                                            MenuItem { text: "Rot";    checkable: true; checked: drawLayer.defaultRectColor === "red";   onTriggered: rectMenu.choose("red") }
                                            MenuItem { text: "Blau";   checkable: true; checked: drawLayer.defaultRectColor === "blue";  onTriggered: rectMenu.choose("blue") }
                                            MenuItem { text: "Grün";   checkable: true; checked: drawLayer.defaultRectColor === "green"; onTriggered: rectMenu.choose("green") }
                                            MenuItem { text: "Gelb";   checkable: true; checked: drawLayer.defaultRectColor === "yellow";onTriggered: rectMenu.choose("yellow") }
                                            MenuSeparator {}
                                             // 🔴 neues Menüitem, NICHT checkable
                                             MenuItem {
                                                 text: "Strich (transp. Hintergrund)"
                                                 onTriggered: {
                                                     rectanglesModel.setProperty(rectItem.modelIndex, "color", "none")
                                                 }
                                             }
                                            MenuSeparator {}
                                            MenuItem { text: "Löschen"; onTriggered: rectanglesModel.remove(rectItem.modelIndex) }
                                        }
                                    }
                                }

                                // ---- Außenfläche: Cursor/Rotation ----
                                MouseArea {
                                    id: outerMouseArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    hoverEnabled: true
                                    propagateComposedEvents: true
                                    cursorShape: Qt.ArrowCursor

                                    property real dragStartAngle: 0
                                    property real dragInitialRotation: 0
                                    property real centerGlobalX: 0
                                    property real centerGlobalY: 0

                                    function pointInPoly(px, py, pts) {
                                        let inside = false;
                                        for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
                                            const xi = pts[i].x, yi = pts[i].y;
                                            const xj = pts[j].x, yj = pts[j].y;
                                            const intersect = ((yi > py) !== (yj > py)) &&
                                                              (px < (xj - xi) * (py - yi) / ((yj - yi) || 1e-9) + xi);
                                            if (intersect) inside = !inside;
                                        }
                                        return inside;
                                    }

                                    function handleUnderMouse(mx, my) {
                                        for (let i = 0; i < rectItem.handles.length; ++i) {
                                            const h = rectItem.handles[i];
                                            if (!h) continue;
                                            const p0 = h.mapToItem(outerMouseArea, Qt.point(0, 0));
                                            const p1 = h.mapToItem(outerMouseArea, Qt.point(h.width, 0));
                                            const p2 = h.mapToItem(outerMouseArea, Qt.point(h.width, h.height));
                                            const p3 = h.mapToItem(outerMouseArea, Qt.point(0, h.height));
                                            if (pointInPoly(mx, my, [p0, p1, p2, p3])) return h;
                                        }
                                        return null;
                                    }

                                    function updateCursor(mx, my) {
                                        const h = handleUnderMouse(mx, my);
                                        if (h) {
                                            return; // Handle setzt seinen Cursor selbst
                                        }
                                        const mp = outerMouseArea.mapToItem(innerArea, Qt.point(mx, my));
                                        if (mp.x >= 0 && mp.x <= innerArea.width && mp.y >= 0 && mp.y <= innerArea.height) {
                                            outerMouseArea.cursorShape = rectItem.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
                                            return;
                                        }
                                        outerMouseArea.cursorShape = Qt.ArrowCursor;
                                    }

                                    onEntered: updateCursor(mouseX, mouseY)
                                    onExited:  outerMouseArea.cursorShape = Qt.ArrowCursor

                                    onPressed: (mouse) => {
                                        if (handleUnderMouse(mouse.x, mouse.y)) {
                                            mouse.accepted = false; // Handle bekommt Event
                                            return;
                                        }
                                        const m = outerMouseArea.mapToItem(innerArea, Qt.point(mouse.x, mouse.y));
                                        if (m.x < 0 || m.x > innerArea.width || m.y < 0 || m.y > innerArea.height) {
                                            const center = rectItem.mapToItem(globalCircleCanvas, Qt.point(rectItem.width / 2, rectItem.height / 2));
                                            centerGlobalX = center.x; centerGlobalY = center.y;

                                            const cm = outerMouseArea.mapToItem(globalCircleCanvas, Qt.point(mouse.x, mouse.y));
                                            const dx = cm.x - centerGlobalX, dy = cm.y - centerGlobalY;
                                            dragStartAngle = Math.atan2(dy, dx);
                                            dragInitialRotation = rectItem.rotationAngle;

                                            const outerRadius = Math.sqrt((rectItem.width / 2) ** 2 + (rectItem.height / 2) ** 2);
                                            drawLayer.circleOuterRadius = outerRadius;

                                            const innerCorner = innerArea.mapToItem(globalCircleCanvas, Qt.point(0, 0));
                                            const ix = centerGlobalX - innerCorner.x, iy = centerGlobalY - innerCorner.y;
                                            drawLayer.circleInnerRadius = Math.sqrt(ix * ix + iy * iy);

                                            drawLayer.circleCenterX = centerGlobalX;
                                            drawLayer.circleCenterY = centerGlobalY;
                                            drawLayer.showGlobalCircles = true;
                                            drawLayer.rotatingKind = "rect";
                                            drawLayer.rotatingIndex = rectItem.modelIndex;

                                            globalCircleCanvas.requestPaint();

                                            mouse.accepted = true;
                                        } else {
                                            mouse.accepted = false; // Move-Zone kümmert sich
                                        }
                                    }

                                    onPositionChanged: (mouse) => {
                                        updateCursor(mouse.x, mouse.y);
                                        if (drawLayer.showGlobalCircles) {
                                            const cm = outerMouseArea.mapToItem(globalCircleCanvas, Qt.point(mouse.x, mouse.y));
                                            const dx = cm.x - centerGlobalX, dy = cm.y - centerGlobalY;
                                            const angle = Math.atan2(dy, dx);
                                            const delta = angle - dragStartAngle;
                                            if (Math.abs(delta) > 0.003) {
                                                rectItem.rotationAngle = dragInitialRotation + delta * 180 / Math.PI;
                                                rectanglesModel.setProperty(rectItem.modelIndex, "rotationAngle", rectItem.rotationAngle);
                                            }
                                        }
                                    }

                                    onReleased: {
                                        drawLayer.showGlobalCircles = false;
                                        globalCircleCanvas.requestPaint();
                                    }
                                }
                            }
                        }

                        // --- Blaue Zeichen-Vorschau ---
                        Rectangle {
                            visible: drawLayer.drawing
                            color: "transparent"
                            border.color: "blue"
                            border.width: 2
                            x: Math.min(drawLayer.startX, drawLayer.currentX) * drawLayer.scaleX
                            y: Math.min(drawLayer.startY, drawLayer.currentY) * drawLayer.scaleY
                            width: Math.abs(drawLayer.currentX - drawLayer.startX) * drawLayer.scaleX
                            height: Math.abs(drawLayer.currentY - drawLayer.startY) * drawLayer.scaleY
                        }

                        // --- Pfeile ---
                        Repeater {
                            model: arrowModel
                            delegate: Item {
                                id: arrowItem
                                width: 96; height: 96
                                x: model.x * drawLayer.scaleX
                                y: model.y * drawLayer.scaleY
                                z: 2100

                                property int modelIndex: index
                                property real rotationAngle: model.rotationAngle || 0
                                property real centerX: width / 2
                                property real centerY: height / 2

                                function setColor(newColor) {
                                    arrowModel.setProperty(modelIndex, "color", newColor)
                                    var srcFile = "qrc:/icons/arrow-right-" + newColor + ".png"
                                    arrowImageID.source = srcFile
                                    arrowPlaceholder.source = srcFile
                                    drawLayer.selectedArrowColor = newColor
                                }

                                transform: Rotation {
                                    origin.x: centerX
                                    origin.y: centerY
                                    angle: rotationAngle
                                }

                                Image {
                                    id: arrowImageID
                                    anchors.fill: parent
                                    source: "qrc:/icons/arrow-right-" + model.color + ".png"
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
                                        if (mouse.button === Qt.RightButton) mouse.accepted = true
                                    }

                                    onReleased: (mouse) => {
                                        if (mouse.button === Qt.LeftButton) {
                                            const imgX = parent.x / drawLayer.scaleX
                                            const imgY = parent.y / drawLayer.scaleY
                                            arrowModel.setProperty(modelIndex, "x", imgX)
                                            arrowModel.setProperty(modelIndex, "y", imgY)
                                        }
                                    }

                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            colorMenu.popup(mouse.screenX, mouse.screenY)
                                            mouse.accepted = true
                                        }
                                    }

                                    Menu {
                                        id: colorMenu
                                        function choose(c) {
                                            arrowModel.setProperty(arrowItem.modelIndex, "color", c)   // Pfeil einfärben
                                            drawLayer.defaultArrowColor = c                            // ← neuen Default merken
                                        }

                                        MenuItem { text: "Schwarz"; checkable: true; checked: drawLayer.defaultArrowColor === "black"; onTriggered: colorMenu.choose("black") }
                                        MenuItem { text: "Weiß";   checkable: true; checked: drawLayer.defaultArrowColor === "white"; onTriggered: colorMenu.choose("white") }
                                        MenuItem { text: "Rot";    checkable: true; checked: drawLayer.defaultArrowColor === "red";   onTriggered: colorMenu.choose("red") }
                                        MenuItem { text: "Blau";   checkable: true; checked: drawLayer.defaultArrowColor === "blue";  onTriggered: colorMenu.choose("blue") }
                                        MenuItem { text: "Grün";   checkable: true; checked: drawLayer.defaultArrowColor === "green"; onTriggered: colorMenu.choose("green") }
                                        MenuItem { text: "Gelb";   checkable: true; checked: drawLayer.defaultArrowColor === "yellow";onTriggered: colorMenu.choose("yellow") }

                                        MenuSeparator {}
                                        MenuItem { text: "Löschen"; onTriggered: arrowModel.remove(arrowItem.modelIndex) }
                                    }
                                }

                                Rectangle {
                                    id: tipTarget
                                    width: 24; height: 24
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
                                            drawLayer.rotatingKind = "arrow";
                                            drawLayer.rotatingIndex = arrowItem.modelIndex;
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
                                            rotationHelper.active = false
                                            drawLayer.showGlobalCircles = false
                                            drawLayer.rotatingKind = ""
                                            drawLayer.rotatingIndex = -1
                                            globalCircleCanvas.requestPaint()
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
                                             && drawLayer.rotatingKind === "arrow"
                                             && drawLayer.rotatingIndex === arrowItem.modelIndex
                                    z: 9999
                                }
                            }
                        }

                        // --- Rotations-Hilfskreise (geclippt aufs Bild) ---
                        Canvas {
                            id: globalCircleCanvas
                            anchors.fill: parent
                            visible: drawLayer.showGlobalCircles
                            z: 999

                            onPaint: {
                                const ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                if (!drawLayer.showGlobalCircles) return
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

                    // =======================
                    //  Zeichenfläche (außerhalb des Clips)
                    // =======================
                    MouseArea {
                        id: drawArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton

                        onPressed: (mouse) => {
                            if (!drawLayer.isPointInImage(mouse.x, mouse.y)) return;

                            var imgX = (mouse.x - drawLayer.offsetX) / drawLayer.scaleX
                            var imgY = (mouse.y - drawLayer.offsetY) / drawLayer.scaleY

                            if (drawLayer.pointInExistingRect(imgX, imgY)) {
                                mouse.accepted = false; // bestehendes Rechteck bewegt
                                return;
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
                            if (!drawLayer.drawing) return
                            drawLayer.drawing = false
                            drawLayer.currentX = (mouse.x - drawLayer.offsetX) / drawLayer.scaleX
                            drawLayer.currentY = (mouse.y - drawLayer.offsetY) / drawLayer.scaleY

                            if (Math.abs(drawLayer.currentX - drawLayer.startX) >= 1 &&
                                Math.abs(drawLayer.currentY - drawLayer.startY) >= 1) {
                                rectanglesModel.append({
                                    startX: drawLayer.startX,
                                    startY: drawLayer.startY,
                                    endX: drawLayer.currentX,
                                    endY: drawLayer.currentY,
                                    rotationAngle: 0,
                                    color: drawLayer.defaultRectColor   // ← Rechteck-Default nutzen
                                })
                            }
                        }
                    }

                    // ---- Dreh-Helfer ----
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

                    // (Optional) unbenutztes, aber referenced
                    Component {
                        id: arrowPrototype
                        Image {
                            id: arrowPrototypeImageID
                            property string color:  drawLayer.defaultArrowColor
                            source: ""
                            width: 96
                            height: 96
                            opacity: 0.6
                            z: 3100
                            layer.enabled: true
                            onColorChanged: source = "qrc:/icons/arrow-right-" + color + ".png"
                            Component.onCompleted: source = "qrc:/icons/arrow-right-" + color + ".png"
                        }
                    }
                }
            }
        }

        // =======================
        //  Untere Steuerleiste
        // =======================
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            // Linker Rand: Pfeil (Farbvorschau)
            Image {
                id: arrowPlaceholder
                source: "qrc:/icons/arrow-right-" + drawLayer.defaultArrowColor + ".png"
                fillMode: Image.Stretch
                opacity: 0.5
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: tempArrow ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                    // temporärer Ghost-Pfeil, der auf dem drawLayer schwebt
                    property var tempArrow: null

                    function toDrawLayerPoint(mx, my) {
                        // Mauspunkt aus der dragArea ins drawLayer koord-transformieren
                        return dragArea.mapToItem(drawLayer, Qt.point(mx, my));
                    }

                    onPressed: (mouse) => {
                        const p = toDrawLayerPoint(mouse.x, mouse.y);
                        // Ghost auf dem drawLayer erzeugen (über dem Image)
                        tempArrow = arrowPrototype.createObject(drawLayer, {
                            x: p.x - 48,   // halbe Breite: 96/2
                            y: p.y - 48,
                            z: 3200        // sicher über dem Image
                        });
                        mouse.accepted = true;
                    }

                    onPositionChanged: (mouse) => {
                        if (!tempArrow) return;
                        const p = toDrawLayerPoint(mouse.x, mouse.y);
                        tempArrow.x = p.x - tempArrow.width  / 2;
                        tempArrow.y = p.y - tempArrow.height / 2;
                    }

                    onReleased: (mouse) => {
                        if (!tempArrow) return;

                        // Ghost-Position (drawLayer→Bildkoordinaten) ins Model übernehmen
                        let imgX = (tempArrow.x - drawLayer.offsetX) / drawLayer.scaleX;
                        let imgY = (tempArrow.y - drawLayer.offsetY) / drawLayer.scaleY;

                        // optional: auf Bildgrenzen clampen
                        const maxX = imagePreview.originalImageWidth  - tempArrow.width  / drawLayer.scaleX;
                        const maxY = imagePreview.originalImageHeight - tempArrow.height / drawLayer.scaleY;
                        imgX = Math.max(0, Math.min(imgX, maxX));
                        imgY = Math.max(0, Math.min(imgY, maxY));

                        arrowModel.append({
                            x: imgX,
                            y: imgY,
                            rotationAngle: 0,
                            color: drawLayer.defaultArrowColor,  // ← Pfeil-Default nutzen
                            scaleFactor: 1.0
                        })

                        tempArrow.destroy();
                        tempArrow = null;
                    }

                    onCanceled: {
                        if (tempArrow) { tempArrow.destroy(); tempArrow = null; }
                    }
                }
            }

            // Flex-Spacing
            Item { Layout.fillWidth: true }

            // Buttons mittig
            RowLayout {
                id: buttonsRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Button {
                    text: "OK"
                    function saveRectanglesToString() {
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
                        return rects.join("|");
                    }
                    function saveArrowsToString() {
                        const arrows = [];
                        for (let i = 0; i < arrowModel.count; ++i) {
                            const a = arrowModel.get(i);
                            const x = parseFloat(a.x).toFixed(2);
                            const y = parseFloat(a.y).toFixed(2);
                            const rot = parseInt(a.rotationAngle || 0);
                            const col = a.color || "red";
                            const scale = parseFloat(a.scaleFactor || 1.0).toFixed(2);
                            arrows.push(`${x},${y},${rot},${col},${scale}`);
                        }
                        return arrows.join("|");
                    }
                    onClicked: {
                        const excludeString = saveRectanglesToString();
                        const arrowString = saveArrowsToString();

                        const sourcePath = imagePreview.source.toString().toLowerCase();
                        let xmlKey = sourcePath.includes("frage") ? "ArrowDescFra" : "ArrowDescAnt";

                        accepted(JSON.stringify({
                            excludeData: excludeString,
                            arrowData: arrowString,
                            arrowKey: xmlKey
                        }));

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

            // rechter Flex-Spacing
            Item { Layout.fillWidth: true }
        }
    }
}
