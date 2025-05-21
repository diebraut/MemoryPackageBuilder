#pragma once

#include <QAbstractListModel>
#include <QDir>

struct PackageEntry {
    QString name;
    QString path;
};

class PackageModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        PathRole
    };

    explicit PackageModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void loadPackages(const QString &folderPath);
    Q_INVOKABLE QVariant get(int index) const;

private:
    QList<PackageEntry> m_packages;
};
