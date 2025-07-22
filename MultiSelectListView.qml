import QtQuick 2.15
import QtQuick.Controls 2.15

ListView {
    id: multiSelectListView
    property var modelData

    onModelDataChanged: {
        if (modelData) {
            model = modelData;
            updateSelectedItems(); // bei neuem Model auch gleich Selektion aktualisieren
        }
    }
    property var selectedIndices: []
    property int selectionAnchor: -1
    property int currentListViewIndex: -1

    focus: true
    clip: true

    Keys.onPressed: function(event) {
        let newIndex = currentListViewIndex;
        const itemsPerPage = Math.floor(height / 40);

        switch (event.key) {
            case Qt.Key_Up:
                if (currentListViewIndex > 0) newIndex--;
                break;
            case Qt.Key_Down:
                if (currentListViewIndex < count - 1) newIndex++;
                break;
            case Qt.Key_PageUp:
                newIndex = Math.max(0, currentListViewIndex - itemsPerPage);
                break;
            case Qt.Key_PageDown:
                newIndex = Math.min(count - 1, currentListViewIndex + itemsPerPage);
                break;
            case Qt.Key_Home:
                newIndex = 0;
                break;
            case Qt.Key_End:
                newIndex = count - 1;
                break;
            case Qt.Key_Space:
                event.accepted = true;
                if (currentListViewIndex >= 0) {
                    toggleSelection(currentListViewIndex);
                    updateSelectedItems();
                }
                return;
            default:
                return;
        }

        if (newIndex !== currentListViewIndex) {
            const previousIndex = currentListViewIndex;
            currentListViewIndex = newIndex;
            currentIndex = newIndex;

            if (event.modifiers & Qt.ShiftModifier) {
                if (selectionAnchor === -1) {
                    selectionAnchor = previousIndex;
                    if (!(event.modifiers & Qt.ControlModifier)) {
                        selectedIndices = [previousIndex];
                    }
                }
                selectRange(selectionAnchor, newIndex, event.modifiers & Qt.ControlModifier);
            } else {
                selectionAnchor = -1;
            }

            positionViewAtIndex(newIndex, ListView.Contain);
        }

        event.accepted = true;
    }

    function toggleSelection(index) {
        if (selectedIndices.includes(index)) {
            selectedIndices = selectedIndices.filter(i => i !== index);
        } else {
            selectedIndices.push(index);
        }
        selectionAnchor = index;
        updateSelectedItems();
    }

    function selectRange(from, to, isCtrlPressed) {
        const start = Math.min(from, to);
        const end = Math.max(from, to);
        let newSelection = [];
        for (let i = start; i <= end; i++) {
            newSelection.push(i);
        }

        if (isCtrlPressed) {
            selectedIndices = [...new Set([...selectedIndices, ...newSelection])];
        } else {
            selectedIndices = newSelection;
        }

        selectedIndices.sort((a, b) => a - b);
        updateSelectedItems();
    }

    function updateSelectedItems() {
        for (let i = 0; i < model.count; i++) {
            model.setProperty(i, "selected", selectedIndices.includes(i));
        }
    }

    delegate: Item {
        width: multiSelectListView.width
        height: 40

        Rectangle {
            anchors.fill: parent
            color: model.selected ? "lightsteelblue" : "transparent"
            radius: 2
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: function(mouse) {
                const clickedIndex = index;
                currentListViewIndex = clickedIndex;
                multiSelectListView.currentIndex = clickedIndex;
                multiSelectListView.forceActiveFocus();

                if (mouse.modifiers & Qt.ShiftModifier) {
                    if (selectionAnchor === -1) {
                        selectionAnchor = currentListViewIndex;
                    }
                    selectRange(selectionAnchor, clickedIndex, mouse.modifiers & Qt.ControlModifier);
                } else if (mouse.modifiers & Qt.ControlModifier) {
                    toggleSelection(clickedIndex);
                } else {
                    selectedIndices = [clickedIndex];
                    selectionAnchor = clickedIndex;
                }
                updateSelectedItems();
            }
        }
    }
}
