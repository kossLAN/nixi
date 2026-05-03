#ifndef UTILS_H
#define UTILS_H

#include <QtCore/QObject>
#include <QtCore/QString>

class Utils: public QObject {
	Q_OBJECT

public:
	Utils(QObject* parent = nullptr);
	Q_INVOKABLE bool inPath(const QString& program) const;
};

#endif // UTILS_H
