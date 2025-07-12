// FileHelper.cpp
#include "FileHelper.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>


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
