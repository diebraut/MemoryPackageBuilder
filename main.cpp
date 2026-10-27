#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfo>
#include <QCursor>
#include <QQuickStyle>
#include "packagemodel.h"
#include "exersizeloader.h"
#include "ImageDownloader.h"
#include "licenceinfowiki.h"
#include "filehelper.h"
#include "buildexercisepackage.h"
#include "rectanglekeyfilter.h"


#include <QtWebEngineQuick/qtwebenginequickglobal.h>


#include <QDateTime>
#include <QFile>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QThread>
#include <cstdio>

namespace {
QFile diagnosticLog;
QMutex diagnosticLogMutex;

void writeDiagnosticMessage(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    const char *level = "DEBUG";
    switch (type) {
    case QtInfoMsg: level = "INFO"; break;
    case QtWarningMsg: level = "WARN"; break;
    case QtCriticalMsg: level = "ERROR"; break;
    case QtFatalMsg: level = "FATAL"; break;
    default: break;
    }
    const QString entry = QStringLiteral("%1 [%2] [thread %3] [%4] %5 (%6:%7)\n")
        .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs))
        .arg(QString::fromLatin1(level))
        .arg(quintptr(QThread::currentThreadId()), 0, 16)
        .arg(QString::fromUtf8(context.category ? context.category : "default"))
        .arg(message)
        .arg(QString::fromUtf8(context.file ? context.file : ""))
        .arg(context.line);
    const QByteArray bytes = entry.toUtf8();
    QMutexLocker locker(&diagnosticLogMutex);
    if (diagnosticLog.isOpen()) {
        diagnosticLog.write(bytes);
        diagnosticLog.flush(); // Preserve the last operation if the process aborts.
    }
    std::fwrite(bytes.constData(), 1, size_t(bytes.size()), stderr);
    std::fflush(stderr);
}

void initializeDiagnosticLog()
{
    const QString directory = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
                              + QStringLiteral("/logs");
    if (!QDir().mkpath(directory)) {
        qWarning() << "Cannot create diagnostic log directory:" << directory;
        return;
    }
    const QString path = directory + QStringLiteral("/MemoryPackageBuilder.log");
    // Retain the preceding log when the current file grows beyond 10 MiB.
    if (QFileInfo(path).size() > 10 * 1024 * 1024) {
        const QString previous = path + QStringLiteral(".previous");
        QFile::remove(previous);
        QFile::rename(path, previous);
    }
    diagnosticLog.setFileName(path);
    if (!diagnosticLog.open(QIODevice::WriteOnly | QIODevice::Append)) {
        qWarning() << "Cannot open diagnostic log:" << path << diagnosticLog.errorString();
        return;
    }
    qInstallMessageHandler(writeDiagnosticMessage);
    qInfo() << "=== SESSION START ===" << "pid" << QCoreApplication::applicationPid()
            << "Qt" << qVersion() << "executable" << QCoreApplication::applicationFilePath()
            << "log" << path;
}
}

int main(int argc, char *argv[])
{
    qmlRegisterModule("MemoryPackagesBuilder", 1, 0);

    QQuickStyle::setStyle("Windows");
    QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    QCoreApplication::setOrganizationName("DeineOrg");
    QCoreApplication::setOrganizationDomain("example.com");
    QCoreApplication::setApplicationName("MemoryPackagesBuilder");

    initializeDiagnosticLog();
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &app, []() { qInfo() << "=== SESSION END ==="; });
    qDebug() << QDir(":/icons").entryList();

    qmlRegisterSingletonInstance("ExersizeLoader", 1, 0, "ExersizeLoader", new ExersizeLoader);
    qmlRegisterType<ImageDownloader>("Helpers", 1, 0, "ImageDownloader");

    qmlRegisterType<LicenceInfoWiki>("Wiki", 1, 0, "LicenceInfoWiki");
    qRegisterMetaType<WikiLicenceInfo>("WikiLicenceInfo");

    qmlRegisterType<BuildExercisePackage>("ExerciseIO", 1, 0, "BuildExercisePackage");

    RectangleKeyFilter rectangleKeyFilter;
    app.installEventFilter(&rectangleKeyFilter);
    qmlRegisterSingletonInstance("RectKeyFilter", 1, 0, "RectKeyFilter", &rectangleKeyFilter);

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

    qDebug() << "Qt Quick Controls Style:" << QQuickStyle::name();
    return app.exec();
}
