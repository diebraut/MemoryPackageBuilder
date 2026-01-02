import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root

    property string title: ""
    property int frameInset: 4
    property int contentMargin: 12
    property int contentTopMargin: 18

    property color frameColor: "#888"
    property color titleBackgroundColor: "white"

    // ✅ Slot für Inhalt (damit Children NICHT über Titel/Rahmen liegen)
    default property alias content: contentItem.data

    // --- Inhalt (liegt unten) ---
    Item {
        id: contentItem
        anchors.fill: parent
        anchors.leftMargin: frameInset + contentMargin
        anchors.rightMargin: frameInset + contentMargin
        anchors.bottomMargin: frameInset + contentMargin
        anchors.topMargin: frameInset + contentMargin + (title !== "" ? contentTopMargin : 0)
        z: 0
    }

    // --- Rahmen (liegt über Inhalt) ---
    Rectangle {
        anchors.fill: parent
        anchors.margins: frameInset
        radius: 6
        color: "transparent"
        border.color: frameColor
        border.width: 1
        z: 1
    }

    // --- Titel (ganz oben) ---
    Label {
        visible: title !== ""
        text: title
        font.bold: true
        anchors.left: parent.left
        anchors.leftMargin: frameInset + 12
        anchors.top: parent.top
        anchors.topMargin: frameInset - 8
        padding: 4
        background: Rectangle { color: titleBackgroundColor; radius: 2 }
        z: 2
    }
}
