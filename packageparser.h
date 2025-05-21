#ifndef PACKAGEPARSER_H
#define PACKAGEPARSER_H

#define PACKAGE_NAME "package.xml"

#include "ExersizeModel.h"
#include <QString>
#include <QFile>
#include <QDomDocument>
#include <QDebug>

class PackageParser {
public:
    explicit PackageParser(const QString &xmlFilePath);
    // statt: Daten getPackageData();
    QVariantMap getPackageData();

private:
    QString m_xmlFilePath;
};

#endif // PACKAGEPARSER_H
