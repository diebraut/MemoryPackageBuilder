#ifndef LICENCEINFOWIKI_H
#define LICENCEINFOWIKI_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QString>
#include <QJsonObject>

struct WikiLicenceInfo
{
    QString authorName;
    QString authorUrl;
    QString licenceName;
    QString licenceUrl;
    QString imageDescriptionUrl;
    QString imageUrl;
};

Q_DECLARE_METATYPE(WikiLicenceInfo)

class LicenceInfoWiki : public QObject
{
    Q_OBJECT
public:
    explicit LicenceInfoWiki(QObject *parent = nullptr);

    // Startet den Abruf der Lizenzinformationen zu einem Wikipedia-Dateibild
    Q_INVOKABLE void fetchLicenceInfo(const QString &fileTitle);

signals:
    // Wird ausgelöst, wenn die Infos erfolgreich geladen wurden
    void infoReady(QJsonObject info);

    // Wird ausgelöst, wenn ein Fehler aufgetreten ist
    void errorOccurred(const QString &message);

private slots:
    void onReplyFinished(QNetworkReply *reply);

private:
    QNetworkAccessManager manager;
    QString lastFileTitle;
};

#endif // LICENCEINFOWIKI_H
