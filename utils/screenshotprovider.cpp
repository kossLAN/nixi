#include "screenshotprovider.h"

ScreenshotProvider* ScreenshotProvider::s_instance = nullptr;

ScreenshotProvider::ScreenshotProvider(): QQuickImageProvider(QQuickImageProvider::Image) {}

QImage ScreenshotProvider::requestImage(
    const QString& /*id*/,
    QSize* size,
    const QSize& /*requestedSize*/
) {
	QMutexLocker lock(&m_mutex);
	if (size) *size = m_image.size();
	return m_image;
}

void ScreenshotProvider::store(const QImage& image) {
	QMutexLocker lock(&m_mutex);
	m_image = image;
}

ScreenshotProvider* ScreenshotProvider::instance() { return s_instance; }

void ScreenshotProvider::setInstance(ScreenshotProvider* provider) { s_instance = provider; }
