#include "imageinformation.h"

#include <QBuffer>
#include <QColorSpace>
#include <QDateTime>
#include <QFileInfo>
#include <QFile>
#include <QSaveFile>
#include <QtEndian>
#include <cmath>
#include <QHash>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>

namespace {
QImage exactPaletteImage(const QImage &source)
{
    if (source.depth() > 32)
        return {}; // Never reduce 16-bit channels to 8-bit palette entries.
    const QImage rgba = source.convertToFormat(QImage::Format_ARGB32);
    QImage indexed(source.size(), QImage::Format_Indexed8);
    if (indexed.isNull())
        return {};
    QHash<QRgb, int> colors;
    QList<QRgb> palette;
    for (int y = 0; y < rgba.height(); ++y) {
        const auto *pixels = reinterpret_cast<const QRgb *>(rgba.constScanLine(y));
        uchar *out = indexed.scanLine(y);
        for (int x = 0; x < rgba.width(); ++x) {
            const QRgb pixel = pixels[x];
            auto found = colors.constFind(pixel);
            if (found == colors.cend()) {
                if (palette.size() == 256)
                    return {}; // No quantization: every color must fit exactly.
                const int index = palette.size();
                palette.append(pixel);
                colors.insert(pixel, index);
                out[x] = uchar(index);
            } else {
                out[x] = uchar(found.value());
            }
        }
    }
    indexed.setColorTable(palette);
    indexed.setColorSpace(source.colorSpace());
    indexed.setDotsPerMeterX(source.dotsPerMeterX());
    indexed.setDotsPerMeterY(source.dotsPerMeterY());
    for (const QString &key : source.textKeys())
        indexed.setText(key, source.text(key));
    return indexed;
}
}

static QVariantMap prepareImage(const QString &filePath, QByteArray &original, QByteArray &bestData)
{
    const QFileInfo before(filePath);
    QVariantMap info{{QStringLiteral("state"), QStringLiteral("error")},
                     {QStringLiteral("sizeBytes"), before.size()}};
    if (!before.isFile()) {
        info[QStringLiteral("message")] = QStringLiteral("Bilddatei nicht gefunden");
        return info;
    }
    QFile input(filePath);
    if (!input.open(QIODevice::ReadOnly)) {
        info[QStringLiteral("message")] = input.errorString();
        return info;
    }
    original = input.readAll();
    if (input.error() != QFileDevice::NoError) {
        info[QStringLiteral("message")] = input.errorString();
        return info;
    }
    input.close();
    QBuffer originalBuffer(&original);
    originalBuffer.open(QIODevice::ReadOnly);
    QImageReader reader(&originalBuffer);
    reader.setDecideFormatFromContent(true); // Some package PNGs have a .jpg suffix.
    if (!reader.canRead()) {
        info[QStringLiteral("message")] = QStringLiteral("Bild kann nicht gelesen werden");
        return info;
    }
    const QByteArray format = reader.format().toLower();
    info[QStringLiteral("format")] = QString::fromLatin1(format).toUpper();
    if (format != "png") {
        info[QStringLiteral("state")] = QStringLiteral("unsupported");
        info[QStringLiteral("message")] = QStringLiteral("Verlustfreie Komprimierung: für %1 nicht ermittelt")
            .arg(QString::fromLatin1(format).toUpper());
        return info;
    }
    bool animated = false;
    // APNG is not recognized as animated by every Qt PNG plugin.
    for (qsizetype pos = 8; pos + 12 <= original.size();) {
        const quint32 length = qFromBigEndian<quint32>(original.constData() + pos);
        if (quint64(length) + 12 > quint64(original.size() - pos)) break;
        const QByteArray type = original.mid(pos + 4, 4);
        if (type == "acTL") animated = true;
        if (type == "IDAT") break;
        pos += qsizetype(length) + 12;
    }
    if (animated || reader.supportsAnimation() || reader.imageCount() > 1) {
        info[QStringLiteral("state")] = QStringLiteral("unsupported");
        info[QStringLiteral("message")] = QStringLiteral("Komprimierung für animierte Bilder nicht ermittelt");
        return info;
    }
    const QImage source = reader.read();
    if (source.isNull()) {
        info[QStringLiteral("message")] = QStringLiteral("Bild kann nicht gelesen werden");
        return info;
    }
    const QImage pixels = source.convertToFormat(QImage::Format_RGBA64);
    qint64 bestSize = before.size();
    bool verified = false;
    const auto tryCandidate = [&](const QImage &candidate) {
        if (candidate.isNull())
            return;
        QByteArray encoded;
        QBuffer buffer(&encoded);
        buffer.open(QIODevice::WriteOnly);
        QImageWriter writer(&buffer, "png");
        // Qt's PNG compression scale is 0..100, independent of image quality.
        writer.setCompression(100);
        if (!writer.write(candidate))
            return;
        const QImage decoded = QImage::fromData(encoded, "png");
        if (decoded.isNull() || decoded.size() != source.size()
            || decoded.convertToFormat(QImage::Format_RGBA64) != pixels
            || decoded.colorSpace() != source.colorSpace())
            return;
        if (decoded.dotsPerMeterX() != source.dotsPerMeterX()
            || decoded.dotsPerMeterY() != source.dotsPerMeterY()) return;
        for (const QString &key : source.textKeys())
            if (decoded.text(key) != source.text(key)) return;
        verified = true;
        if (encoded.size() < bestSize) {
            bestSize = encoded.size();
            bestData = encoded;
        }
    };
    tryCandidate(source);
    tryCandidate(exactPaletteImage(source));
    if (source.depth() <= 32 && !source.hasAlphaChannel())
        tryCandidate(source.convertToFormat(QImage::Format_RGB32));

    const QFileInfo after(filePath);
    if (before.size() != after.size() || before.lastModified() != after.lastModified()) {
        info[QStringLiteral("message")] = QStringLiteral("Bild wurde während der Prüfung geändert – erneut öffnen");
        return info;
    }
    if (!verified) {
        info[QStringLiteral("message")] = QStringLiteral("Verlustfreie Komprimierung konnte nicht geprüft werden");
        return info;
    }
    const qint64 saving = qMax(qint64(0), before.size() - bestSize);
    info[QStringLiteral("state")] = QStringLiteral("ready");
    info[QStringLiteral("compressedBytes")] = bestSize;
    info[QStringLiteral("savingBytes")] = saving;
    info[QStringLiteral("savingPercent")] = before.size() > 0 ? 100.0 * saving / before.size() : 0.0;
    return info;
}

QVariantMap analyzeImageInformation(const QString &filePath)
{
    QByteArray original, bestData;
    return prepareImage(filePath, original, bestData);
}

QVariantMap compressImageLosslessly(const QString &filePath)
{
    QByteArray original, bestData;
    QVariantMap info = prepareImage(filePath, original, bestData);
    if (info.value(QStringLiteral("state")) != QStringLiteral("ready") || bestData.isEmpty())
        return info;
    const auto fail = [&info](const QString &message) {
        info[QStringLiteral("state")] = QStringLiteral("error");
        info[QStringLiteral("message")] = message;
        return info;
    };
    QFile current(filePath);
    if (QFileInfo(filePath).isSymLink() || !current.open(QIODevice::ReadOnly))
        return fail(QStringLiteral("Originaldatei kann nicht sicher ersetzt werden"));
    const QByteArray contents = current.readAll();
    if (current.error() != QFileDevice::NoError || contents != original)
        return fail(QStringLiteral("Originaldatei wurde während der Prüfung geändert"));
    current.close();
    QSaveFile output(filePath);
    output.setDirectWriteFallback(false); // Keep the original intact if saving fails.
    if (!output.open(QIODevice::WriteOnly)) return fail(output.errorString());
    if (output.write(bestData) != bestData.size()) {
        const QString error = output.errorString();
        output.cancelWriting();
        return fail(error);
    }
    if (!output.commit()) return fail(output.errorString());
    info[QStringLiteral("state")] = QStringLiteral("compressed");
    return info;
}

QVariantMap prepareImageCompressionPreview(const QString &filePath, int quality,
                                          QByteArray &original, QByteArray &encoded)
{
    QVariantMap info{{QStringLiteral("state"), QStringLiteral("error")}};
    QFile input(filePath);
    if (!input.open(QIODevice::ReadOnly)) {
        info[QStringLiteral("message")] = input.errorString();
        return info;
    }
    original = input.readAll();
    if (input.error() != QFileDevice::NoError) {
        info[QStringLiteral("message")] = input.errorString();
        return info;
    }
    input.close();
    QBuffer buffer(&original);
    buffer.open(QIODevice::ReadOnly);
    QImageReader reader(&buffer);
    reader.setDecideFormatFromContent(true);
    const QByteArray format = reader.format().toLower();
    if (format != "png" && format != "jpeg" && format != "jpg" && format != "webp") {
        info[QStringLiteral("message")] = QStringLiteral("Vorschau-Komprimierung unterstützt PNG, JPEG und WebP.");
        return info;
    }
    bool animated = reader.supportsAnimation() || reader.imageCount() > 1;
    if (format == "png") {
        for (qsizetype pos = 8; pos + 12 <= original.size();) {
            const quint32 length = qFromBigEndian<quint32>(original.constData() + pos);
            if (quint64(length) + 12 > quint64(original.size() - pos)) break;
            const QByteArray type = original.mid(pos + 4, 4);
            if (type == "acTL") animated = true;
            if (type == "IDAT") break;
            pos += qsizetype(length) + 12;
        }
    }
    if (animated) {
        info[QStringLiteral("message")] = QStringLiteral("Animierte Bilder werden nicht verändert.");
        return info;
    }
    // Orientation metadata must not disappear when JPEGs are re-encoded.
    reader.setAutoTransform(true);
    const QImage source = reader.read();
    if (source.isNull()) {
        info[QStringLiteral("message")] = reader.errorString();
        return info;
    }
    quality = qBound(10, quality, 100);
    QImage candidate = source;
    if (format == "png" && quality < 100) {
        // PNG has no JPEG-style quality setting. Reduce RGB precision only;
        // retain resolution, alpha (including 16-bit alpha), profile and annotations.
        const int step = qMax(1, qRound(std::pow(2.0, (100 - quality) / 15.0)));
        if (source.depth() > 32) {
            candidate = source.convertToFormat(QImage::Format_RGBA64);
            const int deepStep = step * 257;
            const auto channel = [deepStep](int v) {
                return quint16(qMin(65535, ((v + deepStep / 2) / deepStep) * deepStep));
            };
            for (int y = 0; y < candidate.height(); ++y) {
                auto *row = reinterpret_cast<QRgba64 *>(candidate.scanLine(y));
                for (int x = 0; x < candidate.width(); ++x) {
                    const QRgba64 p = row[x];
                    row[x] = QRgba64::fromRgba64(channel(p.red()), channel(p.green()), channel(p.blue()), p.alpha());
                }
            }
        } else {
            candidate = source.convertToFormat(QImage::Format_ARGB32);
            const auto channel = [step](int v) { return qMin(255, ((v + step / 2) / step) * step); };
            for (int y = 0; y < candidate.height(); ++y) {
                auto *row = reinterpret_cast<QRgb *>(candidate.scanLine(y));
                for (int x = 0; x < candidate.width(); ++x) {
                    const QRgb p = row[x];
                    row[x] = qRgba(channel(qRed(p)), channel(qGreen(p)), channel(qBlue(p)), qAlpha(p));
                }
            }
        }
    }
    QString error;
    const auto encode = [&](const QImage &image) {
        if (image.isNull()) return;
        QByteArray data;
        QBuffer output(&data);
        output.open(QIODevice::WriteOnly);
        QImageWriter writer(&output, format);
        if (format == "png") writer.setCompression(100);
        else writer.setQuality(quality);
        if (!writer.write(image)) { error = writer.errorString(); return; }
        const QImage decoded = QImage::fromData(data, format.constData());
        if (decoded.isNull() || decoded.size() != source.size()) {
            error = QStringLiteral("Komprimiertes Bild konnte nicht geprüft werden.");
            return;
        }
        if (format == "png" && (decoded.convertToFormat(QImage::Format_RGBA64)
                                  != candidate.convertToFormat(QImage::Format_RGBA64)
                                || decoded.colorSpace() != source.colorSpace())) {
            error = QStringLiteral("PNG-Prüfung fehlgeschlagen.");
            return;
        }
        if (encoded.isEmpty() || data.size() < encoded.size()) encoded = data;
    };
    encode(candidate);
    if (format == "png") {
        encode(exactPaletteImage(candidate));
        if (quality == 100 && (encoded.isEmpty() || original.size() < encoded.size()))
            encoded = original;
    }
    if (encoded.isEmpty()) {
        info[QStringLiteral("message")] = error;
        return info;
    }
    info[QStringLiteral("state")] = QStringLiteral("ready");
    info[QStringLiteral("quality")] = quality;
    info[QStringLiteral("format")] = QString::fromLatin1(format);
    info[QStringLiteral("originalBytes")] = original.size();
    info[QStringLiteral("sizeBytes")] = encoded.size();
    return info;
}
