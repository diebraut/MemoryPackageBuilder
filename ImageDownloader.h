#ifndef IMAGEDOWNLOADER_H
#define IMAGEDOWNLOADER_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>

class ImageDownloader : public QObject
{
    Q_OBJECT
public:
    explicit ImageDownloader(QObject *parent = nullptr);

    Q_INVOKABLE void downloadImage(const QString &url, const QString &savePath);

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
