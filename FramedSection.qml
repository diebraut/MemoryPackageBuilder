import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15

Item {
    id: root

    /* =====================================================
       Öffentliche API
       ===================================================== */

    property string title: ""

    // Rahmen / Farben
    property color frameColor: "#888"
    property color titleBackgroundColor: "white"

    // Außenabstand im Layout
    property int topMargin: 8
    property int bottomMargin: 8

    // Innenabstände
    property int contentMargin: 12          // links / rechts / unten
    property int contentTopMargin: 22       // oben (wegen Titel)

    // true  -> füllt verfügbaren Platz (Listen, ScrollViews)
    // false -> Höhe ergibt sich aus Inhalt (Formulare)
    property bool fillHeight: false

    // Slot für beliebigen Inhalt
    default property alias content: contentItem.data

    property int frameInset: 4   // Abstand des Rahmens nach innen

    /* =====================================================
       Layout-Anbindung
       ===================================================== */

    Layout.fillWidth: true
    Layout.fillHeight: fillHeight
    Layout.topMargin: topMargin
    Layout.bottomMargin: bottomMargin

    // 🔑 ENTSCHEIDEND:
    // contentItem ist ein Item → implicitHeight ist sonst 0.
    // Deshalb verwenden wir contentItem.implicitHeight, das wir unten aus childrenRect ableiten.
    implicitHeight: fillHeight
        ? undefined
        : contentItem.implicitHeight + contentTopMargin + contentMargin

    /* =====================================================
       Rahmen
       ===================================================== */

    Rectangle {
        anchors.fill: parent
        anchors.margins: frameInset   // 👈 Rahmen nach innen
        radius: 6
        color: "transparent"
        border.color: frameColor
        border.width: 1
    }

    /* =====================================================
       Titel
       ===================================================== */

    Label {
        visible: title !== ""
        text: title
        font.bold: true
        color: "#444"

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: -8

        padding: 4

        background: Rectangle {
            color: titleBackgroundColor
            radius: 2
        }
    }

    /* =====================================================
       Inhaltscontainer
       ===================================================== */

    Item {
        id: contentItem
        anchors.fill: parent

        anchors.leftMargin: contentMargin
        anchors.rightMargin: contentMargin
        anchors.bottomMargin: contentMargin
        anchors.topMargin: contentTopMargin

        // ✅ DAS ist der Fix:
        // Item hat sonst implicitHeight=0 → Layout bricht.
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
    }
}
