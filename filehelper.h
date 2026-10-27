// FileHelper.h
#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QObject>
#include <QThreadPool>
#include <QHash>
#include <QTemporaryDir>
#include <QVariantMap>

class FileHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool imageCompressionRunning READ imageCompressionRunning NOTIFY imageCompressionRunningChanged)
public:
    explicit FileHelper(QObject *parent = nullptr);
    Q_INVOKABLE void requestImageInformation(const QString &path, const QString &requestToken);
    Q_INVOKABLE void requestImageCompressionPreview(const QString &path, int quality, const QString &token);
    Q_INVOKABLE void discardImageCompressionPreview(const QString &token);
    Q_INVOKABLE QVariantMap applyImageCompressionPreview(const QString &token);
    bool imageCompressionRunning() const { return m_imageCompressionRunning; }
    Q_INVOKABLE bool compressPackageImages(const QString &path);
    Q_INVOKABLE static bool removeFile(const QString &path);
    Q_INVOKABLE static bool renameFile(const QString &oldPath, const QString &newPath);
    Q_INVOKABLE static bool fileExists(const QString &path);
    Q_INVOKABLE bool removeFilesWithSameBaseName(const QString& filePath);
    Q_INVOKABLE bool removeTMPFiles(const QString &path);
    Q_INVOKABLE QString saveClipboardImageTemporary(const QString &path, const QString &baseName, int partIndex);
    Q_INVOKABLE bool clipboardHasImage();
    Q_INVOKABLE bool imageHasTransparency(const QString &path);
    Q_INVOKABLE bool flattenImageTransparencyOnWhite(const QString &path);
    Q_INVOKABLE bool makeImageColorTransparent(const QString &path, int imageX, int imageY);
    // ✅ NEU
    Q_INVOKABLE static QStringList directoryEntries(const QString &path);

signals:
    void imageCompressionPreviewReady(const QString &token, const QVariantMap &result);
    void imageFileReplaced(const QString &path);
    void imageCompressionRunningChanged();
    void imageCompressionProgress(int processed, int total, const QString &fileName);
    void imageCompressionFinished(const QVariantMap &summary);
    void imageCompressionFileFinished(const QString &fileName, const QVariantMap &result);
    void imageInformationReady(const QString &requestToken, const QVariantMap &information);

private:
    // The pool is destroyed first, so all jobs finish before preview files are removed.
    QTemporaryDir m_imagePreviewDirectory;
    QHash<QString, QVariantMap> m_imagePreviews;
    QThreadPool m_imageInformationPool;
    bool m_imageCompressionRunning = false;

};

#endif // FILEHELPER_H
