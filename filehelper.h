// FileHelper.h
#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QObject>

class FileHelper : public QObject
{
    Q_OBJECT
public:
    Q_INVOKABLE static bool removeFile(const QString &path);
    Q_INVOKABLE static bool renameFile(const QString &oldPath, const QString &newPath);
    Q_INVOKABLE static bool fileExists(const QString &path);
    Q_INVOKABLE bool removeFilesWithSameBaseName(const QString& filePath);
    Q_INVOKABLE bool removeTMPFiles(const QString &path);
    // ✅ NEU
    Q_INVOKABLE static QStringList directoryEntries(const QString &path);


};

#endif // FILEHELPER_H
