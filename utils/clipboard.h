#ifndef CLIPBOARDUTILS_H
#define CLIPBOARDUTILS_H

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QUrl>
#include <QtGui/QImage>

class ClipboardUtils: public QObject {
	Q_OBJECT

public:
	ClipboardUtils(QObject* parent = nullptr);
	Q_INVOKABLE QString clipboardImage() const;
	Q_INVOKABLE QString fileToBase64(const QUrl& fileUrl) const;
	Q_INVOKABLE QString getMimeType(const QUrl& fileUrl) const;
	Q_INVOKABLE QString writeTempFile(const QString& base64Data, const QString& mimeType) const;
	Q_INVOKABLE void deleteFile(const QString& filePath) const;
};

#endif // CLIPBOARDUTILS_H
