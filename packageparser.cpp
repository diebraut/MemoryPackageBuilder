#include "PackageParser.h"
#include <QVariant>
#include <QDIR>

PackageParser::PackageParser(const QString &xmlFilePath)
    : m_xmlFilePath(xmlFilePath) {}

QVariantMap PackageParser::getPackageData()
{
    QVariantMap result;

    // =====================================================
    // 1️⃣ SCHEMA-DEFAULTS (GARANTIE!)
    // =====================================================
    result["name"]                 = "";
    result["frageType"]            = "";
    result["frageText"]            = "";
    result["frageTextUmgekehrt"]   = "";
    result["sequentiell"]          = false;
    result["umgekehrt"]            = false;
    result["hideAuthorByQuestion"] = false;
    result["uebungsliste"]         = QVariantList{};

    QFile file(m_xmlFilePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "❌ Fehler beim Öffnen der Datei:" << m_xmlFilePath;
        return result;   // ← leeres, aber gültiges Schema
    }

    QDomDocument doc;
    if (!doc.setContent(&file)) {
        qWarning() << "❌ Fehler beim Parsen von XML";
        file.close();
        return result;
    }
    file.close();

    // =====================================================
    // 2️⃣ Struktur lesen (defensiv)
    // =====================================================
    QDomElement root = doc.documentElement();
    if (root.tagName() != "Daten") {
        qWarning() << "❌ Ungültiges Root-Element:" << root.tagName();
        return result;
    }

    QDomElement uebungenElem = root.firstChildElement("Übungen");
    if (uebungenElem.isNull()) {
        qWarning() << "❌ <Übungen>-Element nicht gefunden!";
        return result;
    }

    auto attrTrue = [](const QString &s) {
        return s.compare("true", Qt::CaseInsensitive) == 0 || s == "1";
    };

    // =====================================================
    // 3️⃣ Attribute (überschreiben Defaults)
    // =====================================================
    result["name"]                 = uebungenElem.attribute("name", "");
    result["frageType"]            = uebungenElem.attribute("frageType", "");
    result["sequentiell"]          = attrTrue(uebungenElem.attribute("sequentiell"));
    result["umgekehrt"]            = attrTrue(uebungenElem.attribute("umgekehrt"));
    result["hideAuthorByQuestion"] = attrTrue(uebungenElem.attribute("hideAuthorByQuestion"));

    QDomElement mainListElem = uebungenElem.firstChildElement("MainÜbungsliste");
    if (mainListElem.isNull()) {
        qWarning() << "❌ <MainÜbungsliste>-Element nicht gefunden!";
        return result;
    }

    // =====================================================
    // 4️⃣ Texte (immer String)
    // =====================================================
    auto readText = [&](const QString &tag) -> QString {
        QDomElement e = mainListElem.firstChildElement(tag);
        return e.isNull() ? "" : e.text();
    };

    result["frageText"]          = readText("FrageText");
    result["frageTextUmgekehrt"] = readText("FrageTextUmgekehrt");

    // =====================================================
    // 5️⃣ Übungen (IMMER Liste)
    // =====================================================
    QVariantList uebungList;

    QDomNodeList uebungenNodes = mainListElem.elementsByTagName("Übung");
    for (int i = 0; i < uebungenNodes.count(); ++i) {
        QDomElement e = uebungenNodes.at(i).toElement();
        if (e.isNull())
            continue;

        QVariantMap u;
        u["nummer"] = e.attribute("nummer").toInt();

        auto getText = [&](const QString &tag) {
            QDomElement el = e.firstChildElement(tag);
            return el.isNull() ? "" : el.text().trimmed();
        };

        u["frageSubjekt"]               = getText("FrageSubjekt");
        u["antwortSubjekt"]             = getText("AntwortSubjekt");
        u["subjektPrefixFrage"]         = getText("SubjektPrefixFrage");
        u["subjektPrefixAntwort"]       = getText("SubjektPrefixAntwort");
        u["imagefileFrage"]             = getText("ImagefileFrage");
        u["imagefileAntwort"]           = getText("ImagefileAntwort");
        u["infoURLFrage"]               = getText("InfoURLFrage");
        u["infoURLAntwort"]             = getText("InfoURLAntwort");
        u["imageFrageAuthor"]           = getText("ImageFrageAuthor");
        u["imageFrageLizenz"]           = getText("ImageFrageLizenz");
        u["imageAntwortAuthor"]         = getText("ImageAntwortAuthor");
        u["imageAntwortLizenz"]         = getText("ImageAntwortLizenz");
        u["wikiPageFraVers"]            = getText("WikiPageFraVers");
        u["wikiPageAntVers"]            = getText("WikiPageAntVers");
        u["excludeAereaFra"]            = getText("ExcludeAereaFra");
        u["excludeAereaAnt"]            = getText("ExcludeAereaAnt");
        u["imageFrageBildDescription"]  = getText("ImageFrageBildDescription");
        u["imageAntwortBildDescription"]= getText("ImageAntwortBildDescription");
        u["imageFrageUrl"]              = getText("ImageFrageUrl");
        u["imageAntwortUrl"]            = getText("ImageAntwortUrl");
        u["arrowDescFra"]               = getText("ArrowDescFra");
        u["arrowDescAnt"]               = getText("ArrowDescAnt");

        uebungList.append(u);
    }

    result["uebungsliste"] = uebungList;
    return result;
}
