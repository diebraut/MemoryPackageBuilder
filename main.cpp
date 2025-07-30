#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QCursor>
#include "packagemodel.h"
#include "exersizeloader.h"
#include "ImageDownloader.h"
#include "licenceinfowiki.h"
#include "filehelper.h"
#include "buildexercisepackage.h"


#include <QtWebEngineQuick/qtwebenginequickglobal.h>


int main(int argc, char *argv[])
{
    qmlRegisterModule("MemoryPackagesBuilder", 1, 0);
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    qDebug() << QDir(":/icons").entryList();

    qmlRegisterSingletonInstance("ExersizeLoader", 1, 0, "ExersizeLoader", new ExersizeLoader);
    qmlRegisterType<ImageDownloader>("Helpers", 1, 0, "ImageDownloader");

    qmlRegisterType<LicenceInfoWiki>("Wiki", 1, 0, "LicenceInfoWiki");
    qRegisterMetaType<WikiLicenceInfo>("WikiLicenceInfo");

    qmlRegisterType<BuildExercisePackage>("ExerciseIO", 1, 0, "BuildExercisePackage");

    qmlRegisterSingletonType<FileHelper>("FileHelper", 1, 0, "FileHelper", [](QQmlEngine*, QJSEngine*) -> QObject* {
        return new FileHelper();
    });

    // Modell als QML-Typ registrieren
    qmlRegisterType<PackageModel>("Package", 1, 0, "PackageModel");

    // Pfad zum Ordner "exercisepackages" relativ zum Programmverzeichnis
    QString packageFolderPath = QCoreApplication::applicationDirPath() + "/exercisepackages";

    // Pfad zum Ordner "exercise packages" relativ zum Programmverzeichnis
    QString buildSourcenPath = QCoreApplication::applicationDirPath() + "/buildsourcen";

    // Debug-Ausgabe zur Kontrolle
    qDebug() << "📂 Pfad zu exercisepackages:" << packageFolderPath;

    QQmlApplicationEngine engine;

    // Übergabe des Pfads an QML
    engine.rootContext()->setContextProperty("packagesFolder", packageFolderPath);
    // Übergabe der build sourcen an QML
    engine.rootContext()->setContextProperty("buildSourcenFolder", buildSourcenPath);

    //const QUrl url(u"qrc:/MemoryPackagesBuilder/Main.qml"_qs);
    const QUrl url(u"qrc:/MemoryPackagesBuilder/Main.qml"_qs);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    QPoint pos = QCursor::pos();  // globale Mausposition
    engine.rootContext()->setContextProperty("globalMousePos", pos);

    return app.exec();
}
