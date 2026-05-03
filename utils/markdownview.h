#ifndef MARKDOWNVIEW_H
#define MARKDOWNVIEW_H

#include <QColor>
#include <QPointF>
#include <QTextCursor>
#include <QTextDocument>
#include <QtQuick/QQuickPaintedItem>

class MarkdownView: public QQuickPaintedItem {
	Q_OBJECT
	Q_PROPERTY(QString text READ text WRITE setText NOTIFY textChanged)
	Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
	Q_PROPERTY(qreal fontSize READ fontSize WRITE setFontSize NOTIFY fontSizeChanged)
	Q_PROPERTY(QString fontFamily READ fontFamily WRITE setFontFamily NOTIFY fontFamilyChanged)
	Q_PROPERTY(QColor linkColor READ linkColor WRITE setLinkColor NOTIFY linkColorChanged)
	Q_PROPERTY(
	    bool selectByMouse READ selectByMouse WRITE setSelectByMouse NOTIFY selectByMouseChanged
	)
	Q_PROPERTY(
	    QColor selectionColor READ selectionColor WRITE setSelectionColor NOTIFY selectionColorChanged
	)
	Q_PROPERTY(
	    QColor selectedTextColor READ selectedTextColor WRITE setSelectedTextColor NOTIFY
	        selectedTextColorChanged
	)

public:
	explicit MarkdownView(QQuickItem* parent = nullptr);
	MarkdownView(const MarkdownView&) = delete;
	MarkdownView(MarkdownView&&) = delete;
	MarkdownView& operator=(const MarkdownView&) = delete;
	MarkdownView& operator=(MarkdownView&&) = delete;
	~MarkdownView() override = default;

	void paint(QPainter* painter) override;

	[[nodiscard]] QString text() const;
	void setText(const QString& text);

	[[nodiscard]] QColor color() const;
	void setColor(const QColor& color);

	[[nodiscard]] qreal fontSize() const;
	void setFontSize(qreal size);

	[[nodiscard]] QString fontFamily() const;
	void setFontFamily(const QString& family);

	[[nodiscard]] QColor linkColor() const;
	void setLinkColor(const QColor& color);

	[[nodiscard]] bool selectByMouse() const;
	void setSelectByMouse(bool enabled);

	[[nodiscard]] QColor selectionColor() const;
	void setSelectionColor(const QColor& color);

	[[nodiscard]] QColor selectedTextColor() const;
	void setSelectedTextColor(const QColor& color);

signals:
	void textChanged();
	void colorChanged();
	void fontSizeChanged();
	void fontFamilyChanged();
	void linkColorChanged();
	void selectByMouseChanged();
	void selectionColorChanged();
	void selectedTextColorChanged();

protected:
	void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
	void mousePressEvent(QMouseEvent* event) override;
	void mouseMoveEvent(QMouseEvent* event) override;
	void mouseReleaseEvent(QMouseEvent* event) override;
	void mouseDoubleClickEvent(QMouseEvent* event) override;
	void keyPressEvent(QKeyEvent* event) override;
	void hoverMoveEvent(QHoverEvent* event) override;

private:
	void updateDocument();

	QTextDocument mDocument;
	QTextCursor mCursor;

	QString mText;
	QColor mColor {Qt::white};
	qreal mFontSize {13.0};
	QString mFontFamily;
	QColor mLinkColor {0x88, 0xaa, 0xff};
	QColor mSelectionColor {0x33, 0x66, 0x99};
	QColor mSelectedTextColor {Qt::white};
	bool mSelectByMouse {true};
	bool mSelecting {false};
	bool mPendingUpdate {false}; // deferred when width is not yet known
	QPointF mPressPos;           // position of last mouse-press (for link-click detection)
};

#endif // MARKDOWNVIEW_H
