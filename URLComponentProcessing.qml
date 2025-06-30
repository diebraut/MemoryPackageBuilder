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

    ImageDownloader {
        id: imgDownloader

        onDownloadSucceeded: handleDownloadSucceeded
        onDownloadFailed: handleDownloadFailed
    }

    function handleDownloadSucceeded(path) {
        console.log("✅ Bild gespeichert unter:", path);
        // Optional: Fenster schließen oder Status anzeigen
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
                    } else if (request.status === 1 && request.isMainFrame) {
                        errorLabel.visible = false;
                        console.log("✅ Seite geladen:", request.url);
                    }
                }

                onContextMenuRequested: function(request) {
                    request.accepted = true;

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

                        // TODO: Hier die Logik für das Erzeugen des Rechtecks implementieren
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
}
