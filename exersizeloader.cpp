#include <QDir>

#include "ExersizeLoader.h"
#include "packageparser.h"
#include <QRegularExpression>


ExersizeLoader::ExersizeLoader(QObject *parent)
    : QObject(parent) {
    // Falls keine spezielle Initialisierung notwendig ist, bleibt der Konstruktor leer
}

QVariantMap ExersizeLoader::loadPackage(const QString &fullPackageXMLName) {
    // → Paketpfad, erwarte darin: /path/package.xml
    PackageParser parser(fullPackageXMLName); // erwartet Verzeichnis
    return parser.getPackageData();
}

bool ExersizeLoader::savePackage(const QString &path, const QVariantMap &data)
{
    QFile file(path);
    QDomDocument doc;

    QDomElement root;
    QDomElement uebungenElem;
    QDomElement mainListElem;

    // =====================================================
    // 1️⃣ XML-Deklaration explizit hinzufügen
    // =====================================================
    QDomProcessingInstruction xmlDecl =
        doc.createProcessingInstruction("xml", "version=\"1.0\" encoding=\"UTF-8\"");
    doc.appendChild(xmlDecl);

    // =====================================================
    // 2️⃣ Datei existiert NICHT → korrektes Grundgerüst
    // =====================================================
    if (!file.exists()) {
        // <Daten>
        root = doc.createElement("Daten");
        doc.appendChild(root);

        // <Übungen>
        uebungenElem = doc.createElement("Übungen");
        root.appendChild(uebungenElem);

        // <MainÜbungsliste>
        mainListElem = doc.createElement("MainÜbungsliste");
        uebungenElem.appendChild(mainListElem);

        // Pflichttexte (dürfen leer sein)
        QDomElement frageText = doc.createElement("FrageText");
        frageText.appendChild(doc.createTextNode(""));
        mainListElem.appendChild(frageText);

        QDomElement frageTextUmg = doc.createElement("FrageTextUmgekehrt");
        frageTextUmg.appendChild(doc.createTextNode(""));
        mainListElem.appendChild(frageTextUmg);
    }
    // =====================================================
    // 3️⃣ Datei existiert → laden & prüfen
    // =====================================================
    else {
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            qWarning() << "❌ Konnte Datei nicht zum Lesen öffnen:" << path;
            return false;
        }

        if (!doc.setContent(&file)) {
            qWarning() << "❌ Fehler beim Parsen der XML-Datei:" << path;
            file.close();
            return false;
        }
        file.close();

        root = doc.documentElement();
        if (root.tagName() != "Daten") {
            qWarning() << "❌ Ungültiges Root-Element:" << root.tagName();
            return false;
        }

        uebungenElem = root.firstChildElement("Übungen");
        mainListElem = uebungenElem.firstChildElement("MainÜbungsliste");

        if (uebungenElem.isNull() || mainListElem.isNull()) {
            qWarning() << "❌ Ungültige XML-Struktur:" << path;
            return false;
        }
    }

    // =====================================================
    // 4️⃣ Attribute setzen
    // =====================================================
    uebungenElem.setAttribute("name", data.value("name").toString());
    uebungenElem.setAttribute("frageType", data.value("frageType").toString());
    uebungenElem.setAttribute(
        "sequentiell", data.value("sequentiell").toBool() ? "true" : "false");
    uebungenElem.setAttribute(
        "umgekehrt", data.value("umgekehrt").toBool() ? "true" : "false");
    uebungenElem.setAttribute(
        "hideAuthorByQuestion",
        data.value("hideAuthorByQuestion").toBool() ? "true" : "false");

    // =====================================================
    // 5️⃣ Texte robust setzen
    // =====================================================
    auto setText = [&](const QString &tag, const QString &value) {
        QDomElement e = mainListElem.firstChildElement(tag);
        if (e.isNull()) {
            e = doc.createElement(tag);
            mainListElem.appendChild(e);
        }
        if (e.firstChild().isNull())
            e.appendChild(doc.createTextNode(value));
        else
            e.firstChild().setNodeValue(value);
    };

    setText("FrageText", data.value("frageText").toString());
    setText("FrageTextUmgekehrt", data.value("frageTextUmgekehrt").toString());

    // =====================================================
    // 6️⃣ Alte Übungen löschen
    // =====================================================
    QDomNodeList alte = mainListElem.elementsByTagName("Übung");
    while (!alte.isEmpty()) {
        mainListElem.removeChild(alte.at(0));
    }

    // =====================================================
    // 7️⃣ Whitelist + Key→Tag Mapping
    // =====================================================
    const QStringList allowedFields = {
        "frageSubjekt", "antwortSubjekt",
        "subjektPrefixFrage", "subjektPrefixAntwort",
        "imagefileFrage", "imagefileAntwort",
        "infoURLFrage", "infoURLAntwort",
        "imageFrageAuthor", "imageFrageLizenz",
        "imageAntwortAuthor", "imageAntwortLizenz",
        "wikiPageFraVers", "wikiPageAntVers",
        "excludeAereaFra", "excludeAereaAnt",
        "imageFrageBildDescription", "imageAntwortBildDescription",
        "imageFrageUrl", "imageAntwortUrl",
        "arrowDescFra", "arrowDescAnt"
    };

    auto keyToTagName = [](const QString &key) -> QString {
        if (key.isEmpty()) return QString();
        return key.left(1).toUpper() + key.mid(1);
    };

    // =====================================================
    // 8️⃣ Neue Übungen schreiben
    // =====================================================
    const QVariantList uebungen = data.value("uebungsliste").toList();

    for (const QVariant &uebVar : uebungen) {
        const QVariantMap u = uebVar.toMap();

        QDomElement e = doc.createElement("Übung");
        e.setAttribute("nummer", u.value("nummer").toInt());

        for (const QString &key : allowedFields) {
            if (u.contains(key)) {
                QDomElement elem = doc.createElement(keyToTagName(key));
                elem.appendChild(doc.createTextNode(u.value(key).toString()));
                e.appendChild(elem);
            }
        }

        mainListElem.appendChild(e);
    }

    // =====================================================
    // 9️⃣ Datei schreiben (UTF-8)
    // =====================================================
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qWarning() << "❌ Konnte Datei nicht zum Schreiben öffnen:" << path;
        return false;
    }

    QTextStream out(&file);
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    out.setEncoding(QStringConverter::Utf8);
#else
    out.setCodec("UTF-8");
#endif
    doc.save(out, 4);
    file.close();

    return true;
}

bool ExersizeLoader::removePackageFile(const QString &filePath)
{
    QFileInfo fi(filePath);
    if (!fi.exists()) {
        qWarning() << "❌ Datei existiert nicht:" << filePath;
        return false;
    }

    QDir dir = fi.dir();
    const QString baseName = fi.baseName();   // package_01
    const QString suffix   = fi.completeSuffix(); // xml

    // Nummer extrahieren
    QRegularExpression re("^package_(\\d+)$");
    QRegularExpressionMatch m = re.match(baseName);
    if (!m.hasMatch()) {
        qWarning() << "❌ Ungültiger Dateiname:" << baseName;
        return false;
    }

    int removedIndex = m.captured(1).toInt();

    // 1️⃣ Datei löschen
    if (!QFile::remove(filePath)) {
        qWarning() << "❌ Löschen fehlgeschlagen:" << filePath;
        return false;
    }

    // 2️⃣ Alle höheren Nummern umbenennen
    int nextIndex = removedIndex + 1;

    while (true) {
        const QString oldName =
            QString("package_%1.%2")
                .arg(nextIndex, 2, 10, QLatin1Char('0'))
                .arg(suffix);

        const QString newName =
            QString("package_%1.%2")
                .arg(nextIndex - 1, 2, 10, QLatin1Char('0'))
                .arg(suffix);

        if (!dir.exists(oldName))
            break;

        if (!dir.rename(oldName, newName)) {
            qWarning() << "❌ Umbenennen fehlgeschlagen:" << oldName << "→" << newName;
            return false;
        }

        nextIndex++;
    }

    return true;
}



