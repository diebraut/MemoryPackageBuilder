#include "LicenceInfoWiki.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QUrlQuery>
#include <QRegularExpression>
#include <QRegularExpressionMatch>
#include <QDebug>

LicenceInfoWiki::LicenceInfoWiki(QObject *parent) : QObject(parent)
{
    connect(&manager, &QNetworkAccessManager::finished,
            this, &LicenceInfoWiki::onReplyFinished);
}

void LicenceInfoWiki::fetchLicenceInfo(const QString &fileTitle)
{
    // Titel merken und normalisieren (Unterstriche statt Leerzeichen)
    lastFileTitle = fileTitle.trimmed();
    if (lastFileTitle.contains(' '))
        lastFileTitle.replace(' ', '_');

    // 1) Zuerst Commons versuchen
    triedEnwiki = false;
    makeRequest(QUrl(QStringLiteral("https://commons.wikimedia.org/w/api.php")), "commons");
}

void LicenceInfoWiki::makeRequest(const QUrl &apiBase, const char *apiKind)
{
    QUrl url(apiBase);
    QUrlQuery query;
    query.addQueryItem("action",  "query");
    query.addQueryItem("format",  "json");
    query.addQueryItem("prop",    "imageinfo");
    query.addQueryItem("iiprop",  "url|size|mime|extmetadata"); // Original + Metadaten
    query.addQueryItem("iiurlwidth", QString::number(m_thumbWidth)); // ← gewünschte Breite
    // query.addQueryItem("iiurlheight", "500"); // optional, wenn du lieber Höhe vorgibst
    query.addQueryItem("titles",  lastFileTitle); // nicht manuell double-encoden

    url.setQuery(query);
    QNetworkRequest req(url);
    QNetworkReply *rep = manager.get(req);
    rep->setProperty("api_kind", QString::fromUtf8(apiKind));
}

void LicenceInfoWiki::onReplyFinished(QNetworkReply *reply)
{
    const QString apiKind = reply->property("api_kind").toString();

    if (reply->error() != QNetworkReply::NoError) {
        // Fehler – Fallback auf enwiki, falls noch nicht versucht
        const QString err = reply->errorString();
        reply->deleteLater();

        if (apiKind == QLatin1String("commons") && !triedEnwiki) {
            triedEnwiki = true;
            makeRequest(QUrl(QStringLiteral("https://en.wikipedia.org/w/api.php")), "enwiki");
            return;
        }

        emit errorOccurred(err);
        return;
    }

    const QByteArray data = reply->readAll();
    reply->deleteLater();

    QJsonParseError jerr{};
    const QJsonDocument doc = QJsonDocument::fromJson(data, &jerr);
    if (jerr.error != QJsonParseError::NoError) {
        // JSON defekt – Fallback auf enwiki, falls noch nicht versucht
        if (apiKind == QLatin1String("commons") && !triedEnwiki) {
            triedEnwiki = true;
            makeRequest(QUrl(QStringLiteral("https://en.wikipedia.org/w/api.php")), "enwiki");
            return;
        }
        emit errorOccurred(QStringLiteral("JSON-Fehler: %1").arg(jerr.errorString()));
        return;
    }

    const QJsonObject root = doc.object();

    // Versuchen zu parsen; wenn keine imageinfo → Fallback
    const bool ok = parseAndEmit(root, apiKind);
    if (!ok) {
        if (apiKind == QLatin1String("commons") && !triedEnwiki) {
            triedEnwiki = true;
            makeRequest(QUrl(QStringLiteral("https://en.wikipedia.org/w/api.php")), "enwiki");
            return;
        }
        emit errorOccurred(QStringLiteral("Keine 'imageinfo' in der Antwort vorhanden."));
    }
}

bool LicenceInfoWiki::parseAndEmit(const QJsonObject &root, const QString &apiKind)
{
    const QJsonObject pages = root.value("query").toObject().value("pages").toObject();
    if (pages.isEmpty()) return false;

    for (const auto &pageVal : pages) {
        const QJsonObject page = pageVal.toObject();
        const QJsonArray imageinfoArray = page.value("imageinfo").toArray();
        if (imageinfoArray.isEmpty()) continue;

        const QJsonObject imageinfo = imageinfoArray.at(0).toObject();
        const QJsonObject extMeta   = imageinfo.value("extmetadata").toObject();

        const QString originalUrl = imageinfo.value("url").toString();
        const QString thumbUrl    = imageinfo.value("thumburl").toString(); // ← fertig generiertes Thumb

        auto getExt = [](const QJsonObject &m, const char *k){
            return m.value(QLatin1String(k)).toObject().value("value").toString();
        };

        // Autor
        QString authorName = getExt(extMeta, "Artist");
        QString authorUrl;
        static const QRegularExpression rx("<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>", QRegularExpression::CaseInsensitiveOption);
        if (auto m = rx.match(authorName); m.hasMatch()) {
            authorUrl  = m.captured(1);
            authorName = m.captured(2);
        }

        // Lizenz
        const QString licenceName = getExt(extMeta, "LicenseShortName");
        const QString licenceUrl  = getExt(extMeta, "LicenseUrl");

        // Beschreibungsseite
        const QString descHost = (apiKind == QLatin1String("commons")) ? "commons.wikimedia.org"
                                                                       : "en.wikipedia.org";
        const QString imageDescriptionUrl = QString("https://%1/wiki/%2").arg(descHost, lastFileTitle);

        QJsonObject out;
        out["imageUrl"]            = originalUrl;              // Original
        out["thumbUrl"]            = thumbUrl;                 // ← skaliert (falls vorhanden)
        out["imageDescriptionUrl"] = imageDescriptionUrl;
        out["authorName"]          = authorName;
        out["authorUrl"]           = authorUrl;
        out["licenceName"]         = licenceName;
        out["licenceUrl"]          = licenceUrl;

        emit infoReady(out);
        return true;
    }
    return false;
}
