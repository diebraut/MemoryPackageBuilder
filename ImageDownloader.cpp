#include "ImageDownloader.h"
#include <QFile>
#include <QDebug>

#include <QImage>

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

Q_INVOKABLE void ImageDownloader::grabAndSaveCropped(QQuickWindow *window, int x, int y, int w, int h, const QString &path) {
    if (!window) {
        qWarning() << "❌ Fenster ist null";
        return;
    }

    QImage image = window->grabWindow();
    if (image.isNull()) {
        qWarning() << "❌ Screenshot fehlgeschlagen";
        return;
    }

    QImage cropped = image.copy(x, y, w, h);
    if (cropped.save(path)) {
        qDebug() << "✅ Bereich gespeichert unter:" << path;
    } else {
        qWarning() << "❌ Speichern fehlgeschlagen";
    }
}
