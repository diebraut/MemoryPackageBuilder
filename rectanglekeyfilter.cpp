#include "rectanglekeyfilter.h"

#include <QEvent>
#include <QKeyEvent>
#include <Qt>

RectangleKeyFilter::RectangleKeyFilter(QObject *parent)
    : QObject(parent)
{
}

bool RectangleKeyFilter::enabled() const
{
    return m_enabled;
}

void RectangleKeyFilter::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;

    m_enabled = enabled;
    emit enabledChanged();
}

bool RectangleKeyFilter::eventFilter(QObject *watched, QEvent *event)
{
    Q_UNUSED(watched)

    if (!m_enabled)
        return QObject::eventFilter(watched, event);

    if (event->type() != QEvent::ShortcutOverride && event->type() != QEvent::KeyPress)
        return QObject::eventFilter(watched, event);

    auto *keyEvent = static_cast<QKeyEvent *>(event);
    const int key = keyEvent->key();
    const bool isArrowKey = key == Qt::Key_Left
                         || key == Qt::Key_Right
                         || key == Qt::Key_Up
                         || key == Qt::Key_Down;

    if (!isArrowKey)
        return QObject::eventFilter(watched, event);

    keyEvent->accept();

    if (event->type() == QEvent::KeyPress)
        emit arrowKeyPressed(key, static_cast<int>(keyEvent->modifiers()));

    return true;
}
