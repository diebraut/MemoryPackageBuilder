#ifndef LICENCEINFOWIKI_H
#define LICENCEINFOWIKI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QUrl>
#include <QJsonObject>

struct WikiLicenceInfo {
    QString imageUrl;
    QString imageDescriptionUrl;
    QString authorName;
    QString authorUrl;
    QString licenceName;
    QString licenceUrl;
};

class LicenceInfoWiki : public QObject {
    Q_OBJECT
    Q_PROPERTY(int thumbWidth READ thumbWidth WRITE setThumbWidth NOTIFY thumbWidthChanged)
public:
    explicit LicenceInfoWiki(QObject *parent = nullptr);

    Q_INVOKABLE void fetchLicenceInfo(const QString &fileTitle);

    int thumbWidth() const { return m_thumbWidth; }
    void setThumbWidth(int w) { if (m_thumbWidth == w) return; m_thumbWidth = w; emit thumbWidthChanged(); }

signals:
    void infoReady(const QJsonObject &info);
    void errorOccurred(const QString &message);
    void thumbWidthChanged();

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    void makeRequest(const QUrl &apiBase, const char *apiKind);
    bool parseAndEmit(const QJsonObject &root, const QString &apiKind);

    QNetworkAccessManager manager;
    QString lastFileTitle;
    bool triedEnwiki = false;
    int m_thumbWidth = 500; // Standardbreite
};

#endif // LICENCEINFOWIKI_H
