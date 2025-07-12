import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.9

import Helpers 1.0
import FileHelper 1.0

import Wiki 1.0  // Dein C++ Modul

Window {
    id: urlWindow
    title: "Webseite ansehen"
    width: 800
    height: 600
    modality: Qt.ApplicationModal
    visible: true
    property string urlString: ""
    property string subjektnamen: ""
    property string packagePath: ""

    signal accepted(string newUrl)
    property var dynamicMenu
    property var lastContextMenuPosition
    property bool pageReady: false

    property string tempImagePath: ""
    property string finalImagePath: ""
    property bool imageAvailable: false

    property var currentImageLicenceInfo: null
    property string licenceFetchMode: ""  // z.B. "bildLaden" oder "rechteck"

    function cleanupTempFile() {
        if (tempImagePath !== "") {
            var file = new QFile(tempImagePath);
            if (file.exists()) {
                file.remove();
                console.log("🗑️ Temporäre Datei gelöscht:", tempImagePath);
            }
            tempImagePath = "";
            finalImagePath = "";
            imageAvailable = false;
            saveButton.enabled = false;
        }
    }
    function handleRechteckErzeugen() {
        console.log("🟩 Rechteck erzeugen gewählt");

        // Menü vor dem Erzeugen schließen, damit es nicht im Screenshot landet
        if (urlWindow.dynamicMenu) {
            urlWindow.dynamicMenu.destroy();
            urlWindow.dynamicMenu = null;
        }

        var rect = Qt.createQmlObject(`
            import QtQuick 2.15
            import QtQuick.Controls 2.15

            Rectangle {
                width: 100; height: 100
                color: "transparent"
                x: ${lastContextMenuPosition.x}
                y: ${lastContextMenuPosition.y}
                border.color: "black"
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    drag.target: parent
                    cursorShape: Qt.SizeAllCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: function(mouse) {
                        if (mouse.button === Qt.RightButton) {
                            console.log("📌 Rechtsklick auf Rechteck");

                            if (urlWindow.dynamicMenu) {
                                urlWindow.dynamicMenu.destroy();
                            }

                            urlWindow.dynamicMenu = Qt.createQmlObject('import QtQuick.Controls 2.15; Menu {}', rectangleContainer);

                            var saveItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Bereich speichern" }', urlWindow.dynamicMenu);
                            saveItem.triggered.connect(function() {
                                var extension = "jpg";
                                var tempName = subjektnamen + "_TEMP." + extension;
                                var savePath = packagePath + "/" + tempName;

                                tempImagePath = savePath;
                                finalImagePath = savePath.replace("_TEMP.", ".");
                                imageAvailable = true;
                                saveButton.enabled = true;

                                console.log("💾 Bereich speichern als (temporär):", savePath);

                                // Handle ausblenden
                                resizeHandle.visible = false;

                                // Screenshot verzögert auslösen
                                Qt.callLater(function() {
                                    imgDownloader.grabAndSaveCropped(urlWindow,
                                                                     parent.x,
                                                                     parent.y,
                                                                     parent.width,
                                                                     parent.height,
                                                                     savePath);

                                    // Handle wieder einblenden (falls Rechteck nicht zerstört würde)
                                    resizeHandle.visible = true;

                                    // Rechteck entfernen
                                    parent.destroy();
                                    console.log("🗑️ Rechteck nach dem Speichern entfernt");
                                });
                            });
                            urlWindow.dynamicMenu.addItem(saveItem);

                            var removeItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck entfernen" }', urlWindow.dynamicMenu);
                            removeItem.triggered.connect(function() {
                                console.log("🗑️ Rechteck entfernt");
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

                    Rectangle {
                        anchors.fill: parent
                        color: "black"
                    }

                    property real dragXStart: 0
                    property real dragYStart: 0

                    onPressed: function(mouse) {
                        dragXStart = mouse.x;
                        dragYStart = mouse.y;
                    }

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

        if (imageUrl.includes("upload.wikimedia.org")) {
            var fileTitle = extractOriginalFileTitle(imageUrl);
            if (!fileTitle || fileTitle === "File:") {
                console.warn("❌ Kein gültiger Dateititel extrahiert.");
                return;
            }

            licenceFetcher.autoDownloadImage = true;
            licenceFetchMode = "bildLaden";

            licenceFetcher.fetchLicenceInfo(fileTitle);

        } else {
            saveImageTemporarily(imageUrl);
        }
    }

    function handleRechteckMitBild(imageUrl) {
        console.log("🟩 Rechteck (mit Bild) gewählt für:", imageUrl);

        if (!imageUrl || imageUrl === "") {
            console.warn("⚠️ Leere Bild-URL");
            return;
        }

        if (imageUrl.includes("upload.wikimedia.org")) {
            var fileTitle = extractOriginalFileTitle(imageUrl);
            if (!fileTitle || fileTitle === "File:") {
                console.warn("❌ Kein gültiger Dateititel extrahiert.");
                return;
            }

            licenceFetcher.autoDownloadImage = false;
            licenceFetchMode = "rechteck";

            licenceFetcher.fetchLicenceInfo(fileTitle);

        } else {
            currentImageLicenceInfo = null;
            handleRechteckErzeugen();
        }
    }

    function extractOriginalFileTitle(imageUrl) {
        var parts = imageUrl.split('/');
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
            return;
        }

        var extension = imageUrl.split('.').pop().split(/\#|\?/)[0];
        if (!extension.match(/^[a-zA-Z0-9]+$/)) {
            extension = "jpg";  // Fallback
        }

        var filename = subjektnamen + "_TEMP." + extension;
        var savePath = packagePath + "/" + filename;

        tempImagePath = savePath;
        finalImagePath = savePath.replace("_TEMP.", ".");

        console.log("💾 Temporäre Speicherung:", savePath);
        imgDownloader.downloadImage(imageUrl, savePath);
    }

    ImageDownloader {
        id: imgDownloader

        onDownloadSucceeded: function(filePath) {
            console.log("✅ Signal empfangen in QML:", filePath);
            handleDownloadSucceeded(filePath);
        }

        onDownloadFailed: {
            console.log("❌ Fehler beim Download:", errorString);
            handleDownloadFailed(errorString);
        }
    }

    LicenceInfoWiki {
        id: licenceFetcher

        property bool autoDownloadImage: true  // Standard für <Bild laden>

        onInfoReady: function(info) {
            currentImageLicenceInfo = info;

            console.log("✅ Lizenzinfo erhalten:", info.licenceName);

            if (licenceFetchMode === "bildLaden" && autoDownloadImage && info.imageUrl.includes("wikimedia.org")) {
                var thumbUrl = build500pxThumbnailUrl(info.imageUrl);
                console.log("🌐 Lade 500px-Thumbnail:", thumbUrl);
                saveImageTemporarily(thumbUrl);
            } else if (licenceFetchMode === "rechteck") {
                console.log("🟩 Lizenzinfo für Rechteck gespeichert. Rechteck wird jetzt erzeugt.");
                handleRechteckErzeugen();
            } else {
                console.log("ℹ️ Lizenzinfo erhalten, aber kein weiterer Vorgang definiert.");
            }
        }

        onErrorOccurred: function(message) {
            console.warn("❌ Fehler beim Abrufen der Lizenzinfos:", message);
        }
        function build500pxThumbnailUrl(originalUrl) {
            // Beispiel: https://upload.wikimedia.org/wikipedia/commons/b/be/FILENAME.svg
            var parts = originalUrl.split('/');
            if (parts.length < 7) {
                console.warn("❗ Ungültige Wikimedia-URL:", originalUrl);
                return originalUrl;  // Fallback: Original verwenden
            }

            var dir1 = parts[parts.length - 3];  // z.B. 'b'
            var dir2 = parts[parts.length - 2];  // z.B. 'be'
            var file = parts[parts.length - 1];  // z.B. 'FILENAME.svg'

            return "https://upload.wikimedia.org/wikipedia/commons/thumb/"
                + dir1 + "/" + dir2 + "/" + file + "/500px-" + file + ".png";
        }
    }

    function handleDownloadSucceeded(path) {
        tempImagePath = path;
        finalImagePath = path.replace("_TEMP", "");  // z.B. von foo_TEMP.png → foo.png
        imageAvailable = true;
        saveButton.enabled = true;
        console.log("✅ Bild temporär gespeichert:", path);
    }

    function handleDownloadFailed(error) {
        console.warn("❌ Download fehlgeschlagen:", error);
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
                        errorLabel.visible = false;
                        console.log("✅ Seite geladen:", request.url);
                        pageReady = true;
                    }
                }

                onContextMenuRequested: function(request) {
                    request.accepted = true;

                    lastContextMenuPosition = { "x": request.position.x, "y": request.position.y };

                    var viewX = request.position.x / webView.zoomFactor;
                    var viewY = request.position.y / webView.zoomFactor;

                    var js = `
                        (function() {
                            var elem = document.elementFromPoint(${viewX}, ${viewY});
                            if (!elem) return "";
                            if (elem.tagName === "IMG") return elem.src;
                            return "";
                        })();
                    `;

                    webView.runJavaScript(js, function(result) {
                        if (dynamicMenu) {
                            dynamicMenu.destroy();
                        }

                        dynamicMenu = Qt.createQmlObject('import QtQuick.Controls 2.15; Menu {}', urlWindow);

                        var hasItem = false;

                        if (result !== "") {
                            var imgItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Bild laden" }', dynamicMenu);
                            imgItem.triggered.connect(function() {
                                handleBildLaden(result);
                            });
                            dynamicMenu.addItem(imgItem);

                            var rectImageItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck erzeugen (mit Bild)" }', dynamicMenu);
                            rectImageItem.triggered.connect(function() {
                                handleRechteckMitBild(result);
                            });
                            dynamicMenu.addItem(rectImageItem);

                            hasItem = true;
                        }

                        var rectItem = Qt.createQmlObject('import QtQuick.Controls 2.15; MenuItem { text: "Rechteck erzeugen" }', dynamicMenu);
                        rectItem.triggered.connect(handleRechteckErzeugen);
                        dynamicMenu.addItem(rectItem);
                        hasItem = true;

                        if (hasItem) {
                            dynamicMenu.x = request.position.x;
                            dynamicMenu.y = request.position.y;
                            dynamicMenu.open();
                        }
                    });

                }
            }
        }

        Label {
            id: errorLabel
            text: "❌ Seite nicht erreichbar oder ungültige URL"
            color: "red"
            visible: false
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
                        webView.zoomFactor = value;
                        console.log("🔍 Zoomfaktor geändert:", value);
                    }
                }

                Label {
                    text: (zoomSlider.value * 100).toFixed(0) + "%"
                    Layout.preferredWidth: 50
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 10

                Button {
                    id: saveButton
                    enabled: false;
                    text: "Übernehmen"
                    onClicked: {
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
                        }

                        // Clean up
                        tempImagePath = "";
                        finalImagePath = "";
                        imageAvailable = false;
                        saveButton.enabled = false;
                    }
                }

                Button {
                    text: "Abbrechen"
                    onClicked: {
                        accepted(webView.url.toString());
                        cleanupTempFile();
                        urlWindow.close();
                    }
                }
            }
        }
    }

    Item {
        id: rectangleContainer
        anchors.fill: parent
        z: 1000
    }
}
