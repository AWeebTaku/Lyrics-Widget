cmake_minimum_required(VERSION 3.21)
project(lyric-widget VERSION 2.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

include(GNUInstallDirs)
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml DBus Network Sql WebSockets)
find_package(ICU REQUIRED COMPONENTS uc i18n)  # Han->pinyin, kana->romaji
qt_standard_project_setup()

# ---- C++ backend, shipped as the QML module "org.lyricwidget" -----------------
qt_add_qml_module(lyricbackend
  URI org.lyricwidget
  VERSION 1.0
  SHARED
  PLUGIN_TARGET lyricbackend
  SOURCES
    src/LrcParser.h
    src/Text.h
    src/Romanizer.h        src/Romanizer.cpp
    src/PlayerWatcher.h    src/PlayerWatcher.cpp
    src/LyricsStore.h      src/LyricsStore.cpp
    src/LyricsFetcher.h    src/LyricsFetcher.cpp
    src/SpotifyApp.h       src/SpotifyApp.cpp
    src/Process.h          src/Process.cpp
    src/BrowserSetup.h     src/BrowserSetup.cpp
    src/LyricsLibrary.h    src/LyricsLibrary.cpp
    src/ReadingFetcher.h   src/ReadingFetcher.cpp
    src/BrowserQueue.h     src/BrowserQueue.cpp
    src/LyricsController.h src/LyricsController.cpp
)
target_include_directories(lyricbackend PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_options(lyricbackend PRIVATE -Wall -Wextra)
target_link_libraries(lyricbackend PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::DBus Qt6::Network Qt6::Sql Qt6::WebSockets ICU::uc ICU::i18n)

# Qt's QML dir (e.g. /usr/lib/qt6/qml) -- plasmashell finds the module here.
set(LYRIC_QML_DIR ${CMAKE_INSTALL_LIBDIR}/qt6/qml/org/lyricwidget)
install(TARGETS lyricbackend LIBRARY DESTINATION ${LYRIC_QML_DIR})
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/qmldir
  ${CMAKE_CURRENT_BINARY_DIR}/lyricbackend.qmltypes
  DESTINATION ${LYRIC_QML_DIR})

# ---- Japanese romanization helper (run by the widget with the Python environment from setup-romaji.sh)
install(FILES romaji/romaji.py DESTINATION ${CMAKE_INSTALL_DATADIR}/lyric-widget)

# ---- Chrome extension for the YouTube Music queue (load it unpacked)
install(DIRECTORY extension/ DESTINATION ${CMAKE_INSTALL_DATADIR}/lyric-widget/extension)

# ---- Plasma widget package ----------------------------------------------------
install(DIRECTORY plasmoid/
  DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/plasmoids/org.lyricwidget)

