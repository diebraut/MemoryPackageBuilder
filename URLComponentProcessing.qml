import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.9

import Helpers 1.0

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

    ImageDownloader {
        id: imgDownloader

        onDownloadSucceeded: handleDownloadSucceeded
        onDownloadFailed: handleDownloadFailed
    }

    function handleDownloadSucceeded(path) {
        console.log("✅ Bild gespeichert unter:", path);
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

                    function handleBildLaden(imageUrl) {
                        var subject = subjektnamen;
                        var imageType = imageUrl.split('.').pop().split(/\#|\?/)[0];
                        var filename = subject + "." + imageType;
                        var savePath = packagePath + "/" + filename;

                        console.log("💾 Bild wird gespeichert unter:", savePath);

                        imgDownloader.downloadImage(imageUrl, savePath);
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
                                                var savePath = packagePath + "/" + subjektnamen + ".jpg";
                                                console.log("💾 Bereich speichern als:", savePath);

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

                                                    // Handle wieder einblenden (falls du das Rechteck doch nicht zerstören willst)
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
                    text: "Übernehmen"
                    onClicked: {
                        accepted(webView.url.toString());
                        urlWindow.close();
                    }
                }

                Button {
                    text: "Abbrechen"
                    onClicked: urlWindow.close();
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
