cmake_minimum_required(VERSION 3.16)

project(utils LANGUAGES C CXX)

# Acknowledge variables injected by the Nix cmake build hook to suppress warnings.
option(BUILD_TESTING "Build tests" OFF)
set(CMAKE_EXPORT_NO_PACKAGE_REGISTRY ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Gui Network Quick)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INSTALL_RPATH "$ORIGIN")
set(CMAKE_AUTOMOC ON)
qt_policy(SET QTP0001 NEW)

# nix workaround
if (CMAKE_EXPORT_COMPILE_COMMANDS)
	set(CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES})
endif()

# MicroTeX
find_library(MICROTEX_LIBRARY NAMES LaTeX clatexmath microtex REQUIRED)
find_path(MICROTEX_INCLUDE_DIR NAMES "microtex/latex.h" REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(TINYXML2 REQUIRED tinyxml2)

# Wayland screencopy protocol
pkg_check_modules(WAYLAND_CLIENT REQUIRED wayland-client)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)

if (NOT DEFINED WLR_PROTOCOLS_DIR)
	message(FATAL_ERROR "WLR_PROTOCOLS_DIR must be set to the wlr-protocols share directory")
endif()

set(SCREENCOPY_XML "${WLR_PROTOCOLS_DIR}/unstable/wlr-screencopy-unstable-v1.xml")

set(SCREENCOPY_HEADER "${CMAKE_CURRENT_BINARY_DIR}/wlr-screencopy-client-protocol.h")
set(SCREENCOPY_SOURCE "${CMAKE_CURRENT_BINARY_DIR}/wlr-screencopy-protocol.c")

add_custom_command(
	OUTPUT "${SCREENCOPY_HEADER}"
	COMMAND "${WAYLAND_SCANNER}" client-header "${SCREENCOPY_XML}" "${SCREENCOPY_HEADER}"
	DEPENDS "${SCREENCOPY_XML}"
	COMMENT "Generating wlr-screencopy client header"
)

add_custom_command(
	OUTPUT "${SCREENCOPY_SOURCE}"
	COMMAND "${WAYLAND_SCANNER}" private-code "${SCREENCOPY_XML}" "${SCREENCOPY_SOURCE}"
	DEPENDS "${SCREENCOPY_XML}"
	COMMENT "Generating wlr-screencopy protocol source"
)

set_source_files_properties("${SCREENCOPY_SOURCE}" PROPERTIES LANGUAGE C)

add_library(nixiutils SHARED
	utilsplugin.cpp
	clipboard.cpp clipboard.h
	utils.cpp utils.h
	cachedimage.cpp cachedimage.h
	httprequest.cpp httprequest.h
	markdownview.cpp markdownview.h
	screenshotter.cpp screenshotter.h
	screenshotprovider.cpp screenshotprovider.h
	"${SCREENCOPY_SOURCE}"
)

# screenshotter.cpp includes the generated header — make the dependency explicit
set_source_files_properties(screenshotter.cpp PROPERTIES
	OBJECT_DEPENDS "${SCREENCOPY_HEADER}"
)

target_include_directories(nixiutils PRIVATE
	${MICROTEX_INCLUDE_DIR}
	${MICROTEX_INCLUDE_DIR}/microtex
	${WAYLAND_CLIENT_INCLUDE_DIRS}
	${CMAKE_CURRENT_BINARY_DIR}
)

target_link_libraries(nixiutils
	Qt6::Qml Qt6::Gui Qt6::Core Qt6::Network Qt6::Quick
	${MICROTEX_LIBRARY}
	${TINYXML2_LIBRARIES}
	${WAYLAND_CLIENT_LIBRARIES}
)

target_compile_definitions(nixiutils PRIVATE BUILD_QT)

if (MICROTEX_RES_DIR)
	target_compile_definitions(nixiutils PRIVATE MICROTEX_RES_DIR="${MICROTEX_RES_DIR}")
endif()

install(TARGETS nixiutils DESTINATION lib/qt-6/qml/NixiUtils)
install(FILES qmldir DESTINATION lib/qt-6/qml/NixiUtils)
