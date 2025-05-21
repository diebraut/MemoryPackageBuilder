#include "PackageModel.h"

PackageModel::PackageModel(QObject *parent)
    : QAbstractListModel(parent) {}

int PackageModel::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : m_packages.count();
}

QVariant PackageModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_packages.count())
        return QVariant();

    const PackageEntry &entry = m_packages.at(index.row());

    switch (role) {
    case NameRole:
        return entry.name;
    case PathRole:
        return entry.path;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> PackageModel::roleNames() const {
    return {
        { NameRole, "displayName" },
        { PathRole, "path" }
    };
}

void PackageModel::loadPackages(const QString &folderPath) {
    beginResetModel();
    m_packages.clear();

    QDir dir(folderPath);
    const QFileInfoList entries = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);

    for (const QFileInfo &info : entries) {
        m_packages.append({info.fileName(), info.absoluteFilePath()});
    }

    endResetModel();
}

QVariant PackageModel::get(int index) const {
    if (index < 0 || index >= m_packages.count())
        return QVariant();

    const PackageEntry &entry = m_packages.at(index);

    QVariantMap map;
    map["displayName"] = entry.name;
    map["path"] = entry.path;
    return map;
}


