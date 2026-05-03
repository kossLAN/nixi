#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QVariantList>
#include <QtCore/QVariantMap>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

// Instantiatable QML component for HTTP requests.
// Supports GET, POST JSON, and POST multipart/form-data.
// Streaming responses are delivered via dataReceived() as chunks arrive.
//
// Parts map for postMultipart():
//   { name: string, body: string, mimeType: string,
//     isBase64: bool (default false), filename: string (optional) }
//
// Calling abort() (or starting a new request while one is in-flight) cleanly
// cancels the in-flight request — no signals fire after abort() returns.

class HttpRequest: public QObject {
	Q_OBJECT
	Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
	explicit HttpRequest(QObject* parent = nullptr);

	[[nodiscard]] bool running() const;

	Q_INVOKABLE void get(const QString& url, const QVariantMap& headers = {});
	Q_INVOKABLE void postJson(const QString& url, const QVariantMap& headers, const QString& body);
	Q_INVOKABLE void
	postMultipart(const QString& url, const QVariantMap& headers, const QVariantList& parts);
	Q_INVOKABLE void abort();

signals:
	void dataReceived(const QString& chunk);
	void finished(int statusCode);
	void errorOccurred(const QString& message);
	void runningChanged();

private:
	void setReply(QNetworkReply* reply);
	void applyHeaders(QNetworkRequest& request, const QVariantMap& headers) const;
	void setRunning(bool running);

	QNetworkAccessManager mNam;
	QNetworkReply* mReply = nullptr;
	bool mRunning = false;
};
