#pragma once

#include <QImage>
#include <QMutex>
#include <QQuickImageProvider>

class ScreenshotProvider: public QQuickImageProvider {
public:
    ScreenshotProvider();

    QImage requestImage(const QString& id, QSize* size, const QSize& requestedSize) override;
    void store(const QImage& image);

    static ScreenshotProvider* instance();
    static void setInstance(ScreenshotProvider* provider);

private:
    mutable QMutex m_mutex;
    QImage m_image;

    static ScreenshotProvider* s_instance;
};
