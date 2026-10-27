import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import FileHelper 1.0

Rectangle {
    id: root
    property string filePath: ""
    property string refreshToken: ""
    property string imageContext: ""
    property int imageRevision: 0
    property var information: ({})
    property string requestToken: ""
    property int requestNumber: 0
    readonly property string requestPrefix: String(Date.now()) + "-" + String(Math.random())
    property string compressionToken: ""
    property var compressionResult: ({})
    property bool busy: false
    property string statusText: ""
    readonly property string previewUrl: compressionResult.previewUrl || ""
    readonly property bool hasPreview: previewUrl !== ""
    signal imageAccepted()

    color: "#eef3fb"
    border.color: "#c8d2df"
    radius: 3
    implicitHeight: 80

    function kilobytes(bytes) {
        return (Number(bytes || 0) / 1024).toLocaleString(Qt.locale(), "f", 1) + " KB"
    }
    function discardPreview() {
        if (compressionToken) FileHelper.discardImageCompressionPreview(compressionToken)
        compressionToken = ""
        compressionResult = ({})
        busy = false
        statusText = ""
    }
    function resetForImage() {
        discardPreview()
        if (qualitySlider) qualitySlider.value = 100
        information = ({})
        requestToken = ""
        refreshTimer.restart()
    }
    function refreshInformation() {
        requestToken = requestPrefix + "-" + String(++requestNumber)
        if (!filePath) { information = ({}); return }
        information = ({ state: "loading" })
        FileHelper.requestImageInformation(filePath, requestToken)
    }
    onFilePathChanged: resetForImage()
    onImageContextChanged: resetForImage()
    onRefreshTokenChanged: resetForImage()
    Component.onCompleted: refreshTimer.restart()
    Component.onDestruction: {
        if (compressionToken) FileHelper.discardImageCompressionPreview(compressionToken)
    }
    Timer { id: refreshTimer; interval: 100; onTriggered: root.refreshInformation() }
    Connections {
        target: FileHelper
        function onImageInformationReady(token, result) {
            if (token === root.requestToken) root.information = result
        }
        function onImageCompressionPreviewReady(token, result) {
            if (token !== root.compressionToken) return
            root.busy = false
            root.compressionResult = result
            root.statusText = result.state === "ready"
                ? "Vorschau: " + root.kilobytes(result.sizeBytes) + " bei " + result.quality + " % Qualität"
                    + (result.sizeBytes >= result.originalBytes ? " – keine kleinere Datei" : "")
                : (result.message || "Komprimierung fehlgeschlagen")
        }
        function onImageFileReplaced(path) {
            // A file may be used by both question and answer previews.
            const normalized = root.filePath.replace(/\\/g, "/")
            if (normalized.toLowerCase() === path.replace(/\\/g, "/").toLowerCase()) {
                root.discardPreview()
                root.refreshInformation()
                // Refresh only views of this actual file, keeping other previews intact.
                root.imageRevision++
                root.imageAccepted()
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            Label {
                Layout.preferredWidth: Math.min(145, root.width * 0.26)
                text: root.information.sizeBytes !== undefined
                    ? "Bildgröße: " + root.kilobytes(root.information.sizeBytes)
                    : (root.information.message || "Bildgröße: …")
                elide: Text.ElideRight
            }
            Label { text: "10 %" }
            Slider {
                id: qualitySlider
                Layout.fillWidth: true
                Layout.minimumWidth: 70
                from: 10
                to: 100
                stepSize: 10
                snapMode: Slider.SnapAlways
                value: 100
                implicitHeight: 30
                handle: Rectangle {
                    x: qualitySlider.leftPadding + qualitySlider.visualPosition * (qualitySlider.availableWidth - width)
                    y: qualitySlider.topPadding + (qualitySlider.availableHeight - height) / 2
                    implicitWidth: 46
                    implicitHeight: 26
                    radius: 13
                    color: qualitySlider.pressed ? "#c9def7" : "#ffffff"
                    border.color: qualitySlider.enabled ? "#527baa" : "#aab2bb"
                    Label {
                        anchors.centerIn: parent
                        text: Math.round(qualitySlider.value) + " %"
                        font.pixelSize: 11
                        color: "#24364b"
                    }
                }
                enabled: !!root.filePath && !root.busy
                ToolTip.visible: hovered
                ToolTip.text: "Bildqualität: 100 % = höchste Qualität, 10 % = stärkste Komprimierung"
            }
            Label { text: "100 %" }
            Button {
                text: root.busy ? "Läuft …" : "Komprimieren"
                enabled: !!root.filePath && !root.busy && !FileHelper.imageCompressionRunning
                onClicked: {
                    root.discardPreview()
                    root.busy = true
                    root.statusText = "Vorschau wird berechnet …"
                    root.compressionToken = root.requestPrefix + "-compression-" + String(++root.requestNumber)
                    FileHelper.requestImageCompressionPreview(root.filePath, Math.round(qualitySlider.value), root.compressionToken)
                }
            }
            Button {
                text: "Übernehmen"
                enabled: root.hasPreview && !root.busy
                onClicked: {
                    const result = FileHelper.applyImageCompressionPreview(root.compressionToken)
                    if (result.state !== "ready") root.statusText = result.message
                    else root.statusText = "Komprimiertes Bild übernommen."
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: root.statusText || "100 % = höchste Qualität. Original bleibt bis Übernehmen erhalten."
            elide: Text.ElideRight
            color: root.compressionResult.state === "error" ? "#a02020" : "#475569"
            ToolTip.visible: statusHover.hovered
            ToolTip.text: text
            HoverHandler { id: statusHover }
        }
    }
}
