#include "httprequest.h"

#include <QtNetwork/QHttpMultiPart>
#include <QtNetwork/QHttpPart>

HttpRequest::HttpRequest(QObject* parent): QObject(parent) {
	// Follow HTTP redirects automatically (equivalent to curl -L)
	mNam.setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);
}

bool HttpRequest::running() const { return mRunning; }

void HttpRequest::setRunning(bool r) {
	if (mRunning == r) return;
	mRunning = r;
	emit runningChanged();
}

void HttpRequest::applyHeaders(QNetworkRequest& req, const QVariantMap& headers) const {
	for (auto it = headers.cbegin(); it != headers.cend(); ++it) {
		req.setRawHeader(it.key().toUtf8(), it.value().toString().toUtf8());
	}
}

// Replace the current in-flight reply.
// Disconnects and aborts any previous reply cleanly — no signals fire after return.
void HttpRequest::setReply(QNetworkReply* reply) {
	if (mReply) {
		mReply->disconnect(this); // prevent queued signals from the old reply
		mReply->abort();
		mReply->deleteLater();
		mReply = nullptr;
	}

	mReply = reply;
	setRunning(reply != nullptr);

	if (!reply) return;

	connect(reply, &QNetworkReply::readyRead, this, [this]() {
		if (!mReply) return;
		QByteArray data = mReply->readAll();
		if (!data.isEmpty()) emit dataReceived(QString::fromUtf8(data));
	});

	connect(reply, &QNetworkReply::finished, this, [this]() {
		if (!mReply) return;
		int status = mReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

		// Drain any remaining buffered data before closing
		QByteArray remaining = mReply->readAll();
		if (!remaining.isEmpty()) emit dataReceived(QString::fromUtf8(remaining));

		mReply->deleteLater();
		mReply = nullptr;
		setRunning(false);
		emit finished(status);
	});

	connect(reply, &QNetworkReply::errorOccurred, this, [this](QNetworkReply::NetworkError) {
		if (!mReply) return;
		emit errorOccurred(mReply->errorString());
	});
}

void HttpRequest::get(const QString& url, const QVariantMap& headers) {
	QNetworkRequest req {QUrl {url}};
	applyHeaders(req, headers);
	setReply(mNam.get(req));
}

void HttpRequest::postJson(const QString& url, const QVariantMap& headers, const QString& body) {
	QNetworkRequest req {QUrl {url}};
	applyHeaders(req, headers);
	setReply(mNam.post(req, body.toUtf8()));
}

void HttpRequest::postMultipart(
    const QString& url,
    const QVariantMap& headers,
    const QVariantList& parts
) {
	QNetworkRequest req {QUrl {url}};
	applyHeaders(req, headers);

	auto* multipart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

	for (const QVariant& v: parts) {
		QVariantMap p = v.toMap();
		QString name = p.value("name").toString();
		QString mimeType = p.value("mimeType", "application/octet-stream").toString();
		bool isBase64 = p.value("isBase64", false).toBool();
		QString filename = p.value("filename").toString();

		QByteArray body;
		if (isBase64) {
			body = QByteArray::fromBase64(p.value("body").toString().toLatin1());
		} else {
			body = p.value("body").toString().toUtf8();
		}

		QHttpPart part;
		QString disposition = QString(R"(form-data; name="%1")").arg(name);
		if (!filename.isEmpty()) disposition += QString(R"(; filename="%1")").arg(filename);

		part.setHeader(QNetworkRequest::ContentDispositionHeader, disposition);
		part.setHeader(QNetworkRequest::ContentTypeHeader, mimeType);
		part.setBody(body);
		multipart->append(part);
	}

	auto* reply = mNam.post(req, multipart);
	multipart->setParent(reply); // cleaned up automatically when reply is deleted
	setReply(reply);
}

// Abort the current request. No signals fire after this returns.
void HttpRequest::abort() {
	if (mReply) {
		mReply->disconnect(this);
		mReply->abort();
		mReply->deleteLater();
		mReply = nullptr;
		setRunning(false);
	}
}
