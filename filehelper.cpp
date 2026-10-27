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
#include <QPainter>
#include <QUrl>
#include <QVariant>
#include <QDateTime>
#include <QPointer>
#include <QTimer>
#include <QCryptographicHash>
#include <QTemporaryFile>
#include <QSaveFile>
#include "imageinformation.h"

namespace {
QString localFilePathFromString(const QString &path)
{
    const QUrl url(path);
    if (url.isValid() && url.isLocalFile())
        return url.toLocalFile();
    return path;
}
}

FileHelper::FileHelper(QObject *parent) : QObject(parent)
{
    m_imageInformationPool.setMaxThreadCount(1);
}

void FileHelper::requestImageInformation(const QString &path, const QString &requestToken)
{
    const QFileInfo file(localFilePathFromString(path));
    QVariantMap information;
    if (file.isFile()) {
        information = {{QStringLiteral("state"), QStringLiteral("ready")},
                       {QStringLiteral("sizeBytes"), file.size()}};
    } else {
        information = {{QStringLiteral("state"), QStringLiteral("error")},
                       {QStringLiteral("message"), QStringLiteral("Bilddatei nicht gefunden")}};
    }
    QTimer::singleShot(0, this, [this, requestToken, information]() {
        emit imageInformationReady(requestToken, information);
    });
}

bool FileHelper::compressPackageImages(const QString &path)
{
    const QString directory = localFilePathFromString(path);
    if (m_imageCompressionRunning || !QDir(directory).exists())
        return false;
    m_imageCompressionRunning = true;
    emit imageCompressionRunningChanged();
    const QPointer<FileHelper> guard(this);
    m_imageInformationPool.start([guard, directory]() {
        QFileInfoList images;
        const auto formats = QImageReader::supportedImageFormats();
        // Package images are stored directly in this directory. Leave backup folders alone.
        for (const QFileInfo &file : QDir(directory).entryInfoList(QDir::Files | QDir::NoSymLinks, QDir::Name)) {
            const QByteArray suffix = file.suffix().toLower().toLatin1();
            QImageReader reader(file.absoluteFilePath());
            reader.setDecideFormatFromContent(true);
            if (formats.contains(suffix) || suffix == "jpg" || suffix == "jpeg"
                || suffix == "png" || reader.canRead())
                images.append(file);
        }
        const int total = int(images.size());
        const auto progress = [guard, total](int processed, const QString &name) {
            if (guard)
                QMetaObject::invokeMethod(guard.data(), [guard, processed, total, name]() {
                    if (guard) emit guard->imageCompressionProgress(processed, total, name);
                }, Qt::QueuedConnection);
        };
        int processed = 0, compressed = 0, unchanged = 0, unsupported = 0;
        qint64 saved = 0;
        QStringList errors;
        for (const QFileInfo &file : images) {
            progress(processed, file.fileName());
            const QVariantMap result = compressImageLosslessly(file.absoluteFilePath());
            const QString state = result.value(QStringLiteral("state")).toString();
            if (state == QStringLiteral("compressed")) {
                ++compressed;
                saved += result.value(QStringLiteral("savingBytes")).toLongLong();
            } else if (state == QStringLiteral("ready")) {
                ++unchanged;
            } else if (state == QStringLiteral("unsupported")) {
                ++unsupported;
            } else {
                errors.append(file.fileName() + QStringLiteral(": ")
                              + result.value(QStringLiteral("message")).toString());
            }
            if (guard)
                QMetaObject::invokeMethod(guard.data(), [guard, name = file.fileName(), result]() {
                    if (guard) emit guard->imageCompressionFileFinished(name, result);
                }, Qt::QueuedConnection);
            progress(++processed, file.fileName());
        }
        const QVariantMap summary{{QStringLiteral("total"), total},
            {QStringLiteral("compressed"), compressed}, {QStringLiteral("unchanged"), unchanged},
            {QStringLiteral("unsupported"), unsupported}, {QStringLiteral("savedBytes"), saved},
            {QStringLiteral("errors"), errors}, {QStringLiteral("errorCount"), int(errors.size())}};
        if (guard)
            QMetaObject::invokeMethod(guard.data(), [guard, summary]() {
                if (!guard) return;
                guard->m_imageCompressionRunning = false;
                emit guard->imageCompressionRunningChanged();
                emit guard->imageCompressionFinished(summary);
            }, Qt::QueuedConnection);
    });
    return true;
}

void FileHelper::requestImageCompressionPreview(const QString &path, int quality, const QString &token)
{
    discardImageCompressionPreview(token);
    const QString localPath = QFileInfo(localFilePathFromString(path)).absoluteFilePath();
    if (!m_imagePreviewDirectory.isValid() || QFileInfo(localPath).isSymLink()) {
        emit imageCompressionPreviewReady(token, {{QStringLiteral("state"), QStringLiteral("error")},
            {QStringLiteral("message"), QStringLiteral("Temporäre Vorschau kann nicht angelegt werden.")}});
        return;
    }
    m_imagePreviews.insert(token, {{QStringLiteral("originalPath"), localPath}});
    const QString temporaryDirectory = m_imagePreviewDirectory.path();
    const QPointer<FileHelper> guard(this);
    m_imageInformationPool.start([guard, localPath, quality, token, temporaryDirectory]() {
        QByteArray original, encoded;
        QVariantMap result = prepareImageCompressionPreview(localPath, quality, original, encoded);
        QVariantMap record;
        if (result.value(QStringLiteral("state")).toString() == QStringLiteral("ready")) {
            QTemporaryFile preview(temporaryDirectory + QStringLiteral("/preview-XXXXXX.")
                                   + result.value(QStringLiteral("format")).toString());
            if (!preview.open() || preview.write(encoded) != encoded.size() || !preview.flush()) {
                result[QStringLiteral("state")] = QStringLiteral("error");
                result[QStringLiteral("message")] = preview.errorString();
            } else {
                preview.setAutoRemove(false);
                const QString temporaryPath = preview.fileName();
                preview.close();
                record = {{QStringLiteral("originalPath"), localPath},
                    {QStringLiteral("temporaryPath"), temporaryPath},
                    {QStringLiteral("originalHash"), QCryptographicHash::hash(original, QCryptographicHash::Sha256)},
                    {QStringLiteral("previewHash"), QCryptographicHash::hash(encoded, QCryptographicHash::Sha256)}};
                result[QStringLiteral("previewUrl")] = QUrl::fromLocalFile(temporaryPath).toString();
            }
        }
        if (guard)
            QMetaObject::invokeMethod(guard.data(), [guard, token, record, result]() {
                if (!guard || !guard->m_imagePreviews.contains(token)) {
                    if (!record.isEmpty()) QFile::remove(record.value(QStringLiteral("temporaryPath")).toString());
                    return;
                }
                if (!record.isEmpty()) guard->m_imagePreviews.insert(token, record);
                else guard->m_imagePreviews.remove(token);
                emit guard->imageCompressionPreviewReady(token, result);
            }, Qt::QueuedConnection);
    });
}

void FileHelper::discardImageCompressionPreview(const QString &token)
{
    const QVariantMap record = m_imagePreviews.take(token);
    const QString path = record.value(QStringLiteral("temporaryPath")).toString();
    if (!path.isEmpty()) QFile::remove(path);
}

QVariantMap FileHelper::applyImageCompressionPreview(const QString &token)
{
    const auto fail = [](const QString &message) {
        return QVariantMap{{QStringLiteral("state"), QStringLiteral("error")},
                           {QStringLiteral("message"), message}};
    };
    const QVariantMap record = m_imagePreviews.value(token);
    const QString path = record.value(QStringLiteral("originalPath")).toString();
    const QString temporaryPath = record.value(QStringLiteral("temporaryPath")).toString();
    if (path.isEmpty() || temporaryPath.isEmpty()) return fail(QStringLiteral("Keine komprimierte Vorschau vorhanden."));
    QFile current(path), preview(temporaryPath);
    if (QFileInfo(path).isSymLink() || !current.open(QIODevice::ReadOnly) || !preview.open(QIODevice::ReadOnly))
        return fail(QStringLiteral("Original oder Vorschau kann nicht gelesen werden."));
    const QByteArray original = current.readAll();
    if (current.error() != QFileDevice::NoError
        || QCryptographicHash::hash(original, QCryptographicHash::Sha256) != record.value(QStringLiteral("originalHash")).toByteArray())
        return fail(QStringLiteral("Das Original wurde inzwischen geändert. Bitte eine neue Vorschau erzeugen."));
    const QByteArray encoded = preview.readAll();
    if (preview.error() != QFileDevice::NoError
        || QCryptographicHash::hash(encoded, QCryptographicHash::Sha256) != record.value(QStringLiteral("previewHash")).toByteArray())
        return fail(QStringLiteral("Die Vorschau wurde inzwischen geändert. Bitte neu komprimieren."));
    current.close();
    preview.close();
    QSaveFile output(path);
    output.setDirectWriteFallback(false);
    if (!output.open(QIODevice::WriteOnly)) return fail(output.errorString());
    if (output.write(encoded) != encoded.size()) {
        const QString error = output.errorString();
        output.cancelWriting();
        return fail(error);
    }
    if (!output.commit()) return fail(output.errorString());
    discardImageCompressionPreview(token);
    emit imageFileReplaced(path);
    return {{QStringLiteral("state"), QStringLiteral("ready")}};
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

bool FileHelper::imageHasTransparency(const QString &path)
{
    const QString filePath = localFilePathFromString(path);
    if (filePath.isEmpty())
        return false;

    QImage image(filePath);
    if (image.isNull() || !image.hasAlphaChannel())
        return false;

    image = image.convertToFormat(QImage::Format_ARGB32);
    for (int y = 0; y < image.height(); ++y) {
        const QRgb *line = reinterpret_cast<const QRgb *>(image.constScanLine(y));
        for (int x = 0; x < image.width(); ++x) {
            if (qAlpha(line[x]) < 255)
                return true;
        }
    }

    return false;
}

bool FileHelper::flattenImageTransparencyOnWhite(const QString &path)
{
    const QString filePath = localFilePathFromString(path);
    if (filePath.isEmpty()) {
        qWarning() << "Transparenz aus: Kein Bildpfad angegeben";
        return false;
    }

    const QImage source(filePath);
    if (source.isNull()) {
        qWarning() << "Transparenz aus: Bild kann nicht geladen werden:" << filePath;
        return false;
    }

    QImage flattened(source.size(), QImage::Format_RGB32);
    flattened.fill(Qt::white);
    {
        QPainter painter(&flattened);
        painter.setCompositionMode(QPainter::CompositionMode_SourceOver);
        painter.drawImage(0, 0, source);
    }

    if (!flattened.save(filePath, "PNG")) {
        qWarning() << "Transparenz aus: Speichern fehlgeschlagen:" << filePath;
        return false;
    }

    qDebug() << "Transparenz durch Weiss ersetzt:" << filePath;
    return true;
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
