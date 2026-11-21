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
# the module has no QML files or resources, so the new default resource prefix changes nothing; set it to silence the warning
if(COMMAND qt_policy)
  qt_policy(SET QTP0001 NEW)
endif()

# ---- C++ backend, shipped as the QML module "org.lyricwidget" -----------------
qt_add_qml_module(lyricbackend
  URI org.lyricwidget
  VERSION 1.0
  SHARED
  PLUGIN_TARGET lyricbackend
  OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/org/lyricwidget
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
    src/VizCore.h
    src/VizAnalysis.h      src/VizAnalysis.cpp
    src/TrackDetails.h     src/TrackDetails.cpp
    src/WindowPlacer.h     src/WindowPlacer.cpp
)
target_include_directories(lyricbackend PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_compile_options(lyricbackend PRIVATE -Wall -Wextra)
target_link_libraries(lyricbackend PRIVATE
  Qt6::Core Qt6::Gui Qt6::Qml Qt6::DBus Qt6::Network Qt6::Sql Qt6::WebSockets ICU::uc ICU::i18n)

# Qt's QML dir (e.g. /usr/lib/qt6/qml) -- plasmashell finds the module here.
set(LYRIC_QML_DIR ${CMAKE_INSTALL_LIBDIR}/qt6/qml/org/lyricwidget)
install(TARGETS lyricbackend LIBRARY DESTINATION ${LYRIC_QML_DIR})
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/org/lyricwidget/qmldir
  ${CMAKE_CURRENT_BINARY_DIR}/org/lyricwidget/lyricbackend.qmltypes
  DESTINATION ${LYRIC_QML_DIR})

# ---- Japanese romanization helper (run by the widget with the Python environment from setup-romaji.sh)
install(FILES romaji/romaji.py DESTINATION ${CMAKE_INSTALL_DATADIR}/lyric-widget)

# ---- the doctor script (checks what the widget needs) and examples of your own visualizers, seek bars and buttons
install(PROGRAMS tools/doctor.sh DESTINATION ${CMAKE_INSTALL_DATADIR}/lyric-widget)
install(DIRECTORY examples/ DESTINATION ${CMAKE_INSTALL_DATADIR}/lyric-widget/examples)

# ---- Chrome extension for the YouTube Music queue (load it unpacked)
install(DIRECTORY extension/ DESTINATION ${CMAKE_INSTALL_DATADIR}/lyric-widget/extension)

# ---- the widget's icon (the website's favicon): metadata.json names it "org.lyricwidget"
install(FILES docs/favicon.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps RENAME org.lyricwidget.svg)

# ---- Plasma widget package ----------------------------------------------------
# PLUGIN_ONLY=ON (install.sh): the plugin and its data only, for a widget installed from the KDE Store
option(PLUGIN_ONLY "Install only the plugin and its data, not the widget files" OFF)
if(NOT PLUGIN_ONLY)
  install(DIRECTORY plasmoid/
    DESTINATION ${CMAKE_INSTALL_DATADIR}/plasma/plasmoids/org.lyricwidget)
endif()


# ---- tests (optional): table-driven checks of the lyric matching in src/Text.h
option(BUILD_TESTS "Build the matching tests (run: ctest --test-dir build)" OFF)
if(BUILD_TESTS)
  enable_testing()
  add_executable(matching_tests tests/matching.cpp src/Romanizer.cpp)
  target_include_directories(matching_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(matching_tests PRIVATE Qt6::Core Qt6::Gui ICU::uc ICU::i18n)   # Gui: QColor and QImage for the cover colors
  add_test(NAME matching COMMAND matching_tests)
  add_executable(wordtiming_tests tests/wordtiming.cpp)
  target_include_directories(wordtiming_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(wordtiming_tests PRIVATE Qt6::Core)
  add_test(NAME wordtiming COMMAND wordtiming_tests)
  add_executable(viz_tests tests/vizanalysis.cpp)
  target_include_directories(viz_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  add_test(NAME viz COMMAND viz_tests)
  add_executable(localfiles_tests tests/localfiles.cpp)
  target_include_directories(localfiles_tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
  target_link_libraries(localfiles_tests PRIVATE Qt6::Core)
  add_test(NAME localfiles COMMAND localfiles_tests)
  find_program(NODE_EXECUTABLE node)
  if(NODE_EXECUTABLE)
    add_test(NAME presets COMMAND ${NODE_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/presets.test.js)
    add_test(NAME layouts COMMAND ${NODE_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/layouts.test.js)
    add_test(NAME settings COMMAND ${NODE_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/tests/settings.test.js)
  endif()
endif()
