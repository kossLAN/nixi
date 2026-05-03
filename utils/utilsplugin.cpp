#include "utilsplugin.h"

#include <QtQml>

#include "cachedimage.h"
#include "clipboard.h"
#include "utils.h"
#include "httprequest.h"
#include "markdownview.h"
#include "screenshotter.h"
#include "screenshotprovider.h"

void UtilsPlugin::registerTypes(const char* uri) {
	qmlRegisterSingletonType<Utils>(
	    uri,
	    1,
	    0,
	    "NixiUtils",
	    [](QQmlEngine* engine, QJSEngine* scriptEngine) -> QObject* {
		    Q_UNUSED(engine)
		    Q_UNUSED(scriptEngine)
		    return new Utils();
	    }
	);

	qmlRegisterSingletonType<ClipboardUtils>(
	    uri,
	    1,
	    0,
	    "ClipboardUtils",
	    [](QQmlEngine* engine, QJSEngine* scriptEngine) -> QObject* {
		    Q_UNUSED(engine)
		    Q_UNUSED(scriptEngine)
		    return new ClipboardUtils();
	    }
	);

	qmlRegisterType<CachedImage>(uri, 1, 0, "CachedImage");
	qmlRegisterType<HttpRequest>(uri, 1, 0, "HttpRequest");
	qmlRegisterType<MarkdownView>(uri, 1, 0, "MarkdownView");
	qmlRegisterType<Screenshotter>(uri, 1, 0, "Screenshotter");
}

void UtilsPlugin::initializeEngine(QQmlEngine* engine, const char* uri) {
	Q_UNUSED(uri)
	auto* provider = new ScreenshotProvider();
	ScreenshotProvider::setInstance(provider);
	engine->addImageProvider(QStringLiteral("screenshotter"), provider);
}
