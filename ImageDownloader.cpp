#include "ImageDownloader.h"
#include <QFile>
#include <QImage>
#include <QNetworkReply>
#include <QDebug>

ImageDownloader::ImageDownloader(QObject *parent)
    : QObject(parent)
{
    // Kein globaler Slot nötig
}

void ImageDownloader::downloadImage(const QString &url, const QString &savePath)
{
    QUrl qurl(url);
    if (!qurl.isValid()) {
        emit downloadFailed("Ungültige URL");
        return;
    }

    QNetworkRequest request(qurl);
    QNetworkReply* reply = manager.get(request);

    // Pro-Request-Handling mit Lambda
    connect(reply, &QNetworkReply::finished, this, [reply, savePath, this]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit downloadFailed("Netzwerkfehler: " + reply->errorString());
            reply->deleteLater();
            return;
        }

        QByteArray data = reply->readAll();
        QFile file(savePath);
        if (!file.open(QIODevice::WriteOnly)) {
            emit downloadFailed("Fehler beim Öffnen der Datei: " + file.errorString());
            reply->deleteLater();
            return;
        }

        file.write(data);
        file.close();

        qDebug() << "✅ Bild gespeichert unter:" << savePath;
        emit downloadSucceeded(savePath);

        reply->deleteLater();
    });
}

void ImageDownloader::grabAndSaveCropped(QQuickWindow *window, int x, int y, int w, int h, const QString &path)
{
    if (!window) {
        emit downloadFailed("Fenster ist null");
        return;
    }

    QImage image = window->grabWindow();
    if (image.isNull()) {
        emit downloadFailed("Screenshot fehlgeschlagen");
        return;
    }

    QImage cropped = image.copy(x, y, w, h);
    if (cropped.save(path)) {
        qDebug() << "✅ Bereich gespeichert unter:" << path;
        emit downloadSucceeded(path);
    } else {
        emit downloadFailed("Speichern fehlgeschlagen");
    }
}
