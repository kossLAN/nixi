#include "screenshotter.h"
#include <algorithm>
#include <cerrno>
#include <cstring>

#include <QClipboard>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QPainterPath>
#include <QPen>
#include <QScreen>
#include <QThreadPool>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>

#include "screenshotprovider.h"
#include "wlr-screencopy-client-protocol.h"

static int create_anon_file(size_t size) {
	int fd = memfd_create("nixi-screenshot", MFD_CLOEXEC);
	if (fd < 0) return -1;
	if (ftruncate(fd, static_cast<off_t>(size)) < 0) {
		close(fd);
		return -1;
	}
	return fd;
}

struct OutputCapture {
	struct wl_shm* shm = nullptr;

	uint32_t fmt = 0;
	uint32_t width = 0;
	uint32_t height = 0;
	uint32_t stride = 0;
	bool yflip = false;

	int fd = -1;
	void* data = nullptr;
	size_t dataSize = 0;

	struct wl_buffer* buffer = nullptr;
	bool done = false;
	bool failed = false;
};

static void frame_on_buffer(
    void* userdata,
    struct zwlr_screencopy_frame_v1* frame,
    uint32_t fmt,
    uint32_t width,
    uint32_t height,
    uint32_t stride
) {
	auto* cap = static_cast<OutputCapture*>(userdata);

	cap->fmt = fmt;
	cap->width = width;
	cap->height = height;
	cap->stride = stride;
	cap->dataSize = static_cast<size_t>(stride) * height;

	cap->fd = create_anon_file(cap->dataSize);
	if (cap->fd < 0) {
		cap->failed = true;
		return;
	}

	cap->data = mmap(nullptr, cap->dataSize, PROT_READ | PROT_WRITE, MAP_SHARED, cap->fd, 0);
	if (cap->data == MAP_FAILED) {
		cap->data = nullptr;
		close(cap->fd);
		cap->fd = -1;
		cap->failed = true;
		return;
	}

	struct wl_shm_pool* pool =
	    wl_shm_create_pool(cap->shm, cap->fd, static_cast<int32_t>(cap->dataSize));
	cap->buffer = wl_shm_pool_create_buffer(
	    pool,
	    0,
	    static_cast<int32_t>(width),
	    static_cast<int32_t>(height),
	    static_cast<int32_t>(stride),
	    fmt
	);
	wl_shm_pool_destroy(pool);

	zwlr_screencopy_frame_v1_copy(frame, cap->buffer);
}

static void
frame_on_flags(void* userdata, struct zwlr_screencopy_frame_v1* /*frame*/, uint32_t flags) {
	auto* cap = static_cast<OutputCapture*>(userdata);
	cap->yflip = (flags & ZWLR_SCREENCOPY_FRAME_V1_FLAGS_Y_INVERT) != 0;
}

static void frame_on_ready(
    void* userdata,
    struct zwlr_screencopy_frame_v1* frame,
    uint32_t /*tv_sec_hi*/,
    uint32_t /*tv_sec_lo*/,
    uint32_t /*tv_nsec*/
) {
	auto* cap = static_cast<OutputCapture*>(userdata);
	cap->done = true;
	zwlr_screencopy_frame_v1_destroy(frame);
}

static void frame_on_failed(void* userdata, struct zwlr_screencopy_frame_v1* frame) {
	auto* cap = static_cast<OutputCapture*>(userdata);
	cap->failed = true;
	zwlr_screencopy_frame_v1_destroy(frame);
}

static void
frame_noop_damage(void*, struct zwlr_screencopy_frame_v1*, uint32_t, uint32_t, uint32_t, uint32_t) {
}
static void
frame_noop_linux_dmabuf(void*, struct zwlr_screencopy_frame_v1*, uint32_t, uint32_t, uint32_t) {}
static void frame_noop_buffer_done(void*, struct zwlr_screencopy_frame_v1*) {}

static const struct zwlr_screencopy_frame_v1_listener frame_listener = {
    .buffer = frame_on_buffer,
    .flags = frame_on_flags,
    .ready = frame_on_ready,
    .failed = frame_on_failed,
    .damage = frame_noop_damage,
    .linux_dmabuf = frame_noop_linux_dmabuf,
    .buffer_done = frame_noop_buffer_done,
};

struct OutputInfo {
	struct wl_output* output = nullptr;
	QString name;
	int32_t x = 0;
	int32_t y = 0;
	int32_t modeW = 0;
	int32_t modeH = 0;
	int32_t scale = 1;
	bool done = false;
};

static void out_on_geometry(
    void* data,
    struct wl_output* /*output*/,
    int32_t x,
    int32_t y,
    int32_t /*phys_w*/,
    int32_t /*phys_h*/,
    int32_t /*subpixel*/,
    const char* /*make*/,
    const char* /*model*/,
    int32_t /*transform*/
) {
	auto* oi = static_cast<OutputInfo*>(data);
	oi->x = x;
	oi->y = y;
}

static void out_on_mode(
    void* data,
    struct wl_output* /*output*/,
    uint32_t flags,
    int32_t width,
    int32_t height,
    int32_t /*refresh*/
) {
	if (flags & WL_OUTPUT_MODE_CURRENT) {
		auto* oi = static_cast<OutputInfo*>(data);
		oi->modeW = width;
		oi->modeH = height;
	}
}

static void out_on_done(void* data, struct wl_output* /*output*/) {
	static_cast<OutputInfo*>(data)->done = true;
}

static void out_on_scale(void* data, struct wl_output*, int32_t scale) {
	static_cast<OutputInfo*>(data)->scale = qMax(1, scale);
}

static void out_on_name(void* data, struct wl_output*, const char* name) {
	static_cast<OutputInfo*>(data)->name = QString::fromUtf8(name);
}
static void out_on_description(void*, struct wl_output*, const char*) {}

static const struct wl_output_listener output_listener = {
    .geometry = out_on_geometry,
    .mode = out_on_mode,
    .done = out_on_done,
    .scale = out_on_scale,
    .name = out_on_name,
    .description = out_on_description,
};

struct RegistryState {
	struct wl_shm* shm = nullptr;
	struct zwlr_screencopy_manager_v1* screecopyMgr = nullptr;
	QList<OutputInfo*> outputs;
};

static void
reg_on_global(void* data, struct wl_registry* reg, uint32_t name, const char* iface, uint32_t ver) {
	auto* rs = static_cast<RegistryState*>(data);

	if (strcmp(iface, wl_shm_interface.name) == 0) {
		rs->shm = static_cast<struct wl_shm*>(wl_registry_bind(reg, name, &wl_shm_interface, 1));
	} else if (strcmp(iface, zwlr_screencopy_manager_v1_interface.name) == 0) {
		uint32_t bindVer = (ver >= 3) ? 3 : ver;
		rs->screecopyMgr = static_cast<struct zwlr_screencopy_manager_v1*>(
		    wl_registry_bind(reg, name, &zwlr_screencopy_manager_v1_interface, bindVer)
		);
	} else if (strcmp(iface, wl_output_interface.name) == 0) {
		uint32_t bindVer = (ver >= 4) ? 4 : ver;
		auto* oi = new OutputInfo;
		oi->output =
		    static_cast<struct wl_output*>(wl_registry_bind(reg, name, &wl_output_interface, bindVer));
		wl_output_add_listener(oi->output, &output_listener, oi);
		rs->outputs.append(oi);
	}
}

static void reg_on_global_remove(void* /*data*/, struct wl_registry* /*reg*/, uint32_t /*name*/) {}

static const struct wl_registry_listener registry_listener = {
    .global = reg_on_global,
    .global_remove = reg_on_global_remove,
};

Screenshotter::Screenshotter(QObject* parent): QObject(parent) {}
Screenshotter::~Screenshotter() = default;

bool Screenshotter::isCapturing() const { return m_capturing; }

QString Screenshotter::imagePath() const { return m_imagePath; }

int Screenshotter::captureWidth() const { return m_lastCapture.width(); }

int Screenshotter::captureHeight() const { return m_lastCapture.height(); }

QString Screenshotter::screenRects() const { return m_screenRects; }

static QImage::Format shmFmtToQt(uint32_t fmt) {
	switch (fmt) {
	case WL_SHM_FORMAT_ARGB8888: return QImage::Format_ARGB32;
	case WL_SHM_FORMAT_XRGB8888: return QImage::Format_RGB32;
	case WL_SHM_FORMAT_ABGR8888: return QImage::Format_RGBA8888;
	case WL_SHM_FORMAT_XBGR8888: return QImage::Format_RGBX8888;
	default: return QImage::Format_Invalid;
	}
}

static bool captureOutput(
    struct zwlr_screencopy_manager_v1* mgr,
    struct wl_display* display,
    struct wl_shm* shm,
    struct wl_output* output,
    bool withCursor,
    QImage& result
) {
	OutputCapture cap;
	cap.shm = shm;

	struct zwlr_screencopy_frame_v1* frame =
	    zwlr_screencopy_manager_v1_capture_output(mgr, withCursor ? 1 : 0, output);
	if (!frame) return false;

	zwlr_screencopy_frame_v1_add_listener(frame, &frame_listener, &cap);

	while (!cap.done && !cap.failed) {
		if (wl_display_dispatch(display) < 0) break;
	}

	if (!cap.done) {
		if (cap.data) munmap(cap.data, cap.dataSize);
		if (cap.fd >= 0) close(cap.fd);
		if (cap.buffer) wl_buffer_destroy(cap.buffer);
		return false;
	}

	QImage::Format qfmt = shmFmtToQt(cap.fmt);
	if (qfmt == QImage::Format_Invalid) {
		munmap(cap.data, cap.dataSize);
		close(cap.fd);
		wl_buffer_destroy(cap.buffer);
		return false;
	}

	QImage raw(
	    static_cast<const uchar*>(cap.data),
	    static_cast<int>(cap.width),
	    static_cast<int>(cap.height),
	    static_cast<int>(cap.stride),
	    qfmt
	);
	result = raw.copy();

	if (cap.yflip) result = result.flipped(Qt::Vertical);

	munmap(cap.data, cap.dataSize);
	close(cap.fd);
	wl_buffer_destroy(cap.buffer);
	return true;
}

struct ScreenGeometry {
	QString name;
	QRect logicalRect;
};

struct CapturedOutput {
	QString name;
	QRect logicalRect;
	QImage image;
};

static const ScreenGeometry* matchScreen(const QList<ScreenGeometry>& screens, const OutputInfo* oi) {
	if (!oi->name.isEmpty()) {
		for (const auto& sg: screens) {
			if (sg.name == oi->name) return &sg;
		}
	}

	for (const auto& sg: screens) {
		if (qAbs(sg.logicalRect.x() - oi->x) <= 1 && qAbs(sg.logicalRect.y() - oi->y) <= 1)
			return &sg;
	}

	return nullptr;
}

static QList<int> axisBoundaries(const QList<CapturedOutput>& captures, bool horizontal) {
	QList<int> bounds;
	for (const auto& cap: captures) {
		const QRect& r = cap.logicalRect;
		bounds.append(horizontal ? r.left() : r.top());
		bounds.append(horizontal ? r.right() + 1 : r.bottom() + 1);
	}

	std::sort(bounds.begin(), bounds.end());
	bounds.erase(std::unique(bounds.begin(), bounds.end()), bounds.end());
	return bounds;
}

static qreal axisScaleFor(const CapturedOutput& cap, bool horizontal) {
	const int logical = horizontal ? cap.logicalRect.width() : cap.logicalRect.height();
	const int physical = horizontal ? cap.image.width() : cap.image.height();
	return logical > 0 ? static_cast<qreal>(physical) / logical : 1.0;
}

static QHash<int, int> axisNativePositions(const QList<CapturedOutput>& captures, bool horizontal) {
	QHash<int, int> mapped;
	const QList<int> bounds = axisBoundaries(captures, horizontal);
	if (bounds.isEmpty()) return mapped;

	int nativePos = 0;
	mapped.insert(bounds.first(), nativePos);
	for (qsizetype i = 0; i < bounds.size() - 1; ++i) {
		const int start = bounds[i];
		const int end = bounds[i + 1];
		qreal scale = 1.0;

		for (const auto& cap: captures) {
			const QRect& r = cap.logicalRect;
			const int capStart = horizontal ? r.left() : r.top();
			const int capEnd = horizontal ? r.right() + 1 : r.bottom() + 1;
			if (capStart <= start && capEnd >= end)
				scale = qMax(scale, axisScaleFor(cap, horizontal));
		}

		nativePos += qRound((end - start) * scale);
		mapped.insert(end, nativePos);
	}

	return mapped;
}

void Screenshotter::captureAll() {
	if (m_capturing) return;

	m_capturing = true;
	emit capturingChanged();

	// Collect Qt screen info on the main thread before handing off to worker.
	QList<ScreenGeometry> screenGeometries;
	for (auto* s: QGuiApplication::screens()) {
		screenGeometries.append({s->name(), s->geometry()});
	}

	QThreadPool::globalInstance()->start([this, screenGeometries]() {
		// Open a dedicated Wayland connection so we don't interfere with Qt's connection
		struct wl_display* display = wl_display_connect(nullptr);
		if (!display) {
			QMetaObject::invokeMethod(this, [this]() {
				m_capturing = false;
				emit capturingChanged();
				emit captureError(QStringLiteral("Failed to connect to Wayland compositor"));
			}, Qt::QueuedConnection);
			return;
		}

		RegistryState rs;
		struct wl_registry* registry = wl_display_get_registry(display);
		wl_registry_add_listener(registry, &registry_listener, &rs);

		// First roundtrip: get globals + bind outputs (triggers output listeners)
		wl_display_roundtrip(display);
		// Second roundtrip: receive wl_output geometry/mode/done events
		wl_display_roundtrip(display);

		auto cleanup = [&]() {
			for (auto* oi: rs.outputs) {
				wl_output_destroy(oi->output);
				delete oi;
			}
			if (rs.shm) wl_shm_destroy(rs.shm);
			if (rs.screecopyMgr) zwlr_screencopy_manager_v1_destroy(rs.screecopyMgr);
			wl_registry_destroy(registry);
			wl_display_disconnect(display);
		};

		if (!rs.shm || !rs.screecopyMgr || rs.outputs.isEmpty()) {
			cleanup();
			QMetaObject::invokeMethod(this, [this]() {
				m_capturing = false;
				emit capturingChanged();
				emit captureError(
				    QStringLiteral("Compositor missing wl_shm or zwlr_screencopy_manager_v1")
				);
			}, Qt::QueuedConnection);
			return;
		}

		QList<CapturedOutput> captures;
		for (auto* oi: rs.outputs) {
			QImage outputImg;
			if (!captureOutput(rs.screecopyMgr, display, rs.shm, oi->output, false, outputImg))
				continue;

			const ScreenGeometry* match = matchScreen(screenGeometries, oi);
			const QRect logicalRect = match
			    ? match->logicalRect
			    : QRect(
			          QPoint(oi->x, oi->y),
			          QSize(
			              qMax(1, qRound(static_cast<qreal>(outputImg.width()) / oi->scale)),
			              qMax(1, qRound(static_cast<qreal>(outputImg.height()) / oi->scale))
			          )
			      );

			captures.append({oi->name, logicalRect, std::move(outputImg)});
		}

		if (captures.isEmpty()) {
			cleanup();
			QMetaObject::invokeMethod(this, [this]() {
				m_capturing = false;
				emit capturingChanged();
				emit captureError(QStringLiteral("All output captures failed"));
			}, Qt::QueuedConnection);
			return;
		}

		const QHash<int, int> nativeX = axisNativePositions(captures, true);
		const QHash<int, int> nativeY = axisNativePositions(captures, false);

		QList<QRect> nativeRects;
		QRect nativeBounds;
		for (const auto& cap: captures) {
			const int x = nativeX.value(cap.logicalRect.left(), 0);
			const int y = nativeY.value(cap.logicalRect.top(), 0);
			QRect rect(QPoint(x, y), cap.image.size());
			nativeRects.append(rect);
			nativeBounds = nativeBounds.united(rect);
		}

		QImage combined(nativeBounds.size(), QImage::Format_RGB32);
		combined.fill(Qt::black);
		QPainter painter(&combined);

		QJsonArray screenRects;
		for (qsizetype i = 0; i < captures.size(); ++i) {
			const auto& cap = captures[i];
			const QRect rect = nativeRects[i].translated(-nativeBounds.topLeft());
			painter.drawImage(rect.topLeft(), cap.image);

			QJsonObject obj;
			obj["name"] = cap.name;
			obj["logicalX"] = cap.logicalRect.x();
			obj["logicalY"] = cap.logicalRect.y();
			obj["logicalW"] = cap.logicalRect.width();
			obj["logicalH"] = cap.logicalRect.height();
			obj["imgX"] = rect.x();
			obj["imgY"] = rect.y();
			obj["imgW"] = rect.width();
			obj["imgH"] = rect.height();
			screenRects.append(obj);
		}
		painter.end();
		cleanup();

		const QString screenRectsJson =
		    QString::fromUtf8(QJsonDocument(screenRects).toJson(QJsonDocument::Compact));

		// Store in the image provider so QML can display it without any file I/O.
		if (auto* prov = ScreenshotProvider::instance()) prov->store(combined);

		QMetaObject::invokeMethod(this, [this, img = std::move(combined), screenRectsJson]() mutable {
			m_lastCapture = std::move(img);
			m_screenRects = screenRectsJson;
			m_imagePath = QStringLiteral("image://screenshotter/current");
			m_capturing = false;
			emit capturingChanged();
			emit imagePathChanged();
			emit captureComplete();
		}, Qt::QueuedConnection);
	});
}

static QImage applyBoxBlur(const QImage& src, int radius) {
	QImage img = src.convertToFormat(QImage::Format_ARGB32);
	int w = img.width(), h = img.height();
	const int cnt = 2 * radius + 1;

	// Horizontal pass
	QImage tmp(w, h, QImage::Format_ARGB32);
	tmp.fill(Qt::transparent);
	for (int y = 0; y < h; ++y) {
		const auto* s = reinterpret_cast<const QRgb*>(img.constScanLine(y));
		auto* d = reinterpret_cast<QRgb*>(tmp.scanLine(y));
		for (int x = 0; x < w; ++x) {
			int r = 0, g = 0, b = 0, a = 0;
			for (int k = -radius; k <= radius; ++k) {
				QRgb p = s[qBound(0, x + k, w - 1)];
				a += qAlpha(p);
				r += qRed(p);
				g += qGreen(p);
				b += qBlue(p);
			}
			d[x] = qRgba(r / cnt, g / cnt, b / cnt, a / cnt);
		}
	}

	// Vertical pass
	QImage out(w, h, QImage::Format_ARGB32);
	out.fill(Qt::transparent);
	for (int y = 0; y < h; ++y) {
		auto* d = reinterpret_cast<QRgb*>(out.scanLine(y));
		for (int x = 0; x < w; ++x) {
			int r = 0, g = 0, b = 0, a = 0;
			for (int k = -radius; k <= radius; ++k) {
				const auto* s = reinterpret_cast<const QRgb*>(tmp.constScanLine(qBound(0, y + k, h - 1)));
				QRgb p = s[x];
				a += qAlpha(p);
				r += qRed(p);
				g += qGreen(p);
				b += qBlue(p);
			}
			d[x] = qRgba(r / cnt, g / cnt, b / cnt, a / cnt);
		}
	}
	return out;
}

// Apply rounded corners and/or drop shadow to a region crop.
static QImage applyEffects(const QImage& cropped, bool roundCorners, bool dropShadow) {
	const int w = cropped.width(), h = cropped.height();
	constexpr int cornerRadius = 12;

	QImage rounded = cropped;
	if (roundCorners) {
		rounded = QImage(w, h, QImage::Format_ARGB32);
		rounded.fill(Qt::transparent);
		QPainter rp(&rounded);
		rp.setRenderHint(QPainter::Antialiasing);
		rp.setPen(Qt::NoPen);
		rp.setBrush(Qt::black);
		rp.drawRoundedRect(0, 0, w, h, cornerRadius, cornerRadius);
		rp.setCompositionMode(QPainter::CompositionMode_SourceIn);
		rp.drawImage(0, 0, cropped);
	}

	if (!dropShadow) return rounded;

	constexpr int shadowBlur = 18;
	constexpr int shadowDx = 0;
	constexpr int shadowDy = 4;
	constexpr int pad = shadowBlur + 4;
	const int canvasW = w + pad * 2;
	const int canvasH = h + pad * 2;

	QImage shadowLayer(canvasW, canvasH, QImage::Format_ARGB32);
	shadowLayer.fill(Qt::transparent);
	{
		QPainter mp(&shadowLayer);
		mp.setRenderHint(QPainter::Antialiasing);
		mp.setBrush(QColor(0, 0, 0, 160));
		mp.setPen(Qt::NoPen);
		const int r = roundCorners ? cornerRadius : 0;
		mp.drawRoundedRect(pad + shadowDx, pad + shadowDy, w, h, r, r);
	}
	const int blurR = shadowBlur / 2;
	shadowLayer = applyBoxBlur(shadowLayer, blurR);
	shadowLayer = applyBoxBlur(shadowLayer, blurR);

	QImage result(canvasW, canvasH, QImage::Format_ARGB32);
	result.fill(Qt::transparent);
	{
		QPainter p(&result);
		p.drawImage(0, 0, shadowLayer);
		p.drawImage(pad, pad, rounded);
	}
	return result;
}

bool Screenshotter::saveCropped(
    const QString& destPath,
    int x,
    int y,
    int w,
    int h,
    bool roundCorners,
    bool dropShadow
) {
	if (m_lastCapture.isNull()) return false;

	const bool isRegion = (w > 0 && h > 0);
	QImage cropped = isRegion ? m_lastCapture.copy(x, y, w, h) : m_lastCapture;
	QImage result = isRegion ? applyEffects(cropped, roundCorners, dropShadow) : cropped;

	QDir().mkpath(QFileInfo(destPath).dir().absolutePath());
	bool ok = result.save(destPath, "PNG");
	if (ok) QGuiApplication::clipboard()->setImage(result);
	return ok;
}

bool Screenshotter::saveWithAnnotation(
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
) {
	if (m_lastCapture.isNull() || w <= 0 || h <= 0) return false;

	QImage cropped = m_lastCapture.copy(x, y, w, h);

	// Draw annotation paths onto the crop
	QJsonDocument doc = QJsonDocument::fromJson(pathsJson.toUtf8());
	if (doc.isArray() && !doc.array().isEmpty()) {
		QPainter ap(&cropped);
		ap.setRenderHint(QPainter::Antialiasing);
		ap.setPen(QPen(QColor(penColor), penWidth, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));

		for (const QJsonValue& pathVal: doc.array()) {
			if (!pathVal.isArray()) continue;
			const QJsonArray pts = pathVal.toArray();
			if (pts.size() < 2) continue;

			QPainterPath path;
			auto p0 = pts[0].toObject();
			path.moveTo(p0["x"].toDouble(), p0["y"].toDouble());
			for (qsizetype i = 1; i < pts.size(); ++i) {
				auto p = pts[i].toObject();
				path.lineTo(p["x"].toDouble(), p["y"].toDouble());
			}
			ap.drawPath(path);
		}
	}

	QImage result = applyEffects(cropped, roundCorners, dropShadow);
	QDir().mkpath(QFileInfo(destPath).dir().absolutePath());
	bool ok = result.save(destPath, "PNG");
	if (ok) QGuiApplication::clipboard()->setImage(result);
	return ok;
}
