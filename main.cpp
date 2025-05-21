#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include "packagemodel.h"
#include "exersizeloader.h"


int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterSingletonInstance("ExersizeLoader", 1, 0, "ExersizeLoader", new ExersizeLoader);

    // Modell als QML-Typ registrieren
    qmlRegisterType<PackageModel>("Package", 1, 0, "PackageModel");

    // Pfad zum Ordner "exercisepackages" relativ zum Programmverzeichnis
    QString packageFolderPath = QCoreApplication::applicationDirPath() + "/exercisepackages";

    // Debug-Ausgabe zur Kontrolle
    qDebug() << "📂 Pfad zu exercisepackages:" << packageFolderPath;

    QQmlApplicationEngine engine;

    // Übergabe des Pfads an QML
    engine.rootContext()->setContextProperty("packagesFolder", packageFolderPath);

    const QUrl url(u"qrc:/MemoryPackagesBuilder/Main.qml"_qs);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
