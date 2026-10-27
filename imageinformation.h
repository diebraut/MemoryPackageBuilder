#ifndef IMAGEINFORMATION_H
#define IMAGEINFORMATION_H

#include <QString>
#include <QByteArray>
#include <QVariantMap>

// Read-only analysis. No image or package file is written.
QVariantMap analyzeImageInformation(const QString &filePath);

// Atomically replace only when a smaller, pixel-identical PNG is available.
QVariantMap compressImageLosslessly(const QString &filePath);

// Encode a preview without touching the source. Quality is 10..100.
QVariantMap prepareImageCompressionPreview(const QString &filePath, int quality,
                                          QByteArray &original, QByteArray &encoded);

#endif
