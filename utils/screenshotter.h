#ifndef SCREENSHOTTER_H
#define SCREENSHOTTER_H

#include <QImage>
#include <QObject>
#include <QSize>
#include <QString>

struct wl_display;
struct wl_shm;
struct zwlr_screencopy_manager_v1;

class Screenshotter: public QObject {
	Q_OBJECT
	Q_PROPERTY(bool capturing READ isCapturing NOTIFY capturingChanged)
	Q_PROPERTY(QString imagePath READ imagePath NOTIFY imagePathChanged)
	Q_PROPERTY(int captureWidth READ captureWidth NOTIFY imagePathChanged)
	Q_PROPERTY(int captureHeight READ captureHeight NOTIFY imagePathChanged)
	Q_PROPERTY(QString screenRects READ screenRects NOTIFY imagePathChanged)

public:
	explicit Screenshotter(QObject* parent = nullptr);
	~Screenshotter() override;

	bool isCapturing() const;
	QString imagePath() const;
	int captureWidth() const;
	int captureHeight() const;
	QString screenRects() const;

	// Capture all Wayland outputs into a combined image, save to temp path
	Q_INVOKABLE void captureAll();

	// Crop the last capture and save to destPath. w/h <= 0 = full image.
	Q_INVOKABLE bool saveCropped(
	    const QString& destPath,
	    int x,
	    int y,
	    int w,
	    int h,
	    bool roundCorners = true,
	    bool dropShadow = true
	);

	// Same as saveCropped but composites freehand annotation paths (JSON) first.
	// pathsJson: JSON array of paths, each path an array of {x,y} objects in
	// crop-local image coordinates. Pass "[]" for no annotations.
	Q_INVOKABLE bool saveWithAnnotation(
	    const QString& destPath,
	    int x,
	    int y,
	    int w,
	    int h,
	    const QString& pathsJson,
	    qreal penWidth,
	    const QString& penColor,
	    bool roundCorners,
	    bool dropShadow
	);

signals:
	void capturingChanged();
	void imagePathChanged();
	void captureComplete();
	void captureError(const QString& message);

private:
	bool m_capturing = false;
	QString m_imagePath;
	QString m_screenRects;
	QImage m_lastCapture;
};

#endif // SCREENSHOTTER_H
