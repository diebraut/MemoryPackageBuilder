import QtQuick
import QtQuick.Window
import QtQuick.Controls

ApplicationWindow {
    id: mainWindow
    width: 600
    height: 400
    visible: true
    title: "Hauptfenster"
    color: "#f0f0f0"

    // Referenz auf das Kindfenster speichern
    property var childWindowRef: null

    TextField {
        id: mainInput
        anchors.centerIn: parent
        width: 200
        placeholderText: "Hauptfenster Eingabe"
    }

    // Inline-Komponente für das Kindfenster
    Component {
        id: childWindowComponent
        Window {
            id: childWindow
            width: 300
            height: 200
            title: "Kindfenster"
            flags: Qt.Tool
            visible: true

            required property Window parentWindow

            // Titel-Leiste für Bewegung
            Rectangle {
                id: titleBar
                width: parent.width
                height: 30
                color: "#e0e0e0"

                Text {
                    text: childWindow.title
                    anchors.centerIn: parent
                    font.bold: true
                }

                // Manuelle Bewegung implementieren
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    property point startPos: "0,0"

                    onPressed: {
                        startPos = Qt.point(mouse.x, mouse.y)
                    }

                    onPositionChanged: {
                        if (pressed) {
                            childWindow.x += mouse.x - startPos.x
                            childWindow.y += mouse.y - startPos.y
                        }
                    }
                }
            }

            // Eingabefeld unter der Titel-Leiste
            TextField {
                id: childInput
                anchors {
                    top: titleBar.bottom
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 20
                }
                width: 180
                placeholderText: "Kindfenster Eingabe"
            }

            // NUR BEIM START POSITIONIEREN
            Component.onCompleted: {
                x = parentWindow.x + parentWindow.width - width - 20
                y = parentWindow.y + 40
            }

            // Sichtbarkeit an Hauptfenster-Zustand binden
            Connections {
                target: mainWindow
                function onVisibilityChanged() {
                    if (mainWindow.visibility === Window.Minimized) {
                        childWindow.visible = false
                    } else {
                        childWindow.visible = true
                    }
                }
            }

            // Immer über dem Hauptfenster bleiben ohne Fokus zu stehlen
            Connections {
                target: mainWindow
                function onActiveChanged() {
                    if (mainWindow.active) {
                        // Bringt das Fenster nach vorne ohne Fokus zu stehlen
                        childWindow.raise()
                    }
                }
            }
        }
    }

    // Kindfenster beim Start erstellen
    Component.onCompleted: {
        childWindowRef = childWindowComponent.createObject(null, {
            "parentWindow": mainWindow
        })
    }

    // Kindfenster schließen, wenn Hauptfenster geschlossen wird
    Connections {
        target: mainWindow
        function onClosing(close) {
            if (childWindowRef) {
                childWindowRef.visible = false
                childWindowRef.destroy()
                childWindowRef = null
            }
            close.accepted = true
        }
    }

    // Fokus auf das Hauptfenster setzen
    onActiveChanged: {
        if (active) {
            mainInput.forceActiveFocus()
        }
    }
}
