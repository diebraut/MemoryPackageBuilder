// FileHelper.cpp
#include "FileHelper.h"
#include <QClipboard>
#include <QColor>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImage>
#include <QImageReader>
#include <QDir>
#include <QMimeData>
#include <QPixmap>
#include <QUrl>
#include <QVariant>

namespace {
QString localFilePathFromString(const QString &path)
{
    const QUrl url(path);
    if (url.isValid() && url.isLocalFile())
        return url.toLocalFile();
    return path;
}
}

bool FileHelper::removeFile(const QString &path) {
    return QFile::remove(path);
}

bool FileHelper::renameFile(const QString &oldPath, const QString &newPath) {
    return QFile::rename(oldPath, newPath);
}

bool FileHelper::fileExists(const QString &path) {
    return QFile::exists(path);
}

bool FileHelper::removeFilesWithSameBaseName(const QString& filePath) {
    QFileInfo refInfo(filePath);
    QString baseName = refInfo.completeBaseName(); // z.B. "Konrad Adenauer"
    QDir dir = refInfo.dir();

    if (!dir.exists())
        return false;

    // Alle Dateien im Ordner holen
    QFileInfoList allFiles = dir.entryInfoList(QDir::Files);
    bool allSuccess = true;

    for (const QFileInfo& fileInfo : allFiles) {
        if (fileInfo.completeBaseName() == baseName) {
            if (!QFile::remove(fileInfo.absoluteFilePath())) {
                qWarning() << "❌ Konnte Datei nicht löschen:" << fileInfo.absoluteFilePath();
                allSuccess = false;
            } else {
                qDebug() << "🧹 Datei gelöscht:" << fileInfo.fileName();
            }
        }
    }

    return allSuccess;
}

bool FileHelper::removeTMPFiles(const QString &path) {
    QDir dir(path);

    if (!dir.exists())
        return false;
    qDebug() << "pfad:" << dir.absolutePath();
    QFileInfoList allFiles = dir.entryInfoList(QDir::Files);
    bool allSuccess = true;

    for (const QFileInfo& fileInfo : allFiles) {
        if (fileInfo.completeBaseName().contains("_TEMP")) {
            if (!QFile::remove(fileInfo.absoluteFilePath())) {
                qWarning() << "❌ TEMP-Datei konnte nicht gelöscht werden:" << fileInfo.absoluteFilePath();
                allSuccess = false;
            } else {
                qDebug() << "🗑️ TEMP-Datei gelöscht:" << fileInfo.fileName();
            }
        }
    }

    return allSuccess;
}


QString FileHelper::saveClipboardImageTemporary(
    const QString &path,
    const QString &baseName,
    int partIndex)
{
    if (path.isEmpty() || baseName.isEmpty()) {
        qWarning() << "Clipboard-Bild: Zielpfad oder Basisname fehlt";
        return {};
    }

    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        qWarning() << "Clipboard-Bild: Keine Zwischenablage verfuegbar";
        return {};
    }

    const QMimeData *mime = clipboard->mimeData();
    if (!mime) {
        qWarning() << "Clipboard-Bild: Keine Mime-Daten verfuegbar";
        return {};
    }

    qDebug() << "Clipboard MIME-Formate:" << mime->formats();

    QImage image;

    // 1. Qt-eigene Bildrepräsentation
    const QVariant imageData = mime->imageData();

    if (imageData.canConvert<QImage>())
        image = qvariant_cast<QImage>(imageData);

    if (image.isNull() && imageData.canConvert<QPixmap>())
        image = qvariant_cast<QPixmap>(imageData).toImage();

    // 2. Explizite MIME-Bilddaten
    if (image.isNull()) {
        static const QStringList imageFormats = {
            QStringLiteral("image/png"),
            QStringLiteral("image/jpeg"),
            QStringLiteral("image/jpg"),
            QStringLiteral("image/bmp"),
            QStringLiteral("image/webp")
        };

        for (const QString &format : imageFormats) {
            if (!mime->hasFormat(format))
                continue;

            const QByteArray data = mime->data(format);
            if (data.isEmpty())
                continue;

            if (image.loadFromData(data)) {
                qDebug() << "Clipboard-Bild aus MIME geladen:" << format;
                break;
            }
        }
    }

    // 3. Kopierte Bilddatei aus Explorer etc.
    if (image.isNull() && mime->hasUrls()) {
        const QList<QUrl> urls = mime->urls();

        for (const QUrl &url : urls) {
            if (!url.isLocalFile())
                continue;

            QImageReader reader(url.toLocalFile());
            reader.setAutoTransform(true);

            QImage loaded = reader.read();
            if (!loaded.isNull()) {
                image = loaded;
                break;
            }
        }
    }

    if (image.isNull()) {
        qWarning() << "Clipboard-Bild: Keine lesbaren Bilddaten gefunden.";
        qWarning() << "Vorhandene MIME-Formate:" << mime->formats();
        return {};
    }

    QDir dir(localFilePathFromString(path));

    if (!dir.exists() && !dir.mkpath(QStringLiteral("."))) {
        qWarning() << "Clipboard-Bild: Zielordner kann nicht erstellt werden:"
                   << dir.absolutePath();
        return {};
    }

    QString suffix = QStringLiteral("_TEMP");

    if (partIndex > 0)
        suffix += QString::number(partIndex);

    const QString filePath =
        dir.filePath(baseName + suffix + QStringLiteral(".png"));

    if (!image.save(filePath, "PNG")) {
        qWarning() << "Clipboard-Bild: Speichern fehlgeschlagen:"
                   << filePath;
        return {};
    }

    qDebug() << "Clipboard-Bild gespeichert:" << filePath
             << image.size();

    return filePath;
}

bool FileHelper::clipboardHasImage()
{
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard)
        return false;

    const QMimeData *mime = clipboard->mimeData();
    if (!mime)
        return false;

    if (mime->hasImage())
        return true;

    if (!mime->hasUrls())
        return false;

    const QList<QUrl> urls = mime->urls();
    for (const QUrl &url : urls) {
        if (!url.isLocalFile())
            continue;
        QImageReader reader(url.toLocalFile());
        if (reader.canRead())
            return true;
    }

    return false;
}

bool FileHelper::makeImageColorTransparent(const QString &path, int imageX, int imageY)
{
    const QString filePath = localFilePathFromString(path);
    if (filePath.isEmpty()) {
        qWarning() << "Transparenz: Kein Bildpfad angegeben";
        return false;
    }

    QImage image(filePath);
    if (image.isNull()) {
        qWarning() << "Transparenz: Bild kann nicht geladen werden:" << filePath;
        return false;
    }

    if (imageX < 0 || imageY < 0 || imageX >= image.width() || imageY >= image.height()) {
        qWarning() << "Transparenz: Klickposition ausserhalb des Bildes:" << imageX << imageY;
        return false;
    }

    const QImage source = image.convertToFormat(QImage::Format_ARGB32);
    image = source;

    const QColor picked = image.pixelColor(imageX, imageY);
    const int tolerance = 16;

    for (int y = 0; y < image.height(); ++y) {
        QRgb *line = reinterpret_cast<QRgb *>(image.scanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            const QColor current = QColor::fromRgba(line[x]);
            if (qAbs(current.red() - picked.red()) <= tolerance
                    && qAbs(current.green() - picked.green()) <= tolerance
                    && qAbs(current.blue() - picked.blue()) <= tolerance) {
                line[x] = qRgba(current.red(), current.green(), current.blue(), 0);
            }
        }
    }

    if (!image.save(filePath, "PNG")) {
        qWarning() << "Transparenz: Speichern fehlgeschlagen:" << filePath;
        return false;
    }

    qDebug() << "Transparenzfarbe angewendet:" << filePath << picked;
    return true;
}

QStringList FileHelper::directoryEntries(const QString &path)
{
    QStringList result;

    if (path.isEmpty())
        return result;

    QDir dir(path);
    if (!dir.exists())
        return result;

    // Nur Dateien, keine Unterordner
    QFileInfoList files = dir.entryInfoList(
        QDir::Files | QDir::NoDotAndDotDot,
        QDir::Name
        );

    for (const QFileInfo &info : files) {
        result << info.fileName();
    }

    return result;
}
