#include "utils.h"

#include <QtCore/QStandardPaths>

Utils::Utils(QObject* parent): QObject(parent) {}

bool Utils::inPath(const QString& program) const {
	return !QStandardPaths::findExecutable(program).isEmpty();
}
