#ifndef UTILSPLUGIN_H
#define UTILSPLUGIN_H

#include <QQmlExtensionPlugin>

class UtilsPlugin: public QQmlExtensionPlugin {
	Q_OBJECT
	Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface/1.0")

public:
	void registerTypes(const char* uri) override;
	void initializeEngine(QQmlEngine* engine, const char* uri) override;
};

#endif // UTILSPLUGIN_H
