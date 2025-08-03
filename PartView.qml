// PartView.qml
import QtQuick 2.15

Item {
    id: part

    property int index: 0
    property bool selected: false
    property string label: ""
    property real borderWidth: 3
    property color highlightColor: "#0077ff"

    property real marginLeft: 0
    property real marginTop: 0
    property real marginRight: 0
    property real marginBottom: 0

    signal clicked(int index)

    function setImage(path) {
        console.log("🔍 Bildpfad:", path);
        image.source = ""; // Reset
        image.source = path
        image.visible = true;
    }

    // Optional: Bildanzeige
    Image {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        cache: false
        //border.color: "red"  // temporär testen
        visible: true
        z: 1
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        z: -1

        MouseArea {
            anchors.fill: parent
            onClicked: part.clicked(index)
        }

        Text {
            anchors.centerIn: parent
            text: label
            font.pixelSize: 48
            z: 2
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
            z: 3
        }
    }
}
