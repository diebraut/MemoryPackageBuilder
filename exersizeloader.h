#ifndef EXERSIZELOADER_H
#define EXERSIZELOADER_H

#include <QObject>
#include <QString>
#include <QVariantMap>

class ExersizeLoader : public QObject {
    Q_OBJECT
public:
    explicit ExersizeLoader(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap loadPackage(const QString &path);
    Q_INVOKABLE bool savePackage(const QString &path, const QVariantMap &data);

private:
         // keine Notwendigkeit für Memberparser, da Methode lokal arbeitet
};

#endif // EXERSIZELOADER_H
