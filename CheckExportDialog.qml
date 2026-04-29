import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import QtWebEngine 1.9

import ExersizeLoader 1.0
import FileHelper 1.0

Window {
    id: root
    title: packageName !== "" ? "Pr\u00fcfen/Exportieren - " + packageName : "Pr\u00fcfen/Exportieren"
    visible: false
    modality: Qt.ApplicationModal

    property string packageName: ""
    property string packagePath: ""
    property var units: []
    property int currentExerciseIndex: 0
    property int currentUnitIndex: 0
    property bool reversePreview: false
    property string webUrl: ""
    readonly property var currentUnit: units.length > 0 ? units[currentUnitIndex] : ({ exercises: [] })
    readonly property var currentExercises: currentUnit.exercises || []
    readonly property var currentExercise: currentExercises.length > 0 ? currentExercises[currentExerciseIndex] : ({})

    width: Math.min(1460, Screen.desktopAvailableWidth * 0.98)
    height: Math.min(1080, Screen.desktopAvailableHeight * 0.96)
    minimumWidth: 1120
    minimumHeight: 820

    function open() {
        show()
        raise()
        requestActivate()
    }

    function packageFileSortValue(fileName) {
        if (fileName.toLowerCase() === "package.xml")
            return 0

        const match = /^package_(\d+)\.xml$/i.exec(fileName)
        return match ? parseInt(match[1], 10) : 9999
    }

    function loadExercises() {
        if (packagePath === "")
            return

        let files = FileHelper.directoryEntries(packagePath).filter(function(fileName) {
            return /^package(_\d+)?\.xml$/i.test(fileName)
        })

        files.sort(function(a, b) {
            return packageFileSortValue(a) - packageFileSortValue(b)
        })

        let loadedUnits = []
        for (let i = 0; i < files.length; ++i) {
            const xmlPath = packagePath + "/" + files[i]
            const data = ExersizeLoader.loadPackage(xmlPath)
            if (!data || !data.uebungsliste)
                continue

            const list = data.uebungsliste
            let unitExercises = []
            for (let j = 0; j < list.length; ++j) {
                let exercise = {}
                for (let key in list[j])
                    exercise[key] = list[j][key]
                exercise.sourceXml = files[i]
                unitExercises.push(exercise)
            }

            unitExercises.sort(function(a, b) {
                return Number(a.nummer || 0) - Number(b.nummer || 0)
            })

            loadedUnits.push({
                fileName: files[i],
                title: "Einheit_" + String(i + 1).padStart(2, "0"),
                name: data.name || packageName,
                frageType: data.frageType || "",
                sequentiell: data.sequentiell || false,
                umgekehrt: data.umgekehrt || false,
                hideAuthorByQuestion: data.hideAuthorByQuestion || false,
                frageText: data.frageText || "",
                frageTextUmgekehrt: data.frageTextUmgekehrt || "",
                exercises: unitExercises
            })
        }

        units = loadedUnits
        currentUnitIndex = 0
        currentExerciseIndex = 0
        reversePreview = false
    }

    function switchUnit(index) {
        if (index < 0 || index >= units.length)
            return

        currentUnitIndex = index
        currentExerciseIndex = 0
        reversePreview = false
    }

    function imageUrl(fileName) {
        if (!fileName || packagePath === "")
            return ""

        const normalized = (packagePath + "/" + fileName).replace(/\\/g, "/")
        return "file:///" + normalized
    }

    function parseExcludeAreas(value) {
        if (!value || typeof value !== "string" || !value.trim())
            return []

        const result = []
        const entries = value.split("|")
        for (let i = 0; i < entries.length; ++i) {
            const parts = entries[i].split(",")
            if (parts.length < 5)
                continue

            const x = parseFloat(parts[0])
            const y = parseFloat(parts[1])
            const w = parseFloat(parts[2])
            const h = parseFloat(parts[3])
            const rotation = parseFloat(parts[4])
            if (!Number.isFinite(x) || !Number.isFinite(y) ||
                !Number.isFinite(w) || !Number.isFinite(h) ||
                !Number.isFinite(rotation))
                continue

            let color = "black"
            if (parts.length > 5 && parts[5].trim() !== "")
                color = parts[5].trim()

            let isBackgroundRectancle = false
            if (parts.length > 6) {
                const flag = parts[6].trim().toLowerCase()
                isBackgroundRectancle = flag === "1" || flag === "true" || flag === "yes"
            }

            result.push({
                x: x,
                y: y,
                width: w,
                height: h,
                rotation: rotation,
                color: color,
                isBackgroundRectancle: isBackgroundRectancle
            })
        }
        return result
    }

    function parseArrows(value) {
        if (!value || typeof value !== "string" || !value.trim())
            return []

        const result = []
        const entries = value.split("|")
        for (let i = 0; i < entries.length; ++i) {
            const parts = entries[i].split(",")
            if (parts.length < 5)
                continue

            const x = parseFloat(parts[0])
            const y = parseFloat(parts[1])
            const rotation = parseFloat(parts[2])
            const scale = parseFloat(parts[4])
            if (!Number.isFinite(x) || !Number.isFinite(y) || !Number.isFinite(rotation))
                continue

            result.push({
                x: x,
                y: y,
                rotation: rotation,
                color: parts[3] && parts[3].trim() !== "" ? parts[3].trim() : "red",
                scaleFactor: Number.isFinite(scale) && scale > 0 ? scale : 1.0
            })
        }
        return result
    }

    function isValidUrl(value) {
        return extractUrl(value) !== ""
    }

    function decodeHtmlEntities(value) {
        if (!value || typeof value !== "string")
            return ""

        return value.replace(/&amp;/gi, "&")
                    .replace(/&quot;/gi, "\"")
                    .replace(/&#39;/gi, "'")
                    .replace(/&lt;/gi, "<")
                    .replace(/&gt;/gi, ">")
    }

    function normalizeWebUrl(value) {
        if (!value || typeof value !== "string")
            return ""

        let url = decodeHtmlEntities(value).trim()
        if (url === "")
            return ""

        if (url.indexOf("//") === 0)
            url = "https:" + url
        else if (url.indexOf("/wiki/") === 0)
            url = "https://en.wikipedia.org" + url
        else if (!/^https?:\/\//i.test(url))
            url = "https://" + url.replace(/^\/+/, "")

        url = url.replace(/\/wiki\/en:/i, "/wiki/")
        return url.replace(/\s/g, "%20")
    }

    function extractUrl(value) {
        if (!value || typeof value !== "string")
            return ""

        const text = decodeHtmlEntities(value)
        let match = /href\s*=\s*["']([^"']+)["']/i.exec(text)
        if (match && match[1])
            return normalizeWebUrl(match[1])

        match = /\[([^\]]+)\]\s*$/i.exec(text)
        if (match && match[1])
            return normalizeWebUrl(match[1])

        match = /(https?:\/\/[^\s"'<>[\]]+)/i.exec(text)
        if (match && match[1])
            return normalizeWebUrl(match[1])

        match = /(\/\/[^\s"'<>[\]]+)/i.exec(text)
        if (match && match[1])
            return normalizeWebUrl(match[1])

        match = /((?:www\.)?[a-z0-9.-]+\.[a-z]{2,}(?:\/[^\s"'<>[\]]*)?)/i.exec(text)
        return match && match[1] ? normalizeWebUrl(match[1]) : ""
    }

    function openWebUrl(value) {
        const url = extractUrl(value)
        if (url === "")
            return

        webUrl = url
        webPreviewWindow.show()
        webPreviewWindow.raise()
        webPreviewWindow.requestActivate()
    }

    function previousExercise() {
        if (currentExerciseIndex > 0) {
            currentExerciseIndex--
        }
    }

    function nextExercise() {
        if (currentExerciseIndex + 1 < currentExercises.length) {
            currentExerciseIndex++
        }
    }

    function checkCurrentExercise() {
        nextExercise()
    }

    function currentAnswerText() {
        return reversePreview ? (currentExercise.frageSubjekt || "") : (currentExercise.antwortSubjekt || "")
    }

    function currentQuestionText() {
        let text = reversePreview ? (currentUnit.frageTextUmgekehrt || "") : (currentUnit.frageText || "")
        if (text === "")
            return reversePreview ? (currentExercise.antwortSubjekt || "") : (currentExercise.frageSubjekt || "")

        text = text.replace("[FrageSubjekt]", reversePreview ? (currentExercise.antwortSubjekt || "") : (currentExercise.frageSubjekt || ""))
        text = text.replace("[AntwortSubjekt]", reversePreview ? (currentExercise.frageSubjekt || "") : (currentExercise.antwortSubjekt || ""))
        text = text.replace("[SubjektPrefixFrage]", reversePreview ? (currentExercise.subjektPrefixAntwort || "") : (currentExercise.subjektPrefixFrage || ""))
        text = text.replace("[SubjektPrefixAntwort]", reversePreview ? (currentExercise.subjektPrefixFrage || "") : (currentExercise.subjektPrefixAntwort || ""))
        return text.replace(/\s+/g, " ").trim()
    }

    function questionImageFile() {
        return reversePreview ? (currentExercise.imagefileAntwort || "") : (currentExercise.imagefileFrage || "")
    }

    function answerImageFile() {
        return reversePreview ? (currentExercise.imagefileFrage || "") : (currentExercise.imagefileAntwort || "")
    }

    function hasQuestionImage() {
        return questionImageFile() !== ""
    }

    function hasAnswerImage() {
        return answerImageFile() !== ""
    }

    function questionExcludeAreas() {
        return parseExcludeAreas(reversePreview ? currentExercise.excludeAereaAnt : currentExercise.excludeAereaFra)
    }

    function answerExcludeAreas() {
        return parseExcludeAreas(reversePreview ? currentExercise.excludeAereaFra : currentExercise.excludeAereaAnt)
    }

    function questionArrows() {
        return parseArrows(reversePreview ? currentExercise.arrowDescAnt : currentExercise.arrowDescFra)
    }

    function answerArrows() {
        return parseArrows(reversePreview ? currentExercise.arrowDescFra : currentExercise.arrowDescAnt)
    }

    function setCurrentExerciseField(fieldName, value) {
        if (currentExerciseIndex < 0 || currentExerciseIndex >= currentExercises.length)
            return

        let exercise = currentExercises[currentExerciseIndex]
        exercise[fieldName] = value
        currentExercises[currentExerciseIndex] = exercise
    }

    function saveCurrentUnit() {
        if (currentUnitIndex < 0 || currentUnitIndex >= units.length)
            return

        const unit = units[currentUnitIndex]
        const data = {
            name: unit.name || packageName,
            frageType: unit.frageType || "",
            frageText: unit.frageText || "",
            frageTextUmgekehrt: unit.frageTextUmgekehrt || "",
            sequentiell: !!unit.sequentiell,
            umgekehrt: !!unit.umgekehrt,
            hideAuthorByQuestion: !!unit.hideAuthorByQuestion,
            uebungsliste: unit.exercises || []
        }

        const xmlPath = packagePath + "/" + unit.fileName
        ExersizeLoader.savePackage(xmlPath, data)
    }

    Component.onCompleted: loadExercises()
    onPackagePathChanged: loadExercises()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        Label {
            text: root.packageName
            visible: root.packageName !== ""
            font.bold: true
            font.pointSize: 16
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Label {
            text: root.currentExercises.length > 0
                  ? (root.currentExerciseIndex + 1) + " / " + root.currentExercises.length + " \u00dcbungen"
                  : "0 \u00dcbungen"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: "#555555"
        }

        TabBar {
            id: unitTabs
            currentIndex: root.currentUnitIndex
            Layout.fillWidth: true
            visible: root.units.length > 1

            Repeater {
                model: root.units

                TabButton {
                    text: modelData.title
                    implicitWidth: 160
                    onClicked: root.switchUnit(index)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#f2f2f2"
            border.color: "#c8c8c8"
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1

                        Label {
                            text: root.currentUnit.frageType && root.currentUnit.frageType !== ""
                                  ? root.currentUnit.frageType
                                  : "Keine \u00dcbungen gefunden"
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: reverseOptionHeader.left
                            anchors.rightMargin: 8
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        CheckBox {
                            id: reverseOptionHeader
                            text: "Umgekehrt"
                            checked: root.reversePreview
                            visible: !!root.currentUnit.umgekehrt
                            onToggled: root.reversePreview = checked
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    PreviewImage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: parent.height * 0.58
                        caption: "Frage: " + root.currentQuestionText()
                        imageSource: root.imageUrl(root.questionImageFile())
                        excludeAreas: root.questionExcludeAreas()
                        arrows: root.questionArrows()
                    }

                    PreviewImage {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredHeight: parent.height * 0.58
                        caption: "Antwort: " + root.currentAnswerText()
                        imageSource: root.imageUrl(root.answerImageFile())
                        excludeAreas: root.answerExcludeAreas()
                        arrows: root.answerArrows()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 168 : 0
                    Layout.maximumHeight: visible ? 168 : 0
                    Layout.topMargin: visible ? 8 : 0
                    spacing: 10
                    visible: root.hasQuestionImage() || root.hasAnswerImage()

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        LicenseInfoBox {
                            anchors.fill: parent
                            title: "Lizenzinformationen Frage"
                            visible: root.hasQuestionImage()
                            urlLabel: "InfoURLFrage"
                            urlField: root.reversePreview ? "infoURLAntwort" : "infoURLFrage"
                            authorLabel: "ImageFrageAuthor"
                            authorField: root.reversePreview ? "imageAntwortAuthor" : "imageFrageAuthor"
                            licenseLabel: "ImageFrageLizenz"
                            licenseField: root.reversePreview ? "imageAntwortLizenz" : "imageFrageLizenz"
                            descriptionLabel: "ImageFrageBildDescription"
                            descriptionField: root.reversePreview ? "imageAntwortBildDescription" : "imageFrageBildDescription"
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1

                        LicenseInfoBox {
                            anchors.fill: parent
                            title: "Lizenzinformationen Antwort"
                            visible: root.hasAnswerImage()
                            urlLabel: "InfoURLAntwort"
                            urlField: root.reversePreview ? "infoURLFrage" : "infoURLAntwort"
                            authorLabel: "ImageAntwortAuthor"
                            authorField: root.reversePreview ? "imageFrageAuthor" : "imageAntwortAuthor"
                            licenseLabel: "ImageAntwortLizenz"
                            licenseField: root.reversePreview ? "imageFrageLizenz" : "imageAntwortLizenz"
                            descriptionLabel: "ImageAntwortBildDescription"
                            descriptionField: root.reversePreview ? "imageFrageBildDescription" : "imageAntwortBildDescription"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: "Zur\u00fcck"
                        enabled: root.currentExerciseIndex > 0
                        onClicked: root.previousExercise()
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: "Weiter"
                        enabled: root.currentExerciseIndex + 1 < root.currentExercises.length
                        onClicked: root.nextExercise()
                    }
                }
            }
        }
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "Pr\u00fcfen"
                highlighted: true
                focus: true
                enabled: root.currentExercises.length > 0
                onClicked: root.checkCurrentExercise()
            }

            Button {
                text: "Exportieren"
                onClicked: root.close()
            }

            Button {
                text: "Abbrechen"
                onClicked: root.close()
            }
        }
    }

    component PreviewImage: Item {
        id: previewRoot

        property url imageSource: ""
        property string caption: ""
        property var excludeAreas: []
        property var arrows: []
        property color previewBackgroundColor: "white"
        readonly property bool hasImage: imageSource.toString() !== ""

        Rectangle {
            anchors.fill: parent
            color: previewRoot.previewBackgroundColor
            border.color: "#d0d0d0"
            border.width: 1

            Label {
                id: previewCaption
                text: previewRoot.caption
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                font.bold: true
                elide: Text.ElideRight
            }

            Item {
                id: imageArea
                anchors.top: previewCaption.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                clip: true
                property color backgroundColor: previewRoot.previewBackgroundColor

                Image {
                    id: imagePreview
                    anchors.fill: parent
                    source: previewRoot.imageSource
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    asynchronous: true
                }

                Label {
                    anchors.centerIn: parent
                    width: parent.width * 0.8
                    text: "Kein Bild"
                    visible: !previewRoot.hasImage || imagePreview.status === Image.Error
                    color: "#777777"
                    font.bold: true
                    font.pointSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Item {
                    id: imageOverlay
                    anchors.fill: imagePreview
                    clip: true
                    visible: imagePreview.status === Image.Ready

                    property real scale: imagePreview.sourceSize.width > 0
                                         ? imagePreview.paintedWidth / imagePreview.sourceSize.width
                                         : 1
                    property real offsetX: (imagePreview.width - imagePreview.paintedWidth) / 2
                    property real offsetY: (imagePreview.height - imagePreview.paintedHeight) / 2

                    Repeater {
                        model: previewRoot.excludeAreas || []

                        Rectangle {
                            readonly property bool drawAsBackground: modelData.isBackgroundRectancle
                            x: imageOverlay.offsetX + modelData.x * imageOverlay.scale
                            y: imageOverlay.offsetY + modelData.y * imageOverlay.scale
                            width: Math.max(modelData.width * imageOverlay.scale, 1)
                            height: Math.max(modelData.height * imageOverlay.scale, 1)
                            rotation: modelData.rotation || 0
                            transformOrigin: Item.Center
                            antialiasing: false
                            color: drawAsBackground ? imageArea.backgroundColor : modelData.color
                            border.color: drawAsBackground ? imageArea.backgroundColor : "black"
                            border.width: drawAsBackground ? 0 : 2
                            z: 10
                        }
                    }

                    Repeater {
                        model: previewRoot.arrows || []

                        Item {
                            id: arrowItem
                            x: imageOverlay.offsetX + modelData.x * imageOverlay.scale
                            y: imageOverlay.offsetY + modelData.y * imageOverlay.scale
                            width: 96 * modelData.scaleFactor * imageOverlay.scale
                            height: 96 * modelData.scaleFactor * imageOverlay.scale
                            z: 20

                            transform: Rotation {
                                origin.x: arrowItem.width / 2
                                origin.y: arrowItem.height / 2
                                angle: modelData.rotation || 0
                            }

                            Image {
                                anchors.fill: parent
                                source: "qrc:/icons/arrow-right-" + (modelData.color || "red") + ".png"
                                fillMode: Image.Stretch
                                smooth: true
                            }
                        }
                    }
                }
            }
        }
    }

    component LicenseInfoBox: Item {
        id: licenseRoot

        property string title: ""
        property string urlLabel: ""
        property string urlField: ""
        property string authorLabel: ""
        property string authorField: ""
        property string licenseLabel: ""
        property string licenseField: ""
        property string descriptionLabel: ""
        property string descriptionField: ""
        property string savedUrl: ""
        property string savedAuthor: ""
        property string savedLicense: ""
        property string savedDescription: ""
        readonly property color boxColor: "#eef3fb"
        readonly property int fieldHeight: 22

        FontMetrics {
            id: licenseFontMetrics
        }

        function fieldValue(fieldName) {
            return root.currentExercise[fieldName] || ""
        }

        function updateField(fieldName, value) {
            root.setCurrentExerciseField(fieldName, value)
        }

        function commitFields() {
            updateField(urlField, urlFieldItem.text)
            updateField(authorField, authorFieldItem.text)
            updateField(licenseField, licenseFieldItem.text)
            updateField(descriptionField, descriptionFieldItem.text)
        }

        function refreshSavedValues() {
            savedUrl = fieldValue(urlField)
            savedAuthor = fieldValue(authorField)
            savedLicense = fieldValue(licenseField)
            savedDescription = fieldValue(descriptionField)
        }

        function hasChanges() {
            return urlFieldItem.text !== savedUrl ||
                   authorFieldItem.text !== savedAuthor ||
                   licenseFieldItem.text !== savedLicense ||
                   descriptionFieldItem.text !== savedDescription
        }

        Component.onCompleted: refreshSavedValues()

        Connections {
            target: root
            function onCurrentExerciseChanged() {
                Qt.callLater(licenseRoot.refreshSavedValues)
            }
            function onReversePreviewChanged() {
                Qt.callLater(licenseRoot.refreshSavedValues)
            }
        }

        Rectangle {
            anchors.fill: parent
            color: licenseRoot.boxColor
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: "#ffffff"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "#ffffff"
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: "#8f8f8f"
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: "#8f8f8f"
        }

        Rectangle {
            anchors.left: licenseTitle.left
            anchors.right: licenseTitle.right
            anchors.top: licenseTitle.top
            anchors.bottom: licenseTitle.bottom
            anchors.leftMargin: -4
            anchors.rightMargin: -4
            anchors.topMargin: -1
            anchors.bottomMargin: -1
            color: licenseRoot.boxColor
            z: 1
        }

        Label {
            id: licenseTitle
            text: licenseRoot.title
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: 10
            anchors.topMargin: -implicitHeight / 2
            font.bold: true
            font.italic: true
            z: 2
        }

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: licenseTitle.bottom
            anchors.margins: 8
            anchors.topMargin: Math.max(4, licenseFontMetrics.height / 2)
            spacing: Math.max(4, licenseFontMetrics.height / 2)

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: licenseRoot.urlLabel
                    Layout.preferredWidth: 165
                    font.bold: true
                    elide: Text.ElideRight
                }

                TextField {
                    id: urlFieldItem
                    text: licenseRoot.fieldValue(licenseRoot.urlField)
                    Layout.fillWidth: true
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    selectByMouse: true
                }

                SmallActionButton {
                    text: "\u00d6ffnen"
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    enabled: root.isValidUrl(urlFieldItem.text)
                    onClicked: {
                        root.openWebUrl(urlFieldItem.text)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: licenseRoot.authorLabel
                    Layout.preferredWidth: 165
                    font.bold: true
                    elide: Text.ElideRight
                }
                TextField {
                    id: authorFieldItem
                    text: licenseRoot.fieldValue(licenseRoot.authorField)
                    Layout.fillWidth: true
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    selectByMouse: true
                }
                SmallActionButton {
                    text: "\u00d6ffnen"
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    enabled: root.isValidUrl(authorFieldItem.text)
                    onClicked: {
                        root.openWebUrl(authorFieldItem.text)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: licenseRoot.licenseLabel
                    Layout.preferredWidth: 165
                    font.bold: true
                    elide: Text.ElideRight
                }
                TextField {
                    id: licenseFieldItem
                    text: licenseRoot.fieldValue(licenseRoot.licenseField)
                    Layout.fillWidth: true
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    selectByMouse: true
                }
                SmallActionButton {
                    text: "\u00d6ffnen"
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    enabled: root.isValidUrl(licenseFieldItem.text)
                    onClicked: {
                        root.openWebUrl(licenseFieldItem.text)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: licenseRoot.descriptionLabel
                    Layout.preferredWidth: 165
                    font.bold: true
                    elide: Text.ElideRight
                }
                TextField {
                    id: descriptionFieldItem
                    text: licenseRoot.fieldValue(licenseRoot.descriptionField)
                    Layout.fillWidth: true
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    selectByMouse: true
                }

                SmallActionButton {
                    text: "\u00d6ffnen"
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    enabled: root.isValidUrl(descriptionFieldItem.text)
                    onClicked: {
                        root.openWebUrl(descriptionFieldItem.text)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                SmallActionButton {
                    text: "\u00c4ndern"
                    Layout.preferredHeight: licenseRoot.fieldHeight
                    enabled: licenseRoot.hasChanges()
                    primary: true
                    onClicked: {
                        licenseRoot.commitFields()
                        root.saveCurrentUnit()
                        licenseRoot.refreshSavedValues()
                    }
                }
            }
        }
    }

    component SmallActionButton: Item {
        id: actionRoot

        property string text: ""
        property bool primary: false
        signal clicked()

        implicitWidth: Math.max(primary ? 78 : 58, actionLabel.implicitWidth + 18)
        implicitHeight: 24
        opacity: enabled ? 1.0 : 0.48

        Rectangle {
            anchors.fill: parent
            radius: 4
            border.width: 1
            border.color: actionRoot.enabled
                          ? (actionRoot.primary ? "#4f6f9f" : "#a9b8ca")
                          : "#c8c8c8"
            color: !actionRoot.enabled
                   ? "#f0f0f0"
                   : actionMouse.pressed
                     ? (actionRoot.primary ? "#d6e3f7" : "#e1e7ef")
                     : actionMouse.containsMouse
                       ? (actionRoot.primary ? "#e8f0fc" : "#f5f8fc")
                       : (actionRoot.primary ? "#f0f5ff" : "#ffffff")
        }

        Text {
            id: actionLabel
            anchors.centerIn: parent
            text: actionRoot.text
            color: actionRoot.enabled ? "#1f1f1f" : "#777777"
            font.pixelSize: 12
            font.bold: actionRoot.primary
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: actionRoot.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.clicked()
        }
    }

    Window {
        id: webPreviewWindow
        title: root.webUrl
        width: Math.min(1000, Screen.desktopAvailableWidth * 0.85)
        height: Math.min(760, Screen.desktopAvailableHeight * 0.85)
        modality: Qt.ApplicationModal
        visible: false

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8

            WebEngineView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                url: root.webUrl
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Abbrechen"
                    onClicked: webPreviewWindow.close()
                }
            }
        }
    }
}
