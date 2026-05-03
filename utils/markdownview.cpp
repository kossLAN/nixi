#include "markdownview.h"
#include <array>

#include <QAbstractTextDocumentLayout>
#include <QClipboard>
#include <QColor>
#include <QCursor>
#include <QDesktopServices>
#include <QDir>
#include <QFont>
#include <QGuiApplication>
#include <QHash>
#include <QHoverEvent>
#include <QImage>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPainter>
#include <QRegularExpression>
#include <QTextBlock>
#include <QTextCursor>
#include <QTextFragment>
#include <QUrl>
#include <microtex/latex.h>
#include <microtex/platform/qt/graphic_qt.h>

namespace {

static bool sLatexInit = false; // NOLINT

void ensureLatexInit() {
	if (sLatexInit) return;

	QString resDir = qEnvironmentVariable("MICROTEX_RES_DIR");
	if (resDir.isEmpty()) {
#ifdef MICROTEX_RES_DIR
		resDir = QStringLiteral(MICROTEX_RES_DIR);
#endif
	}

	if (resDir.isEmpty() || !QDir(resDir).exists()) {
		qWarning() << "MarkdownView: MicroTeX resource directory not found:" << resDir;
		return;
	}

	try {
		tex::LaTeX::init(resDir.toStdString());
		sLatexInit = true;
	} catch (const std::exception& e) {
		qWarning() << "MarkdownView: MicroTeX init failed:" << e.what();
	}
}

struct MathFrag {
	int start;
	int end;
	QString formula;
	bool isDisplay;
};

QList<MathFrag> extractMath(const QString& text) {
	static const QRegularExpression mathRe(QStringLiteral(
	    R"(\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|\\\(([^\n]+?)\\\)|\$(?!\s)([^\n$]+?)(?<!\s)\$)"
	));

	QList<MathFrag> frags;
	auto it = mathRe.globalMatch(text);
	while (it.hasNext()) {
		const auto m = it.next();
		MathFrag frag;
		frag.start = static_cast<int>(m.capturedStart());
		frag.end = static_cast<int>(m.capturedEnd());

		if (m.hasCaptured(1) && !m.captured(1).trimmed().isEmpty()) {
			frag.formula = m.captured(1).trimmed();
			frag.isDisplay = true;
		} else if (m.hasCaptured(2) && !m.captured(2).trimmed().isEmpty()) {
			frag.formula = m.captured(2).trimmed();
			frag.isDisplay = true;
		} else if (m.hasCaptured(3) && !m.captured(3).trimmed().isEmpty()) {
			frag.formula = m.captured(3).trimmed();
			frag.isDisplay = false;
		} else if (m.hasCaptured(4) && !m.captured(4).trimmed().isEmpty()) {
			frag.formula = m.captured(4).trimmed();
			frag.isDisplay = false;
		} else {
			continue;
		}

		frags.append(frag);
	}
	return frags;
}

QImage renderMathFormula(const QString& formula, qreal fontSize, const QColor& color) {
	if (!sLatexInit) return {};

	const auto argb = static_cast<tex::color>(
	    (static_cast<unsigned>(color.alpha()) << 24) | (static_cast<unsigned>(color.red()) << 16)
	    | (static_cast<unsigned>(color.green()) << 8) | static_cast<unsigned>(color.blue())
	);

	tex::TeXRender* render = nullptr;
	try {
		render = tex::LaTeX::parse(
		    formula.toStdWString(),
		    0,
		    static_cast<float>(fontSize),
		    static_cast<float>(fontSize / 3.0),
		    argb
		);
	} catch (const std::exception& e) {
		qWarning() << "MarkdownView: math parse error:" << e.what();
		return {};
	}

	if (!render) return {};

	const int w = static_cast<int>(render->getWidth()) + 4;
	const int h = static_cast<int>(render->getHeight() + render->getDepth()) + 4;

	if (w <= 4 || h <= 4) {
		delete render;
		return {};
	}

	QImage img(w, h, QImage::Format_ARGB32_Premultiplied);
	img.fill(Qt::transparent);

	QPainter painter(&img);
	painter.setRenderHint(QPainter::Antialiasing);
	painter.setRenderHint(QPainter::SmoothPixmapTransform);

	tex::Graphics2D_qt g2(&painter);
	render->draw(g2, 2, 2);

	delete render;
	return img;
}

} // namespace

MarkdownView::MarkdownView(QQuickItem* parent): QQuickPaintedItem(parent), mCursor(&mDocument) {
	setAntialiasing(true);
	setAcceptedMouseButtons(Qt::LeftButton);
	setAcceptHoverEvents(true);
	setCursor(QCursor(Qt::IBeamCursor));
	mDocument.setDocumentMargin(0);
	mDocument.setUndoRedoEnabled(false);
	ensureLatexInit();
}

void MarkdownView::paint(QPainter* painter) {
	painter->save();

	QAbstractTextDocumentLayout::PaintContext ctx;
	ctx.palette.setColor(QPalette::Text, mColor);
	ctx.palette.setColor(QPalette::WindowText, mColor);
	ctx.palette.setColor(QPalette::Mid, QColor(mColor.red(), mColor.green(), mColor.blue(), 80));
	ctx.palette.setColor(QPalette::Window, Qt::transparent);

	if (mCursor.hasSelection()) {
		QAbstractTextDocumentLayout::Selection sel;
		sel.cursor = mCursor;
		QTextCharFormat fmt;
		fmt.setBackground(mSelectionColor);
		fmt.setForeground(mSelectedTextColor);
		sel.format = fmt;
		ctx.selections = {sel};
	}

	mDocument.documentLayout()->draw(painter, ctx);
	painter->restore();
}

void MarkdownView::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
	QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);

	const bool widthChanged = !qFuzzyCompare(newGeometry.width(), oldGeometry.width());
	if (widthChanged && newGeometry.width() > 0) {
		if (mPendingUpdate) {
			updateDocument();
		} else {
			mDocument.setTextWidth(newGeometry.width());
			setImplicitHeight(mDocument.size().height());
			update();
		}
	}
}

void MarkdownView::mousePressEvent(QMouseEvent* event) {
	mPressPos = event->position();

	if (!mSelectByMouse) {
		QQuickPaintedItem::mousePressEvent(event);
		return;
	}

	forceActiveFocus(Qt::MouseFocusReason);
	const int pos = mDocument.documentLayout()->hitTest(event->position(), Qt::FuzzyHit);
	if (pos >= 0) {
		mCursor.setPosition(pos);
		mSelecting = true;
	}
	update();
	event->accept();
}

void MarkdownView::mouseMoveEvent(QMouseEvent* event) {
	if (!mSelectByMouse || !mSelecting) {
		QQuickPaintedItem::mouseMoveEvent(event);
		return;
	}

	const int pos = mDocument.documentLayout()->hitTest(event->position(), Qt::FuzzyHit);
	if (pos >= 0) mCursor.setPosition(pos, QTextCursor::KeepAnchor);
	update();
	event->accept();
}

void MarkdownView::mouseReleaseEvent(QMouseEvent* event) {
	mSelecting = false;

	// Detect a click (press and release within a small radius) and open any link under cursor.
	const qreal dx = event->position().x() - mPressPos.x();
	const qreal dy = event->position().y() - mPressPos.y();
	const bool isClick = (dx * dx + dy * dy) < 16.0; // 4px radius

	if (isClick) {
		const QString anchor = mDocument.documentLayout()->anchorAt(event->position());
		if (!anchor.isEmpty()) {
			QDesktopServices::openUrl(QUrl(anchor));
			event->accept();
			return;
		}
	}

	event->accept();
}

void MarkdownView::hoverMoveEvent(QHoverEvent* event) {
	const QString anchor = mDocument.documentLayout()->anchorAt(event->position());
	setCursor(QCursor(anchor.isEmpty() ? Qt::IBeamCursor : Qt::PointingHandCursor));
	event->accept();
}

void MarkdownView::mouseDoubleClickEvent(QMouseEvent* event) {
	if (!mSelectByMouse) {
		QQuickPaintedItem::mouseDoubleClickEvent(event);
		return;
	}

	const int pos = mDocument.documentLayout()->hitTest(event->position(), Qt::FuzzyHit);
	if (pos >= 0) {
		mCursor.setPosition(pos);
		mCursor.select(QTextCursor::WordUnderCursor);
	}
	mSelecting = false;
	update();
	event->accept();
}

void MarkdownView::keyPressEvent(QKeyEvent* event) {
	if (event->matches(QKeySequence::Copy) && mCursor.hasSelection()) {
		QGuiApplication::clipboard()->setText(mCursor.selectedText());
		event->accept();
		return;
	}
	if (event->matches(QKeySequence::SelectAll)) {
		mCursor.select(QTextCursor::Document);
		update();
		event->accept();
		return;
	}
	QQuickPaintedItem::keyPressEvent(event);
}

void MarkdownView::updateDocument() {
	if (width() <= 0) {
		mPendingUpdate = true;
		return;
	}
	mPendingUpdate = false;

	QFont font;
	if (!mFontFamily.isEmpty()) font.setFamily(mFontFamily);
	font.setPixelSize(static_cast<int>(mFontSize));
	mDocument.setDefaultFont(font);

	const QString fg = mColor.name(QColor::HexRgb);
	const QString link = mLinkColor.name(QColor::HexRgb);
	const int fs = static_cast<int>(mFontSize);

	mDocument.setDefaultStyleSheet(QStringLiteral(
	                                   "body{color:%1;font-size:%2px;}"
	                                   "p{color:%1;}"
	                                   "a{color:%3;text-decoration:underline;}"
	                                   "code{font-family:monospace;font-size:%2px;color:%1;}"
	                                   "pre{font-family:monospace;font-size:%2px;}"
	                                   "ul,ol{margin-top:2px;margin-bottom:2px;}"
	                                   "li{color:%1;}"
	                                   "blockquote{margin-left:12px;}"
	                                   "strong{font-weight:bold;}"
	                                   "em{font-style:italic;}"
	                                   "mark{background-color:#554400;color:#FFE08A;}"
	                                   "dt{font-weight:bold;}"
	                                   "dd{margin-left:16px;}"
	)
	                                   .arg(fg)
	                                   .arg(fs)
	                                   .arg(link));

	// Render math spans to images before setMarkdown() clears the resource cache.
	const QList<MathFrag> mathFrags = extractMath(mText);
	QHash<int, QImage> mathImages;
	mathImages.reserve(mathFrags.size());

	QString processedText;
	processedText.reserve(mText.size() + mathFrags.size() * 32);
	int pos = 0;

	for (int i = 0; i < mathFrags.size(); ++i) {
		const MathFrag& frag = mathFrags.at(i);
		processedText += mText.mid(pos, frag.start - pos);

		QImage img = renderMathFormula(frag.formula, mFontSize, mColor);
		if (!img.isNull()) {
			mathImages[i] = img;
			const QString tag = QStringLiteral("<img src=\"math://%1\"/>").arg(i);
			processedText +=
			    frag.isDisplay ? (QStringLiteral("\n\n") + tag + QStringLiteral("\n\n")) : tag;
		} else {
			processedText += mText.mid(frag.start, frag.end - frag.start);
		}

		pos = frag.end;
	}
	processedText += mText.mid(pos);

	// Strip image syntax — QTextDocument has no network access so images would
	// just show as broken placeholders.
	static const QRegularExpression sImages(QStringLiteral(R"(!\[[^\]]*\]\([^\)]*\))"));
	processedText.remove(sImages);

	mDocument.setMarkdown(processedText, QTextDocument::MarkdownDialectGitHub);

	// Re-add image resources after setMarkdown() cleared the cache.
	for (auto it = mathImages.constBegin(); it != mathImages.constEnd(); ++it) {
		mDocument.addResource(
		    QTextDocument::ImageResource,
		    QUrl(QStringLiteral("math://%1").arg(it.key())),
		    QVariant(it.value())
		);
	}

	mDocument.setTextWidth(width());

	// Qt's built-in UA stylesheet uses abstract size keywords for headings that
	// override our font-size rules, so enforce sizes directly on each fragment.
	// setDefaultStyleSheet() only applies to HTML (setHtml()), NOT to blocks
	// created by setMarkdown(), so paragraph spacing must also be set here.
	static constexpr std::array<qreal, 7> kScales = {0.0, 1.5, 1.3, 1.15, 1.1, 1.05, 1.0};
	for (QTextBlock blk = mDocument.begin(); blk.isValid(); blk = blk.next()) {
		const int lvl = blk.blockFormat().headingLevel();

		if (lvl >= 1 && lvl <= 6) {
			// Fix heading font sizes.
			const int sz = static_cast<int>(mFontSize * kScales[static_cast<std::size_t>(lvl)]);
			QTextCursor cur(&mDocument);
			for (auto it = blk.begin(); !it.atEnd(); ++it) {
				const QTextFragment frag = it.fragment();
				if (!frag.isValid()) continue;
				QTextCharFormat fmt;
				fmt.setProperty(QTextFormat::FontPixelSize, sz);
				cur.setPosition(frag.position());
				cur.setPosition(frag.position() + frag.length(), QTextCursor::KeepAnchor);
				cur.mergeCharFormat(fmt);
			}
		} else if (blk.textList() == nullptr) {
			// Fix paragraph spacing for plain paragraphs (not list items).
			// The Markdown importer leaves bottom-margin at zero; set it now.
			QTextBlockFormat bfmt = blk.blockFormat();
			bfmt.setBottomMargin(mFontSize * 0.8);
			QTextCursor cur(&mDocument);
			cur.setPosition(blk.position());
			cur.mergeBlockFormat(bfmt);
		}
	}

	// Re-run layout after heading size changes so size() is correct.
	mDocument.setTextWidth(width());

	mCursor = QTextCursor(&mDocument);
	setImplicitHeight(mDocument.size().height());
	update();
}

QString MarkdownView::text() const { return mText; }

void MarkdownView::setText(const QString& text) {
	if (mText == text) return;
	mText = text;
	emit textChanged();
	updateDocument();
}

QColor MarkdownView::color() const { return mColor; }

void MarkdownView::setColor(const QColor& color) {
	if (mColor == color) return;
	mColor = color;
	emit colorChanged();
	updateDocument();
}

qreal MarkdownView::fontSize() const { return mFontSize; }

void MarkdownView::setFontSize(qreal size) {
	if (qFuzzyCompare(mFontSize, size)) return;
	mFontSize = size;
	emit fontSizeChanged();
	updateDocument();
}

QString MarkdownView::fontFamily() const { return mFontFamily; }

void MarkdownView::setFontFamily(const QString& family) {
	if (mFontFamily == family) return;
	mFontFamily = family;
	emit fontFamilyChanged();
	updateDocument();
}

QColor MarkdownView::linkColor() const { return mLinkColor; }

void MarkdownView::setLinkColor(const QColor& color) {
	if (mLinkColor == color) return;
	mLinkColor = color;
	emit linkColorChanged();
	updateDocument();
}

bool MarkdownView::selectByMouse() const { return mSelectByMouse; }

void MarkdownView::setSelectByMouse(bool enabled) {
	if (mSelectByMouse == enabled) return;
	mSelectByMouse = enabled;
	emit selectByMouseChanged();
	if (!enabled) {
		mCursor.clearSelection();
		update();
	}
}

QColor MarkdownView::selectionColor() const { return mSelectionColor; }

void MarkdownView::setSelectionColor(const QColor& color) {
	if (mSelectionColor == color) return;
	mSelectionColor = color;
	emit selectionColorChanged();
	update();
}

QColor MarkdownView::selectedTextColor() const { return mSelectedTextColor; }

void MarkdownView::setSelectedTextColor(const QColor& color) {
	if (mSelectedTextColor == color) return;
	mSelectedTextColor = color;
	emit selectedTextColorChanged();
	update();
}
