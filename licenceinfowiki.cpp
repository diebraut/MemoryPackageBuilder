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
    QUrl url("https://commons.wikimedia.org/w/api.php");
    QUrlQuery query;
    query.addQueryItem("action", "query");
    query.addQueryItem("format", "json");
    query.addQueryItem("prop", "imageinfo");
    query.addQueryItem("iiprop", "url|size|mime|extmetadata");

    // Titel korrekt encodieren
    QString encodedTitle = QString::fromUtf8(QUrl::toPercentEncoding(fileTitle));
    query.addQueryItem("titles", encodedTitle);

    url.setQuery(query);

    manager.get(QNetworkRequest(url));
}

void LicenceInfoWiki::onReplyFinished(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        emit errorOccurred(reply->errorString());
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();
    //qDebug().noquote() << "📥 Antwort JSON:" << QString::fromUtf8(data);
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject root = doc.object();

    QJsonObject pages = root.value("query").toObject().value("pages").toObject();
    if (pages.isEmpty()) {
        emit errorOccurred("Keine Bildinformationen gefunden");
        reply->deleteLater();
        return;
    }

    WikiLicenceInfo info;

    for (const auto &pageVal : pages) {
        QJsonObject page = pageVal.toObject();
        QJsonArray imageinfoArray = page.value("imageinfo").toArray();
        if (imageinfoArray.isEmpty()) continue;

        QJsonObject imageinfo = imageinfoArray.at(0).toObject();

        QJsonObject extMeta = imageinfo.value("extmetadata").toObject();

        // Helper-Lambda für sicheren Zugriff
        auto getExtMetaValue = [](const QJsonObject &extMeta, const QString &key) -> QString {
            if (extMeta.contains(key)) {
                return extMeta.value(key).toObject().value("value").toString();
            }
            return QString();
        };
        QString baseName = getExtMetaValue(extMeta, "ObjectName");
        // Hole die Dateiendung aus der tatsächlichen URL
        info.imageUrl = imageinfo.value("url").toString();
        QString fileExtension;

        int lastDot = info.imageUrl.lastIndexOf('.');
        if (lastDot != -1)
            fileExtension = info.imageUrl.mid(lastDot);  // inkl. Punkt, z. B. ".svg"

        info.imageDescriptionUrl = "https://commons.wikimedia.org/wiki/File:" + baseName + fileExtension;
        // Autor
        info.authorName = getExtMetaValue(extMeta, "Artist");
        info.authorUrl = "";

        // Autor-Name und Link extrahieren
        static const QRegularExpression rx("<a[^>]*href=\"([^\"]+)\"[^>]*>([^<]+)</a>");
        QRegularExpressionMatch match = rx.match(info.authorName);
        if (match.hasMatch()) {
            info.authorUrl = match.captured(1);
            info.authorName = match.captured(2);
        }

        // Lizenz
        info.licenceName = getExtMetaValue(extMeta, "LicenseShortName");
        info.licenceUrl = getExtMetaValue(extMeta, "LicenseUrl");

        // Debug-Ausgabe (optional)
        /*
        qDebug() << "✅ Bildquelle:" << info.imageDescriptionUrl;
        qDebug() << "👤 Autor:" << info.authorName << info.authorUrl;
        qDebug() << "📜 Lizenz:" << info.licenceName << info.licenceUrl;
        */

        QJsonObject jsonInfo;
        jsonInfo["imageUrl"] = info.imageUrl;
        jsonInfo["imageDescriptionUrl"] = info.imageDescriptionUrl;
        jsonInfo["authorName"] = info.authorName;
        jsonInfo["authorUrl"] = info.authorUrl;
        jsonInfo["licenceName"] = info.licenceName;
        jsonInfo["licenceUrl"] = info.licenceUrl;
        emit infoReady(jsonInfo);
        break; // Nur erstes gefundenes Bild verwenden
    }

    reply->deleteLater();
}
