import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Fusion 2.15
import Qt.labs.platform 1.1 as Platform

import FileHelper 1.0

import ExersizeLoader 1.0

Window {
    id: dialogWindow
    width: 900
    height: 600
    title: "Übungen bearbeiten"
    visible: true
    modality: Qt.ApplicationModal

    // Eigenschaften
    property string packagePath
    property bool sequentiell: sequentiellCheckBox.checked
    property bool hideAuthorByQuestion: hideAuthorByQuestionCheckBox.checked
    property bool umgekehrt: umgekehrtCheckBox.checked
    property string frageText: frageTextField.text
    property string frageTextUmgekehrt: frageTextUmgekehrtField.text
    property string uebungenName: uebungenNameField.text

    property var uebungenData
    property int labelWidth: 120

    // Anzahl der Spalten
    property int columnCount: 9
    // Zwischenraum zwischen den Spalten (Row.spacing)
    property int columnSpacing: 5

    property var io    // kommt aus main.qml, z.B. buildExercize

    EditExersizeDialog {
        id: editExersizeDialog

        onSave: function(updatedData, index) {
            if (index >= 0 && index < uebungModel.count) {
                const keys = Object.keys(updatedData);
                for (let key of keys) {
                    uebungModel.setProperty(index, key, updatedData[key]);
                }
                // Optionales Refresh der View
                saveCurrentModelToXml();
            } else {
                console.warn("❌ Ungültiger Index beim Speichern:", index);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                customContextMenu.popup(mouse.x, mouse.y)
            }
        }
    }
    // ------------------------------------------------------------------
    // Info-Popup (OK)
    // ------------------------------------------------------------------
    Popup {
        id: infoPopup
        modal: true
        focus: true
        width: 400

        // alias, damit du infoPopup.text setzen kannst
        property alias text: infoLabel.text

        background: Rectangle {
            color: "#fff0f0"
            radius: 8
            border.color: "black"
            border.width: 2
        }

        contentItem: Column {
            spacing: 10
            padding: 20

            Label {
                id: infoLabel
                text: ""
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: 10
                Button {
                    text: "OK"
                    Layout.preferredWidth: 120
                    onClicked: infoPopup.close()
                }
            }
        }

        onVisibleChanged: if (visible) {
            Qt.callLater(() => {
                infoPopup.x = (dialogWindow.width  - infoPopup.width)  / 2;
                infoPopup.y = (dialogWindow.height - infoPopup.height) / 2;
            });
        }
    }

    /* ===== Meldungen via Popup ===== */
    // ------------------------------------------------------------------
    // Bestätigungs-Popup (Löschen / Abbrechen)
    // ------------------------------------------------------------------
    Popup {
        id: confirmDeletePopup
        modal: true
        focus: true
        width: 400

        // alias, damit du confirmDeletePopup.text setzen kannst
        property alias text: confirmLabel.text
        // trägt die zu löschenden Indizes
        property var indicesToDelete: []

        background: Rectangle {
            color: "#fff0f0"
            radius: 8
            border.color: "black"
            border.width: 2
        }

        contentItem: Column {
            spacing: 10
            padding: 20

            Label {
                id: confirmLabel
                text: ""
                wrapMode: Text.WordWrap
            }

            RowLayout {
                spacing: 10

                Button {
                    text: "Löschen"
                    Layout.preferredWidth: 120
                    onClicked: {
                        const idx = confirmDeletePopup.indicesToDelete || [];
                        confirmDeletePopup.close();
                        performDelete(idx);
                    }
                }

                Button {
                    text: "Abbrechen"
                    Layout.preferredWidth: 100
                    onClicked: confirmDeletePopup.close()
                }
            }
        }

        onVisibleChanged: if (visible) {
            Qt.callLater(() => {
                confirmDeletePopup.x = (dialogWindow.width  - confirmDeletePopup.width)  / 2;
                confirmDeletePopup.y = (dialogWindow.height - confirmDeletePopup.height) / 2;
            });
        }
    }
    /* ===== CSV-Import ===== */
    Platform.FileDialog {
        id: csvImportDialog
        title: "CSV-Datei importieren"
        folder: "file:///" + buildSourcenFolder  // ← wichtig
        nameFilters: ["CSV-Dateien (*.csv)", "Alle Dateien (*.*)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            const url = (files && files.length) ? files[0].toString()
                      : (file && file.toString ? file.toString() : String(file));
            importCsvFromUrl(url);
        }
        onRejected: console.log("❌ CSV-Import abgebrochen.")
    }

    // --- Helfer: Separator erkennen ---
    function _sniffSeparator(headerLine) {
        if (headerLine.indexOf("\t") !== -1) return "\t";
        const sc = (headerLine.match(/;/g) || []).length;
        const cc = (headerLine.match(/,/g) || []).length;
        return sc > cc ? ";" : ",";
    }

    // --- Helfer: CSV-Zeile in Felder zerlegen (mit Quotes) ---
    function _splitCsvLine(line, sep) {
        let out = [], cur = "", inQuotes = false;
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === '"') {
                if (inQuotes && line[i + 1] === '"') { cur += '"'; i++; }
                else inQuotes = !inQuotes;
            } else if (ch === sep && !inQuotes) {
                out.push(cur); cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    // --- CSV-Text in Objekte parsen (FrageSubjekt, AntwortSubjekt, InfoUrlFrage, InfoUrlAntwort) ---
    function _parseCsv(text) {
        // BOM entfernen + Zeilen normalisieren
        if (text.length && text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
        text = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");

        const lines = text.split("\n").filter(l => l.trim().length > 0);
        if (lines.length === 0) return [];

        const sep = _sniffSeparator(lines[0]);

        const headers = _splitCsvLine(lines[0], sep).map(h => h.trim());
        // Header-Index-Suche (tolerant gegenüber Schreibweisen)
        function idxOf(name) {
            const target = name.toLowerCase().replace(/[\s_]/g, "");
            for (let i = 0; i < headers.length; i++) {
                const h = headers[i].toLowerCase().replace(/[\s_]/g, "");
                if (h === target) return i;
            }
            return -1;
        }
        let iFrage = idxOf("FrageSubjekt");
        let iAntwort = idxOf("AntwortSubjekt");
        let iUrlF = idxOf("InfoUrlFrage");
        let iUrlA = idxOf("InfoUrlAntwort");

        // Falls kein Header: als 4 feste Spalten interpretieren
        let startIdx = 1;
        if (iFrage === -1 && iAntwort === -1 && iUrlF === -1 && iUrlA === -1) {
            iFrage = 0; iAntwort = 1; iUrlF = 2; iUrlA = 3;
            startIdx = 0;
        }

        const rows = [];
        for (let li = startIdx; li < lines.length; li++) {
            const cols = _splitCsvLine(lines[li], sep);
            function get(i) {
                const v = (i >= 0 && i < cols.length) ? cols[i] : "";
                return String(v).trim().replace(/^"|"$/g, "");
            }
            const r = {
                FrageSubjekt: get(iFrage),
                AntwortSubjekt: get(iAntwort),
                InfoUrlFrage: get(iUrlF),
                InfoUrlAntwort: get(iUrlA)
            };
            if (r.FrageSubjekt) rows.push(r);
        }
        return rows;
    }

    // --- Datei laden und importieren ---
    // Hilfsfunktion: file:///... → lokaler Pfad
    function _urlToLocalPath(u) {
        let s = String(u || "");
        if (s.startsWith("file:///")) s = s.substring(8);     // "C:/foo/bar.csv" (Windows)
        else if (s.startsWith("file://")) s = s.substring(7);
        s = decodeURIComponent(s);
        // Windows: manchmal beginnt es noch mit "/" vor "C:"
        if (Qt.platform.os === "windows" && s.length >= 3 && s[0] === "/" && s[2] === ":") {
            s = s.substring(1);
        }
        return s;
    }

    function importCsvFromUrl(fileUrl) {
        if (/^file:/i.test(fileUrl)) {
            const localPath = _urlToLocalPath(fileUrl);
            console.log("📄 CSV fileUrl:", fileUrl);
            console.log("📄 CSV localPath:", localPath);

            let text = "";
            try {
                if (io && io.readTextFile) {           // <<<<<<<<  übergebenen Reader nutzen
                    text = io.readTextFile(localPath);
                }
            } catch (e) {
                console.warn("⚠️ Ausnahme beim Lesen:", e);
                text = "";
            }

            if (!text || text.length === 0) {
                infoPopup.text = "CSV konnte nicht gelesen werden:\n" + localPath;
                infoPopup.open();
                return;
            }

            const rows = _parseCsv(text);
            _appendRowsToModel(rows);
            return;
        }

        // HTTP/HTTPS bleibt wie gehabt …
        const xhr = new XMLHttpRequest();
        xhr.open("GET", fileUrl, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    const rows = _parseCsv(xhr.responseText || "");
                    _appendRowsToModel(rows);
                } else {
                    infoPopup.text = "CSV konnte nicht gelesen werden:\n" + fileUrl;
                    infoPopup.open();
                }
            }
        };
        xhr.onerror = function() {
            infoPopup.text = "Fehler beim Lesen der CSV:\n" + fileUrl;
            infoPopup.open();
        };
        xhr.send();
    }

    // --- Rows ans Model hängen (mit Duplikat-Check auf FrageSubjekt) ---
    function _appendRowsToModel(rows) {
        if (!rows || rows.length === 0) {
            infoPopup.text = "Keine gültigen Einträge in der CSV gefunden.";
            infoPopup.open();
            return;
        }

        // Duplikat-Set aus aktuellem Model
        const exists = {};
        for (let i = 0; i < uebungModel.count; i++) {
            const k = (uebungModel.get(i).frageSubjekt || "").toString().trim().toLowerCase();
            if (k) exists[k] = true;
        }

        let added = 0, skipped = 0;
        let num = nextFreeNumber();

        for (let r of rows) {
            const key = (r.FrageSubjekt || "").toString().trim().toLowerCase();
            if (!key || exists[key]) { skipped++; continue; }

            exists[key] = true;

            uebungModel.append({
                nummer: num++,
                frageSubjekt: r.FrageSubjekt || "",
                antwortSubjekt: r.AntwortSubjekt || "",
                infoURLFrage: r.InfoUrlFrage || "",
                infoURLAntwort: r.InfoUrlAntwort || "",
                hideAuthor: false,
                infoURLFrage_bgcolor: "white",
                infoURLAntwort_bgcolor: "white",
                selected: false
            });
            added++;
        }

        // Persistieren
        saveCurrentModelToXml();

        infoPopup.text = "Import abgeschlossen:\nHinzugefügt: " + added + "\nÜbersprungen (Duplikate): " + skipped;
        infoPopup.open();
    }

    /* ===== Lösch-Workflow ===== */
    // --- Helfer: Auswahl aus der ListView holen ---
    function selectedRows() {
        return (listView && listView.selectedIndices) ? listView.selectedIndices.slice() : [];
    }

    // --- Dummy: später echte XML-Löschung hier implementieren ---
    function removeEntriesFromXml(indices) {
        console.log("🧪 Dummy XML-Remove – noch nicht implementiert. Indices:", indices);
        // TODO: echte Entfernung aus der XML-Datei
        return true;
    }

    // --- Public API: vom Button aus aufrufen ---
    function requestDeleteSelectedRows() {
        const sel = selectedRows();
        if (sel.length === 0) {
            infoPopup.text = "Kein Zeile zum löschen markiert";
            infoPopup.open();
            return;
        }
        confirmDeletePopup.text = "<Achtung die markierten Zeilen werden endgültig gelöscht";
        confirmDeletePopup.indicesToDelete = sel.slice(); // Kopie der Auswahl
        confirmDeletePopup.open();
    }

    /* ===== XML-Entfernung: echte Implementierung ===== */
    function deleteEntriesFromXml(indices) {
        if (!indices || indices.length === 0) return true;
        if (!packagePath) {
            console.warn("❌ deleteEntriesFromXml: packagePath fehlt");
            return false;
        }

        // Set der zu löschenden Indizes
        const skip = {};
        indices.forEach(i => { if (i >= 0) skip[i] = true; });

        // Daten neu aufbauen (wie saveCurrentModelToXml), aber OHNE die zu löschenden Einträge
        const data = {
            name: uebungenNameField.text,
            frageText: frageTextField.text,
            frageTextUmgekehrt: frageTextUmgekehrtField.text,
            sequentiell: sequentiellCheckBox.checked,
            umgekehrt: umgekehrtCheckBox.checked,
            hideAuthorByQuestion: hideAuthorByQuestionCheckBox.checked,
            uebungsliste: []
        };

        for (let i = 0; i < uebungModel.count; ++i) {
            if (skip[i]) continue; // diesen Eintrag auslassen
            let eintrag = JSON.parse(JSON.stringify(uebungModel.get(i)));
            delete eintrag[""]; // evtl. leere Key-Leiche
            data.uebungsliste.push(eintrag);
        }

        const ok = ExersizeLoader.savePackage(packagePath, data);
        if (!ok) {
            console.warn("❌ deleteEntriesFromXml: Speichern nach Löschung fehlgeschlagen");
        }
        return ok;
    }

    /* ===== eigentliche Model-Löschung (ruft jetzt deleteEntriesFromXml) ===== */
    function performDelete(indices) {
        if (!indices || indices.length === 0) return;

        // (optional) wenn du weiterhin zuerst in der Datei löschen willst:
        // const numsToDelete = indices.map(i => Number(uebungModel.get(i).nummer)).filter(Number.isFinite);
        // deleteEntriesFromXml(numsToDelete); // falls vorhanden – sonst weglassen

        // 1) Aus dem Model löschen (absteigend für stabile Indizes)
        indices.sort((a,b) => b - a).forEach(i => {
            if (i >= 0 && i < uebungModel.count) uebungModel.remove(i);
        });

        // 2) Lückenlose Nummerierung wiederherstellen (1,2,3,…)
        renumberRowsSequentially(1);

        // 3) In XML persistieren (schreibt komplette Liste inkl. neuer Nummern)
        saveCurrentModelToXml();
        const data = ExersizeLoader.loadPackage(packagePath);
        uebungModel.clear();
        for (let e of data.uebungsliste) uebungModel.append(e);

        // 4) Auswahl/Fokus aufräumen
        listView.selectedIndices = [];
        listView.currentIndex = -1;
    }

    function renumberRowsSequentially(startAt) {
        const start = (typeof startAt === "number" && startAt > 0) ? startAt : 1;
        for (let i = 0; i < uebungModel.count; ++i) {
            const wanted = start + i;
            if (uebungModel.get(i).nummer !== wanted)
                uebungModel.setProperty(i, "nummer", wanted);
        }
    }

    function nextFreeNumber() {
        var maxN = 0;
        for (let i = 0; i < uebungModel.count; ++i) {
            const n = parseInt(uebungModel.get(i).nummer);
            if (!isNaN(n)) maxN = Math.max(maxN, n);
        }
        return maxN + 1;
    }

    /* ===== Duplikate anzeigen ===== */
    function showDuplicateRowsByFrageSubjekt() {
        // bisherige Auswahl zurücksetzen
        listView.selectedIndices = [];
        listView.currentIndex = -1;
        if ("selectionAnchor" in listView) listView.selectionAnchor = -1;

        const firstIndexByKey = {};
        const duplicates = [];

        for (let i = 0; i < uebungModel.count; ++i) {
            const raw = uebungModel.get(i).frageSubjekt;
            const key = (raw === undefined || raw === null) ? "" : String(raw).trim().toLowerCase();
            if (key === "") continue; // leere ignorieren – bei Bedarf entfernen, um auch "" zu zählen

            if (firstIndexByKey.hasOwnProperty(key)) {
                duplicates.push(i);   // nur ab der 2. Vorkommnis markieren
            } else {
                firstIndexByKey[key] = i;
            }
        }

        if (duplicates.length === 0) {
            infoPopup.text = "Keine doppelten Einträge in „FrageSubjekt“ gefunden.";
            infoPopup.open();
            return;
        }

        listView.selectedIndices = duplicates;
        listView.currentIndex = duplicates[0];
        if (listView.updateSelectedItems) listView.updateSelectedItems();
    }


    Component {
        id: imageProcessingComponent

        ImageProcessing {
            onAccepted: {
                console.log("Bildbearbeitung bestätigt.");
            }
            onRejected: {
                console.log("Bildbearbeitung abgebrochen.");
            }

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }
        }
    }

    Menu {
        id: imageContextMenu
        property string roleName
        property int rowIndex

        // Funktion zum sicheren Zugriff auf den Wert
        function getCurrentValue() {
            if (rowIndex >= 0 && rowIndex < uebungModel.count) {
                return uebungModel.get(rowIndex)[roleName] || "";
            }
            return "";
        }

        function openFileDialog() {
            console.log("FileDialog öffnen für:", roleName, "bei Zeile:", rowIndex);
            // Hier FileDialog implementieren
        }

        // Dynamische Erstellung der Menüeinträge
        function buildMenu() {
            // Alte Einträge entfernen
            while (count > 0) {
                removeItem(itemAt(0));
            }

            var currentVal = getCurrentValue();

            var texts = [];

            if (currentVal) {
                texts.push("Bild entfernen");
                texts.push("Bild austauschen");
                texts.push("Bild bearbeiten");
            } else {
                texts.push("Bild hinzufügen");
            }

            var maxWidth = 0;
            const metrics = Qt.createQmlObject(`
                import QtQuick 2.15
                FontMetrics { }
            `, imageContextMenu);

            for (var t of texts) {
                const width = metrics.boundingRect(t).width;
                maxWidth = Math.max(maxWidth, width);
            }

            const padding = 30; // Links + rechts + Reserve
            const finalWidth = maxWidth + padding;

            for (t of texts) {
                const action = getActionForText(t);
                const item = createMenuItem(t, action, finalWidth);
                addItem(item);
            }

            width = finalWidth; // 👈 Menübreite explizit setzen
        }

        function getActionForText(text) {
            switch (text) {
                case "Bild entfernen":
                    return "uebungModel.setProperty(rowIndex, roleName, \"\")";
                case "Bild austauschen":
                    return "openFileDialog()";
                case "Bild bearbeiten":
                     return "imageContextMenu.startSequentialImageEditing('" + imageContextMenu.roleName + "')";
                case "Bild hinzufügen":
                    return "openFileDialog()";
                default:
                    return "";
            }
        }


        function createMenuItem(text, action, itemWidth) {
            return Qt.createQmlObject(`
                import QtQuick.Controls 2.15
                MenuItem {
                    text: "${text}"
                    width: ${itemWidth}
                    onTriggered: {
                        ${action}
                    }
                }
            `, imageContextMenu);
        }

        function startSequentialImageEditing(role) {
            const allIndices = listView.selectedIndices.filter(i => i >= 0);
            let validIndices;

            if (allIndices.length === 0) {
                // 👉 Kein Eintrag markiert → verwende nur die aktuell geklickte Zeile
                if (imageContextMenu.rowIndex < 0 || imageContextMenu.rowIndex >= uebungModel.count) {
                    console.warn("❌ Ungültiger rowIndex");
                    return;
                }

                const fileName = uebungModel.get(imageContextMenu.rowIndex)[role];
                if (!fileName || fileName.trim() === "") {
                    console.log("⚠️ Kein Bild vorhanden für diese Zeile");
                    return;
                }

                validIndices = [imageContextMenu.rowIndex];
            } else {
                // 👉 Mehrere markierte Zeilen
                validIndices = allIndices.filter(i => {
                    const fileName = uebungModel.get(i)[role];
                    return fileName && fileName.trim() !== "";
                });

                if (validIndices.length === 0) {
                    console.log("⚠️ Keine gültigen Einträge zur Bearbeitung");
                    return;
                }
            }

            let current = 0;

            function editNext() {
                if (current >= validIndices.length) {
                    console.log("✅ Alle Bilder bearbeitet.");
                    return;
                }

                const index = validIndices[current];
                const fileName = uebungModel.get(index)[role];
                const fullPath = packagePath + "/" + fileName;
                const sanitizedPath = fullPath.replace(/\\/g, '/');

                const win = imageProcessingComponent.createObject(dialogWindow);

                let excludeRect = (role === "imagefileFrage") ? uebungModel.get(index).excludeAereaFra
                                                               : uebungModel.get(index).excludeAereaAnt;

                let arrowData = (role === "imagefileFrage") ? uebungModel.get(index).arrowDescFra
                                                            : uebungModel.get(index).arrowDescAnt;

                win.openWithImage("file:///" + sanitizedPath,
                                  Screen.desktopAvailableWidth,
                                  Screen.desktopAvailableHeight,
                                  excludeRect,
                                  arrowData);

                win.accepted.connect(function(resultJson) {
                    const result = JSON.parse(resultJson);
                    const excludeData = result.excludeData;
                    const arrowData = result.arrowData;

                    if (role === "imagefileFrage") {
                        uebungModel.setProperty(index, "excludeAereaFra", excludeData);
                        uebungModel.setProperty(index, "arrowDescFra", arrowData);
                    } else {
                        uebungModel.setProperty(index, "excludeAereaAnt", excludeData);
                        uebungModel.setProperty(index, "arrowDescAnt", arrowData);
                    }

                    saveCurrentModelToXml();
                    current++;
                    editNext();
                });

                win.rejected.connect(function() {
                    console.log("🚫 Bildbearbeitung vom Benutzer abgebrochen bei Index", index);
                    // ❗️Keine weiteren Schritte – Kette wird gestoppt.
                });
            }

            editNext();
        }
   }

   Menu {
        id: urlContextMenu
        property string roleName
        property int rowIndex
        property string dynamicMenuText: "Alle markierten Webseiten anzeigen"  // Standardtext

        FontMetrics {
            id: urlMenuFontMetrics
        }

        function adjustWidth() {
            let maxTextWidth = 0;
            for (let i = 0; i < urlContextMenu.count; ++i) {
                const item = itemAt(i);
                if (item && item.text) {
                    const width = urlMenuFontMetrics.boundingRect(item.text).width;
                    maxTextWidth = Math.max(maxTextWidth, width);
                }
            }
            const padding = 15;
            width = maxTextWidth + padding;
        }

        MenuItem {
            text: urlContextMenu.dynamicMenuText
            onTriggered: {
                urlContextMenu.startSequentialUrlEditing(urlContextMenu.roleName);
            }
        }        MenuItem {
            onTriggered: {
                const url = uebungModel.get(urlContextMenu.rowIndex)[urlContextMenu.roleName];
                checkWebsite(url, urlContextMenu.rowIndex, urlContextMenu.roleName);
            }
            text: "Check Website"
        }

        function startSequentialUrlEditing(role) {
            const allIndices = listView.selectedIndices.filter(i => i >= 0);
            let validIndices;

            if (allIndices.length === 0) {
                if (urlContextMenu.rowIndex < 0 || urlContextMenu.rowIndex >= uebungModel.count) {
                    console.warn("❌ Ungültiger rowIndex");
                    return;
                }

                const url = uebungModel.get(urlContextMenu.rowIndex)[role];
                if (!url || url.trim() === "") {
                    console.log("⚠️ Kein URL-Wert vorhanden");
                    return;
                }

                validIndices = [urlContextMenu.rowIndex];
            } else {
                validIndices = allIndices.filter(i => {
                    const url = uebungModel.get(i)[role];
                    return url && url.trim() !== "";
                });

                if (validIndices.length === 0) {
                    console.log("⚠️ Keine gültigen URLs");
                    return;
                }
            }

            let current = 0;

            function editNext() {
                if (current >= validIndices.length) {
                    console.log("✅ Alle URLs bearbeitet.");
                    return;
                }

                const index = validIndices[current];
                const url = uebungModel.get(index)[role] || "";
                const extraProp = (role === "infoURLFrage")
                                  ? uebungModel.get(index).frageSubjekt
                                  : uebungModel.get(index).antwortSubjekt;

                const component = Qt.createComponent("qrc:/MemoryPackagesBuilder/URLComponentProcessing.qml");

                if (component.status === Component.Ready) {
                    const win = component.createObject(null, {
                        urlString: url,
                        subjektName: extraProp,
                        packagePath: packagePath,
                        isMultiEdit: true,
                        multiEditCurrentIndex: current,
                        multiEditCount: validIndices.length,
                        isLastStep: current === validIndices.length - 1 // 👈 wichtig
                    });

                    if (!win) {
                        console.warn("❌ Fehler beim Erstellen des Dialogfensters.");
                        return;
                    }

                    win.accepted.connect(function(newUrl, licenceInfo, savedFileExtension) {
                        uebungModel.setProperty(index, role, newUrl);

                        const prefix = (role === "infoURLFrage") ? "imageFrage"
                                     : (role === "infoURLAntwort") ? "imageAntwort" : null;

                        if (licenceInfo) {
                            uebungModel.setProperty(index, prefix + "Author",
                                licenceInfo.authorName + "[" + licenceInfo.authorUrl + "]");

                            uebungModel.setProperty(index, prefix + "Lizenz",
                                licenceInfo.licenceName + "[" + licenceInfo.licenceUrl + "]");

                            uebungModel.setProperty(index, prefix + "BildDescription",
                                licenceInfo.imageDescriptionUrl);

                        }
                        if (prefix) {
                            const imageFileKey = (prefix === "imageFrage") ? "imagefileFrage" : "imagefileAntwort";
                            let currentFileName = uebungModel.get(index)[imageFileKey];
                            const subjectKey = (prefix === "imageFrage") ? "frageSubjekt" : "antwortSubjekt";
                            const subjectValue = uebungModel.get(index)[subjectKey] || "";

                            if (currentFileName && currentFileName.trim() !== "") {
                                const baseName = currentFileName.substring(0, currentFileName.lastIndexOf("."));
                                const currentExt = currentFileName.split(".").pop().toLowerCase();
                                if (currentExt !== savedFileExtension.toLowerCase()) {
                                    const newName = baseName + "." + savedFileExtension;
                                    uebungModel.setProperty(index, imageFileKey, newName);
                                }
                            } else {
                                const newName = subjectValue.trim() + "." + savedFileExtension;
                                uebungModel.setProperty(index, imageFileKey, newName);
                            }
                        }
                        saveCurrentModelToXml();
                        current++;
                        editNext();
                    });
                    win.continueRequested.connect(function() {
                        current++;
                        editNext();
                    });
                    win.rejected.connect(function() {
                        console.log("🚫 Bearbeitung abgebrochen bei Index", index);
                        // ❗️ Kette hier nicht fortsetzen
                    });

                    win.show();

                } else {
                    console.warn("❌ Fehler beim Laden:", component.errorString());
                }
            }

            editNext();
        }
    }

    function checkWebsite(url, rowIndex, roleName) {
        // Prüfen ob die Zeile noch existiert
        if (rowIndex < 0 || rowIndex >= uebungModel.count) {
            console.warn("Ungültiger Index:", rowIndex);
            return;
        }

        // Temporäre Kopie für die Closure erstellen
        let currentRow = rowIndex;
        let currentRole = roleName;
        // 🔶 Status: Gelb für "wird geprüft"
        const colorKey = roleName + "_bgcolor";
        uebungModel.setProperty(rowIndex, colorKey, "yellow");

        let xhr = new XMLHttpRequest();
        xhr.open("HEAD", url, true);
        xhr.timeout = 5000;

        xhr.onreadystatechange = function() {
            // Prüfen ob Zeile noch existiert
            if (currentRow >= uebungModel.count) return;
            console.log("xhr.readyState",xhr.readyState)
            if (xhr.readyState === XMLHttpRequest.DONE) {
                let success = (xhr.status >= 200 && xhr.status < 400);
                let color = success ? "#ccffcc" : "#ffcccc";  // hellgrün / hellrot
                uebungModel.setProperty(currentRow, colorKey, color);
                console.log(success ? "✅ erreichbar:" : "❌ nicht erreichbar:", url);
            }
        };

        xhr.onerror = function() {
            if (currentRow < uebungModel.count) {
                console.warn("⚠️ Fehler beim Prüfen:", url);
                uebungModel.setProperty(currentRow, colorKey, "#ffdddd");
            }
        };

        xhr.ontimeout = function() {
            if (currentRow < uebungModel.count) {
                console.warn("⏰ Timeout bei:", url);
                uebungModel.setProperty(currentRow, colorKey, "#ffdddd");
            }
        };

        try {
            xhr.send();
        } catch (e) {
            if (currentRow < uebungModel.count) {
                console.warn("❌ Ausnahme bei:", url, e);
                uebungModel.setProperty(currentRow, colorKey, "#ffdddd");
            }
        }
    }

    function saveCurrentModelToXml() {
        var data = {
            name: uebungenNameField.text,
            frageText: frageTextField.text,
            frageTextUmgekehrt: frageTextUmgekehrtField.text,
            sequentiell: sequentiellCheckBox.checked,
            umgekehrt: umgekehrtCheckBox.checked,
            hideAuthorByQuestion: hideAuthorByQuestionCheckBox.checked, // neu
            uebungsliste: []
        };

        for (var i = 0; i < uebungModel.count; ++i) {
            let eintrag = JSON.parse(JSON.stringify(uebungModel.get(i)));
            delete eintrag[""];
            data.uebungsliste.push(eintrag);
        }

        const result = ExersizeLoader.savePackage(packagePath, data);
        if (result) {
            console.log("💾 Änderungen in XML gespeichert.");
        } else {
            console.warn("❌ Fehler beim Speichern.");
        }
    }

    Item {
        id: windowContent
        anchors.fill: parent
    }

    Canvas {
        id: circleCanvas
        anchors.fill: parent
        visible: showCircles
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (!showCircles) return;

            ctx.strokeStyle = "red";
            ctx.lineWidth = 2;

            ctx.beginPath();
            ctx.arc(centerX, centerY, innerRadius, 0, 2 * Math.PI);
            ctx.stroke();

            ctx.beginPath();
            ctx.arc(centerX, centerY, outerRadius, 0, 2 * Math.PI);
            ctx.stroke();
        }

        property bool showCircles: false
        property real centerX: 0
        property real centerY: 0
        property real innerRadius: 0
        property real outerRadius: 0
    }

    Component {
        id: columnEditor
        Item {
            id: columnItemId
            property string roleName
            property int rowIndex

            // Guard gegen Ping-Pong bei programmatischen Updates
            property bool _updatingFromModel: false

            // vom Loader befüllt
            property string bgColor: "white"
            property string textVal: ""

            height: 40

            TextField {
                id: textField
                anchors.centerIn: parent
                height: parent.height * 0.8

                // Breite für 4 Ziffern dynamisch
                FontMetrics { id: fm; font: textField.font }
                readonly property int fourDigitWidth: Math.ceil(fm.boundingRect("8888").width) + 12

                // Nummer-Spalte schmaler, Rest ~90%
                width: columnItemId.roleName === "nummer"
                       ? Math.min(parent.width * 0.9, Math.max(48, fourDigitWidth))
                       : parent.width * 0.9

                // Datenbindung (zweirichtig); Guard verhindert Echo zurück
                text: columnItemId.textVal

                IntValidator { id: nummerValidator; bottom: 0; top: 100000000 }
                validator: columnItemId.roleName === "nummer" ? nummerValidator : null
                horizontalAlignment: columnItemId.roleName === "nummer" ? Text.AlignRight : Text.AlignLeft
                inputMethodHints: columnItemId.roleName === "nummer" ? Qt.ImhDigitsOnly : Qt.ImhNone

                background: Rectangle {
                    radius: 3
                    border.color: textField.activeFocus ? "blue" : "#ccc"
                    color: columnItemId.bgColor
                }

                onTextChanged: {
                    if (columnItemId._updatingFromModel) return;
                    if (columnItemId.rowIndex < 0 || columnItemId.rowIndex >= uebungModel.count) return;

                    if (columnItemId.roleName === "nummer") {
                        var n = parseInt(text, 10);
                        if (!Number.isFinite(n)) n = 0;
                        if (uebungModel.get(columnItemId.rowIndex).nummer !== n)
                            uebungModel.setProperty(columnItemId.rowIndex, "nummer", n);
                    } else {
                        var modelVal = uebungModel.get(columnItemId.rowIndex)[columnItemId.roleName] || "";
                        if (text !== modelVal)
                            uebungModel.setProperty(columnItemId.rowIndex, columnItemId.roleName, text);

                        if (columnItemId.roleName === "infoURLFrage" || columnItemId.roleName === "infoURLAntwort") {
                            const colorKey = columnItemId.roleName + "_bgcolor";
                            uebungModel.setProperty(columnItemId.rowIndex, colorKey, "white");
                        }
                    }
                }

                // ===== RECHTSKLICK-KONTEXTMENÜS (wie bei dir, nur robust auf columnItemId referenziert) =====
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    enabled: true
                    propagateComposedEvents: true

                    onPressed: function(mouse) {
                        if (mouse.button !== Qt.RightButton) {
                            mouse.accepted = false;
                            return;
                        }
                        var role = columnItemId.roleName;

                        if (role === "infoURLFrage" || role === "infoURLAntwort") {
                            openContextMenu(urlContextMenu, role, columnItemId.rowIndex, mouse);
                        } else if (role === "imagefileFrage" || role === "imagefileAntwort") {
                            openContextMenu(imageContextMenu, role, columnItemId.rowIndex, mouse, true);
                        } else {
                            mouse.accepted = false;
                        }
                    }

                    function openContextMenu(menu, roleName, rowIndex, mouse, isImage) {
                        menu.roleName = roleName;
                        menu.rowIndex = rowIndex;

                        const selected = listView.selectedIndices.filter(i => i >= 0);
                        if (menu === urlContextMenu && menu.adjustWidth) {
                            menu.dynamicMenuText = selected.length === 0
                                ? "Webseite anzeigen"
                                : "Alle markierten Webseiten anzeigen";
                            menu.adjustWidth();
                        }

                        const globalPos = mapToItem(windowContent, mouse.x, mouse.y);
                        menu.x = globalPos.x;
                        menu.y = globalPos.y;

                        if (isImage && menu.buildMenu) menu.buildMenu();

                        menu.open();
                        mouse.accepted = true;
                    }
                }
            }
        }
    }

    ListModel {
        id: uebungModel
    }

    Component.onCompleted: {
        if (packagePath) {
            uebungenData = ExersizeLoader.loadPackage(packagePath);
            uebungenNameField.text = uebungenData.name;
            frageTextField.text = uebungenData.frageText;
            frageTextUmgekehrtField.text = uebungenData.frageTextUmgekehrt;
            sequentiellCheckBox.checked = !!uebungenData.sequentiell;
            umgekehrtCheckBox.checked = !!uebungenData.umgekehrt;
            hideAuthorByQuestionCheckBox.checked = !!uebungenData.hideAuthorByQuestion; // neu

            uebungModel.clear();

            for (var i = 0; i < uebungenData.uebungsliste.length; ++i) {
                let eintrag = JSON.parse(JSON.stringify(uebungenData.uebungsliste[i]));
                // ✅ Neue Farb-            // ✅ hier fügst du die Defaults ein:
                if (!("nummer" in eintrag)) {
                    eintrag.nummer = i + 1; // Fallback, falls Parser das Attribut noch nicht liefert
                }
                if (!("hideAuthor" in eintrag)) {
                    eintrag.hideAuthor = false;
                }
                if (!("infoURLFrage_bgcolor" in eintrag)) {
                    eintrag.infoURLFrage_bgcolor = "white"; // oder dein Standard
                }
                if (!("infoURLAntwort_bgcolor" in eintrag)) {
                    eintrag.infoURLAntwort_bgcolor = "white";
                }
                if (!("selected" in eintrag)) {
                    eintrag.selected = false;
                }
                uebungModel.append(eintrag);
            }
        }

        // Dynamische Breite berechnen (mindestens 900px)
        const colWidth = 150;
        const spacing = columnSpacing;
        const total = columnCount * colWidth + (columnCount - 1) * spacing;

        dialogWindow.width = Math.max(total + 60, 900);  // etwas Puffer für Ränder
        dialogWindow.height = 600;

        listView.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Obere Eingabefelder
        GroupBox {
            title: "Uebungen Eigenschaften"
            Layout.fillWidth: true
            padding: 10

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                RowLayout {
                    Label { text: "Name:"; Layout.preferredWidth: labelWidth }
                    TextField { id: uebungenNameField; Layout.preferredWidth: 300 }
                }

                RowLayout {
                    Label { text: "Fragetext:"; Layout.preferredWidth: labelWidth }
                    TextField { id: frageTextField; Layout.preferredWidth: 600 }
                }

                RowLayout {
                    Label { text: "Fragetext umgekehrt:"; Layout.preferredWidth: labelWidth }
                    TextField { id: frageTextUmgekehrtField; Layout.fillWidth: true }
                }

                // << geändert: HideAuthorByQuestion neben Sequentiell >>
                RowLayout {
                    Label { text: "Sequentiell:"; Layout.preferredWidth: labelWidth }
                    CheckBox { id: sequentiellCheckBox }

                    Item { width: 24; height: 1 } // kleiner Abstand

                    Label { text: "HideAuthorByQuestion:" }
                    CheckBox {
                        id: hideAuthorByQuestionCheckBox
                        checked: false // Default
                    }
                }

                RowLayout {
                    Label { text: "Umgekehrt:"; Layout.preferredWidth: labelWidth }
                    CheckBox { id: umgekehrtCheckBox }
                }
            }
        }

        // Listenbereich
        GroupBox {
            title: "Übungsliste"
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: listArea
                anchors.fill: parent

                // Breite für 4 Ziffern + etwas Padding (dynamisch per FontMetrics)
                FontMetrics { id: numFM }
                property real numColWidth: Math.max(56, numFM.boundingRect("8888").width + 16)

                // übrige Spalten (Minimum)
                property real columnWidth: 150
                property real totalContentWidth: 0

                onWidthChanged: recalcWidths()
                Component.onCompleted: recalcWidths()

                function recalcWidths() {
                    const restCols = columnCount - 1
                    const spacing  = columnSpacing * (columnCount - 1)
                    const restWidth = Math.max(0, width - numColWidth - spacing)
                    columnWidth = Math.max(150, restWidth / restCols)
                    totalContentWidth = numColWidth + restCols * columnWidth + spacing
                }
                // Kopfzeile
                Rectangle {
                    id: header
                    height: 40
                    width: parent.width
                    anchors.top: parent.top
                    color: "#dddddd"

                    Row {
                        anchors.fill: parent
                        spacing: columnSpacing

                        Repeater {
                            model: ["Nummer","FrageSubjekt","AntwortSubjekt","SubjektPrefixFrage",
                                    "SubjektPrefixAntwort","ImagefileFrage","ImagefileAntwort",
                                    "InfoURLFrage","InfoURLAntwort"]

                            Item {
                                width: (index === 0 ? listArea.numColWidth : listArea.columnWidth)
                                height: parent.height

                                Label {
                                    // statt fester Breite relative nehmen, damit es auch in der schmalen Spalte passt
                                    width: parent.width * 0.9
                                    height: parent.height * 0.8
                                    anchors.centerIn: parent
                                    text: modelData
                                    horizontalAlignment: Text.AlignLeft
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    font.bold: true
                                    color: "#333"
                                }
                            }
                        }
                    }
                }

                // Liste
                MultiSelectListView {
                    id: listView
                    anchors.top: header.bottom
                    anchors.left: parent.left
                    width: listArea.totalContentWidth
                    anchors.bottom: parent.bottom
                    clip: true
                    modelData: uebungModel
                    currentIndex: -1
                    interactive: true
                    focus: true
                    spacing: 0
                    flickableDirection: Flickable.VerticalFlick | Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.horizontal: ScrollBar {}
                    ScrollBar.vertical: ScrollBar {}

                    // 👇 NEU: Scroll-Verhinderung bei gezieltem currentIndex-Setzen
                    property bool blockedPositioning: false

                    Component.onCompleted: forceActiveFocus()

                    delegate: Rectangle {
                        id: delegateRoot
                        property int indexOutside: index
                        property bool selected: model.selected
                        width: listArea.totalContentWidth
                        height: 40

                        color: selected ? "#cce5ff" : (indexOutside % 2 === 0 ? "#f9f9f9" : "#ffffff")
                        border.color: listView.currentIndex === indexOutside ? "blue" : "transparent"
                        border.width: 1

                        function handleDoubleClick(index) {
                            console.log("Doubleclick für Zeile:", index);
                            if (listView.currentIndex >= 0) {
                                editExersizeDialog.itemData = JSON.parse(JSON.stringify(uebungModel.get(listView.currentIndex)));
                                editExersizeDialog.open();
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            propagateComposedEvents: true
                            preventStealing: true

                            onPressed: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    const globalPos = mapToItem(windowContent, mouse.x, mouse.y);
                                    rowContextMenu.x = globalPos.x;
                                    rowContextMenu.y = globalPos.y;
                                    rowContextMenu.open();
                                    mouse.accepted = true;
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: function(mouse) {
                                const clickedIndex = indexOutside;
                                listView.currentListViewIndex = clickedIndex;
                                listView.currentIndex = clickedIndex;
                                listView.forceActiveFocus();

                                if (mouse.modifiers & Qt.ShiftModifier) {
                                    if (listView.selectionAnchor === -1)
                                        listView.selectionAnchor = listView.currentListViewIndex;
                                    listView.selectRange(listView.selectionAnchor, clickedIndex, mouse.modifiers & Qt.ControlModifier);
                                } else if (mouse.modifiers & Qt.ControlModifier) {
                                    listView.toggleSelection(clickedIndex);
                                } else {
                                    listView.selectedIndices = [clickedIndex];
                                    listView.selectionAnchor = clickedIndex;
                                }
                                listView.updateSelectedItems();
                            }
                            onDoubleClicked: function(mouse) {
                                handleDoubleClick(indexOutside);
                                mouse.accepted = true;
                            }
                        }

                        Row {
                            anchors.fill: parent
                            spacing: columnSpacing

                            Repeater {
                                model: ["nummer","frageSubjekt","antwortSubjekt","subjektPrefixFrage",
                                        "subjektPrefixAntwort","imagefileFrage","imagefileAntwort",
                                        "infoURLFrage","infoURLAntwort"]

                                Item {
                                    width: (index === 0 ? listArea.numColWidth : listArea.columnWidth)
                                    height: parent.height

                                    // ===================== Loader im Delegate =====================
                                    Loader {
                                        id: loaderId
                                        anchors.fill: parent
                                        property string roleName: modelData
                                        property int rowIndex: indexOutside
                                        sourceComponent: columnEditor

                                        function refreshFromModel() {
                                            if (!item) return;
                                            const rec = (rowIndex >= 0 && rowIndex < uebungModel.count) ? uebungModel.get(rowIndex) : null;
                                            const bgKey = roleName + "_bgcolor";

                                            item._updatingFromModel = true; // Guard ein
                                            item.bgColor = (rec && rec[bgKey]) || "white";
                                            const v = rec ? rec[roleName] : "";
                                            item.textVal = (v === undefined || v === null) ? "" : String(v);
                                            item._updatingFromModel = false; // Guard aus
                                        }

                                        onLoaded: {
                                            // Kritisch: dynamische Bindungen, damit Delegate-Recycling korrekt wirkt
                                            item.roleName = Qt.binding(() => loaderId.roleName);
                                            item.rowIndex = Qt.binding(() => loaderId.rowIndex);
                                            refreshFromModel();
                                        }

                                        onRoleNameChanged: refreshFromModel()
                                        onRowIndexChanged:  refreshFromModel()

                                        Connections {
                                            target: uebungModel
                                            function onDataChanged(changedIndex, roles) {
                                                const realIndex = (typeof changedIndex === "object" && typeof changedIndex.row === "number")
                                                                  ? changedIndex.row : changedIndex;
                                                if (realIndex !== loaderId.rowIndex || !loaderId.item) return;

                                                // Optional: nur reagieren, wenn unsere Rolle (oder deren _bgcolor) betroffen ist
                                                if (roles && roles.length &&
                                                    roles.indexOf(loaderId.roleName) === -1 &&
                                                    roles.indexOf(loaderId.roleName + "_bgcolor") === -1)
                                                    return;

                                                loaderId.refreshFromModel();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // Button-Zeile
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Linksbündige Buttons
            RowLayout {
                Layout.alignment: Qt.AlignLeft
                spacing: 10

                Button {
                    text: "Bearbeiten"
                    icon.name: "edit"
                    onClicked: {
                        if (listView.currentIndex >= 0) {
                            editExersizeDialog.itemData = JSON.parse(JSON.stringify(uebungModel.get(listView.currentIndex)));
                            editExersizeDialog.open();
                        }
                    }
                }
                Button {
                    text: "Hinzufügen"
                    onClicked: {
                        // optional: automatisch nächste freie Nummer
                        var maxNum = -1;
                        for (var i = 0; i < uebungModel.count; ++i) {
                            var n = Number(uebungModel.get(i).nummer);
                            if (Number.isFinite(n) && n > maxNum) maxNum = n;
                        }
                        uebungModel.append({ nummer: maxNum + 1 });
                    }
                }
                Button {
                    text: "Löschen"
                    onClicked: requestDeleteSelectedRows()
                }
                Button {
                    text: "Check Websites"
                    onClicked: {
                        for (let i = 0; i < uebungModel.count; i++) {
                            ["infoURLFrage", "infoURLAntwort"].forEach(function(role) {
                                let url = uebungModel.get(i)[role];
                                if (url && url.trim() !== "") {
                                    checkWebsite(url, i, role);
                                }
                            });
                        }
                    }
                }
                Button {
                    text: "Zeige doppelte Zeilen"
                    onClicked: showDuplicateRowsByFrageSubjekt()
                }
            }

            // Spacer in der Mitte
            Item { Layout.fillWidth: true }

            // Rechtsbündige Buttons
            Button {
                text: "Speichern"
                icon.name: "save"
                onClicked: {
                    var data = {
                        name: uebungenNameField.text,
                        frageText: frageTextField.text,
                        frageTextUmgekehrt: frageTextUmgekehrtField.text,
                        sequentiell: sequentiellCheckBox.checked,
                        umgekehrt: umgekehrtCheckBox.checked,
                        hideAuthorByQuestion: hideAuthorByQuestionCheckBox.checked, // neu
                        uebungsliste: []
                    }

                    for (var i = 0; i < uebungModel.count; ++i) {
                        let eintrag = JSON.parse(JSON.stringify(uebungModel.get(i)));
                        delete eintrag[""];
                        data.uebungsliste.push(eintrag);
                    }

                    console.log("📦 Zu speichernde Daten:", JSON.stringify(data, null, 2));

                    const result = ExersizeLoader.savePackage(packagePath, data);
                    if (!result) {
                        console.warn("❌ Speichern fehlgeschlagen!");
                    } else {
                        console.log("✅ Speichern erfolgreich.");
                        dialogWindow.close();
                    }
                }
            }

            Button {
                enabled: true
                text: "Neu anlegen"
                onClicked: csvFileDialog.open()
            }
            Button {
                enabled: true
                text: "Import aus CSV"
                onClicked: csvImportDialog.open()
            }
        }
    }

}
