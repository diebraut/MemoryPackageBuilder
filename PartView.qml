import QtQuick 2.15

Item {
    id: part

    clip: true
    property int index: 0
    property bool selected: false
    property string label: ""
    property real borderWidth: 3
    property color highlightColor: "#0077ff"

    property real marginLeft: 0
    property real marginTop: 0
    property real marginRight: 0
    property real marginBottom: 0

    property real zoomFactor: 1.0
    property real minZoom: 0.2
    property real maxZoom: 5.0

    property bool resizedByUser: false
    property bool transparentColorPickMode: false
    property real pipetteCursorX: 0
    property real pipetteCursorY: 0
    property bool pipetteCursorVisible: false

    property alias imageSource: image.source
    property alias imageSourceSize: image.sourceSize

    signal clicked(int index)
    signal transparentColorPicked(int index, string imageSource, int imageX, int imageY)
    signal transparentColorPickCanceled()

    signal frameReadyChanged(bool ready)
    signal frameGeometryChanged()

    onTransparentColorPickModeChanged: {
        if (!transparentColorPickMode)
            pipetteCursorVisible = false
    }

    // PartView.qml, irgendwo unter deinen properties/Funktionen:
    function frameRectIn(targetItem) {
        var ti = targetItem ? targetItem : part.parent
        var p = imageFrame.mapToItem(ti, 0, 0)
        return { x: p.x, y: p.y, w: imageFrame.width, h: imageFrame.height,
                 ready: image.status === Image.Ready, visible: imageFrame.visible }
    }

    function pointIsInsideImageFrame(x, y) {
        return image.status === Image.Ready
                && x >= imageFrame.x
                && y >= imageFrame.y
                && x <= imageFrame.x + imageFrame.width
                && y <= imageFrame.y + imageFrame.height
    }

    function updatePipetteFromPartPoint(x, y) {
        pipetteCursorX = x
        pipetteCursorY = y
        pipetteCursorVisible = transparentColorPickMode && pointIsInsideImageFrame(x, y)
    }

    function pickTransparentColorAtPartPoint(x, y) {
        if (!pointIsInsideImageFrame(x, y)) {
            pipetteCursorVisible = false
            transparentColorPickCanceled()
            return
        }

        const sourceW = image.sourceSize.width
        const sourceH = image.sourceSize.height
        if (sourceW <= 0 || sourceH <= 0) {
            pipetteCursorVisible = false
            transparentColorPickCanceled()
            return
        }

        const localX = x - imageFrame.x
        const localY = y - imageFrame.y
        const imageX = Math.max(0, Math.min(sourceW - 1, Math.floor(localX / imageFrame.width * sourceW)))
        const imageY = Math.max(0, Math.min(sourceH - 1, Math.floor(localY / imageFrame.height * sourceH)))
        pipetteCursorVisible = false
        transparentColorPicked(index, String(image.source), imageX, imageY)
    }

    function updatePickOverlayCursor() {
        if (pickOverlay.containsMouse && pointIsInsideImageFrame(pickOverlay.mouseX, pickOverlay.mouseY))
            pickOverlay.cursorShape = Qt.BlankCursor
        else
            pickOverlay.cursorShape = Qt.ArrowCursor
    }

    // Resize-Konfiguration
    QtObject {
        id: resizeConfigHelper
        property var edgeConfigs: [
            { pos: "right",  edge: "right",  w: 6,  h: -1, cursor: Qt.SizeHorCursor },
            { pos: "left",   edge: "left",   w: 6,  h: -1, cursor: Qt.SizeHorCursor },
            { pos: "top",    edge: "top",    w: -1, h: 6,  cursor: Qt.SizeVerCursor },
            { pos: "bottom", edge: "bottom", w: -1, h: 6,  cursor: Qt.SizeVerCursor },
            { pos: "topLeft",     edge: "topLeft",    w: 10, h: 10, cursor: Qt.SizeFDiagCursor },
            { pos: "topRight",    edge: "topRight",   w: 10, h: 10, cursor: Qt.SizeBDiagCursor },
            { pos: "bottomLeft",  edge: "bottomLeft", w: 10, h: 10, cursor: Qt.SizeBDiagCursor },
            { pos: "bottomRight", edge: "bottomRight",w: 10, h: 10, cursor: Qt.SizeFDiagCursor }
        ]
    }

    // Originale Größe und Position
    property real frameWidth: 100  // Startgröße setzen
    property real frameHeight: 100 // Startgröße setzen

    // Resize-Variablen
    property real initialW: 0
    property real initialH: 0
    property real initialX: 0
    property real initialY: 0
    property real dragStartX: 0
    property real dragStartY: 0
    property string resizingEdge: ""
    property bool resizing: false

    // Neue Hilfsfunktion für Positionsberechnung
    function calculateEdgePosition(dx, dy) {
        switch(resizingEdge) {
        case "right":
            return {
                width: Math.max(10, initialW + dx),
                height: initialH,
                x: initialX,
                y: initialY
            }
        case "left":
            var w = Math.max(10, initialW - dx)
            return {
                width: w,
                height: initialH,
                x: initialX + (initialW - w),
                y: initialY
            }
        case "bottom":
            return {
                width: initialW,
                height: Math.max(10, initialH + dy),
                x: initialX,
                y: initialY
            }
        case "top":
            var h = Math.max(10, initialH - dy)
            return {
                width: initialW,
                height: h,
                x: initialX,
                y: initialY + (initialH - h)
            }
        case "topLeft":
            var w1 = Math.max(10, initialW - dx)
            var h1 = Math.max(10, initialH - dy)
            return {
                width: w1,
                height: h1,
                x: initialX + (initialW - w1),
                y: initialY + (initialH - h1)
            }
        case "topRight":
            var w2 = Math.max(10, initialW + dx)
            var h2 = Math.max(10, initialH - dy)
            return {
                width: w2,
                height: h2,
                x: initialX,
                y: initialY + (initialH - h2)
            }
        case "bottomLeft":
            var w3 = Math.max(10, initialW - dx)
            var h3 = Math.max(10, initialH + dy)
            return {
                width: w3,
                height: h3,
                x: initialX + (initialW - w3),
                y: initialY
            }
        case "bottomRight":
            return {
                width: Math.max(10, initialW + dx),
                height: Math.max(10, initialH + dy),
                x: initialX,
                y: initialY
            }
        default:
            return {
                width: initialW,
                height: initialH,
                x: initialX,
                y: initialY
            }
        }
    }

    function setImage(path) {
        image.source = ""
        image.source = path
        image.visible = true
    }

    function adjustZoom(multiplier) {
        if (image.status !== Image.Ready)
            return false

        let newZoom = zoomFactor * multiplier
        newZoom = Math.max(minZoom, Math.min(maxZoom, newZoom))

        if (Math.abs(newZoom - zoomFactor) < 0.001)
            return false

        const centerX = imageFrame.x + imageFrame.width / 2
        const centerY = imageFrame.y + imageFrame.height / 2

        zoomFactor = newZoom
        resizedByUser = true
        frameWidth = image.sourceSize.width * zoomFactor
        frameHeight = image.sourceSize.height * zoomFactor
        imageFrame.x = centerX - frameWidth / 2
        imageFrame.y = centerY - frameHeight / 2
        return true
    }

    function moveImage(deltaX, deltaY) {
        if (image.status !== Image.Ready)
            return false

        resizedByUser = true
        imageFrame.x += deltaX
        imageFrame.y += deltaY
        return true
    }

    function updateImageFrameSize() {

        if (resizing || resizedByUser) return;

        const iw = image.sourceSize.width
        const ih = image.sourceSize.height

        if (iw === 0 || ih === 0) return;

        const imageAspect = iw / ih
        const partAspect = part.width / part.height

        if (imageAspect > partAspect) {
            frameWidth = part.width
            frameHeight = part.width / imageAspect
        } else {
            frameHeight = part.height
            frameWidth = part.height * imageAspect
        }

        imageFrame.x = (part.width - frameWidth) / 2
        imageFrame.y = (part.height - frameHeight) / 2
    }

    // Größenänderungen überwachen
    onWidthChanged: updateImageFrameSize()
    onHeightChanged: updateImageFrameSize()

    Rectangle {
        id: imageFrame
        color: "transparent"
        border.color: "red"
        border.width: 2
        visible: image.status === Image.Ready
        z: 1

        width: frameWidth
        height: frameHeight

        onXChanged: part.frameGeometryChanged()
        onYChanged: part.frameGeometryChanged()
        onWidthChanged: part.frameGeometryChanged()
        onHeightChanged: part.frameGeometryChanged()

        MouseArea {
            id: imageMouseArea
            anchors.fill: parent
            enabled: !part.transparentColorPickMode
            drag.target: imageFrame
            cursorShape: Qt.ClosedHandCursor
            acceptedButtons: Qt.LeftButton
            onDoubleClicked: {
                resizedByUser = false
                zoomFactor = 1.0
                updateImageFrameSize()
            }
            // optional auch beim User-Resizing feuern (in den MouseAreas):
            onReleased: {
                resizing = false
                part.frameGeometryChanged()
            }
            onWheel: function(wheel) {
                adjustZoom(wheel.angleDelta.y > 0 ? 1.1 : 0.9)
                return
                let delta = wheel.angleDelta.y > 0 ? 1.1 : 0.9
                let newZoom = zoomFactor * delta
                newZoom = Math.max(minZoom, Math.min(maxZoom, newZoom))

                if (Math.abs(newZoom - zoomFactor) < 0.001)
                    return

                zoomFactor = newZoom
                resizedByUser = true

                // Neue Größe
                frameWidth = image.sourceSize.width * zoomFactor
                frameHeight = image.sourceSize.height * zoomFactor

                // Zentriert im Parent (part)
                imageFrame.x = (part.width - frameWidth) / 2
                imageFrame.y = (part.height - frameHeight) / 2
            }
        }

        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (adjustZoom(event.angleDelta.y > 0 ? 1.1 : 0.9))
                    event.accepted = true
            }
        }

        Repeater {
            model: resizeConfigHelper.edgeConfigs.length
            delegate: MouseArea {
                property var conf: resizeConfigHelper.edgeConfigs[index]
                width: conf.w > 0 ? conf.w : imageFrame.width
                height: conf.h > 0 ? conf.h : imageFrame.height
                cursorShape: conf.cursor
                enabled: image.status === Image.Ready && !part.transparentColorPickMode

                anchors {
                    top: conf.pos.indexOf("top") !== -1 ? parent.top : undefined
                    bottom: conf.pos.indexOf("bottom") !== -1 ? parent.bottom : undefined
                    left: conf.pos.indexOf("left") !== -1 ? parent.left : undefined
                    right: conf.pos.indexOf("right") !== -1 ? parent.right : undefined
                }

                onPressed: (mouse) => {
                    part.resizing = true
                    dragStartX = mouse.x
                    dragStartY = mouse.y
                    initialW = imageFrame.width
                    initialH = imageFrame.height
                    initialX = imageFrame.x
                    initialY = imageFrame.y
                    resizingEdge = conf.edge
                }

                onPositionChanged: (mouse) => {
                    resizedByUser = true
                    if (!resizing) return

                    const dx = mouse.x - dragStartX
                    const dy = mouse.y - dragStartY

                    // Direkte Größen- und Positionsberechnung
                    const newPos = calculateEdgePosition(dx, dy)

                    frameWidth = newPos.width
                    frameHeight = newPos.height
                    imageFrame.x = newPos.x
                    imageFrame.y = newPos.y
                }

                onReleased: {
                    resizing = false
                }
            }
        }

        Image {
            id: image
            anchors.fill: parent
            fillMode: Image.Stretch
            cache: false
            asynchronous: true
            smooth: false // Während Resizing keine Glättung
            antialiasing: false // Während Resizing kein Antialiasing

            // Performance-Optimierungen
            layer.enabled: !resizing
            layer.smooth: !resizing
            mipmap: !resizing

            onStatusChanged: if (status === Image.Ready) {
                updateImageFrameSize()
                part.frameReadyChanged(true)
                // WICHTIG: erst nach dem nächsten Tick neu berechnen
                Qt.callLater(part.frameGeometryChanged)
            }

            // Falls sich die Quellgröße später meldet
            onSourceSizeChanged: {
                updateImageFrameSize()
                Qt.callLater(part.frameGeometryChanged)
            }
        }
    }

    Canvas {
        id: pipetteCursor
        width: 28
        height: 28
        x: part.pipetteCursorX + 8
        y: part.pipetteCursorY + 8
        z: 50
        visible: part.transparentColorPickMode && part.pipetteCursorVisible
        Component.onCompleted: requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            ctx.strokeStyle = "black"
            ctx.lineWidth = 5
            ctx.beginPath()
            ctx.moveTo(6, 22)
            ctx.lineTo(20, 8)
            ctx.stroke()

            ctx.strokeStyle = "white"
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.moveTo(6, 22)
            ctx.lineTo(20, 8)
            ctx.stroke()

            ctx.strokeStyle = "black"
            ctx.lineWidth = 4
            ctx.beginPath()
            ctx.moveTo(16, 4)
            ctx.lineTo(24, 12)
            ctx.stroke()

            ctx.strokeStyle = "white"
            ctx.lineWidth = 2
            ctx.beginPath()
            ctx.moveTo(16, 4)
            ctx.lineTo(24, 12)
            ctx.stroke()

            ctx.fillStyle = "black"
            ctx.beginPath()
            ctx.arc(5, 23, 3, 0, Math.PI * 2)
            ctx.fill()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onClicked: function(mouse) {
            if (part.transparentColorPickMode) {
                part.pipetteCursorVisible = false
                part.transparentColorPickCanceled()
                return
            }
            part.clicked(index)
        }
    }

    MouseArea {
        id: pickOverlay
        anchors.fill: parent
        z: 40
        enabled: part.transparentColorPickMode
        visible: enabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor

        onEntered: {
            part.updatePipetteFromPartPoint(mouseX, mouseY)
            part.updatePickOverlayCursor()
        }

        onExited: {
            part.pipetteCursorVisible = false
            part.updatePickOverlayCursor()
        }

        onPositionChanged: function(mouse) {
            part.updatePipetteFromPartPoint(mouse.x, mouse.y)
            part.updatePickOverlayCursor()
        }

        onPressed: function(mouse) {
            part.updatePipetteFromPartPoint(mouse.x, mouse.y)
            mouse.accepted = true
        }

        onClicked: function(mouse) {
            part.pickTransparentColorAtPartPoint(mouse.x, mouse.y)
            mouse.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: selected
        color: "transparent"
        border.color: highlightColor
        border.width: borderWidth
        anchors.leftMargin: marginLeft
        anchors.topMargin: marginTop
        anchors.rightMargin: marginRight
        anchors.bottomMargin: marginBottom
        z: 4
    }
}
