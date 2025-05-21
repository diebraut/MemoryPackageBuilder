#ifndef EXERSIZEMODEL_H
#define EXERSIZEMODEL_H
#pragma once

#include <QString>
#include <QVector>

// Ein einzelnes Übungselement
struct Uebung {
    int nummer;
    QString frageSubjekt;
    QString antwortSubjekt;
    QString subjektPrefixFrage;
    QString subjektPrefixAntwort;
    QString imagefileFrage;
    QString imagefileAntwort;
    QString infoURLFrage;
    QString infoURLAntwort;
    QString imageFrageAuthor;
    QString imageFrageLizenz;
    QString imageAntwortAuthor;
    QString imageAntwortLizenz;
    QString wikiPageFraVers;
    QString wikiPageAntVers;
    QString excludeAereaFra;
    QString excludeAereaAnt;
    QString imageFrageBildDescription;
    QString imageAntwortBildDescription;
    QString imageFrageUrl;
    QString imageAntwortUrl;
};

// Die Hauptliste der Übungen
struct Uebungen {
    QString name;
    bool sequentiell = false;
    bool umgekehrt   = false;
    QString frageText;
    QString frageTextUmgekehrt;
    QVector<Uebung> uebungsliste;
};

// Root-Element
struct Daten {
    Uebungen uebungen;
};

#endif // EXERSIZEMODEL_H
