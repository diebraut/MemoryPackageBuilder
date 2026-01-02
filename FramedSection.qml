import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: root

    /* =======================
       Öffentliche API
       ======================= */

    property string title: ""

    // Optik
    property color frameColor: "#888"
    property color titleBackgroundColor: "white"
    property int frameInset: 4

    // Außenabstand im übergeordneten Layout
    property int topMargin: 8
    property int bottomMargin: 8

    // Innenabstände
    property int contentMargin: 12        // links / rechts / unten
    property int contentTopMargin: 22     // oben (wegen Titel)

    // Steuerung der Höhe
    // false = Höhe aus Inhalt (Formular)
    // true  = füllt verfügbaren Platz (Listen)
    property bool fillHeight: false

    // Slot für beliebigen Inhalt
    default property alias content: contentItem.data

    /* =======================
       Layout-Anbindung
       ======================= */

    Layout.fillWidth: true
    Layout.fillHeight: fillHeight
    Layout.topMargin: topMargin
    Layout.bottomMargin: bottomMargin

    // implicitHeight darf NIE undefined sein
    implicitHeight: fillHeight
        ? 0
        : contentItem.implicitHeight
          + contentTopMargin
          + contentMargin

    /* =======================
       Rahmen
       ======================= */

    Rectangle {
        anchors.fill: parent
        anchors.margins: frameInset
        radius: 6
        color: "transparent"
        border.color: frameColor
        border.width: 1
    }

    /* =======================
       Titel
       ======================= */

    Label {
        visible: title !== ""
        text: title
        font.bold: true
        color: "#444"

        anchors.left: parent.left
        anchors.leftMargin: frameInset + 12
        anchors.top: parent.top
        anchors.topMargin: frameInset - 8

        padding: 4
        background: Rectangle {
            color: titleBackgroundColor
            radius: 2
        }
    }

    /* =======================
       Inhaltscontainer
       ======================= */

    Item {
        id: contentItem
        anchors.fill: parent

        anchors.leftMargin: frameInset + contentMargin
        anchors.rightMargin: frameInset + contentMargin
        anchors.bottomMargin: frameInset + contentMargin
        anchors.topMargin: frameInset + contentTopMargin

        // wichtig für Layouts (sonst implicitHeight = 0)
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
    }
}
