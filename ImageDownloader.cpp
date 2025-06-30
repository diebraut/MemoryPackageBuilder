#include "ImageDownloader.h"
#include <QFile>
#include <QDir>

ImageDownloader::ImageDownloader(QObject *parent) : QObject(parent)
{
    connect(&manager, &QNetworkAccessManager::finished,
            this, &ImageDownloader::onFinished);
}

void ImageDownloader::downloadImage(const QString &url, const QString &savePath)
{
    currentSavePath = savePath;

    QUrl qurl(url);
    if (!qurl.isValid()) {
        emit downloadFailed("Ungültige URL");
        return;
    }

    QNetworkRequest request(qurl);
    manager.get(request);
}

void ImageDownloader::onFinished(QNetworkReply *reply)
{
    if (reply->error() != QNetworkReply::NoError) {
        emit downloadFailed(reply->errorString());
        reply->deleteLater();
        return;
    }

    QByteArray data = reply->readAll();

    QFile file(currentSavePath);
    if (!file.open(QIODevice::WriteOnly)) {
        emit downloadFailed("Fehler beim Öffnen der Datei: " + file.errorString());
        reply->deleteLater();
        return;
    }

    file.write(data);
    file.close();

    emit downloadSucceeded(currentSavePath);
    reply->deleteLater();
}
