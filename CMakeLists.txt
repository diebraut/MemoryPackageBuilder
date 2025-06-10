cmake_minimum_required(VERSION 3.16)

project(MemoryPackagesBuilder VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Qt6 Komponenten finden – jetzt inklusive Xml
find_package(Qt6 6.4 REQUIRED COMPONENTS Quick Core Gui Xml)

#qt_policy(SET QTP0001 NEW)

# Standard Projekt Setup für Qt
qt_standard_project_setup()

qt_add_resources(IMAGE_RESOURCES icons/icons.qrc)

# Füge die ausführbare Datei hinzu
qt_add_executable(appMemoryPackagesBuilder
    main.cpp
    ${IMAGE_RESOURCES}
)

# Füge die QML-Dateien und C++-Quellen hinzu
qt_add_qml_module(appMemoryPackagesBuilder
    URI MemoryPackagesBuilder
    VERSION 1.0
    QML_FILES
        Main.qml
        UebungenDialog.qml
        EditExersizeDialog.qml
        ImageProcessingWindow.qml
    SOURCES
        packagemodel.h packagemodel.cpp
        ExersizeModel.h
        packageparser.h packageparser.cpp
        exersizeloader.h exersizeloader.cpp
)

# Linke die Qt-Bibliotheken – jetzt inklusive Qt6::Xml
target_link_libraries(appMemoryPackagesBuilder
    PRIVATE Qt6::Quick Qt6::Core Qt6::Gui Qt6::Xml
)

# 📂 Kopiere exercisepackages-Verzeichnis nach Build-Ausgabeordner
add_custom_command(TARGET appMemoryPackagesBuilder POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_SOURCE_DIR}/exercisepackages
        $<TARGET_FILE_DIR:appMemoryPackagesBuilder>/exercisepackages
)

# Installiere die Anwendung
include(GNUInstallDirs)
install(TARGETS appMemoryPackagesBuilder
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
