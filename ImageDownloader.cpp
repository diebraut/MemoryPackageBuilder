#include "ImageDownloader.h"

#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QNetworkReply>
#include <QDebug>
#include <QImageWriter>
#include <QColor>
#include <QHash>

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

    QHash<int, int> hist;
    hist.reserve((w + h) * 2 / step + 4);

    auto addEdgePixel = [&](int x, int y) {
        hist[keyOf(img.pixel(x, y))]++;
    };

    for (int x = 0; x < w; x += step) {
        addEdgePixel(x, 0);
        addEdgePixel(x, h - 1);
    }

    for (int y = 0; y < h; y += step) {
        addEdgePixel(0, y);
        addEdgePixel(w - 1, y);
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

    for (int x = 0; x < w; x += step) {
        QRgb c1 = img.pixel(x, 0);

        if (inBin(c1)) {
            tr += qRed(c1);
            tg += qGreen(c1);
            tb += qBlue(c1);
            count++;
        }

        QRgb c2 = img.pixel(x, h - 1);

        if (inBin(c2)) {
            tr += qRed(c2);
            tg += qGreen(c2);
            tb += qBlue(c2);
            count++;
        }
    }

    for (int y = 0; y < h; y += step) {
        QRgb c1 = img.pixel(0, y);

        if (inBin(c1)) {
            tr += qRed(c1);
            tg += qGreen(c1);
            tb += qBlue(c1);
            count++;
        }

        QRgb c2 = img.pixel(w - 1, y);

        if (inBin(c2)) {
            tr += qRed(c2);
            tg += qGreen(c2);
            tb += qBlue(c2);
            count++;
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
// Hintergrundfarbe transparent machen
//
// Wichtig:
// Es gibt KEINEN weichen Alpha-Übergang mehr.
//
// Pixel nahe der Hintergrundfarbe:
//     alpha = 0
//
// Alle anderen Pixel:
//     alpha = 255
//
// RGB-Werte des eigentlichen Inhalts bleiben unverändert.
// Dadurch bleiben Schrift, Linien und Grafiken scharf.
// ---------------------------------------------------------------------

static void colorToAlphaAgainstBg(QImage &img,
                                  const QColor &bg,
                                  int tolerance = 10)
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

    const int toleranceSquared =
        tolerance * tolerance;

    for (int y = 0; y < h; ++y) {

        QRgb *line =
            reinterpret_cast<QRgb *>(img.scanLine(y));

        for (int x = 0; x < w; ++x) {

            const QRgb pixel = line[x];

            const int r = qRed(pixel);
            const int g = qGreen(pixel);
            const int b = qBlue(pixel);

            const int dr = r - br;
            const int dg = g - bgc;
            const int db = b - bb;

            const int distanceSquared =
                dr * dr +
                dg * dg +
                db * db;

            if (distanceSquared <= toleranceSquared) {

                // Hintergrund vollständig transparent.
                //
                // RGB trotzdem erhalten. Das vermeidet unnötige
                // Farbänderungen im Bild.
                line[x] = qRgba(
                    r,
                    g,
                    b,
                    0
                    );

            } else {

                // Inhalt vollständig deckend lassen.
                //
                // Besonders wichtig für Schrift-Antialiasing,
                // dünne Linien und kleine Symbole.
                line[x] = qRgba(
                    r,
                    g,
                    b,
                    255
                    );
            }
        }
    }
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
            << "tolerance = 10";

        /*
         * Nur echte bzw. sehr ähnliche Hintergrundpixel entfernen.
         *
         * Kein Alpha-Verlauf und keine RGB-Farbkorrektur.
         */
        colorToAlphaAgainstBg(
            img,
            bg,
            10
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
