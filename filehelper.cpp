// FileHelper.cpp
#include "FileHelper.h"
#include <QFile>

bool FileHelper::removeFile(const QString &path) {
    return QFile::remove(path);
}

bool FileHelper::renameFile(const QString &oldPath, const QString &newPath) {
    return QFile::rename(oldPath, newPath);
}

bool FileHelper::fileExists(const QString &path) {
    return QFile::exists(path);
}
