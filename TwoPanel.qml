// RefactoredMain.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import "."  // Importiere lokale Komponenten

Item {
    id: root

    property real splitterRatio: 0.5
    property bool isVertical: true
    property int selectedPartIndex: 1
    property real totalWidth: width
    property real totalHeight: height

    property real borderMargin: 3
    property real gapToSplitter: 2

    signal partClicked(int index)

    property alias part1: part1View
    property alias part2: part2View
    function getParts() { return [part1View, part2View] }

    function setImageForPart(index, filePath) {
        if (index === 1) part1View.setImage(filePath);
        else if (index === 2) part2View.setImage(filePath);
        else console.warn("❓ Ungültiger Part:", index);
    }

    // === PART 1 ===
    PartView {
        id: part1View
        index: 1
        label: "1"
        selected: root.selectedPartIndex === 1
        onClicked: root.partClicked(index)

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: borderMargin
        width: root.isVertical ?
               (root.totalWidth - 2 * borderMargin) * root.splitterRatio :
               root.totalWidth - 2 * borderMargin
        height: root.isVertical ?
                root.totalHeight - 2 * borderMargin :
                (root.totalHeight - 2 * borderMargin) * root.splitterRatio

        // ✨ jetzt korrekt:
        marginRight: root.isVertical ? gapToSplitter : 0
        marginBottom: root.isVertical ? 0 : gapToSplitter
    }

    // === SPLITTER ===
    Splitter {
        id: splitter
        isVertical: root.isVertical
        valueChangedHandler: (val) => root.splitterRatio = val
        x: root.isVertical ?
           (part1View.x + part1View.width) :
           borderMargin
        y: root.isVertical ?
           borderMargin :
           (part1View.y + part1View.height)
    }

    // === PART 2 ===
    PartView {
        id: part2View
        index: 2
        label: "2"
        selected: root.selectedPartIndex === 2
        onClicked: root.partClicked(index)

        anchors.margins: borderMargin

        anchors.top: root.isVertical ? parent.top : splitter.bottom
        anchors.left: root.isVertical ? splitter.right : parent.left
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        // Abstand zur Trennlinie nur über äußeres Layout
        anchors.leftMargin: root.isVertical ? gapToSplitter : 0
        anchors.topMargin: root.isVertical ? 0 : gapToSplitter

        // keine internen Markierungs-Margins mehr
        marginLeft: 0
        marginTop: 0
    }
}
