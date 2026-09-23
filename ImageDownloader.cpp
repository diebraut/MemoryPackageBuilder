#include "ImageDownloader.h"

#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QNetworkReply>
#include <QDebug>
#include <QImageWriter>
#include <QColor>
#include <QHash>
#include <QBuffer>
#include <QQueue>
#include <QVector>

ImageDownloader::ImageDownloader(QObject *parent)
    : QObject(parent)
{
    // Kein globaler Slot nötig
}

void ImageDownloader::downloadImage(const QString &url,
                                    const QString &savePath)
{
    QUrl qurl(url);

    if (!qurl.isValid()) {
        emit downloadFailed("Ungültige URL");
        return;
    }

    QNetworkRequest request(qurl);
    QNetworkReply *reply = manager.get(request);

    connect(reply,
            &QNetworkReply::finished,
            this,
            [reply, savePath, this]() {

                if (reply->error() != QNetworkReply::NoError) {
                    emit downloadFailed(
                        "Netzwerkfehler: " + reply->errorString()
                        );

                    reply->deleteLater();
                    return;
                }

                QByteArray data = reply->readAll();

                qDebug() << "SavePath =" << savePath;

                QFile file(savePath);

                if (!file.open(QIODevice::WriteOnly)) {
                    emit downloadFailed(
                        "Fehler beim Öffnen der Datei: "
                        + file.errorString()
                        );

                    reply->deleteLater();
                    return;
                }

                file.write(data);
                file.close();

                qDebug() << "✅ Bild gespeichert unter:" << savePath;

                emit downloadSucceeded(savePath);

                reply->deleteLater();
            });
}


// ---------------------------------------------------------------------
// Dominante Randfarbe bestimmen
// ---------------------------------------------------------------------

static QColor detectDominantEdgeColor(const QImage &img,
                                      int step = 2)
{
    const int w = img.width();
    const int h = img.height();

    if (w <= 0 || h <= 0)
        return QColor(255, 255, 255);

    // 5 Bits pro Kanal = 32 Stufen.
    // Dadurch ist die Erkennung robust gegen geringes Rauschen.
    auto keyOf = [](QRgb c) {
        const int r = qRed(c)   >> 3;
        const int g = qGreen(c) >> 3;
        const int b = qBlue(c)  >> 3;

        return (r << 10) | (g << 5) | b;
    };

    // Nicht nur die aeusserste Pixelreihe betrachten: Liegt die Auswahl
    // exakt auf einer Rahmenlinie, soll die wenige Pixel weiter innen
    // liegende Hintergrundfarbe trotzdem erkannt werden.
    const int edgeDepth = qMax(1, qMin(6, qMin(w, h) / 4));

    QHash<int, int> hist;
    hist.reserve((w + h) * edgeDepth / step + 4);

    auto addEdgePixel = [&](int x, int y) {
        hist[keyOf(img.pixel(x, y))]++;
    };

    for (int depth = 0; depth < edgeDepth; ++depth) {
        for (int x = 0; x < w; x += step) {
            addEdgePixel(x, depth);
            addEdgePixel(x, h - 1 - depth);
        }
        for (int y = 0; y < h; y += step) {
            addEdgePixel(depth, y);
            addEdgePixel(w - 1 - depth, y);
        }
    }

    int bestKey = 0;
    int bestCount = -1;

    for (auto it = hist.constBegin();
         it != hist.constEnd();
         ++it) {

        if (it.value() > bestCount) {
            bestCount = it.value();
            bestKey = it.key();
        }
    }

    // Exakte Durchschnittsfarbe innerhalb des dominanten Bins.
    int tr = 0;
    int tg = 0;
    int tb = 0;
    int count = 0;

    const int br = (bestKey >> 10) & 31;
    const int bg = (bestKey >> 5) & 31;
    const int bb = bestKey & 31;

    auto inBin = [&](QRgb c) {
        return ((qRed(c) >> 3) == br)
        && ((qGreen(c) >> 3) == bg)
            && ((qBlue(c) >> 3) == bb);
    };

    for (int depth = 0; depth < edgeDepth; ++depth) {
        for (int x = 0; x < w; x += step) {
            const QRgb c1 = img.pixel(x, depth);
            if (inBin(c1)) {
                tr += qRed(c1);
                tg += qGreen(c1);
                tb += qBlue(c1);
                count++;
            }

            const QRgb c2 = img.pixel(x, h - 1 - depth);
            if (inBin(c2)) {
                tr += qRed(c2);
                tg += qGreen(c2);
                tb += qBlue(c2);
                count++;
            }
        }

        for (int y = 0; y < h; y += step) {
            const QRgb c1 = img.pixel(depth, y);
            if (inBin(c1)) {
                tr += qRed(c1);
                tg += qGreen(c1);
                tb += qBlue(c1);
                count++;
            }

            const QRgb c2 = img.pixel(w - 1 - depth, y);
            if (inBin(c2)) {
                tr += qRed(c2);
                tg += qGreen(c2);
                tb += qBlue(c2);
                count++;
            }
        }
    }

    if (count == 0)
        return QColor(255, 255, 255);

    return QColor(
        tr / count,
        tg / count,
        tb / count
        );
}


// ---------------------------------------------------------------------
// Nur farblich passende Pixel entfernen, die ueber gleichfarbige Nachbarn mit
// dem Bildrand verbunden sind. Gleichfarbige Flaechen innerhalb des Motivs
// bleiben dadurch erhalten.
// ---------------------------------------------------------------------

static void edgeConnectedColorToAlpha(QImage &img,
                                      const QColor &bg,
                                      int tolerance = 18)
{
    if (img.isNull())
        return;

    if (img.format() != QImage::Format_ARGB32)
        img = img.convertToFormat(QImage::Format_ARGB32);

    const int w = img.width();
    const int h = img.height();

    const int br = bg.red();
    const int bgc = bg.green();
    const int bb = bg.blue();

    const int toleranceSquared = tolerance * tolerance;
    const int pixelCount = w * h;
    const int seedDepth = qMax(1, qMin(6, qMin(w, h) / 4));
    QVector<quint8> visited(pixelCount, 0);
    QQueue<int> pending;

    auto matchesBackground = [&](int x, int y) {
        const QRgb pixel = img.pixel(x, y);
        const int dr = qRed(pixel) - br;
        const int dg = qGreen(pixel) - bgc;
        const int db = qBlue(pixel) - bb;
        return dr * dr + dg * dg + db * db <= toleranceSquared;
    };

    auto enqueue = [&](int x, int y) {
        const int index = y * w + x;
        if (visited[index] || !matchesBackground(x, y))
            return;
        visited[index] = 1;
        pending.enqueue(index);
    };

    // Aus einem schmalen Randstreifen starten. So kann eine Rahmenlinie auf
    // der exakten Auswahlkante die innenliegende Hintergrundflaeche nicht
    // von der Transparenzsuche abschneiden.
    for (int depth = 0; depth < seedDepth; ++depth) {
        for (int x = 0; x < w; ++x) {
            enqueue(x, depth);
            enqueue(x, h - 1 - depth);
        }
        for (int y = 0; y < h; ++y) {
            enqueue(depth, y);
            enqueue(w - 1 - depth, y);
        }
    }

    while (!pending.isEmpty()) {
        const int index = pending.dequeue();
        const int x = index % w;
        const int y = index / w;
        const QRgb pixel = img.pixel(x, y);
        img.setPixel(x, y, qRgba(qRed(pixel), qGreen(pixel), qBlue(pixel), 0));

        if (x > 0)
            enqueue(x - 1, y);
        if (x + 1 < w)
            enqueue(x + 1, y);
        if (y > 0)
            enqueue(x, y - 1);
        if (y + 1 < h)
            enqueue(x, y + 1);
    }
}

static QColor detectDominantColorOutsideRect(const QImage &img,
                                             const QRect &excludedRect,
                                             int step = 2)
{
    QHash<int, int> histogram;
    auto keyOf = [](QRgb color) {
        return ((qRed(color) >> 3) << 10)
            | ((qGreen(color) >> 3) << 5)
            | (qBlue(color) >> 3);
    };

    for (int y = 0; y < img.height(); y += step) {
        for (int x = 0; x < img.width(); x += step) {
            if (!excludedRect.contains(x, y))
                ++histogram[keyOf(img.pixel(x, y))];
        }
    }

    if (histogram.isEmpty())
        return detectDominantEdgeColor(img, step);

    int bestKey = 0;
    int bestCount = -1;
    for (auto it = histogram.constBegin(); it != histogram.constEnd(); ++it) {
        if (it.value() > bestCount) {
            bestKey = it.key();
            bestCount = it.value();
        }
    }

    const int binR = (bestKey >> 10) & 31;
    const int binG = (bestKey >> 5) & 31;
    const int binB = bestKey & 31;
    qint64 totalR = 0;
    qint64 totalG = 0;
    qint64 totalB = 0;
    int count = 0;

    for (int y = 0; y < img.height(); y += step) {
        for (int x = 0; x < img.width(); x += step) {
            if (excludedRect.contains(x, y))
                continue;
            const QRgb color = img.pixel(x, y);
            if ((qRed(color) >> 3) != binR
                || (qGreen(color) >> 3) != binG
                || (qBlue(color) >> 3) != binB) {
                continue;
            }
            totalR += qRed(color);
            totalG += qGreen(color);
            totalB += qBlue(color);
            ++count;
        }
    }

    if (count == 0)
        return detectDominantEdgeColor(img, step);
    return QColor(totalR / count, totalG / count, totalB / count);
}


// ---------------------------------------------------------------------
// Farbe an einer Fensterposition abfragen
// ---------------------------------------------------------------------

QString ImageDownloader::sampleWindowColor(QQuickWindow *window,
                                           int x,
                                           int y)
{
    if (!window)
        return QString();

    QImage fb = window->grabWindow();

    if (fb.isNull())
        return QString();

    const qreal dpr =
        fb.devicePixelRatio() > 0
            ? fb.devicePixelRatio()
            : 1.0;

    const int px = qRound(x * dpr);
    const int py = qRound(y * dpr);

    if (px < 0 ||
        py < 0 ||
        px >= fb.width() ||
        py >= fb.height()) {

        return QString();
    }

    return QColor::fromRgb(
               fb.pixel(px, py)
               ).name(QColor::HexRgb);
}

QVariantMap ImageDownloader::grabTransparentPreview(QQuickWindow *window,
                                                    int x,
                                                    int y,
                                                    int w,
                                                    int h,
                                                    const QString &transparentColor,
                                                    int imageX,
                                                    int imageY,
                                                    int imageW,
                                                    int imageH)
{
    QVariantMap result;
    if (!window || w <= 0 || h <= 0)
        return result;

    QImage frame = window->grabWindow();
    if (frame.isNull())
        return result;

    const qreal dpr = frame.devicePixelRatio() > 0 ? frame.devicePixelRatio() : 1.0;
    QRect crop(qRound(x * dpr), qRound(y * dpr), qRound(w * dpr), qRound(h * dpr));
    crop = crop.intersected(QRect(QPoint(0, 0), frame.size()));
    if (crop.isEmpty())
        return result;

    QImage preview = frame.copy(crop).convertToFormat(QImage::Format_ARGB32);
    preview.setDevicePixelRatio(1.0);

    QColor background(transparentColor);
    if (!background.isValid()) {
        const QRect imageRectInPreview(
            qRound((imageX - x) * dpr),
            qRound((imageY - y) * dpr),
            qRound(imageW * dpr),
            qRound(imageH * dpr));
        background = imageW > 0 && imageH > 0
            ? detectDominantColorOutsideRect(preview, imageRectInPreview)
            : detectDominantEdgeColor(preview);
    }
    result.insert(QStringLiteral("backgroundColor"), background.name(QColor::HexRgb));
    edgeConnectedColorToAlpha(preview, background, 18);

    QByteArray png;
    QBuffer buffer(&png);
    if (!buffer.open(QIODevice::WriteOnly) || !preview.save(&buffer, "PNG"))
        return QVariantMap();

    result.insert(QStringLiteral("source"),
                  QStringLiteral("data:image/png;base64,")
                      + QString::fromLatin1(png.toBase64()));
    return result;
}

bool ImageDownloader::saveDataUrlImage(const QString &dataUrl,
                                       const QString &path)
{
    const int comma = dataUrl.indexOf(QLatin1Char(','));
    if (comma < 0) {
        emit downloadFailed(QStringLiteral("Transparenzvorschau ist ungültig"));
        return false;
    }

    const QByteArray encoded = dataUrl.mid(comma + 1).toLatin1();
    const QByteArray png = QByteArray::fromBase64(encoded);
    QImage image;
    if (png.isEmpty() || !image.loadFromData(png, "PNG")) {
        emit downloadFailed(QStringLiteral("Transparenzvorschau konnte nicht gelesen werden"));
        return false;
    }

    const QFileInfo fi(path);
    const QString outPath = fi.path() + QLatin1Char('/')
                            + fi.completeBaseName() + QStringLiteral(".png");
    QImageWriter writer(outPath, "png");
    writer.setCompression(9);
    if (!writer.write(image)) {
        emit downloadFailed(QStringLiteral("Transparenzvorschau konnte nicht gespeichert werden"));
        return false;
    }

    emit downloadSucceeded(outPath);
    return true;
}


// ---------------------------------------------------------------------
// Fenster aufnehmen, ausschneiden und speichern
// ---------------------------------------------------------------------

bool ImageDownloader::grabAndSaveCropped(
    QQuickWindow *window,
    int x,
    int y,
    int w,
    int h,
    const QString &path,
    bool transparentBackground,
    const QString &transparentColor)
{
    if (!window || w <= 0 || h <= 0) {

        qWarning()
        << "grabAndSaveCropped: invalid args";

        return false;
    }

    // Qt Quick Fenster vollständig rendern.
    QImage fb = window->grabWindow();

    if (fb.isNull()) {

        qWarning()
        << "grabAndSaveCropped: grabWindow() returned null";

        return false;
    }

    // -------------------------------------------------------------
    // HiDPI:
    // QML-Koordinaten sind DIP,
    // QImage arbeitet mit Device-Pixeln.
    // -------------------------------------------------------------

    const qreal dpr =
        fb.devicePixelRatio() > 0
            ? fb.devicePixelRatio()
            : 1.0;

    QRect crop(
        qRound(x * dpr),
        qRound(y * dpr),
        qRound(w * dpr),
        qRound(h * dpr)
        );

    crop = crop.intersected(
        QRect(QPoint(0, 0), fb.size())
        );

    if (crop.isEmpty()) {

        qWarning()
        << "grabAndSaveCropped: crop empty after clamp";

        return false;
    }

    QImage img =
        fb.copy(crop)
            .convertToFormat(QImage::Format_ARGB32);

    // Datei soll normale Pixelmaße erhalten.
    img.setDevicePixelRatio(1.0);

    // -------------------------------------------------------------
    // Optional Hintergrund entfernen
    // -------------------------------------------------------------

    if (transparentBackground) {

        QColor bg(transparentColor);

        // Falls keine Farbe über die Pipette angegeben wurde,
        // dominante Randfarbe automatisch bestimmen.
        if (!bg.isValid())
            bg = detectDominantEdgeColor(img);

        qDebug()
            << "Transparent background:"
            << bg.name()
            << "tolerance = 18";

        /*
         * Nur echte bzw. sehr ähnliche Hintergrundpixel entfernen.
         *
         * Kein Alpha-Verlauf und keine RGB-Farbkorrektur.
         */
        edgeConnectedColorToAlpha(
            img,
            bg,
            18
            );
    }

    // -------------------------------------------------------------
    // Immer PNG speichern
    // -------------------------------------------------------------

    QFileInfo fi(path);

    const QString outPath =
        fi.path()
        + "/"
        + fi.completeBaseName()
        + ".png";

    QImageWriter writer(
        outPath,
        "png"
        );

    writer.setCompression(9);

    if (!writer.write(img)) {

        qWarning()
        << "grabAndSaveCropped: write failed:"
        << writer.errorString()
        << "->"
        << outPath;

        emit downloadFailed(
            "Screenshot fehlgeschlagen"
            );

        return false;
    }

    qDebug()
        << "✅ Saved PNG:"
        << outPath
        << img.size()
        << (transparentBackground
                ? "(transparent)"
                : "");

    emit downloadSucceeded(outPath);

    return true;
}
