import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.9
import QtCore

import Helpers 1.0
import FileHelper 1.0
import RectKeyFilter 1.0

import Wiki 1.0  // Dein C++ Modul

Window {
    id: urlWindow

    // Persistenz für URL-Dialog
    Settings {
        id: urlState
        category: "URLComponentProcessing"
        property int  x: 100
        property int  y: 100
        property int  w: 800
        property int  h: 600
        property real zoom: 1.0
        property int  scrollX: 0     // ✅ NEU
        property int  scrollY: 0
        property int  imageComposerParts: 1
    }

    function clampToDesktop(win) {
        const dw = Screen.desktopAvailableWidth
        const dh = Screen.desktopAvailableHeight
        win.width  = Math.min(win.width,  dw)
        win.height = Math.min(win.height, dh)
        win.x = Math.max(0, Math.min(win.x, dw - win.width))
        win.y = Math.max(0, Math.min(win.y, dh - win.height))
    }

    Timer {
        id: scrollPoll
        interval: 400
        repeat: true
        running: true
        onTriggered: {
            if (!pageReady) return;
            webView.runJavaScript(
                "(function(){return {x: window.scrollX||document.documentElement.scrollLeft||0," +
                "y: window.scrollY||document.documentElement.scrollTop||0};})()",
                function(r) {
                    if (!r) return;
                    urlState.scrollX = r.x|0;
                    urlState.scrollY = r.y|0;
                }
            )
        }
    }

    // Geometrie in Settings zurückschreiben
    onXChanged:      urlState.x = x
    onYChanged:      urlState.y = y
    onWidthChanged:  urlState.w = width
    onHeightChanged: urlState.h = height

    title: "Webseite ansehen"
    width: 800
    height: 600
    modality: Qt.ApplicationModal
    visible: true

    property bool isMultiEdit: false
    property int multiEditCurrentIndex: -1
    property int multiEditCount: 0
    property bool isLastStep:false

    property string urlString: ""
    property string subjektName: ""
    property string packagePath: ""

    signal accepted(string newUrl, var licenceInfo, string savedFileExtension)
    signal continueRequested()
    signal rejected()

    property var dynamicMenu
    property var lastContextMenuPosition
    property var lastContextImageRect: null
    property string lastContextBackgroundColor: ""
    property bool pageReady: false
    property var pendingTransparentColorRect: null
    property point pendingTransparentColorPoint: Qt.point(0, 0)

    property string tempImagePath: ""
    property string finalImagePath: ""
    property bool imageAvailable: false

    property var currentImageLicenceInfo: null
    property string licenceFetchMode: ""  // z.B. "bildLaden" oder "rechteck"

    property var composer: null  // ❗ Füge das hinzu, falls noch nicht vorhanden
    property var activeRectangle: null
    property bool debugRectangleKeys: false

    onActiveRectangleChanged: {
        if (debugRectangleKeys)
            console.log("[URLComponent][rectKeys] activeRectangle changed", activeRectangle)
        RectKeyFilter.enabled = activeRectangle !== null
        focusRectangleKeyCatcher()
    }

    Connections {
        target: RectKeyFilter
        function onArrowKeyPressed(key, modifiers) {
            if (urlWindow.debugRectangleKeys)
                console.log("[URLComponent][rectKeys] eventFilter arrow",
                            "key=", key,
                            "mods=", modifiers)
            urlWindow.handleActiveRectangleKey(key, modifiers)
        }
    }

    function focusRectangleKeyCatcher() {
        if (!activeRectangle)
            return

        Qt.callLater(function() {
            if (activeRectangle) {
                if (debugRectangleKeys)
                    console.log("[URLComponent][rectKeys] focus activeRectangle")
                activeRectangle.forceActiveFocus()
            }
        })
    }

    function handleActiveRectangleKey(key, modifiers) {
        if (!activeRectangle) {
            if (debugRectangleKeys)
                console.log("[URLComponent][rectKeys] no activeRectangle", "key=", key, "mods=", modifiers)
            return
        }

        const rect = activeRectangle
        const step = (modifiers & Qt.ControlModifier) ? 10 : 1
        const leftKey = key === Qt.Key_Left
        const rightKey = key === Qt.Key_Right
        const upKey = key === Qt.Key_Up
        const downKey = key === Qt.Key_Down

        if (debugRectangleKeys)
            console.log("[URLComponent][rectKeys] shortcut",
                        "key=", key,
                        "mods=", modifiers,
                        "step=", step,
                        "before=", rect.x, rect.y, rect.width, rect.height)

        if (modifiers & Qt.ShiftModifier) {
            if (leftKey)
                rect.width = Math.max(rect.minRectSize, rect.width - step)
            else if (rightKey)
                rect.width = Math.max(rect.minRectSize, rect.width + step)
            else if (upKey)
                rect.height = Math.max(rect.minRectSize, rect.height - step)
            else if (downKey)
                rect.height = Math.max(rect.minRectSize, rect.height + step)
        } else {
            if (leftKey)
                rect.x -= step
            else if (rightKey)
                rect.x += step
            else if (upKey)
                rect.y -= step
            else if (downKey)
                rect.y += step
        }

        focusRectangleKeyCatcher()

        if (debugRectangleKeys)
            console.log("[URLComponent][rectKeys] after=", rect.x, rect.y, rect.width, rect.height)
    }

    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Left";        onActivated: handleActiveRectangleKey(Qt.Key_Left,  Qt.NoModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Right";       onActivated: handleActiveRectangleKey(Qt.Key_Right, Qt.NoModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Up";          onActivated: handleActiveRectangleKey(Qt.Key_Up,    Qt.NoModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Down";        onActivated: handleActiveRectangleKey(Qt.Key_Down,  Qt.NoModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Ctrl+Left";   onActivated: handleActiveRectangleKey(Qt.Key_Left,  Qt.ControlModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Ctrl+Right";  onActivated: handleActiveRectangleKey(Qt.Key_Right, Qt.ControlModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Ctrl+Up";     onActivated: handleActiveRectangleKey(Qt.Key_Up,    Qt.ControlModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Ctrl+Down";   onActivated: handleActiveRectangleKey(Qt.Key_Down,  Qt.ControlModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Shift+Left";  onActivated: handleActiveRectangleKey(Qt.Key_Left,  Qt.ShiftModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Shift+Right"; onActivated: handleActiveRectangleKey(Qt.Key_Right, Qt.ShiftModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Shift+Up";    onActivated: handleActiveRectangleKey(Qt.Key_Up,    Qt.ShiftModifier) }
    Shortcut { enabled: urlWindow.visible && activeRectangle !== null; context: Qt.ApplicationShortcut; autoRepeat: true; sequence: "Shift+Down";  onActivated: handleActiveRectangleKey(Qt.Key_Down,  Qt.ShiftModifier) }

    Component.onCompleted: {
        const composerComponent = Qt.createComponent("qrc:/MemoryPackagesBuilder/ImageComposer.qml");

        // Geometrie wiederherstellen
        urlWindow.x = urlState.x
        urlWindow.y = urlState.y
        urlWindow.width  = urlState.w
        urlWindow.height = urlState.h
        clampToDesktop(urlWindow)
        // Zoom wiederherstellen
        zoomSlider.value = urlState.zoom

        if (composerComponent.status === Component.Ready) {
            const w = urlWindow.height ;
            const h = urlWindow.height;

            const x = urlWindow.x + urlWindow.width + 10 ;
            const y = urlWindow.y

            const composer = composerComponent.createObject(null, {
                packagePath: urlWindow.packagePath,
                subjektName: urlWindow.subjektName
            });

            if (composer) {
                urlWindow.composer = composer;
                composer.parentWindow = urlWindow

                composer.width = w;
                composer.height = h;
                composer.x = x;
                composer.y = y;

                composer.transientParent = urlWindow;

                if (urlState.imageComposerParts >= 1 &&
                    urlState.imageComposerParts <= 3) {
                    composer.anzeigeZustand = urlState.imageComposerParts;
                }

                syncPartsChecks();

                composer.visible = true;
                composer.raise();
                composer.requestActivate();
            } else {
                console.warn("❌ Fehler beim Laden von ImageComposer:", composerComponent.errorString());
            }

        } else {
            console.warn("❌ Fehler beim Laden von ImageComposer:", composerComponent.errorString());
        }
    }

    Connections {
        target: composer
        function onAnzeigeZustandChanged() { syncPartsChecks() }
        function onContentChanged() {
            imageAvailable = true;
            saveButton.enabled = true;
        }
    }

    // Kindfenster schließen, wenn Hauptfenster geschlossen wird
    Connections {
        target: urlWindow
        function onClosing(close) {
            RectKeyFilter.enabled = false
            if (composer) {
                // Diese Kombination schließt das Tool-Fenster zuverlässig
                composer.destroy()
                composer = null
            }
            close.accepted = true
        }
    }

    function cleanupTempFile() {
        FileHelper.removeTMPFiles(packagePath);
    }

    function resizeActiveRectangleToPoint(pointX, pointY) {
        if (!activeRectangle)
            return false;

        focusRectangleKeyCatcher();
        activeRectangle.width = Math.max(activeRectangle.minRectSize, pointX - activeRectangle.x);
        activeRectangle.height = Math.max(activeRectangle.minRectSize, pointY - activeRectangle.y);
        return true;
    }

    // Wartet einen Render-Tick, nachdem 'rect' ausgeblendet wurde, und grabbt dann.
    function grabAreaWithoutOverlay(rect, savePath, transparentBg) {
        // Koordinaten sichern (da 'rect' gleich zerstört wird)
        const rx = rect.x, ry = rect.y, rw = rect.width, rh = rect.height;
        const transparentColor = transparentBg ? String(rect.transparentColor) : "";

        if (rect.cancelTransparentPreview)
            rect.cancelTransparentPreview();
        rect.visible = false;
        urlWindow.requestUpdate();  // ⬅️ sorgt für Redraw ohne das Rechteck

        nextFrameTimer.callback = function() {
            imgDownloader.grabAndSaveCropped(urlWindow, rx, ry, rw, rh, savePath, transparentBg, transparentColor);
            rect.destroy();
        };

        nextFrameTimer.interval = 16;
        nextFrameTimer.start();
    }

    function updateTransparentPreview(rect) {
        if (!rect || !rect.transparentBackground || rect.pointerInteractionActive)
            return;

        const rx = rect.x, ry = rect.y, rw = rect.width, rh = rect.height;
        const transparentColor = String(rect.transparentColor);
        rect.visible = false;
        urlWindow.requestUpdate();

        nextFrameTimer.callback = function() {
            const preview = imgDownloader.grabTransparentPreview(
                                urlWindow, rx, ry, rw, rh, transparentColor,
                                rect.sourceImageRect.x, rect.sourceImageRect.y,
                                rect.sourceImageRect.width, rect.sourceImageRect.height);
            rect.applyTransparentPreview(preview);
            rect.visible = true;
            rect.forceActiveFocus();
        };
        nextFrameTimer.interval = 16;
        nextFrameTimer.start();
    }

    function startTransparentColorPick(rect) {
        pendingTransparentColorRect = rect;
    }

    function finishTransparentColorPick() {
        const rect = pendingTransparentColorRect;
        pendingTransparentColorRect = null;

        if (!rect)
            return;

        rect.visible = false;
        urlWindow.requestUpdate();

        nextFrameTimer.callback = function() {
            const color = imgDownloader.sampleWindowColor(urlWindow,
                                                          pendingTransparentColorPoint.x,
                                                          pendingTransparentColorPoint.y);
            rect.visible = true;
            if (color && color.length > 0) {
                rect.setTransparentColor(color);
                rect.forceActiveFocus();
            }
        };
        nextFrameTimer.interval = 16;
        nextFrameTimer.start();
    }

    Timer {
        id: nextFrameTimer
        interval: 16
        repeat: false
        property var callback: null
        onTriggered: { if (callback) callback(); callback = null }
    }

    function handleRechteckErzeugen(info, transparentBg, initialTransparentColor) {
        console.log("🟩 Rechteck erzeugen gewählt");

        // Menü vor dem Erzeugen schließen, damit es nicht im Screenshot landet
        if (urlWindow.dynamicMenu) {
            urlWindow.dynamicMenu.destroy();
            urlWindow.dynamicMenu = null;
        }
        if (info) currentImageLicenceInfo = info;

        const sourceRect = lastContextImageRect || { "x": -1, "y": -1, "width": 0, "height": 0 };
        const initialColor = initialTransparentColor ? String(initialTransparentColor) : "";
        const previewInitiallyEnabled = transparentBg && initialColor.length > 0;

        var rect = Qt.createQmlObject(`
            import QtQuick 2.15
            import QtQuick.Controls 2.15

            Rectangle {
                id: rectItem

                width: 100
                height: 100

                property bool transparentBackground: ${transparentBg}
                // Leer bedeutet: dominante, mit dem Rand verbundene
                // Hintergrundfarbe automatisch bestimmen. Eine mit der
                // Pipette gewaehlte Farbe ueberschreibt die Automatik.
                property string transparentColor: "${initialColor}"
                property string transparentPreviewSource: ""
                property bool componentReady: false
                property bool transparentColorLocked: ${initialColor.length > 0}
                property bool assigningDetectedColor: false
                property bool transparentPreviewEnabled: ${previewInitiallyEnabled}
                property bool pointerInteractionActive: false
                property rect sourceImageRect: Qt.rect(${sourceRect.x}, ${sourceRect.y}, ${sourceRect.width}, ${sourceRect.height})

                function applyTransparentPreview(preview) {
                    if (!preview)
                        return;
                    if (!transparentColorLocked && preview.backgroundColor) {
                        assigningDetectedColor = true;
                        transparentColor = String(preview.backgroundColor);
                        transparentColorLocked = true;
                        assigningDetectedColor = false;
                    }
                    transparentPreviewSource = preview.source ? String(preview.source) : "";
                }

                function setTransparentColor(color) {
                    assigningDetectedColor = true;
                    transparentColor = String(color);
                    transparentColorLocked = true;
                    assigningDetectedColor = false;
                    transparentPreviewEnabled = true;
                    scheduleTransparentPreview();
                }

                function enableTransparentPreview() {
                    transparentPreviewEnabled = true;
                    scheduleTransparentPreview();
                }

                function maybeEnableTransparentPreview() {
                    if (!componentReady || !transparentBackground || transparentPreviewEnabled
                            || sourceImageRect.width <= 0 || sourceImageRect.height <= 0)
                        return;
                    const margin = 2;
                    const outside = x < sourceImageRect.x - margin
                                 || y < sourceImageRect.y - margin
                                 || x + width > sourceImageRect.x + sourceImageRect.width + margin
                                 || y + height > sourceImageRect.y + sourceImageRect.height + margin;
                    if (outside) {
                        transparentPreviewEnabled = true;
                        scheduleTransparentPreview();
                    }
                }

                function scheduleTransparentPreview() {
                    if (!componentReady || !transparentBackground || !transparentPreviewEnabled)
                        return;
                    if (pointerInteractionActive) {
                        previewRefreshTimer.stop();
                        return;
                    }
                    transparentPreviewSource = "";
                    previewRefreshTimer.restart();
                }

                function cancelTransparentPreview() {
                    previewRefreshTimer.stop();
                }

                // Keine halbtransparente Überlagerung mehr.
                // Der Webseiteninhalt bleibt optisch unverändert.
                color: "transparent"

                x: ${lastContextMenuPosition.x}
                y: ${lastContextMenuPosition.y}

                border.color:
                    urlWindow.activeRectangle === rectItem
                    ? "blue"
                    : "black"

                border.width: 1

                focus: true
                Keys.priority: Keys.BeforeItem
                opacity: 1.0

                property int keyStep: 1
                property int minRectSize: 20

                onXChanged: {
                    if (urlWindow.debugRectangleKeys) console.log("[URLComponent][rectKeys] rectItem xChanged", x)
                    maybeEnableTransparentPreview()
                    scheduleTransparentPreview()
                }
                onYChanged: {
                    if (urlWindow.debugRectangleKeys) console.log("[URLComponent][rectKeys] rectItem yChanged", y)
                    maybeEnableTransparentPreview()
                    scheduleTransparentPreview()
                }
                onWidthChanged: {
                    if (urlWindow.debugRectangleKeys) console.log("[URLComponent][rectKeys] rectItem widthChanged", width)
                    maybeEnableTransparentPreview()
                    scheduleTransparentPreview()
                }
                onHeightChanged: {
                    if (urlWindow.debugRectangleKeys) console.log("[URLComponent][rectKeys] rectItem heightChanged", height)
                    maybeEnableTransparentPreview()
                    scheduleTransparentPreview()
                }
                onTransparentColorChanged: {
                    if (!assigningDetectedColor) {
                        transparentColorLocked = transparentColor.length > 0
                        scheduleTransparentPreview()
                    }
                }

                onActiveFocusChanged: if (activeFocus) urlWindow.activeRectangle = rectItem
                Component.onCompleted: {
                    componentReady = true
                    urlWindow.activeRectangle = rectItem
                    urlWindow.focusRectangleKeyCatcher()
                    scheduleTransparentPreview()
                }
                Component.onDestruction: {
                    if (urlWindow.activeRectangle === rectItem)
                        urlWindow.activeRectangle = null
                }

                Keys.onPressed: function(event) {
                    if (urlWindow.debugRectangleKeys)
                        console.log("[URLComponent][rectKeys] rectangle Keys.onPressed",
                                    "key=", event.key,
                                    "mods=", event.modifiers,
                                    "focus=", activeFocus)

                    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                        event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                        urlWindow.activeRectangle = rectItem
                        urlWindow.handleActiveRectangleKey(event.key, event.modifiers)
                        event.accepted = true;
                        return;
                    }
                }

                Timer {
                    id: previewRefreshTimer
                    interval: 180
                    repeat: false
                    onTriggered: {
                        if (!rectItem.pointerInteractionActive)
                            urlWindow.updateTransparentPreview(rectItem)
                    }
                }

                Canvas {
                    id: transparencyChecker
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: rectItem.transparentPreviewSource.length > 0

                    function repaint() { requestPaint() }
                    onWidthChanged: repaint()
                    onHeightChanged: repaint()
                    onVisibleChanged: if (visible) repaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        const size = 10
                        ctx.clearRect(0, 0, width, height)
                        for (let yy = 0; yy < height; yy += size) {
                            for (let xx = 0; xx < width; xx += size) {
                                ctx.fillStyle = ((xx / size + yy / size) % 2 === 0)
                                                ? "#d0d0d0" : "#f2f2f2"
                                ctx.fillRect(xx, yy, size, size)
                            }
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: rectItem.transparentPreviewSource
                    fillMode: Image.Stretch
                    cache: false
                    visible: source.toString().length > 0
                }

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    cursorShape: Qt.SizeAllCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onPressed: function(mouse) {
                        urlWindow.activeRectangle = parent;
                        urlWindow.focusRectangleKeyCatcher();
                        if (mouse.button === Qt.LeftButton) {
                            parent.pointerInteractionActive = true;
                            parent.cancelTransparentPreview();
                            parent.transparentPreviewSource = "";
                        }
                    }

                    onReleased: function(mouse) {
                        if (mouse.button === Qt.LeftButton) {
                            parent.pointerInteractionActive = false;
                            parent.scheduleTransparentPreview();
                        }
                    }

                    onCanceled: {
                        parent.pointerInteractionActive = false;
                        parent.scheduleTransparentPreview();
                    }

                    onClicked: function(mouse) {
                        urlWindow.activeRectangle = parent;
                        urlWindow.focusRectangleKeyCatcher();

                        if (mouse.button === Qt.RightButton) {
                            console.log("📌 Rechtsklick auf Rechteck");

                            if (urlWindow.dynamicMenu) {
                                urlWindow.dynamicMenu.destroy();
                            }

                            urlWindow.dynamicMenu = Qt.createQmlObject('import QtQuick.Controls 2.15; Menu {}', rectangleContainer);

                            var saveItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Bereich speichern" }', urlWindow.dynamicMenu);
                            saveItem.triggered.connect(function() {
                                var extension = "png";
                                var suffix = "_TEMP";
                                if (composer && composer.anzeigeZustand > 1)
                                    suffix += composer.selectedPartIndex;

                                var tempName = subjektName + suffix + "." + extension;
                                var savePath = packagePath + "/" + tempName;

                                tempImagePath = savePath;
                                finalImagePath = savePath.replace("_TEMP.", ".");
                                imageAvailable = true;
                                saveButton.enabled = true;

                                console.log("💾 Bereich speichern als (temporär):", savePath);

                                // Bei Transparenz exakt die bereits sichtbare Vorschau speichern.
                                // Damit stimmen Alpha-Bereiche in Vorschau, Datei und Editor ueberein.
                                if (parent.transparentBackground
                                        && parent.transparentPreviewSource.length > 0) {
                                    parent.cancelTransparentPreview();
                                    if (imgDownloader.saveDataUrlImage(parent.transparentPreviewSource,
                                                                       savePath)) {
                                        parent.destroy();
                                    } else {
                                        grabAreaWithoutOverlay(parent, savePath, true);
                                    }
                                } else {
                                    // Ohne Vorschau den Bereich wie bisher direkt aufnehmen.
                                    grabAreaWithoutOverlay(parent, savePath, ${transparentBg});
                                }
                            });
                            urlWindow.dynamicMenu.addItem(saveItem);

                            if (parent.transparentBackground) {
                                var transparentColorItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Transparentfarbe ändern" }', urlWindow.dynamicMenu);
                                transparentColorItem.triggered.connect(function() {
                                    urlWindow.startTransparentColorPick(parent);
                                });
                                urlWindow.dynamicMenu.addItem(transparentColorItem);
                            }

                            var removeItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck entfernen" }', urlWindow.dynamicMenu);
                            removeItem.triggered.connect(function() {
                                console.log("🗑️ Rechteck entfernt");
                                if (urlWindow.activeRectangle === parent)
                                    urlWindow.activeRectangle = null;
                                parent.destroy();
                            });
                            urlWindow.dynamicMenu.addItem(removeItem);

                            var globalPoint = parent.mapToItem(rectangleContainer, mouse.x, mouse.y);
                            urlWindow.dynamicMenu.x = globalPoint.x;
                            urlWindow.dynamicMenu.y = globalPoint.y;
                            urlWindow.dynamicMenu.open();
                        }
                    }
                }

                MouseArea {
                    id: resizeHandle
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 20
                    height: 20
                    cursorShape: Qt.SizeFDiagCursor
                    acceptedButtons: Qt.LeftButton

                    onPressed: function(mouse) {
                        urlWindow.activeRectangle = parent;
                        urlWindow.focusRectangleKeyCatcher();
                        parent.pointerInteractionActive = true;
                        parent.cancelTransparentPreview();
                        parent.transparentPreviewSource = "";
                        dragXStart = mouse.x;
                        dragYStart = mouse.y;
                    }

                    onReleased: {
                        parent.pointerInteractionActive = false;
                        parent.scheduleTransparentPreview();
                    }

                    onCanceled: {
                        parent.pointerInteractionActive = false;
                        parent.scheduleTransparentPreview();
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                    }

                    property real dragXStart: 0
                    property real dragYStart: 0

                    onPositionChanged: function(mouse) {
                        var newWidth = Math.max(20, parent.width + mouse.x - dragXStart);
                        var newHeight = Math.max(20, parent.height + mouse.y - dragYStart);
                        parent.width = newWidth;
                        parent.height = newHeight;
                    }
                }

            }
        `, rectangleContainer);
    }

    function handleBildLaden(imageUrl) {
        console.log("📌 Bild-URL:", imageUrl);

        if (!imageUrl || imageUrl === "") {
            console.warn("⚠️ Leere Bild-URL");
            return;
        }
        currentImageLicenceInfo = null;
        if (isWikimediaImageUrl(imageUrl)) {
            var fileTitle = extractOriginalFileTitle(imageUrl);
            if (!fileTitle || fileTitle === "File:") {
                console.warn("❌ Kein gültiger Dateititel extrahiert.");
                return;
            }
            licenceFetchMode = "bildLaden";
            licenceFetcher.fetchLicenceInfo(fileTitle);

        } else {
            saveImageTemporarily(imageUrl);
        }
    }

    function handleErzeugeLizenzInfos(imageUrl) {
        console.log("📄 Lizenz-Infos erzeugen für:", imageUrl);

        if (!imageUrl || imageUrl === "") {
            console.warn("⚠️ Leere Bild-URL");
            return;
        }

        currentImageLicenceInfo = null;

        if (isWikimediaImageUrl(imageUrl)) {
            var fileTitle = extractOriginalFileTitle(imageUrl);
            if (!fileTitle || fileTitle === "File:") {
                console.warn("❌ Kein gültiger Dateititel extrahiert.");
                return;
            }

            licenceFetchMode = "lizenzInfo";
            licenceFetcher.fetchLicenceInfo(fileTitle);
        } else {
            console.warn("⚠️ Lizenz-Infos können aktuell nur für Wikimedia-Bilder erzeugt werden.");
        }
    }

    function handleRechteckMitBild(imageUrl, transparentBg) {
        console.log("🟩 Rechteck (mit Bild) gewählt für:", imageUrl);

        if (!imageUrl || imageUrl === "") {
            console.warn("⚠️ Leere Bild-URL");
            return;
        }

        currentImageLicenceInfo = null;

        if (isWikimediaImageUrl(imageUrl)) {
            var fileTitle = extractOriginalFileTitle(imageUrl);
            if (!fileTitle || fileTitle === "File:") {
                console.warn("❌ Kein gültiger Dateititel extrahiert.");
                return;
            }

            licenceFetchMode = transparentBg ? "rechteckTransp" : "rechteck";
            licenceFetcher.fetchLicenceInfo(fileTitle);
        } else {
            currentImageLicenceInfo = null;
            handleRechteckErzeugen(null, transparentBg);
        }
    }


    function isWikimediaImageUrl(imageUrl) {
        return /^https?:\/\/(upload|thumb)\.wikimedia\.org\//i.test(String(imageUrl));
    }

    function extractOriginalFileTitle(imageUrl) {
        // Query- und Fragmentteil gehoeren nicht zum Wikimedia-Dateinamen.
        var cleanUrl = String(imageUrl).split(/[?#]/)[0];
        var parts = cleanUrl.split('/');
        var fileName = parts[parts.length - 1];

        // Entferne Thumbnail-Prefix (z.B. 300px-)
        var match = fileName.match(/(?:\d+px-)?(.*)/);
        if (match && match[1]) {
            var cleaned = match[1];

            // Prüfen: Ist das ein SVG-Thumbnail? (z. B. FILENAME.svg.png)
            if (cleaned.endsWith('.svg.png') || cleaned.endsWith('.svg.jpg')) {
                // Bild stammt von SVG → extrahiere SVG-Dateiname
                cleaned = cleaned.replace(/\.png$/, "").replace(/\.jpg$/, "");
            }

            // Gib Dateinamen inkl. Endung zurück
            return "File:" + decodeURIComponent(cleaned);
        }

        // Fallback: falls keine Präfixe erkannt wurden
        return "File:" + decodeURIComponent(fileName);
    }

    function saveImageTemporarily(imageUrl) {
        if (!imageUrl || imageUrl === "") {
            console.warn("⚠️ Ungültige Bild-URL");
            return "";
        }

        var extension = imageUrl.split('.').pop().split(/\#|\?/)[0];
        if (!extension.match(/^[a-zA-Z0-9]+$/)) {
            extension = "jpg";  // Fallback
        }

        var suffix = "_TEMP";
        if (composer && composer.anzeigeZustand > 1) {
            suffix += composer.selectedPartIndex;
        }
        var filename = subjektName + suffix + "." + extension;
        var savePath = packagePath + "/" + filename;

        tempImagePath = savePath;
        finalImagePath = savePath.replace("_TEMP.", ".");

        console.log("💾 Temporäre Speicherung:", savePath);
        imgDownloader.downloadImage(imageUrl, savePath);

        return extension;  // ⬅️ GIBT Dateityp zurück
    }

    ImageDownloader {
        id: imgDownloader

        onDownloadSucceeded: function(filePath) {
            console.log("✅ Signal empfangen in QML:", filePath);
            handleDownloadSucceeded(filePath);
        }

        onDownloadFailed: function(filePath) {
            console.log("❌ Fehler beim Download:", filePath);
            handleDownloadFailed(filePath);
        }
    }

    LicenceInfoWiki {
        id: licenceFetcher
        thumbWidth: 500

        onInfoReady: function(info) {
            currentImageLicenceInfo = info;

            if (licenceFetchMode === "bildLaden") {
                var urlToLoad = info.thumbUrl && info.thumbUrl.length > 0
                              ? info.thumbUrl
                              : info.imageUrl; // Fallback: Originalgröße

                console.log("🌐 Lade Thumbnail/Original:", urlToLoad);
                saveImageTemporarily(urlToLoad);
                return;
            }

            if (licenceFetchMode === "rechteck") {
                handleRechteckErzeugen(info, false);
                return;
            }

            if (licenceFetchMode === "rechteckTransp") {
                handleRechteckErzeugen(info, true);
                return;
            }

            if (licenceFetchMode === "lizenzInfo") {
                console.log("✅ Lizenz-Infos erzeugt:", info.authorName, "-", info.licenceName);
                return;
            }

            console.warn("⚠️ Unbekannter licenceFetchMode:", licenceFetchMode);
        }

        onErrorOccurred: function(message) {
            console.warn("❌ Fehler beim Abrufen der Lizenzinfos:", message);
        }
    }


    function handleDownloadSucceeded(path) {
        tempImagePath = path;
        finalImagePath = path.replace("_TEMP", "");  // z.B. von foo_TEMP.png → foo.png
        imageAvailable = true;
        saveButton.enabled = true;
        if (composer && finalImagePath !== "") {
            composer.loadImageInCurrentMode(tempImagePath);
        }
        console.log("✅ Bild temporär gespeichert:", path);
    }

    function handleDownloadFailed(error) {
        console.warn("❌ Download fehlgeschlagen:", error);
    }

    // Helfer: Checkboxes an Composer-Status angleichen
    function syncPartsChecks() {
        if (!composer) return
        parts1.checked = composer.anzeigeZustand === 1
        parts2.checked = composer.anzeigeZustand === 2
        parts3.checked = composer.anzeigeZustand === 3
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            WebEngineView {
                id: webView
                anchors.fill: parent
                focus: urlWindow.activeRectangle === null

                property url expectedUrl

                Component.onCompleted: {
                    const fallback = "https://de.wikipedia.org";
                    const pageToLoad = (urlString && urlString.trim() !== "") ? urlString : fallback;
                    expectedUrl = pageToLoad;
                    webView.url = pageToLoad;
                    console.log("🌐 Lade Seite:", pageToLoad);
                }

                onLoadingChanged: function(request) {
                    if (request.status === 2 && request.isMainFrame) {
                        errorLabel.visible = true;
                        console.log("❌ Fehler beim Laden der Hauptseite:", request.url);
                        pageReady = false;
                    } else if (request.status === 1 && request.isMainFrame) {
                        // Zoom & Scrollposition nach Page-Load setzen
                        webView.zoomFactor = urlState.zoom
                        zoomSlider.value   = urlState.zoom
                        webView.runJavaScript("window.scrollTo(" + urlState.scrollX + "," + urlState.scrollY + ");")
                        errorLabel.visible = false;
                        console.log("✅ Seite geladen:", request.url);
                        pageReady = true;
                    }
                }

                onContextMenuRequested: function(request) {
                    request.accepted = true;

                    lastContextMenuPosition = { "x": request.position.x, "y": request.position.y };
                    lastContextImageRect = null;
                    lastContextBackgroundColor = imgDownloader.sampleWindowColor(
                                                    urlWindow,
                                                    request.position.x,
                                                    request.position.y);

                    var viewX = request.position.x / webView.zoomFactor;
                    var viewY = request.position.y / webView.zoomFactor;

                    var js = `
                        (function() {
                            var elem = document.elementFromPoint(${viewX}, ${viewY});
                            if (!elem) return "";
                            if (elem.tagName === "IMG") {
                                var rect = elem.getBoundingClientRect();
                                return {
                                    src: elem.currentSrc || elem.src,
                                    x: rect.left,
                                    y: rect.top,
                                    width: rect.width,
                                    height: rect.height
                                };
                            }
                            return "";
                        })();
                    `;

                    webView.runJavaScript(js, function(result) {
                        if (dynamicMenu) {
                            dynamicMenu.destroy();
                        }

                        dynamicMenu = Qt.createQmlObject('import QtQuick.Controls 2.15; Menu {}', urlWindow);
                        var hasItem = false;

                        if (result && result.src) {
                            lastContextImageRect = {
                                "x": result.x * webView.zoomFactor,
                                "y": result.y * webView.zoomFactor,
                                "width": result.width * webView.zoomFactor,
                                "height": result.height * webView.zoomFactor
                            };
                            var imgItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Bild laden" }', dynamicMenu);
                            imgItem.triggered.connect(function() {
                                handleBildLaden(result.src);
                            });
                            dynamicMenu.addItem(imgItem);

                            var licenceInfoItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Erzeuge Lizenz Infos" }', dynamicMenu);
                            licenceInfoItem.triggered.connect(function() {
                                handleErzeugeLizenzInfos(result.src);
                            });
                            dynamicMenu.addItem(licenceInfoItem);

                            var rectImageItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck erzeugen (mit Bild)" }', dynamicMenu);
                            rectImageItem.triggered.connect(function() {
                                handleRechteckMitBild(result.src);
                            });
                            dynamicMenu.addItem(rectImageItem);

                            var rectImageTranspItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck erzeugen (mit Bild) transp.Hg" }', dynamicMenu);
                            rectImageTranspItem.triggered.connect(function() {
                                handleRechteckMitBild(result.src, true);
                            });
                            dynamicMenu.addItem(rectImageTranspItem);

                            hasItem = true;
                        }

                        var rectItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck erzeugen" }', dynamicMenu);
                        rectItem.triggered.connect(function() {
                            lastContextImageRect = null;
                            handleRechteckErzeugen(null, false);
                        });
                        dynamicMenu.addItem(rectItem);

                        var rectTranspItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck erzeugen transp.Hg" }', dynamicMenu);
                        rectTranspItem.triggered.connect(function() {
                            lastContextImageRect = null;
                            handleRechteckErzeugen(null, true, lastContextBackgroundColor);
                        });
                        dynamicMenu.addItem(rectTranspItem);

                        hasItem = true;

                        if (hasItem) {
                            dynamicMenu.x = request.position.x;
                            dynamicMenu.y = request.position.y;
                            dynamicMenu.open();
                        }
                    });

                }
            }

            MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                preventStealing: false

                onPressed: function(mouse) {
                    const wantsResize = activeRectangle !== null
                                     && mouse.button === Qt.LeftButton
                                     && (mouse.modifiers & Qt.ControlModifier);
                    mouse.accepted = wantsResize;
                }

                onClicked: function(mouse) {
                    const wantsResize = activeRectangle !== null
                                     && mouse.button === Qt.LeftButton
                                     && (mouse.modifiers & Qt.ControlModifier);

                    if (wantsResize) {
                        resizeActiveRectangleToPoint(mouse.x, mouse.y);
                        mouse.accepted = true;
                        return;
                    }

                    mouse.accepted = false;
                }
            }
        }

        Label {
            id: errorLabel
            text: "❌ Seite nicht erreichbar oder ungültige URL"
            color: "red"
            visible: false
        }
        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#888" // oder z.B. "#888" für stärkeren Kontrast
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                spacing: 5

                Label {
                    text: "Zoom:"
                    Layout.preferredWidth: 40
                }

                Slider {
                    id: zoomSlider
                    from: 0.5
                    to: 3.0
                    value: 1.0
                    stepSize: 0.1
                    Layout.preferredWidth: 150
                    onValueChanged: {
                        webView.zoomFactor = value
                        urlState.zoom = value     // 👈 speichern
                        console.log("🔍 Zoomfaktor geändert:", value)
                    }
                }

                Label {
                    text: (zoomSlider.value * 100).toFixed(0) + "%"
                    Layout.preferredWidth: 50
                }
            }
            GroupBox {
                title: "ImageComposer-Parts"
                Layout.preferredWidth: 300

                ButtonGroup { id: composerPartGroup; exclusive: true }

                RowLayout {
                    spacing: 12

                    CheckBox {
                        id: parts1
                        text: "Parts 1"
                        ButtonGroup.group: composerPartGroup
                        onCheckedChanged: if (checked && composer) { composer.anzeigeZustand = 1; urlState.imageComposerParts = 1; }
                    }
                    CheckBox {
                        id: parts2
                        text: "Parts 2"
                        ButtonGroup.group: composerPartGroup
                        onCheckedChanged: if (checked && composer) { composer.anzeigeZustand = 2; urlState.imageComposerParts = 2; }
                    }
                    CheckBox {
                        id: parts3
                        text: "Parts 3"
                        ButtonGroup.group: composerPartGroup
                        onCheckedChanged: if (checked && composer) { composer.anzeigeZustand = 3; urlState.imageComposerParts = 3; }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 10
                Button {
                    id: nextButton
                    text: (urlWindow.multiEditCount && urlWindow.multiEditCount > 1 && !urlWindow.isLastStep) ? "Weiter" : "Beenden"
                    visible: urlWindow.isMultiEdit

                    onClicked: {
                        function continueNextStep() {
                            cleanupTempFile();
                            if (urlWindow.isLastStep || urlWindow.multiEditCount <= 1) {
                                rejected();      // <<< wichtig
                                urlWindow.close();
                            } else {
                                continueRequested();
                                urlWindow.close();
                            }
                        }

                        if (saveButton.enabled) {
                            unsavedWarningDialog.currentActionText = nextButton.text;
                            unsavedWarningDialog.continueCallback = continueNextStep;
                            unsavedWarningDialog.visible = true;
                        } else {
                            continueNextStep();
                        }
                    }
                }

                Button {
                    id: saveButton
                    enabled: false
                    text: "Speichern"
                    onClicked: {
                        if (composer && composer.anzeigeZustand > 1) {
                            saveButton.enabled = false;
                            composer.composeImages(function(success, composedPath) {
                                if (!success) {
                                    console.warn("Compose-Bild konnte nicht erzeugt werden:", composedPath);
                                    saveButton.enabled = true;
                                    return;
                                }

                                var composedUrl = webView.url.toString();
                                accepted(composedUrl, currentImageLicenceInfo, "png");

                                tempImagePath = "";
                                finalImagePath = "";
                                imageAvailable = false;
                                saveButton.enabled = false;
                            });
                            return;
                        }

                        if (tempImagePath === "" || finalImagePath === "") {
                            console.warn("⚠️ Kein temporäres Bild zum Speichern");
                            return;
                        }

                        if (FileHelper.removeFilesWithSameBaseName(finalImagePath)) {
                            console.log("🧹 Alle Varianten von", finalImagePath, "wurden gelöscht");
                        } else {
                            console.warn("❌ Dateien konnten nicht gelöscht werden");
                        }

                        if (FileHelper.renameFile(tempImagePath, finalImagePath)) {
                            console.log("💾 Bild gespeichert als:", finalImagePath);
                        } else {
                            console.warn("❌ Umbenennen fehlgeschlagen");
                            return;
                        }

                        // Signal senden an aufrufenden Dialog
                        var lUrl = webView.url.toString();
                        var savedType = finalImagePath.split('.').pop().toLowerCase();
                        accepted(lUrl, currentImageLicenceInfo, savedType);

                        // Clean up, aber NICHT schließen
                        tempImagePath = "";
                        finalImagePath = "";
                        imageAvailable = false;
                        cleanupTempFile();
                        saveButton.enabled = false
                    }
                }

                Button {
                    text: "Abbrechen"
                    onClicked: {
                        if (saveButton.enabled) {
                            cancelWarningPopup.open();
                        } else {
                            cleanupTempFile();
                            rejected();      // <<< wichtig
                            urlWindow.close();
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: cancelWarningPopup
        modal: true
        focus: true

        width: 400
        background: Rectangle {
            color: "#fff0f0"
            radius: 8
            border.color: "black"
            border.width: 2
        }

        contentItem: Column {
            spacing: 10
            padding: 20

            Label {
                text: "Es gibt noch nicht gespeicherte Aktionen. Trotzdem abbrechen?"
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: 10

                Button {
                    text: "Abbrechen"
                    Layout.preferredWidth: 120
                    onClicked: {
                        cancelWarningPopup.close();
                        cleanupTempFile();
                        rejected();      // <<< wichtig
                        urlWindow.close();
                    }
                }

                Button {
                    text: "Zurück"
                    Layout.preferredWidth: 100
                    onClicked: cancelWarningPopup.close()
                }
            }
        }

        onVisibleChanged: if (visible) {
            Qt.callLater(() => {
                cancelWarningPopup.x = (urlWindow.width - cancelWarningPopup.width) / 2;
                cancelWarningPopup.y = (urlWindow.height - cancelWarningPopup.height) / 2;
            });
        }
    }

    Popup {
        id: unsavedWarningDialog
        modal: true
        focus: true   // optional, damit Esc schließt
        property string currentActionText: "Weiter"
        property var continueCallback: function() {}

        background: Rectangle {
            color: "#fff0f0"
            radius: 8
            border.color: "black"
            border.width: 2
        }

        contentItem: Column {
            spacing: 10
            padding: 20
            width: 460

            Label {
                text: "Es gibt noch nicht gespeicherte Aktionen."
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: 10

                Button {
                    text: unsavedWarningDialog.currentActionText + " mit Speichern"
                    Layout.preferredWidth: 160
                    onClicked: {
                        unsavedWarningDialog.close();
                        saveButton.onClicked();
                    }
                }

                Button {
                    text: unsavedWarningDialog.currentActionText + " ohne Speichern"
                    Layout.preferredWidth: 160
                    onClicked: {
                        unsavedWarningDialog.close();
                        unsavedWarningDialog.continueCallback();
                    }
                }

                Button {
                    text: "Abbrechen"
                    Layout.preferredWidth: 100
                    onClicked: unsavedWarningDialog.close()
                }
            }
        }

        onVisibleChanged: if (visible) {
            unsavedWarningDialog.x = (urlWindow.width - unsavedWarningDialog.width) / 2;
            unsavedWarningDialog.y = (urlWindow.height - unsavedWarningDialog.height) / 2;
        }
    }

    Item {
        id: rectangleContainer
        anchors.fill: parent
        z: 1000

        MouseArea {
            id: transparentColorPickerArea
            anchors.fill: parent
            z: 10000
            enabled: urlWindow.pendingTransparentColorRect !== null
            visible: enabled
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.CrossCursor

            onClicked: function(mouse) {
                urlWindow.pendingTransparentColorPoint = Qt.point(mouse.x, mouse.y)
                urlWindow.finishTransparentColorPick()
                mouse.accepted = true
            }
        }

        FocusScope {
            id: rectangleKeyCatcher
            anchors.fill: parent
            enabled: false
            focus: false
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: function(event) {
                if (urlWindow.debugRectangleKeys)
                    console.log("[URLComponent][rectKeys] rectangleKeyCatcher",
                                "key=", event.key,
                                "mods=", event.modifiers,
                                "focus=", activeFocus)

                if (event.key === Qt.Key_Left || event.key === Qt.Key_Right ||
                    event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    urlWindow.handleActiveRectangleKey(event.key, event.modifiers)
                    event.accepted = true
                    return
                }
            }

            onActiveFocusChanged: if (urlWindow.debugRectangleKeys)
                console.log("[URLComponent][rectKeys] rectangleKeyCatcher focus", activeFocus)
        }
    }
}
