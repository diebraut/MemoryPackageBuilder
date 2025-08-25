#include <QDir>

#include "ExersizeLoader.h"
#include "packageparser.h"

ExersizeLoader::ExersizeLoader(QObject *parent)
    : QObject(parent) {
    // Falls keine spezielle Initialisierung notwendig ist, bleibt der Konstruktor leer
}

QVariantMap ExersizeLoader::loadPackage(const QString &path) {
    // → Paketpfad, erwarte darin: /path/package.xml
    PackageParser parser(path); // erwartet Verzeichnis – intern wird /package.xml ergänzt
    return parser.getPackageData();
}

bool ExersizeLoader::savePackage(const QString &path, const QVariantMap &data) {
    QString filePath = path + QDir::separator() + PACKAGE_NAME;
    QFile file(filePath);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "❌ Konnte Datei nicht zum Lesen öffnen:" << filePath;
        return false;
    }

    QDomDocument doc;
    if (!doc.setContent(&file)) {
        qWarning() << "❌ Fehler beim Parsen der XML-Datei.";
        file.close();
        return false;
    }
    file.close();

    QDomElement root = doc.documentElement();
    QDomElement uebungenElem = root.firstChildElement("Übungen");
    QDomElement mainListElem = uebungenElem.firstChildElement("MainÜbungsliste");

    if (uebungenElem.isNull() || mainListElem.isNull()) {
        qWarning() << "❌ Struktur der Datei ungültig.";
        return false;
    }

    // Update Attribute
    uebungenElem.setAttribute("name", data.value("name").toString());
    uebungenElem.setAttribute("sequentiell", data.value("sequentiell").toBool() ? "true" : "false");
    uebungenElem.setAttribute("umgekehrt", data.value("umgekehrt").toBool() ? "true" : "false");
    uebungenElem.setAttribute("hideAuthorByQuestion", data.value("hideAuthorByQuestion").toBool() ? "true" : "false"); // neu

    // Texte aktualisieren
    mainListElem.firstChildElement("FrageText").firstChild().setNodeValue(data.value("frageText").toString());
    mainListElem.firstChildElement("FrageTextUmgekehrt").firstChild().setNodeValue(data.value("frageTextUmgekehrt").toString());

    // Alte Übungen löschen
    QDomNodeList alte = mainListElem.elementsByTagName("Übung");
    while (!alte.isEmpty()) {
        mainListElem.removeChild(alte.at(0));
    }

    // Whitelist
    const QStringList allowedFields = {
        "frageSubjekt", "antwortSubjekt", "subjektPrefixFrage", "subjektPrefixAntwort",
        "imagefileFrage", "imagefileAntwort", "infoURLFrage", "infoURLAntwort",
        "imageFrageAuthor", "imageFrageLizenz", "imageAntwortAuthor", "imageAntwortLizenz",
        "wikiPageFraVers", "wikiPageAntVers", "excludeAereaFra", "excludeAereaAnt",
        "imageFrageBildDescription", "imageAntwortBildDescription",
        "imageFrageUrl", "imageAntwortUrl", "arrowDescFra", "arrowDescAnt"
    };

    // Lokale helper-Funktion zum Umwandeln von Key → XML-Tag
    auto keyToTagName = [](const QString &key) -> QString {
        if (key.isEmpty()) return QString();
        return key.left(1).toUpper() + key.mid(1);
    };
    const QVariantList uebungen = data.value("uebungsliste").toList();
    qDebug() << "Anzahl Übungen:" << uebungen.size();
    // Neue Übungen schreiben
    for (const QVariant &uebVar : uebungen) {
        const QVariantMap u = uebVar.toMap();
        QDomElement e = doc.createElement("Übung");
        e.setAttribute("nummer", u.value("nummer").toInt());

        for (const QString &key : allowedFields) {
            if (u.contains(key)) {
                const QString text = u.value(key).toString();
                QDomElement elem = doc.createElement(keyToTagName(key));
                elem.appendChild(doc.createTextNode(text));
                e.appendChild(elem);
            }
        }

        mainListElem.appendChild(e);
    }

    // Speichern
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        qWarning() << "❌ Konnte Datei nicht zum Schreiben öffnen:" << filePath;
        return false;
    }

    QTextStream out(&file);
    doc.save(out, 4);
    file.close();

    return true;
}
