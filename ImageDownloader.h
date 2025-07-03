#ifndef IMAGEDOWNLOADER_H
#define IMAGEDOWNLOADER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QImage>
#include <QQuickWindow>


class ImageDownloader : public QObject
{
    Q_OBJECT
public:
    explicit ImageDownloader(QObject *parent = nullptr);

    Q_INVOKABLE void downloadImage(const QString &url, const QString &savePath);
    Q_INVOKABLE void grabAndSaveCropped(QQuickWindow *window, int x, int y, int w, int h, const QString &path);
    Q_INVOKABLE void saveCropped(const QString &path) {
         qDebug() << "saveGrabbedImage aufgerufen mit:" << path;
    }

signals:
    void downloadSucceeded(const QString &filePath);
    void downloadFailed(const QString &errorString);

private slots:
    void onFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager manager;
    QString currentSavePath;
};

#endif // IMAGEDOWNLOADER_H
