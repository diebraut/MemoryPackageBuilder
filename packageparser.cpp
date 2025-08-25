#include "PackageParser.h"
#include <QVariant>
#include <QDIR>

PackageParser::PackageParser(const QString &xmlFilePath)
    : m_xmlFilePath(xmlFilePath) {}

QVariantMap PackageParser::getPackageData() {
    QVariantMap result;

    QFile file(m_xmlFilePath + QDir::separator() + PACKAGE_NAME );
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "❌ Fehler beim Öffnen der Datei:" << m_xmlFilePath;
        return result;
    }

    QDomDocument doc;
    if (!doc.setContent(&file)) {
        qWarning() << "❌ Fehler beim Parsen von XML";
        file.close();
        return result;
    }
    file.close();

    QDomElement root = doc.documentElement();  // "Daten"
    if (root.tagName() != "Daten") {
        qWarning() << "❌ Ungültiges Root-Element:" << root.tagName();
        return result;
    }

    QDomElement uebungenElem = root.firstChildElement("Übungen");
    if (uebungenElem.isNull()) {
        qWarning() << "❌ <Übungen>-Element nicht gefunden!";
        return result;
    }
    auto attrTrue = [](const QString &s){ return s.compare("true", Qt::CaseInsensitive) == 0 || s == "1"; };

    result["name"] = QVariant(uebungenElem.attribute("name"));
    result["sequentiell"] = QVariant(uebungenElem.attribute("sequentiell") == "true");
    result["hideAuthorByQuestion"] = attrTrue(uebungenElem.attribute("hideAuthorByQuestion")); // NEU (Default false, wenn leer)
    result["umgekehrt"] = QVariant(uebungenElem.attribute("umgekehrt") == "true");

    QDomElement mainListElem = uebungenElem.firstChildElement("MainÜbungsliste");
    if (mainListElem.isNull()) {
        qWarning() << "❌ <MainÜbungsliste>-Element nicht gefunden!";
        return result;
    }

    QDomElement frageTextElem = mainListElem.firstChildElement("FrageText");
    if (!frageTextElem.isNull()) {
        result["frageText"] = frageTextElem.text();
    }

    QDomElement frageTextUmgElem = mainListElem.firstChildElement("FrageTextUmgekehrt");
    if (!frageTextUmgElem.isNull()) {
        result["frageTextUmgekehrt"] = frageTextUmgElem.text();
    }

    QVariantList uebungList;

    QDomNodeList uebungenNodes = mainListElem.elementsByTagName("Übung");
    for (int i = 0; i < uebungenNodes.count(); ++i) {
        QDomElement e = uebungenNodes.at(i).toElement();
        if (!e.isNull()) {
            QVariantMap u;
            u["nummer"] = e.attribute("nummer").toInt();

            auto getText = [&](const QString &tag) {
                return e.firstChildElement(tag).text().trimmed();
            };

            u["frageSubjekt"] = getText("FrageSubjekt");
            u["antwortSubjekt"] = getText("AntwortSubjekt");
            u["subjektPrefixFrage"] = getText("SubjektPrefixFrage");
            u["subjektPrefixAntwort"] = getText("SubjektPrefixAntwort");
            u["imagefileFrage"] = getText("ImagefileFrage");
            u["imagefileAntwort"] = getText("ImagefileAntwort");
            u["infoURLFrage"] = getText("InfoURLFrage");
            u["infoURLAntwort"] = getText("InfoURLAntwort");
            u["imageFrageAuthor"] = getText("ImageFrageAuthor");
            u["imageFrageLizenz"] = getText("ImageFrageLizenz");
            u["imageAntwortAuthor"] = getText("ImageAntwortAuthor");
            u["imageAntwortLizenz"] = getText("ImageAntwortLizenz");
            u["wikiPageFraVers"] = getText("WikiPageFraVers");
            u["wikiPageAntVers"] = getText("WikiPageAntVers");
            u["excludeAereaFra"] = getText("ExcludeAereaFra");
            u["excludeAereaAnt"] = getText("ExcludeAereaAnt");
            u["imageFrageBildDescription"] = getText("ImageFrageBildDescription");
            u["imageAntwortBildDescription"] = getText("ImageAntwortBildDescription");
            u["imageFrageUrl"] = getText("ImageFrageUrl");
            u["imageAntwortUrl"] = getText("ImageAntwortUrl");
            u["arrowDescFra"] = getText("ArrowDescFra");
            u["arrowDescAnt"] = getText("ArrowDescAnt");

            uebungList.append(u);
        }
    }

    result["uebungsliste"] = uebungList;
    return result;
}
