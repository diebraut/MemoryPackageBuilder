import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtWebEngine 1.9

Dialog {
    id: urlDialog
    modal: true
    title: "Webseite ansehen"
    width: 800
    height: 600
    property string urlString: ""
    signal accepted(string newUrl)

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        WebEngineView {
            id: webView
            Layout.fillWidth: true
            Layout.fillHeight: true

            Component.onCompleted: {
                const fallback = "https://de.wikipedia.org";
                const pageToLoad = (urlString && urlString.trim() !== "") ? urlString : fallback;
                console.log("🌐 Lade Seite:", pageToLoad);
                webView.url = pageToLoad;  // ✅ richtig für QML
            }
            onLoadingChanged: function(request) {
                // Nur prüfen, ob die Hauptseite fehlgeschlagen ist
                if (request.status === 2 && request.url === webView.url) {
                    errorLabel.visible = true;
                    console.log("❌ Fehler beim Laden:", request.url);
                } else {
                    errorLabel.visible = false;
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
            Layout.alignment: Qt.AlignRight
            spacing: 10

            Button {
                text: "Übernehmen"
                onClicked: {
                    accepted(webView.url.toString());
                    urlDialog.close();
                }
            }

            Button {
                text: "Abbrechen"
                onClicked: urlDialog.close()
            }
        }
    }
}
