#include "ImageDownloader.h"
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QNetworkReply>
#include <QDebug>
#include <QImageWriter>

ImageDownloader::ImageDownloader(QObject *parent)
    : QObject(parent)
{
    // Kein globaler Slot nötig
}

void ImageDownloader::downloadImage(const QString &url, const QString &savePath)
{
    QUrl qurl(url);
    if (!qurl.isValid()) {
        emit downloadFailed("Ungültige URL");
        return;
    }

    QNetworkRequest request(qurl);
    QNetworkReply* reply = manager.get(request);

    // Pro-Request-Handling mit Lambda
    connect(reply, &QNetworkReply::finished, this, [reply, savePath, this]() {
        if (reply->error() != QNetworkReply::NoError) {
            emit downloadFailed("Netzwerkfehler: " + reply->errorString());
            reply->deleteLater();
            return;
        }

        QByteArray data = reply->readAll();
        QFile file(savePath);
        if (!file.open(QIODevice::WriteOnly)) {
            emit downloadFailed("Fehler beim Öffnen der Datei: " + file.errorString());
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


// --- 1) Dominante Randfarbe robust bestimmen (farb-quantisierte Histogramm) ---
static QColor detectDominantEdgeColor(const QImage &img, int step = 2)
{
    const int w = img.width(), h = img.height();
    if (w <= 0 || h <= 0) return QColor(255,255,255);

    // 5 Bits pro Kanal (32 Stufen) → robust gegen Rauschen
    auto keyOf = [](QRgb c){
        int r = qRed(c)   >> 3;
        int g = qGreen(c) >> 3;
        int b = qBlue(c)  >> 3;
        return (r<<10) | (g<<5) | b;
    };

    QHash<int,int> hist; hist.reserve((w+h)*2/step+4);
    auto addEdgeLine = [&](int x, int y){ hist[keyOf(img.pixel(x,y))]++; };

    for (int x=0; x<w; x+=step) { addEdgeLine(x,0); addEdgeLine(x,h-1); }
    for (int y=0; y<h; y+=step) { addEdgeLine(0,y); addEdgeLine(w-1,y); }

    int bestKey = 0, bestCount = -1;
    for (auto it = hist.constBegin(); it != hist.constEnd(); ++it)
        if (it.value() > bestCount) { bestCount = it.value(); bestKey = it.key(); }

    // Feineres Mittel im gefundenen Bin
    int tr=0,tg=0,tb=0,cnt=0;
    int br = (bestKey>>10)&31, bg=(bestKey>>5)&31, bb=bestKey&31;
    auto inBin = [&](QRgb c){
        return ((qRed(c)>>3)==br) && ((qGreen(c)>>3)==bg) && ((qBlue(c)>>3)==bb);
    };

    for (int x=0; x<w; x+=step) {
        QRgb c1 = img.pixel(x,0);     if (inBin(c1)) { tr+=qRed(c1); tg+=qGreen(c1); tb+=qBlue(c1); cnt++; }
        QRgb c2 = img.pixel(x,h-1);   if (inBin(c2)) { tr+=qRed(c2); tg+=qGreen(c2); tb+=qBlue(c2); cnt++; }
    }
    for (int y=0; y<h; y+=step) {
        QRgb c1 = img.pixel(0,y);     if (inBin(c1)) { tr+=qRed(c1); tg+=qGreen(c1); tb+=qBlue(c1); cnt++; }
        QRgb c2 = img.pixel(w-1,y);   if (inBin(c2)) { tr+=qRed(c2); tg+=qGreen(c2); tb+=qBlue(c2); cnt++; }
    }

    if (cnt == 0) return QColor(255,255,255);
    return QColor(tr/cnt, tg/cnt, tb/cnt);
}

// --- 2) „Color-to-Alpha“ per Distanz zur Randfarbe (weiche Kanten, text bleibt) ---
//   t0 = Distanz (RGB) ab der es transparent wird
//   t1 = Distanz ab der es voll deckend bleibt
static void colorToAlphaAgainstBg(QImage &img, const QColor &bg, int t0 = 8, int t1 = 40, double gamma = 1.2)
{
    if (img.isNull()) return;

    if (img.format() != QImage::Format_ARGB32 &&
        img.format() != QImage::Format_ARGB32_Premultiplied)
        img = img.convertToFormat(QImage::Format_ARGB32);

    const int w = img.width(), h = img.height();
    const int br = bg.red(), bgc = bg.green(), bb = bg.blue();
    const double invRange = (t1 > t0) ? 1.0 / (t1 - t0) : 1.0;

    for (int y=0; y<h; ++y) {
        QRgb *line = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x=0; x<w; ++x) {
            const int r = qRed(line[x]);
            const int g = qGreen(line[x]);
            const int b = qBlue(line[x]);

            // euklidische Distanz zur Randfarbe
            const double dr = double(r - br);
            const double dg = double(g - bgc);
            const double db = double(b - bb);
            const double d = std::sqrt(dr*dr + dg*dg + db*db); // 0..~441

            // weiche Alpha-Maske aus Distanz
            double a;
            if (d <= t0)        a = 0.0;                         // Hintergrund → voll transparent
            else if (d >= t1)   a = 1.0;                         // weit weg vom HG → voll deckend (Text)
            else                a = (d - t0) * invRange;         // Übergangsbereich

            if (gamma != 1.0 && gamma > 0.0) {
                a = std::pow(a, gamma);                          // Kante schärfen/weicher machen
            }
            a = std::clamp(a, 0.0, 1.0);

            // Farbkompensation (ungefähr): ziele Richtung „entmischte“ Farbe
            // (leicht, damit Kante nicht ausbleicht)
            const double aa = a;
            const int nr = int((r - (1.0-aa)*br) / (aa>0 ? aa : 1.0));
            const int ng = int((g - (1.0-aa)*bgc) / (aa>0 ? aa : 1.0));
            const int nb = int((b - (1.0-aa)*bb) / (aa>0 ? aa : 1.0));

            const int outR = std::clamp(nr, 0, 255);
            const int outG = std::clamp(ng, 0, 255);
            const int outB = std::clamp(nb, 0, 255);
            const int outA = int(aa * 255.0 + 0.5);

            line[x] = qRgba(outR, outG, outB, outA);
        }
    }
}

// --- 3) Deine Funktion: grab → crop (HiDPI!) → bg erkennen → color-to-alpha → PNG ---
bool ImageDownloader::grabAndSaveCropped(QQuickWindow *window, int x, int y, int w, int h, const QString &path, bool transparentBackground)
{
    if (!window || w <= 0 || h <= 0) {
        qWarning() << "grabAndSaveCropped: invalid args";
        return false;
    }

    // Qt 6: QuickWindow vollständig rendern
    QImage fb = window->grabWindow();
    if (fb.isNull()) {
        qWarning() << "grabAndSaveCropped: grabWindow() returned null";
        return false;
    }

    // HiDPI: Umrechnung von DIP auf DevicePixel
    const qreal dpr = fb.devicePixelRatio() > 0 ? fb.devicePixelRatio() : 1.0;
    QRect crop = QRect(qRound(x * dpr), qRound(y * dpr), qRound(w * dpr), qRound(h * dpr))
                     .intersected(QRect(QPoint(0, 0), fb.size()));
    if (crop.isEmpty()) {
        qWarning() << "grabAndSaveCropped: crop empty after clamp";
        return false;
    }

    QImage img = fb.copy(crop).convertToFormat(QImage::Format_ARGB32);
    img.setDevicePixelRatio(1.0);

    if (transparentBackground) {
        // Automatische Hintergrundfarbe erkennen
        const QColor bg = detectDominantEdgeColor(img);
        colorToAlphaAgainstBg(img, bg, /*t0=*/8, /*t1=*/40, /*gamma=*/1.2);
    }

    // Immer als PNG speichern (auch wenn z.B. .jpg als Pfad angegeben ist)
    QFileInfo fi(path);
    const QString outPath = fi.path() + "/" + fi.completeBaseName() + ".png";
    QImageWriter wr(outPath, "png");
    wr.setCompression(9);

    if (!wr.write(img)) {
        qWarning() << "grabAndSaveCropped: write failed:" << wr.errorString() << "->" << outPath;
        emit downloadFailed("Screenshot fehlgeschlagen");
        return false;
    }

    qDebug() << "✅ Saved PNG:" << outPath << img.size() << (transparentBackground ? "(transparent)" : "");
    emit downloadSucceeded(outPath);
    return true;
}
