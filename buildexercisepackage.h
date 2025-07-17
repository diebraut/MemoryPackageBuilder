#ifndef BUILDEXERCISEPACKAGE_H
#define BUILDEXERCISEPACKAGE_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QList>

class BuildExercisePackage : public QObject {
    Q_OBJECT
public:
    explicit BuildExercisePackage(QObject *parent = nullptr);

    Q_INVOKABLE bool buildPackage(const QString &csvPath, const QString &exerciseName, const QString &targetFolder);

private:
    QList<QVariantMap> parseCsv(const QString &csvPath);
    QString generateXml(const QString &exerciseName, const QList<QVariantMap> &dataList);
    bool writeXmlFile(const QString &folder, const QString &content);
};

#endif // BUILDEXERCISEPACKAGE_H
