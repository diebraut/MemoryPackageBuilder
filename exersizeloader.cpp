#include "ExersizeLoader.h"
#include "packageparser.h"

ExersizeLoader::ExersizeLoader(QObject *parent)
    : QObject(parent) {
    // Falls keine spezielle Initialisierung notwendig ist, bleibt der Konstruktor leer
}

QVariantMap ExersizeLoader::loadPackage(const QString &path) {
    // → Paketpfad, erwarte darin: /path/package.xml
    PackageParser parser(path); // erwartet Verzeichnis – intern wird /package.xml ergänzt
    return parser.getPackageData();
}
