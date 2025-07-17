#include "BuildExercisePackage.h"
#include <QFile>
#include <QDir>
#include <QTextStream>
#include <QDebug>

BuildExercisePackage::BuildExercisePackage(QObject *parent)
    : QObject(parent) {}

bool BuildExercisePackage::buildPackage(const QString &csvPath, const QString &exerciseName, const QString &targetFolder) {
    QList<QVariantMap> dataList = parseCsv(csvPath);
    if (dataList.isEmpty()) {
        qWarning() << "❌ CSV-Datei enthält keine gültigen Daten.";
        return false;
    }

    QString xmlContent = generateXml(exerciseName, dataList);
    return writeXmlFile(targetFolder + "/" + exerciseName + "/package.xml", xmlContent);
}

QList<QVariantMap> BuildExercisePackage::parseCsv(const QString &csvPath) {
    QList<QVariantMap> result;
    QFile file(csvPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "❌ CSV konnte nicht geöffnet werden:" << csvPath;
        return result;
    }

    QTextStream in(&file);
    const QStringList headers = in.readLine().split(';');

    while (!in.atEnd()) {
        const QStringList values = in.readLine().split(';');
        QVariantMap row;
        for (int i = 0; i < headers.size() && i < values.size(); ++i)
            row[headers[i].trimmed()] = values[i].trimmed();
        result.append(row);
    }

    file.close();
    return result;
}

QString BuildExercisePackage::generateXml(const QString &exerciseName, const QList<QVariantMap> &dataList) {
    QString xml;
    QTextStream stream(&xml);
    stream << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    stream << "<Daten>\n";
    stream << QString("  <Übungen name=\"%1\" sequentiell=\"true\" umgekehrt=\"true\">\n").arg(exerciseName);
    stream << "    <MainÜbungsliste>\n";
    stream << "      <FrageText>Wann war [FrageSubjekt] ...</FrageText>\n";
    stream << "      <FrageTextUmgekehrt>[FrageSubjekt] war wer ...?</FrageTextUmgekehrt>\n";

    int nummer = 1;
    for (const QVariantMap &entry : dataList) {
        stream << QString("      <Übung nummer=\"%1\">\n").arg(nummer++);
        stream << QString("        <FrageSubjekt>%1</FrageSubjekt>\n").arg(entry.value("FrageSubjekt").toString());
        stream << QString("        <AntwortSubjekt>%1</AntwortSubjekt>\n").arg(entry.value("AntwortSubjekt").toString());
        stream << "        <SubjektPrefixFrage></SubjektPrefixFrage>\n";
        stream << "        <SubjektPrefixAntwort></SubjektPrefixAntwort>\n";
        stream << "        <ImagefileFrage></ImagefileFrage>\n";
        stream << "        <ImagefileAntwort></ImagefileAntwort>\n";
        stream << QString("        <InfoURLFrage>%1</InfoURLFrage>\n").arg(entry.value("InfoUrlFrage").toString());
        stream << QString("        <InfoURLAntwort>%1</InfoURLAntwort>\n").arg(entry.value("InfoUrlAntwort").toString());
        stream << "        <ImageFrageAuthor></ImageFrageAuthor>\n";
        stream << "        <ImageFrageLizenz></ImageFrageLizenz>\n";
        stream << "        <ImageAntwortAuthor></ImageAntwortAuthor>\n";
        stream << "        <ImageAntwortLizenz></ImageAntwortLizenz>\n";
        stream << "        <WikiPageFraVers></WikiPageFraVers>\n";
        stream << "        <WikiPageAntVers></WikiPageAntVers>\n";
        stream << "        <ExcludeAereaFra></ExcludeAereaFra>\n";
        stream << "        <ExcludeAereaAnt></ExcludeAereaAnt>\n";
        stream << "        <ImageFrageBildDescription></ImageFrageBildDescription>\n";
        stream << "        <ImageAntwortBildDescription></ImageAntwortBildDescription>\n";
        stream << "        <ImageFrageUrl></ImageFrageUrl>\n";
        stream << "        <ImageAntwortUrl></ImageAntwortUrl>\n";
        stream << "      </Übung>\n";
    }

    stream << "    </MainÜbungsliste>\n";
    stream << "  </Übungen>\n";
    stream << "</Daten>\n";
    return xml;
}

bool BuildExercisePackage::writeXmlFile(const QString &path, const QString &content) {
    QDir().mkpath(QFileInfo(path).path());
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "❌ Schreiben der XML-Datei fehlgeschlagen:" << path;
        return false;
    }
    QTextStream out(&file);
    out << content;
    file.close();
    return true;
}
