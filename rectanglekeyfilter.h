#ifndef RECTANGLEKEYFILTER_H
#define RECTANGLEKEYFILTER_H

#include <QObject>

class RectangleKeyFilter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit RectangleKeyFilter(QObject *parent = nullptr);

    bool enabled() const;
    void setEnabled(bool enabled);

signals:
    void enabledChanged();
    void arrowKeyPressed(int key, int modifiers);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    bool m_enabled = false;
};

#endif // RECTANGLEKEYFILTER_H
