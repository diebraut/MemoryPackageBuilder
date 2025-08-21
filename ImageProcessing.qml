import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtQuick.Shapes 1.15


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


    // --- Auswahl-Index & Helfer ---
    Item {
        id: kbHelpers
        property int selectedRectIndex: -1      // aktuell gewähltes Rechteck

        function applyToSelected(fn) {
            const i = selectedRectIndex;
            if (i < 0 || i >= rectanglesModel.count) return;
            const r = rectanglesModel.get(i);
            fn(r, i);
        }

        function nudge(dx, dy, step) {   // bewegen
            const s = step || 1;
            applyToSelected((r,i) => {
                rectanglesModel.setProperty(i, "startX", r.startX + dx*s);
                rectanglesModel.setProperty(i, "endX",   r.endX   + dx*s);
                rectanglesModel.setProperty(i, "startY", r.startY + dy*s);
                rectanglesModel.setProperty(i, "endY",   r.endY   + dy*s);
            });
        }
        function resizeBy(dw, dh, step) { // Größe (unten-rechts) ändern
            const s = step || 1;
            applyToSelected((r,i) => {
                rectanglesModel.setProperty(i, "endX", r.endX + dw*s);
                rectanglesModel.setProperty(i, "endY", r.endY + dh*s);
            });
        }
        function rotateBy(deg) {
            applyToSelected((r,i) => {
                rectanglesModel.setProperty(i, "rotationAngle", (Number(r.rotationAngle)||0) + deg);
            });
        }
        function setRotation(deg) {
            applyToSelected((r,i) => {
                rectanglesModel.setProperty(i, "rotationAngle", deg);
            });
        }
        function snapSelected() {
            applyToSelected((r,i) => {
                const a = Number(r.rotationAngle) || 0;
                rectanglesModel.setProperty(i, "rotationAngle", drawLayer.snappedRightAngle(a));
            });
        }
    }

    // --- Shortcuts: Pfeile bewegen; Shift+Pfeil = Resize; Ctrl = 10px; Alt+Links/Rechts = drehen ---
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: Qt.Key_Left;     onActivated: kbHelpers.nudge(-1, 0, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: Qt.Key_Right;    onActivated: kbHelpers.nudge( 1, 0, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: Qt.Key_Up;       onActivated: kbHelpers.nudge( 0,-1, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: Qt.Key_Down;     onActivated: kbHelpers.nudge( 0, 1, 1) }

    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Ctrl+Left";     onActivated: kbHelpers.nudge(-10, 0, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Ctrl+Right";    onActivated: kbHelpers.nudge( 10, 0, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Ctrl+Up";       onActivated: kbHelpers.nudge( 0,-10, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Ctrl+Down";     onActivated: kbHelpers.nudge( 0, 10, 1) }

    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Shift+Left";    onActivated: kbHelpers.resizeBy(-1, 0, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Shift+Right";   onActivated: kbHelpers.resizeBy( 1, 0, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Shift+Up";      onActivated: kbHelpers.resizeBy( 0,-1, 1) }
    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; autoRepeat: true; sequence: "Shift+Down";    onActivated: kbHelpers.resizeBy( 0, 1, 1) }

    Shortcut { enabled: imageWindow.visible; context: Qt.WindowShortcut; sequence: "Esc"; onActivated: kbHelpers.selectedRectIndex = -1 }

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
                const rectTranspWithLine =
                    (parts.length >= 7) ? (parts[6] === "1" || parts[6].toLowerCase?.() === "true") : false;

                if (!isNaN(startX) && !isNaN(startY) &&
                    !isNaN(width) && !isNaN(height) &&
                    !isNaN(rotationAngle)) {
                    rectanglesModel.append({
                        startX: startX,
                        startY: startY,
                        endX: startX + width,
                        endY: startY + height,
                        rotationAngle: rotationAngle,
                        color: color,
                        rectTranspWithLine: rectTranspWithLine       // NEU
                    });                } else {
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
                    kbHelpers.selectedRectIndex = modelIndex;
                    drawLayer.selectRect(modelIndex);        // << hinzufügen
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
                onReleased: {
                    keyScope.forceActiveFocus();                 // <— nur wenn du die Fokus-Variante nutzt
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
                    property bool   defaultRectTranspWithLine: false   // NEU

                    // ---- Daten ----
                    ListModel { id: rectanglesModel }
                    ListModel { id: arrowModel }

                    // ---- Helper ----
                    // --- Auswahlstatus ---
                    property int  selectedRectIndex:  -1
                    property int  selectedArrowIndex: -1

                    function selectRect(i)  { selectedRectIndex  = i; selectedArrowIndex = -1; }
                    function selectArrow(i) { selectedArrowIndex = i; selectedRectIndex  = -1; }

                    function cycleRect(dir) {
                        if (rectanglesModel.count <= 0) return;
                        if (selectedRectIndex < 0) selectedRectIndex = 0;
                        else selectedRectIndex = (selectedRectIndex + dir + rectanglesModel.count) % rectanglesModel.count;
                    }
                    function cycleArrow(dir) {
                        if (arrowModel.count <= 0) return;
                        if (selectedArrowIndex < 0) selectedArrowIndex = 0;
                        else selectedArrowIndex = (selectedArrowIndex + dir + arrowModel.count) % arrowModel.count;
                    }

                    function keyMoveStep(mods) {
                        if (mods & Qt.AltModifier)   return 0.5;
                        if (mods & Qt.ControlModifier) return 10;
                        if (mods & Qt.ShiftModifier) return 5;
                        return 1;
                    }

                    // --- Geometrie-Helfer (Rect in Bildkoordinaten) ---
                    function moveSelectedRect(dx, dy) {
                        const i = selectedRectIndex; if (i < 0) return;
                        const r = rectanglesModel.get(i);
                        rectanglesModel.setProperty(i, "startX", r.startX + dx);
                        rectanglesModel.setProperty(i, "startY", r.startY + dy);
                        rectanglesModel.setProperty(i, "endX",   r.endX   + dx);
                        rectanglesModel.setProperty(i, "endY",   r.endY   + dy);
                    }
                    function moveSelectedArrow(dx, dy) {
                        const i = selectedArrowIndex; if (i < 0) return;
                        const a = arrowModel.get(i);
                        arrowModel.setProperty(i, "x", a.x + dx);
                        arrowModel.setProperty(i, "y", a.y + dy);
                    }

                    // einseitig resizen (ändert „End“-Seite, bleibt simpel & stabil)
                    function resizeSelectedRect(dir, amount) {
                        const i = selectedRectIndex; if (i < 0) return;
                        const r = rectanglesModel.get(i);
                        let sx = r.startX, sy = r.startY, ex = r.endX, ey = r.endY;

                        if (dir === "left") {
                            // welche Seite ist „links“ in Model-Koords?
                            if (sx <= ex) sx += amount; else ex += amount;
                        } else if (dir === "right") {
                            if (sx <= ex) ex += amount; else sx += amount;
                        } else if (dir === "up") {
                            if (sy <= ey) sy += amount; else ey += amount;
                        } else if (dir === "down") {
                            if (sy <= ey) ey += amount; else sy += amount;
                        }
                        rectanglesModel.setProperty(i, "startX", sx);
                        rectanglesModel.setProperty(i, "startY", sy);
                        rectanglesModel.setProperty(i, "endX",   ex);
                        rectanglesModel.setProperty(i, "endY",   ey);
                    }

                    function rotateSelectedRect(deltaDeg, snap=false, reset=false) {
                        const i = selectedRectIndex; if (i < 0) return;
                        const r = rectanglesModel.get(i);
                        let ang = reset ? 0 : (Number(r.rotationAngle)||0) + (deltaDeg||0);
                        if (snap) ang = drawLayer.snappedRightAngle(ang);
                        rectanglesModel.setProperty(i, "rotationAngle", ang);
                    }
                    function rotateSelectedArrow(deltaDeg, snap=false, reset=false) {
                        const i = selectedArrowIndex; if (i < 0) return;
                        const a = arrowModel.get(i);
                        let ang = reset ? 0 : (Number(a.rotationAngle)||0) + (deltaDeg||0);
                        if (snap) ang = drawLayer.snappedRightAngle(ang);
                        arrowModel.setProperty(i, "rotationAngle", ang);
                    }
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
                    // In drawLayer {} hinzufügen (neben rotationHelper)

                    function snappedRightAngle(a) {
                        // map nach [0,360)
                        let m = ((a % 360) + 360) % 360;
                        const cand = [0, 90, 180, 270, 360];
                        let best = m, diff = 999;
                        for (let c of cand) {
                            const d = Math.abs(m - c);
                            if (d < diff) { best = c; diff = d; }
                        }
                        if (diff <= 0.2) return (best === 360 ? 0 : best); // Toleranz ~0.2°
                        return a;
                    }

                    function isAxisAligned(a) {
                        const s = drawLayer.snappedRightAngle(a);
                        return s === 0 || s === 90 || s === 180 || s === 270;
                    }
                    function snapCoord(v, strokeWidth) {
                        const dpr = Screen.devicePixelRatio;
                        const w = (strokeWidth || 1) * dpr;
                        const iv = Math.round(v * dpr);
                        return (w % 2 === 1) ? (iv + 0.5) / dpr : iv / dpr;
                    }
                    function snapSize(v) {
                        const dpr = Screen.devicePixelRatio;
                        return Math.max(1, Math.round(v * dpr)) / dpr;
                    }
                    function snapAbs(v) {               // absolute Koordinaten (z.B. imageClip.x/y)
                        const dpr = Screen.devicePixelRatio;
                        return Math.round(v * dpr) / dpr;
                    }
                    function snapAbsHalfAware(v, strokeWidth) {
                        const dpr = Screen.devicePixelRatio;
                        const w = (strokeWidth || 1) * dpr;
                        const iv = Math.round(v * dpr);
                        return (w % 2 === 1) ? (iv + 0.5) / dpr : iv / dpr;
                    }

                    // =======================
                    //  Clip-Container NUR über dem Bild imageClip
                    // =======================
                    Item {
                        id: imageClip
                        x: drawLayer.snapAbs(drawLayer.offsetX)
                        y: drawLayer.snapAbs(drawLayer.offsetY)
                        width:  drawLayer.snapAbs(imagePreview.paintedWidth)
                        height: drawLayer.snapAbs(imagePreview.paintedHeight)
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

                                property bool dragging: false
                                property int modelIndex: index
                                property var handles: []

                                readonly property int strokeW: 2
                                readonly property bool axisAligned: drawLayer.isAxisAligned(model.rotationAngle || 0)

                                // 🔹 Gestrichelter Rahmen als Overlay (nur wenn Flag gesetzt)
                                // --- Einzige Shape: gestrichelter Rahmen + mittige Linie ---
                                Shape {
                                    id: rectOverlay
                                    anchors.fill: parent
                                    visible: model.rectTranspWithLine
                                    z: 2

                                    // bei 0°/90° ohne Filter zeichnen → knackscharf
                                    layer.enabled: rectItem.axisAligned
                                    layer.smooth: false
                                    layer.mipmap: false

                                    // gemeinsam genutzte Hilfen
                                    property real inset: rectItem.strokeW / 2     // Strich innen führen
                                    property int  centerLineW: 3                  // mittlere Linie 3 px
                                    // DPR-bewusste Y-Position der mittigen Linie (odd width → +0.5 px)
                                    property real cy: {
                                        const dpr = Screen.devicePixelRatio;
                                        const iw  = centerLineW * dpr;
                                        const iv  = Math.round((height / 2) * dpr);
                                        return (iw % 2 === 1) ? (iv + 0.5) / dpr : iv / dpr;
                                    }

                                    // 1) Gestrichelter Rechteck-Rahmen
                                    ShapePath {
                                        strokeWidth: rectItem.strokeW
                                        strokeColor: drawLayer.defaultRectColor
                                        fillColor: "transparent"
                                        strokeStyle: ShapePath.DashLine
                                        capStyle: ShapePath.FlatCap
                                        joinStyle: ShapePath.MiterJoin
                                        dashPattern: [6, 4]

                                        startX: rectOverlay.inset
                                        startY: rectOverlay.inset
                                        PathLine { x: rectOverlay.width  - rectOverlay.inset; y: rectOverlay.inset }
                                        PathLine { x: rectOverlay.width  - rectOverlay.inset; y: rectOverlay.height - rectOverlay.inset }
                                        PathLine { x: rectOverlay.inset; y: rectOverlay.height - rectOverlay.inset }
                                        PathLine { x: rectOverlay.inset; y: rectOverlay.inset }
                                    }

                                    // 2) Mittige, solide Linie (horizontale)
                                    ShapePath {
                                        strokeWidth: rectOverlay.centerLineW
                                        strokeColor: drawLayer.defaultRectColor
                                        fillColor: "transparent"
                                        strokeStyle: ShapePath.SolidLine
                                        capStyle: ShapePath.FlatCap
                                        joinStyle: ShapePath.MiterJoin

                                        startX: rectOverlay.inset
                                        startY: rectOverlay.cy
                                        PathLine { x: rectOverlay.width - rectOverlay.inset; y: rectOverlay.cy }
                                    }
                                }                                // ✨ Transform-Liste dynamisch setzen
                                // Auswahl-Outline (unabhängig vom Strichmodus)
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: "#66A8D1FF"   // cyan-ish
                                    border.width: 2
                                    visible: drawLayer.selectedRectIndex === rectItem.modelIndex
                                    z: 5000
                                }
                                Component.onCompleted: updateTransform()
                                onAxisAlignedChanged: updateTransform()

                                Rotation {
                                    id: rectRot
                                    origin.x: rectItem.width / 2
                                    origin.y: rectItem.height / 2
                                    angle: model.rotationAngle || 0
                                }

                                // ✨ Anti-Aliasing für die Kante aus, wenn achs-aligned
                                antialiasing: !axisAligned ? true : false

                                // ✨ Deine bestehenden Snappings bleiben wie sie sind:
                                x: axisAligned
                                   ? drawLayer.snapCoord(Math.min(model.startX, model.endX) * drawLayer.scaleX, strokeW)
                                   : Math.min(model.startX, model.endX) * drawLayer.scaleX

                                y: axisAligned
                                   ? drawLayer.snapCoord(Math.min(model.startY, model.endY) * drawLayer.scaleY, strokeW)
                                   : Math.min(model.startY, model.endY) * drawLayer.scaleY

                                width: axisAligned
                                   ? drawLayer.snapSize(Math.abs(model.endX - model.startX) * drawLayer.scaleX)
                                   : Math.abs(model.endX - model.startX) * drawLayer.scaleX

                                height: axisAligned
                                   ? drawLayer.snapSize(Math.abs(model.endY - model.startY) * drawLayer.scaleY)
                                   : Math.abs(model.endY - model.startY) * drawLayer.scaleY

                                color: "transparent"
                                // 🔹 Normale Linie nur zeigen, wenn NICHT gestrichelt
                                border.color: model.rectTranspWithLine ? "transparent" : (model.color || "red")
                                border.width: strokeW

                                Behavior on width  { NumberAnimation { duration: rectItem.axisAligned ? 0 : 50 } }
                                Behavior on height { NumberAnimation { duration: rectItem.axisAligned ? 0 : 50 } }

                                function updateTransform() {
                                    rectItem.transform = rectItem.axisAligned ? [] : [rectRot];
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(model.rotationAngle || 0) + "°"
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
                                            drawLayer.selectRect(rectItem.modelIndex);
                                            if (mouse.button === Qt.LeftButton) {
                                                kbHelpers.selectedRectIndex = rectItem.modelIndex;  // <— NEU
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
                                            keyScope.forceActiveFocus();
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
                                                checkable: true
                                                // Anzeige wie bei Default-Farbe: globaler Default steuert den Haken
                                                checked: drawLayer.defaultRectTranspWithLine
                                                onTriggered: {
                                                    const newVal = !drawLayer.defaultRectTranspWithLine;
                                                    drawLayer.defaultRectTranspWithLine = newVal;                 // Default umschalten
                                                    rectanglesModel.setProperty(rectItem.modelIndex, "rectTranspWithLine", newVal); // aktuelles Rect setzen
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
                                        kbHelpers.selectedRectIndex = rectItem.modelIndex;
                                        drawLayer.selectRect(rectItem.modelIndex);
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
                                            dragInitialRotation = (model.rotationAngle || 0);

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
                                                const newDeg = dragInitialRotation + delta * 180 / Math.PI;
                                                rectanglesModel.setProperty(rectItem.modelIndex, "rotationAngle", newDeg);
                                            }
                                        }
                                    }
                                    onReleased: {
                                        drawLayer.showGlobalCircles = false;
                                        // SNAP HINZUFÜGEN:
                                        const snapped = drawLayer.snappedRightAngle(model.rotationAngle || 0);
                                        rectanglesModel.setProperty(rectItem.modelIndex, "rotationAngle", snapped);

                                        globalCircleCanvas.requestPaint();
                                        keyScope.forceActiveFocus();
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
                                property real centerX: width / 2
                                property real centerY: height / 2

                                function setColor(newColor) {
                                    arrowModel.setProperty(modelIndex, "color", newColor)
                                    var srcFile = "qrc:/icons/arrow-right-" + newColor + ".png"
                                    arrowImageID.source = srcFile
                                    arrowPlaceholder.source = srcFile
                                    drawLayer.selectedArrowColor = newColor
                                }

                                transform: [
                                    Rotation {
                                        origin.x: centerX
                                        origin.y: centerY
                                        angle: model.rotationAngle || 0
                                    }
                                ]
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
                                        drawLayer.selectArrow(arrowItem.modelIndex);
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
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: "#66A8D1FF"
                                    border.width: 2
                                    visible: drawLayer.selectedArrowIndex === arrowItem.modelIndex
                                    z: 9999
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
                                            rotationHelper.startRotation(this, mouse, globalCenter, model.rotationAngle || 0)
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
                                            arrowModel.setProperty(modelIndex, "rotationAngle", newAngle)
                                        }
                                        onReleased: {
                                            rotationHelper.active = false
                                            drawLayer.showGlobalCircles = false
                                            drawLayer.rotatingKind = ""
                                            drawLayer.rotatingIndex = -1

                                            // SNAP HINZUFÜGEN:
                                            const snapped = drawLayer.snappedRightAngle(model.rotationAngle || 0);
                                            arrowModel.setProperty(arrowItem.modelIndex, "rotationAngle", snapped);

                                            globalCircleCanvas.requestPaint()
                                        }
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: Math.round(model.rotationAngle || 0) + "°"
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
                                    endX:   drawLayer.currentX,
                                    endY:   drawLayer.currentY,
                                    rotationAngle: 0,
                                    color:  drawLayer.defaultRectColor,
                                    rectTranspWithLine: drawLayer.defaultRectTranspWithLine   // NEU
                                })
                                const idx = rectanglesModel.count - 1;
                                drawLayer.selectRect(idx);                  // << auswählen für Keys-Handler
                                kbHelpers.selectedRectIndex = idx;          // << (falls du kbHelpers noch nutzt)
                                keyScope.forceActiveFocus();                // << Fokus zurück an die Tastatur
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
            FocusScope {
                id: keyScope
                anchors.fill: parent
                focus: true
                Keys.priority: Keys.BeforeItem

                Component.onCompleted: forceActiveFocus()
                onActiveFocusChanged: if (activeFocus && imageWindow.visible) forceActiveFocus()
                Connections {
                    target: imageWindow
                    function onVisibleChanged(visible) {  // Qt 6: bool-Argument vorhanden
                        if (visible) keyScope.forceActiveFocus();
                    }
                }

                Keys.onPressed: (event) => {
                    // --- ALT + Arrow = Rotation (Shift = 15°), Alt+Up snap, Alt+Down reset ---
                    if ((event.modifiers & Qt.AltModifier) &&
                        (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                         event.key === Qt.Key_Up   || event.key === Qt.Key_Down)) {

                        console.log("Rotate key hit", event.key, "mods", event.modifiers);
                        const step = (event.modifiers & Qt.ShiftModifier) ? 15 : 1;

                        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                            const d = (event.key === Qt.Key_Left) ? -step : +step;
                            if (drawLayer.selectedRectIndex >= 0)
                                drawLayer.rotateSelectedRect(d, false, false);
                            else if (drawLayer.selectedArrowIndex >= 0)
                                drawLayer.rotateSelectedArrow(d, false, false);
                            event.accepted = true;
                            return;
                        }
                        if (event.key === Qt.Key_Up) {
                            if (drawLayer.selectedRectIndex >= 0)      drawLayer.rotateSelectedRect(0, true,  false);
                            else if (drawLayer.selectedArrowIndex >= 0) drawLayer.rotateSelectedArrow(0, true,  false);
                            event.accepted = true; return;
                        }
                        if (event.key === Qt.Key_Down) {
                            if (drawLayer.selectedRectIndex >= 0)      drawLayer.rotateSelectedRect(0, false, true);
                            else if (drawLayer.selectedArrowIndex >= 0) drawLayer.rotateSelectedArrow(0, false, true);
                            event.accepted = true; return;
                        }
                    }
                    // Q/E = ±1°, Shift = ±15°  (ohne Alt, damit kein OS "Alt+Pfeil"-Konflikt greift)
                    if (event.key === Qt.Key_Q || event.key === Qt.Key_E) {
                        console.log("Rotate (test) key hit", event.key, "mods", event.modifiers);
                        const step = (event.modifiers & Qt.ShiftModifier) ? 15 : 1;
                        const d = (event.key === Qt.Key_Q) ? -step : +step;

                        // falls noch nichts ausgewählt ist: letztes Rechteck oder Pfeil nehmen
                        if (drawLayer.selectedRectIndex < 0 && drawLayer.selectedArrowIndex < 0) {
                            if (rectanglesModel.count > 0)      drawLayer.selectRect(rectanglesModel.count - 1);
                            else if (arrowModel.count > 0)      drawLayer.selectArrow(arrowModel.count - 1);
                        }

                        if (drawLayer.selectedRectIndex >= 0)      drawLayer.rotateSelectedRect(d, false, false);
                        else if (drawLayer.selectedArrowIndex >= 0) drawLayer.rotateSelectedArrow(d, false, false);

                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Tab) {
                        if (event.modifiers & Qt.ControlModifier) {
                            drawLayer.cycleArrow(event.modifiers & Qt.ShiftModifier ? -1 : +1);
                        } else {
                            drawLayer.cycleRect(event.modifiers & Qt.ShiftModifier ? -1 : +1);
                        }
                        event.accepted = true; return;
                    }

                    // Delete: löschen
                    if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                        if (drawLayer.selectedRectIndex >= 0) {
                            rectanglesModel.remove(drawLayer.selectedRectIndex);
                            drawLayer.selectedRectIndex = Math.min(drawLayer.selectedRectIndex, rectanglesModel.count-1);
                        } else if (drawLayer.selectedArrowIndex >= 0) {
                            arrowModel.remove(drawLayer.selectedArrowIndex);
                            drawLayer.selectedArrowIndex = Math.min(drawLayer.selectedArrowIndex, arrowModel.count-1);
                        }
                        event.accepted = true; return;
                    }

                    // Space: Strichmodus toggeln (nur Rect)
                    if (event.key === Qt.Key_Space && drawLayer.selectedRectIndex >= 0) {
                        const i = drawLayer.selectedRectIndex;
                        const r = rectanglesModel.get(i);
                        rectanglesModel.setProperty(i, "rectTranspWithLine", !r.rectTranspWithLine);
                        event.accepted = true; return;
                    }

                    // Pfeile: Move / Resize / Rotate
                    const isArrowKey = (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                                        event.key === Qt.Key_Up   || event.key === Qt.Key_Down);
                    if (isArrowKey) {
                        // RESIZE (nur Rect): Shift + Arrow
                        if ((event.modifiers & Qt.ShiftModifier) && drawLayer.selectedRectIndex >= 0) {
                            const step = drawLayer.keyMoveStep(event.modifiers & ~Qt.ShiftModifier);
                            if (event.key === Qt.Key_Left)  drawLayer.resizeSelectedRect("left",  -step);
                            if (event.key === Qt.Key_Right) drawLayer.resizeSelectedRect("right", +step);
                            if (event.key === Qt.Key_Up)    drawLayer.resizeSelectedRect("up",    -step);
                            if (event.key === Qt.Key_Down)  drawLayer.resizeSelectedRect("down",  +step);
                            event.accepted = true; return;
                        }

                        // MOVE: ohne Shift/Ctrl → bewegen (Rect oder Arrow)
                        const step = drawLayer.keyMoveStep(event.modifiers);
                        let dx = 0, dy = 0;
                        if (event.key === Qt.Key_Left)  dx = -step;
                        if (event.key === Qt.Key_Right) dx = +step;
                        if (event.key === Qt.Key_Up)    dy = -step;
                        if (event.key === Qt.Key_Down)  dy = +step;

                        if (drawLayer.selectedRectIndex >= 0)      drawLayer.moveSelectedRect(dx, dy);
                        else if (drawLayer.selectedArrowIndex >= 0) drawLayer.moveSelectedArrow(dx, dy);
                        event.accepted = true; return;
                    }

                    // R: schnell Snapping zur nächsten 0/90/180/270 (nur Rect)
                    if (event.key === Qt.Key_R && drawLayer.selectedRectIndex >= 0) {
                        drawLayer.rotateSelectedRect(0, true, false);
                        event.accepted = true; return;
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

                            const sx = Number(r.startX) || 0;
                            const sy = Number(r.startY) || 0;
                            const ex = Number(r.endX)   || sx;
                            const ey = Number(r.endY)   || sy;

                            const x = Math.round(Math.min(sx, ex));
                            const y = Math.round(Math.min(sy, ey));
                            const width  = Math.max(0, Math.round(Math.abs(ex - sx)));
                            const height = Math.max(0, Math.round(Math.abs(ey - sy)));

                            // Winkel sicherheitshalber erneut snappen
                            const angle = Math.round(drawLayer.snappedRightAngle(Number(r.rotationAngle) || 0));

                            const color = r.color ? String(r.color) : "red";
                            const rtl   = r.rectTranspWithLine ? 1 : 0;   // 1 = an, 0 = aus

                            // Format: x,y,w,h,angle,color,rectTranspWithLine
                            rects.push(`${x},${y},${width},${height},${angle},${color},${rtl}`);
                        }
                        return rects.join("|");
                    }

                    function saveArrowsToString() {
                        const arrows = [];
                        for (let i = 0; i < arrowModel.count; ++i) {
                            const a = arrowModel.get(i);
                            const x = Number(a.x) || 0;
                            const y = Number(a.y) || 0;

                            // Winkel auch hier snappen
                            const rot = Math.round(drawLayer.snappedRightAngle(Number(a.rotationAngle) || 0));

                            const col   = a.color || "red";
                            const scale = (Number(a.scaleFactor) || 1).toFixed(2);

                            // Format: x,y,rot,color,scale
                            arrows.push(`${x.toFixed(2)},${y.toFixed(2)},${rot},${col},${scale}`);
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
