import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15
import QtQuick.Shapes 1.15
import QtCore
import FileHelper 1.0


Window {
    id: composerWindow

    Settings {
        id: composerState
        // persistenter Ort pro OS:
        category: "ImageComposer"   // trennt die Schlüssel logisch

        // deine Properties
        property int  x: 100
        property int  y: 100
        property int  w: 1000
        property int  h: 1000
        property int  anzeigeZustand: 1
        property int  selectedPartIndex: 1
        property int  layoutMode: 0
        property bool isVertical: true
        property real splitterRatio: 0.5
        property real splitterRatio1: 0.33
        property real splitterRatio2: 0.66
        property real layout1_splitX: 0.5
        property real layout1_splitY: 0.5
        property real layout2_splitX: 0.5
        property real layout2_splitY: 0.5
    }

    function clampToDesktop(win) {
        const dw = Screen.desktopAvailableWidth
        const dh = Screen.desktopAvailableHeight
        win.width  = Math.min(win.width,  dw)
        win.height = Math.min(win.height, dh)
        win.x = Math.max(0, Math.min(win.x, dw - win.width))
        win.y = Math.max(0, Math.min(win.y, dh - win.height))
    }

    function traversalOrder() {
        // Reihenfolge gemäß deiner Vorgaben:
        // - 2 Parts: vertical -> 1(oben),2(darunter); horizontal -> 1(links),2(rechts)
        // - 3 Parts layoutMode 0: alle untereinander/nebeneinander -> 1,2,3
        // - 3 Parts layoutMode 1: 1 oben, 2 unten links, 3 unten rechts -> 1,2,3
        // - 3 Parts layoutMode 2: 2 oben (links/rechts), 1 unten -> 1,2,3
        switch (anzeigeZustand) {
        case 1:  return [1];
        case 2:  return [1, 2];
        case 3:
            if (layoutMode === 1) return [1, 2, 3]; // oben=1, unten: 2,3
            if (layoutMode === 2) return [1, 2, 3]; // oben: 1,2; unten=3
            return [1, 2, 3];                       // „alle untereinander/nebeneinander“
        default: return [];
        }
    }

    function selectNextPart(dir) {
        const order = traversalOrder();
        if (!order.length) return;

        let i = order.indexOf(selectedPartIndex);
        if (i < 0) i = 0; // falls außerhalb
        i = (i + (dir > 0 ? 1 : -1) + order.length) % order.length;

        selectedPartIndex = order[i];
    }

    // Wiederherstellen beim Start
    Component.onCompleted: {
        // Wiederherstellen beim Start
        x = composerState.x
        y = composerState.y
        width  = composerState.w
        height = composerState.h
        clampToDesktop(composerWindow)

        anzeigeZustand     = composerState.anzeigeZustand
        selectedPartIndex  = composerState.selectedPartIndex
        layoutMode         = composerState.layoutMode
        isVertical         = composerState.isVertical
        splitterRatio      = composerState.splitterRatio
        splitterRatio1     = composerState.splitterRatio1
        splitterRatio2     = composerState.splitterRatio2
        layout1_splitX     = composerState.layout1_splitX
        layout1_splitY     = composerState.layout1_splitY
        layout2_splitX     = composerState.layout2_splitX
        layout2_splitY     = composerState.layout2_splitY

        // einmalig nach dem Aufbau: Outline neu berechnen
        rootItem.recomputeOutline()
        rootItem.forceActiveFocus();
        selectedPartIndex = 1
        composerState.selectedPartIndex = 1
    }

    // Geometrie zurückschreiben
    onXChanged:      composerState.x = x
    onYChanged:      composerState.y = y

    // Layout-Status zurückschreiben
    onAnzeigeZustandChanged: {
        composerState.anzeigeZustand = anzeigeZustand
        selectedPartIndex = 1
        composerState.selectedPartIndex = 1
    }

    onLayoutModeChanged: {
        composerState.layoutMode = layoutMode
        selectedPartIndex = 1
        composerState.selectedPartIndex = 1
    }

    onIsVerticalChanged: {
        composerState.isVertical = isVertical
        selectedPartIndex = 1
        composerState.selectedPartIndex = 1
    }

    onSplitterRatioChanged:     composerState.splitterRatio = splitterRatio
    onSplitterRatio1Changed:    composerState.splitterRatio1 = splitterRatio1
    onSplitterRatio2Changed:    composerState.splitterRatio2 = splitterRatio2
    onLayout1_splitXChanged:    composerState.layout1_splitX = layout1_splitX
    onLayout1_splitYChanged:    composerState.layout1_splitY = layout1_splitY
    onLayout2_splitXChanged:    composerState.layout2_splitX = layout2_splitX
    onLayout2_splitYChanged:    composerState.layout2_splitY = layout2_splitY

    width: 1000
    height: 1000
    visible: true
    title: "ImageComposer"
    flags: Qt.FramelessWindowHint | Qt.Window

    property string packagePath: ""
    property string subjektName: ""

    property int anzeigeZustand: 1
    property int selectedPartIndex: 1  // Standard: Teil 1

    property int layoutMode: 0
    property bool isVertical: true

    property real splitterRatio: 0.5
    property real splitterRatio1: 0.33
    property real splitterRatio2: 0.66

    property real layout1_splitX: 0.5
    property real layout1_splitY: 0.5
    property real layout2_splitY: 0.5
    property real layout2_splitX: 0.5

    signal modeSelected(string type)
    signal contentChanged()

    FontMetrics { id: menuFont }

    property Window parentWindow
    property bool lastParentActive: false
    property bool wasPositioned: false

    property bool isComposing: false
    property int  composeGen: 0
    property var  lastComposeStage: null
    property bool transparentColorPickMode: false
    property real keyboardZoomInFactor: 1.01
    property real keyboardZoomOutFactor: 0.99
    property int keyboardMoveStep: 1

    // Kann z. B. ganz oben im QML stehen
    QtObject {
        id: resizeConfigHelper
        property var edgeConfigs: [
            { pos: "right",  edge: Qt.RightEdge,  w: 6,  h: -1, cursor: Qt.SizeHorCursor },
            { pos: "left",   edge: Qt.LeftEdge,   w: 6,  h: -1, cursor: Qt.SizeHorCursor },
            { pos: "top",    edge: Qt.TopEdge,    w: -1, h: 6,  cursor: Qt.SizeVerCursor },
            { pos: "bottom", edge: Qt.BottomEdge, w: -1, h: 6,  cursor: Qt.SizeVerCursor },
            { pos: "topLeft",     edge: Qt.TopEdge | Qt.LeftEdge,    w: 10, h: 10, cursor: Qt.SizeFDiagCursor },
            { pos: "topRight",    edge: Qt.TopEdge | Qt.RightEdge,   w: 10, h: 10, cursor: Qt.SizeBDiagCursor },
            { pos: "bottomLeft",  edge: Qt.BottomEdge | Qt.LeftEdge, w: 10, h: 10, cursor: Qt.SizeBDiagCursor },
            { pos: "bottomRight", edge: Qt.BottomEdge | Qt.RightEdge,w: 10, h: 10, cursor: Qt.SizeFDiagCursor }
        ]
    }

    function toFileUrl(path) {
        if (path.startsWith("file://") || path.startsWith("qrc:/"))
            return path;
        return "file:///" + path.replace(/\\/g, "/");
    }

    function loadImageInCurrentMode(filePath) {
        console.log("📥 Lade Bild in Composer:", filePath);
        if (!filePath || filePath === "")
            return;

        const url = toFileUrl(filePath);
        const targetIndex = selectedPartIndex; // aktuellen Part fixieren

        switch (anzeigeZustand) {
            case 1:
                singlePartView.setImage(url);
                break;
            case 2:
                if (twoSplitter && twoSplitter.setImageForPart)
                    twoSplitter.setImageForPart(targetIndex, url);
                break;
            case 3:
                if (threeSplitter && threeSplitter.setImageForPart)
                    threeSplitter.setImageForPart(targetIndex, url);
                break;
            default:
                console.warn("❗ Ungültiger Anzeigestatus:", anzeigeZustand);
                return;
        }

        // ➜ Nach dem Laden automatisch zum nächsten Part springen
        if (typeof selectNextPart === "function") {
            selectNextPart(+1);
        } else {
            // Fallback: simple Rundlauf-Logik
            const max = (anzeigeZustand === 3) ? 3 : (anzeigeZustand === 2 ? 2 : 1);
            selectedPartIndex = (targetIndex % max) + 1;
        }
        contentChanged();
    }

    function temporaryPartIndex() {
        return anzeigeZustand > 1 ? selectedPartIndex : 0;
    }

    function pasteImageFromClipboard() {
        const partIndex = temporaryPartIndex()

        const effectivePackagePath =
                parentWindow && parentWindow.packagePath
                ? parentWindow.packagePath
                : packagePath

        const effectiveSubjektName =
                parentWindow && parentWindow.subjektName
                ? parentWindow.subjektName
                : subjektName

        console.log("[Clipboard] composer.packagePath =", packagePath)
        console.log("[Clipboard] composer.subjektName =", subjektName)
        console.log("[Clipboard] parent.packagePath =",
                    parentWindow ? parentWindow.packagePath : "<kein parent>")
        console.log("[Clipboard] parent.subjektName =",
                    parentWindow ? parentWindow.subjektName : "<kein parent>")
        console.log("[Clipboard] effektiv path =", effectivePackagePath)
        console.log("[Clipboard] effektiv name =", effectiveSubjektName)
        console.log("[Clipboard] part =", partIndex)

        if (!effectivePackagePath || effectivePackagePath === "") {
            console.warn("[Clipboard] packagePath fehlt")
            return
        }

        let effectiveBaseName = effectiveSubjektName

        if (!effectiveBaseName || effectiveBaseName.trim() === "") {
            effectiveBaseName = "ClipboardImage"
            console.log("[Clipboard] subjektName leer -> verwende:", effectiveBaseName)
        }

        const filePath = FileHelper.saveClipboardImageTemporary(
            effectivePackagePath,
            effectiveBaseName,
            partIndex
        )

        if (!filePath || filePath === "") {
            console.warn("Kein Bild aus der Zwischenablage eingefuegt")
            return
        }

        /*
         * Wichtig:
         * URLComponentProcessing benötigt diese beiden Werte später beim
         * Speichern eines einzelnen Bildes.
         */
        if (parentWindow) {
            parentWindow.tempImagePath = filePath
            parentWindow.finalImagePath = filePath.replace("_TEMP", "")
            parentWindow.imageAvailable = true
        }

        loadImageInCurrentMode(filePath)
    }

    function selectedPart() {
        const parts = rootItem && rootItem.activeParts ? rootItem.activeParts() : [];
        for (let i = 0; i < parts.length; ++i) {
            if (parts[i] && parts[i].index === selectedPartIndex)
                return parts[i];
        }
        return null;
    }

    function anyPartHasImage() {
        const parts = rootItem && rootItem.activeParts ? rootItem.activeParts() : [];
        for (let i = 0; i < parts.length; ++i) {
            if (parts[i] && parts[i].imageSource && parts[i].imageSource !== "")
                return true;
        }
        return false;
    }

    function selectedImageHasTransparency() {
        const part = selectedPart();
        return part && part.imageSource && part.imageSource !== ""
                && FileHelper.imageHasTransparency(String(part.imageSource));
    }

    function disableSelectedImageTransparency() {
        const part = selectedPart();
        if (!part || !part.imageSource || part.imageSource === "")
            return;

        const sourcePath = String(part.imageSource);
        if (FileHelper.flattenImageTransparencyOnWhite(sourcePath)) {
            reloadImageInPart(part.index, sourcePath);
            contentChanged();
        }
    }

    function startTransparentBackgroundPick() {
        if (!anyPartHasImage()) {
            console.warn("Hintergrund transparent: Es ist kein Bild geladen");
            return;
        }

        transparentColorPickMode = true;
    }

    function cancelTransparentBackgroundPick() {
        transparentColorPickMode = false;
    }

    function handlePartClicked(index) {
        if (transparentColorPickMode) {
            cancelTransparentBackgroundPick();
            return;
        }

        selectedPartIndex = index;
    }

    function reloadImageInPart(partIndex, sourcePath) {
        const url = toFileUrl(sourcePath);
        if (anzeigeZustand === 1) {
            singlePartView.setImage(url);
        } else if (anzeigeZustand === 2 && twoSplitter && twoSplitter.setImageForPart) {
            twoSplitter.setImageForPart(partIndex, url);
        } else if (anzeigeZustand === 3 && threeSplitter && threeSplitter.setImageForPart) {
            threeSplitter.setImageForPart(partIndex, url);
        }
    }

    function handleTransparentColorPicked(partIndex, imageSource, imageX, imageY) {
        if (!transparentColorPickMode)
            return;

        transparentColorPickMode = false;
        if (!imageSource || imageSource === "")
            return;

        if (FileHelper.makeImageColorTransparent(imageSource, imageX, imageY)) {
            reloadImageInPart(partIndex, imageSource);
            contentChanged();
        }
    }

    function zoomSelectedPart(multiplier) {
        const parts = rootItem && rootItem.activeParts ? rootItem.activeParts() : []
        let fallbackPart = null

        for (let i = 0; i < parts.length; ++i) {
            const part = parts[i]
            if (!fallbackPart && part && typeof part.adjustZoom === "function" && part.imageSource && part.imageSource !== "")
                fallbackPart = part

            if (part && part.index === composerWindow.selectedPartIndex
                    && part.imageSource && part.imageSource !== ""
                    && typeof part.adjustZoom === "function") {
                return part.adjustZoom(multiplier)
            }
        }

        return fallbackPart ? fallbackPart.adjustZoom(multiplier) : false
    }

    function moveSelectedPart(deltaX, deltaY) {
        const parts = rootItem && rootItem.activeParts ? rootItem.activeParts() : []
        let fallbackPart = null

        for (let i = 0; i < parts.length; ++i) {
            const part = parts[i]
            if (!fallbackPart && part && typeof part.moveImage === "function" && part.imageSource && part.imageSource !== "")
                fallbackPart = part

            if (part && part.index === composerWindow.selectedPartIndex
                    && part.imageSource && part.imageSource !== ""
                    && typeof part.moveImage === "function") {
                return part.moveImage(deltaX, deltaY)
            }
        }

        return fallbackPart ? fallbackPart.moveImage(deltaX, deltaY) : false
    }

    Shortcut {
        sequence: "Ctrl+Up"
        context: Qt.ApplicationShortcut
        onActivated: composerWindow.zoomSelectedPart(composerWindow.keyboardZoomInFactor)
    }

    Shortcut {
        sequence: "Ctrl+V"
        context: Qt.ApplicationShortcut
        onActivated: composerWindow.pasteImageFromClipboard()
    }

    Shortcut {
        sequence: "Ctrl+Down"
        context: Qt.ApplicationShortcut
        onActivated: composerWindow.zoomSelectedPart(composerWindow.keyboardZoomOutFactor)
    }

    Shortcut {
        sequence: "Left"
        context: Qt.WindowShortcut
        onActivated: composerWindow.moveSelectedPart(-composerWindow.keyboardMoveStep, 0)
    }

    Shortcut {
        sequence: "Right"
        context: Qt.WindowShortcut
        onActivated: composerWindow.moveSelectedPart(composerWindow.keyboardMoveStep, 0)
    }

    Shortcut {
        sequence: "Up"
        context: Qt.WindowShortcut
        onActivated: composerWindow.moveSelectedPart(0, -composerWindow.keyboardMoveStep)
    }

    Shortcut {
        sequence: "Down"
        context: Qt.WindowShortcut
        onActivated: composerWindow.moveSelectedPart(0, composerWindow.keyboardMoveStep)
    }

    // Eigene minimalistische Titelzeile
    Rectangle {
        id: titleBar
        width: parent.width
        height: 32
        color: "#d6d6d6"
        border.color: "#bbb"
        border.width: 1

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            text: composerWindow.title
            color: "#222"
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.OpenHandCursor
            onPressed: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    composerWindow.startSystemMove()
                }
            }
        }
    }
    // Geometrie zurückschreiben + Outline neu berechnen
    onWidthChanged: {
        composerState.w = width
        rootItem.recomputeOutline()
    }
    onHeightChanged: {
        composerState.h = height
        rootItem.recomputeOutline()
    }

    // b) Wenn der Anzeigestatus wechselt
    Connections {
        target: composerWindow
        function onAnzeigeZustandChanged() { rootItem.recomputeOutline() }
    }

    // c) Auf Frame-Events aller (potenziellen) Parts hören
    //    -> für singlePartView:
    Connections {
        target: singlePartView
        ignoreUnknownSignals: true
        function onFrameReadyChanged() { rootItem.recomputeOutline() }
        function onFrameGeometryChanged() { rootItem.recomputeOutline() }
    }
    //    -> für TwoPanel-Parts (sobald vorhanden)
    Connections {
        target: twoSplitter.part1   // braucht property alias part1 in TwoPanel
        ignoreUnknownSignals: true
        function onFrameReadyChanged()    { rootItem.recomputeOutline() }
        function onFrameGeometryChanged() { rootItem.recomputeOutline() }
    }
    Connections {
        target: twoSplitter.part2
        ignoreUnknownSignals: true
        function onFrameReadyChanged()    { rootItem.recomputeOutline() }
        function onFrameGeometryChanged() { rootItem.recomputeOutline() }
    }

    //    -> für ThreePanel ähnlich
    // direkt auf die 3 Parts connecten
    Connections {
        target: threeSplitter.part1
        ignoreUnknownSignals: true
        function onFrameReadyChanged()    { rootItem.recomputeOutline() }
        function onFrameGeometryChanged() { rootItem.recomputeOutline() }
    }
    Connections {
        target: threeSplitter.part2
        ignoreUnknownSignals: true
        function onFrameReadyChanged()    { rootItem.recomputeOutline() }
        function onFrameGeometryChanged() { rootItem.recomputeOutline() }
    }
    Connections {
        target: threeSplitter.part3
        ignoreUnknownSignals: true
        function onFrameReadyChanged()    { rootItem.recomputeOutline() }
        function onFrameGeometryChanged() { rootItem.recomputeOutline() }
    }

    // d) Nach dem Laden der Panels die Verbindungen zu deren Parts setzen
    Timer {
        interval: 0; running: true; repeat: true
        onTriggered: {
            // sobald Panels existieren und getParts liefern, deren Signale verbinden
            function hook(parts) {
                for (let i = 0; i < parts.length; ++i) {
                    const p = parts[i]
                    if (!p._outlineHooked) {
                        p._outlineHooked = true
                        p.frameReadyChanged.connect(rootItem.recomputeOutline)
                        p.frameGeometryChanged.connect(rootItem.recomputeOutline)
                    }
                }
            }
            if (twoSplitter.getParts) hook(twoSplitter.getParts())
            if (threeSplitter.getParts) hook(threeSplitter.getParts())
            rootItem.recomputeOutline()
            // Timer kann gestoppt werden, wenn alles einmal „verdrahtet“ ist:
            if (singlePartView && twoSplitter.getParts && threeSplitter.getParts)
                running = false
        }
    }
    //end

    // Sichtbarkeit an Hauptfenster-Zustand binden
    Connections {
        target: parentWindow
        function onVisibilityChanged() {
            if (parentWindow.visibility === Window.Minimized) {
                composerWindow.visible = false
            } else {
                composerWindow.visible = true
            }
        }
    }

    // Immer über dem Hauptfenster bleiben ohne Fokus zu stehlen
    Connections {
        target: parentWindow
        function onActiveChanged() {
            if (parentWindow.active) {
                // Bringt das Fenster nach vorne ohne Fokus zu stehlen
                composerWindow.raise()
            }
        }
    }

    Menu {
        id: customContextMenu
        property var dynamicItems: []
        property var custLength
        width: custLength
    }

    Component {
        id: dynamicMenuItem
        MenuItem { }
    }

    MouseArea {
        id: dragArea
        anchors.top: parent.top
        width: parent.width
        height: 40   // Höhe der "Titelleiste", die du greifen kannst
        drag.target: null
        acceptedButtons: Qt.LeftButton
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                composerWindow.startSystemMove();
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.RightButton

        // Helper: prüfen, ob alle sichtbaren Parts ready sind
        function allVisibleImagesReady() {
            if (!rootItem || !rootItem.activeParts) return false
            const parts = rootItem.activeParts()
            if (!parts.length) return false
            for (let i = 0; i < parts.length; ++i) {
                const p = parts[i]
                if (!p || typeof p.frameRectIn !== "function") return false
                const r = p.frameRectIn(rootItem)
                if (!r.ready) return false
            }
            return true
        }

        onPressed: (mouse) => {
            if (mouse.button !== Qt.RightButton) return

            const selectedHasTransparency = composerWindow.selectedImageHasTransparency()
            const transparencyMenuText = selectedHasTransparency
                                         ? "Transparenz aus"
                                         : "Hintergrund transparent"

            // 1) alte dynamische Items entsorgen
            if (customContextMenu.dynamicItems && customContextMenu.dynamicItems.length) {
                for (let i = 0; i < customContextMenu.dynamicItems.length; ++i) {
                    customContextMenu.dynamicItems[i].destroy()
                }
            }
            customContextMenu.dynamicItems = []

            // 2) Texte für normale Layout-Einträge
            let texts = ["Aus Zwischenablage einfügen", transparencyMenuText]
            if (anzeigeZustand === 2) {
                texts.push("Zweiteilung Vertikal")
                texts.push("Zweiteilung Horizontal")
            } else if (anzeigeZustand === 3) {
                texts.push("Dreiteilung Vertikal")
                texts.push("Dreiteilung Horizontal")
                texts.push("Dreiteilung: 2 Oben, 1 Unten")
                texts.push("Dreiteilung: 1 Unten, 2 Oben")
            }

            // 3) Breite berechnen
            let maxTextWidth = 0
            for (let y = 0; y < texts.length; ++y) {
                const w = menuFont.boundingRect(texts[y]).width
                if (w > maxTextWidth) maxTextWidth = w
            }
            customContextMenu.custLength = maxTextWidth + 20

            // 4) Hilfsfunktion zum Erzeugen von Items
            function addMenuItem(text, handler, enabled) {
                const item = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "' + text.replace(/"/g, '\\"') + '" }',
                                                customContextMenu)
                if (enabled !== undefined)
                    item.enabled = enabled
                if (handler) item.onTriggered.connect(handler)
                customContextMenu.addItem(item)
                customContextMenu.dynamicItems.push(item)
                return item
            }
            function addSeparator() {
                const sep = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuSeparator { }', customContextMenu)
                customContextMenu.addItem(sep)
                customContextMenu.dynamicItems.push(sep)
                return sep
            }

            // 5) Bildfunktionen
            addMenuItem("Aus Zwischenablage einfügen",
                        () => composerWindow.pasteImageFromClipboard(),
                        FileHelper.clipboardHasImage())
            addMenuItem(transparencyMenuText,
                        selectedHasTransparency
                            ? () => composerWindow.disableSelectedImageTransparency()
                            : () => composerWindow.startTransparentBackgroundPick(),
                        selectedHasTransparency || composerWindow.anyPartHasImage())

            if (anzeigeZustand === 2 || anzeigeZustand === 3)
                addSeparator()

            // 6) Normale Einträge gemäß Zustand
            if (anzeigeZustand === 2) {
                addMenuItem("Zweiteilung Vertikal", () => { isVertical = true })
                addMenuItem("Zweiteilung Horizontal", () => { isVertical = false })
            } else if (anzeigeZustand === 3) {
                addMenuItem("Dreiteilung Vertikal", () => { layoutMode = 0; isVertical = true })
                addMenuItem("Dreiteilung Horizontal", () => { layoutMode = 0; isVertical = false })
                addMenuItem("Dreiteilung: 2 Oben, 1 Unten", () => { layoutMode = 1 })
                addMenuItem("Dreiteilung: 1 Unten, 2 Oben", () => { layoutMode = 2 })
            }

            // 7) Menü anzeigen
            customContextMenu.x = mouse.x
            customContextMenu.y = mouse.y
            customContextMenu.open()
        }
    }

    function composeImages(doneCallback) {
        function notifyDone(success, fileName) {
            if (doneCallback)
                doneCallback(success, fileName)
        }

        composeGen++
        const myGen = composeGen

        if (lastComposeStage) {
            try {
                lastComposeStage.destroy()
            } catch (e) {
            }
            lastComposeStage = null
        }

        const parts = rootItem.activeParts ? rootItem.activeParts() : []

        if (!parts.length) {
            console.warn("Keine Parts")
            notifyDone(false, "")
            return
        }

        let minX = Infinity
        let minY = Infinity
        let maxX = -Infinity
        let maxY = -Infinity

        const entries = []

        for (let i = 0; i < parts.length; i++) {
            const p = parts[i]

            if (!p || typeof p.frameRectIn !== "function") {
                console.warn("Part ohne frameRectIn")
                notifyDone(false, "")
                return
            }

            const r = p.frameRectIn(rootItem)

            if (!r.ready || !r.visible) {
                console.warn("Nicht alle Bilder geladen")
                notifyDone(false, "")
                return
            }

            minX = Math.min(minX, r.x)
            minY = Math.min(minY, r.y)
            maxX = Math.max(maxX, r.x + r.w)
            maxY = Math.max(maxY, r.y + r.h)

            entries.push({
                url: p.imageSource || "",
                rect: r
            })
        }

        if (!isFinite(minX) ||
            !isFinite(minY) ||
            !isFinite(maxX) ||
            !isFinite(maxY)) {

            console.warn("Union ungültig")
            notifyDone(false, "")
            return
        }

        const targetW = Math.round(maxX - minX)
        const topMargin = 5
        const targetH = Math.round(maxY - minY) + topMargin

        if (targetW <= 0 || targetH <= 0) {
            console.warn("Ungültige Zielgröße")
            notifyDone(false, "")
            return
        }

        const stage = Qt.createQmlObject(
            'import QtQuick 2.15; Item { visible: false; layer.enabled: true }',
            rootItem
        )

        stage.width = targetW
        stage.height = targetH

        lastComposeStage = stage

        let need = 0
        let ready = 0
        let finalized = false

        function finalizeOnce() {
            if (finalized)
                return

            finalized = true

            if (myGen !== composeGen) {
                try {
                    stage.destroy()
                } catch (e) {
                }
                return
            }

            Qt.callLater(function() {

                const tick = Qt.createQmlObject(
                    'import QtQuick 2.15; Timer { interval: 0; running: true }',
                    stage
                )

                tick.triggered.connect(function() {

                    if (myGen !== composeGen) {
                        try {
                            stage.destroy()
                        } catch (e) {
                        }
                        return
                    }

                    const fileName =
                            (packagePath && packagePath.length)
                            ? packagePath + "/" + subjektName + ".png"
                            : subjektName + ".png"

                    stage.grabToImage(function(res) {

                        const savedWidth = stage.width
                        const savedHeight = stage.height

                        try {
                            stage.destroy()
                        } catch (e) {
                        }

                        if (myGen !== composeGen)
                            return

                        if (!res || !res.saveToFile(fileName)) {
                            console.warn("Speichern fehlgeschlagen")
                            notifyDone(false, "")
                        } else {

                            console.log(
                                "Compose gespeichert:",
                                savedWidth,
                                "x",
                                savedHeight
                            )

                            if (packagePath && packagePath.length)
                                FileHelper.removeTMPFiles(packagePath)

                            notifyDone(true, fileName)
                        }

                    }, Qt.size(targetW, targetH))
                })
            })
        }

        const deadlineTimer = Qt.createQmlObject(
            'import QtQuick 2.15; Timer { interval: 6000; running: true; repeat: false }',
            stage
        )

        deadlineTimer.triggered.connect(function() {

            if (myGen !== composeGen)
                return

            console.warn("Compose Timeout")

            finalizeOnce()
        })

        for (let i = 0; i < entries.length; i++) {

            const e = entries[i]

            if (!e.url)
                continue

            need++

            const dx = Math.round(e.rect.x - minX)
            const dy = Math.round(e.rect.y - minY) + topMargin
            const dw = Math.round(e.rect.w)
            const dh = Math.round(e.rect.h)

            const img = Qt.createQmlObject(
                'import QtQuick 2.15; Image {' +
                'asynchronous:false;' +
                'cache:false;' +
                'smooth:true;' +
                'mipmap:true;' +
                'fillMode: Image.Stretch;' +
                'visible:true;' +
                '}',
                stage
            )

            img.x = dx
            img.y = dy
            img.width = dw
            img.height = dh

            img.sourceSize = Qt.size(dw, dh)
            img.source = e.url

            function onStatus() {

                if (myGen !== composeGen)
                    return

                if (img.status === Image.Ready ||
                    img.status === Image.Error) {

                    ready++

                    if (ready >= need)
                        finalizeOnce()
                }
            }

            if (img.status === Image.Ready ||
                img.status === Image.Error) {

                onStatus()
            } else {
                img.statusChanged.connect(onStatus)
            }
        }

        if (need === 0) {

            try {
                stage.destroy()
            } catch (e) {
            }

            notifyDone(false, "")
        }
    }

    // Inhalt unterhalb der Titelzeile
    Rectangle {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        color: "#f0f0f0"
        border.color: "#999"
        border.width: 1

        Rectangle {
            id: rootItem
            anchors.fill: parent
            color: "#f0f0f0"
            border.color: "#999"
            border.width: 1
            clip: false   // ⬅️ Wichtig! Damit Ränder sichtbar bleiben

            // ---- Overlay-Geometrie ----
            property real outlineX: 0
            property real outlineY: 0
            property real outlineW: 0
            property real outlineH: 0
            property bool outlineVisible: false

            focus: true
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Tab) {
                    selectNextPart(+1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    // Qt sendet bei Shift+Tab meist Key_Backtab – das OR deckt beide Fälle ab
                    selectNextPart(-1);
                    event.accepted = true;
                } else if ((event.modifiers & Qt.ControlModifier)
                           && (event.key === Qt.Key_Up || event.key === Qt.Key_Down)) {
                    const parts = activeParts()
                    let activePart = null

                    for (let i = 0; i < parts.length; ++i) {
                        if (parts[i] && parts[i].index === composerWindow.selectedPartIndex) {
                            activePart = parts[i]
                            break
                        }
                    }

                    if (activePart && typeof activePart.adjustZoom === "function") {
                        activePart.adjustZoom(event.key === Qt.Key_Up
                                              ? composerWindow.keyboardZoomInFactor
                                              : composerWindow.keyboardZoomOutFactor)
                        event.accepted = true;
                    }
                }
            }

            // Offscreen-Compositing-Stage
            Item {
                id: composeStage
                visible: false       // kein Onscreen-Render
                width: 1; height: 1  // wird dynamisch gesetzt
                layer.enabled: true  // sichert sauberes Rendern
            }

            // Helfer: gibt das aktive PartView-Array zurück
            function activeParts() {
                if (anzeigeZustand === 1) return [singlePartView]
                if (anzeigeZustand === 2) return twoSplitter.getParts ? twoSplitter.getParts() : []
                if (anzeigeZustand === 3) return threeSplitter.getParts ? threeSplitter.getParts() : []
                return []
            }

            // Bounding-Box neu berechnen
            function recomputeOutline() {
                console.log("DBG parts:", activeParts().length)
                const parts = activeParts()
                if (!parts.length) {
                    outlineVisible = false
                    outlineX = outlineY = outlineW = outlineH = 0
                    return
                }

                let allReady = true
                let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity

                for (let i = 0; i < parts.length; ++i) {
                    if (!parts[i] || typeof parts[i].frameRectIn !== "function") { allReady = false; break }
                    const r = parts[i].frameRectIn(rootItem)
                    if (!r.ready || !r.visible) { allReady = false; break }
                    minX = Math.min(minX, r.x)
                    minY = Math.min(minY, r.y)
                    maxX = Math.max(maxX, r.x + r.w)
                    maxY = Math.max(maxY, r.y + r.h)
                    console.log("DBG r:", JSON.stringify(r))
                }

                if (!allReady || !isFinite(minX)) {
                    outlineVisible = false
                    outlineX = outlineY = outlineW = outlineH = 0
                    return
                }

                outlineVisible = true
                outlineX = minX
                outlineY = minY
                outlineW = Math.max(0, maxX - minX)
                outlineH = Math.max(0, maxY - minY)
            }

            // ---- Das gestrichelte Overlay ----
            Shape {
                id: outlineShape
                visible: rootItem.outlineVisible
                x: rootItem.outlineX
                y: rootItem.outlineY
                width: rootItem.outlineW
                height: rootItem.outlineH
                z: 9999

                ShapePath {
                    strokeWidth: 4             // "etwas dicker"
                    strokeColor: "#444"
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [8, 6]        // gestrichelt
                    fillColor: "transparent"
                    startX: 0; startY: 0
                    PathLine { x: outlineShape.width;  y: 0 }
                    PathLine { x: outlineShape.width;  y: outlineShape.height }
                    PathLine { x: 0;                  y: outlineShape.height }
                    PathLine { x: 0;                  y: 0 }
                }
            }

            // ===================== EINZEL VIEW =====================
            PartView {
                id: singlePartView
                anchors.fill: parent
                visible: anzeigeZustand === 1
                index: 1
                selected: true
                transparentColorPickMode: composerWindow.transparentColorPickMode
                label: "Teil 1"

                onClicked: (index) => composerWindow.handlePartClicked(index)
                onTransparentColorPicked: (index, imageSource, imageX, imageY) => composerWindow.handleTransparentColorPicked(index, imageSource, imageX, imageY)
                onTransparentColorPickCanceled: composerWindow.cancelTransparentBackgroundPick()
            }
            // ===================== ZWEITEILUNG =====================
            TwoPanel {
                id: twoSplitter
                visible: anzeigeZustand === 2
                anchors.fill: parent

                isVertical: composerWindow.isVertical
                splitterRatio: composerWindow.splitterRatio
                selectedPartIndex: composerWindow.selectedPartIndex
                transparentColorPickMode: composerWindow.transparentColorPickMode

                onPartClicked: (index) => composerWindow.handlePartClicked(index)
                onTransparentColorPicked: (index, imageSource, imageX, imageY) => composerWindow.handleTransparentColorPicked(index, imageSource, imageX, imageY)
                onTransparentColorPickCanceled: composerWindow.cancelTransparentBackgroundPick()
                onSplitterRatioChanged: composerWindow.splitterRatio = splitterRatio
            }
            ThreePanel {
                id: threeSplitter
                visible: anzeigeZustand === 3
                anchors.fill: parent

                layoutMode: composerWindow.layoutMode
                isVertical: composerWindow.isVertical
                splitterRatio1: composerWindow.splitterRatio1
                splitterRatio2: composerWindow.splitterRatio2
                layout1_splitX: composerWindow.layout1_splitX
                layout1_splitY: composerWindow.layout1_splitY
                layout2_splitX: composerWindow.layout2_splitX
                layout2_splitY: composerWindow.layout2_splitY
                selectedPartIndex: composerWindow.selectedPartIndex
                transparentColorPickMode: composerWindow.transparentColorPickMode

                onPartClicked: (index) => composerWindow.handlePartClicked(index)
                onTransparentColorPicked: (index, imageSource, imageX, imageY) => composerWindow.handleTransparentColorPicked(index, imageSource, imageX, imageY)
                onTransparentColorPickCanceled: composerWindow.cancelTransparentBackgroundPick()
                onSplitterRatio1Changed: composerWindow.splitterRatio1 = splitterRatio1
                onSplitterRatio2Changed: composerWindow.splitterRatio2 = splitterRatio2
                onLayout1_splitXChanged: composerWindow.layout1_splitX = layout1_splitX
                onLayout1_splitYChanged: composerWindow.layout1_splitY = layout1_splitY
                onLayout2_splitXChanged: composerWindow.layout2_splitX = layout2_splitX
                onLayout2_splitYChanged: composerWindow.layout2_splitY = layout2_splitY
            }

            // Flackerfreier rechter Rand (systemeigenes Resizing)
            Repeater {
                model: resizeConfigHelper.edgeConfigs.length
                delegate: MouseArea {
                    property var conf: resizeConfigHelper.edgeConfigs[index]
                    width: conf.w > 0 ? conf.w : parent.width
                    height: conf.h > 0 ? conf.h : parent.height
                    cursorShape: conf.cursor

                    anchors {
                        top: conf.pos.indexOf("top") !== -1 ? parent.top : undefined
                        bottom: conf.pos.indexOf("bottom") !== -1 ? parent.bottom : undefined
                        left: conf.pos.indexOf("left") !== -1 ? parent.left : undefined
                        right: conf.pos.indexOf("right") !== -1 ? parent.right : undefined
                    }

                    onPressed: (mouse) => {
                        if (mouse.button === Qt.LeftButton) composerWindow.startSystemResize(conf.edge)
                    }
                }
            }
        }
    }
}
