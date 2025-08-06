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

    property alias imageSource: image.source

    signal clicked(int index)

    signal frameReadyChanged(bool ready)
    signal frameGeometryChanged()

    // PartView.qml, irgendwo unter deinen properties/Funktionen:
    function frameRectIn(targetItem) {
        var ti = targetItem ? targetItem : part.parent
        var p = imageFrame.mapToItem(ti, 0, 0)
        return { x: p.x, y: p.y, w: imageFrame.width, h: imageFrame.height,
                 ready: image.status === Image.Ready, visible: imageFrame.visible }
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
            anchors.fill: parent
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

        Repeater {
            model: resizeConfigHelper.edgeConfigs.length
            delegate: MouseArea {
                property var conf: resizeConfigHelper.edgeConfigs[index]
                width: conf.w > 0 ? conf.w : imageFrame.width
                height: conf.h > 0 ? conf.h : imageFrame.height
                cursorShape: conf.cursor
                enabled: image.status === Image.Ready

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

    MouseArea {
        anchors.fill: parent
        onClicked: part.clicked(index)
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
