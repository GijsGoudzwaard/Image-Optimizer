  # project name
  project (com.github.gijsgoudzwaard.image-optimizer)

    # the oldest stable cmake version we support
    cmake_minimum_required (VERSION 2.6)

    # tell cmake where its modules can be found in our project directory
    list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)
    list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/src)

    # where we install data directory (if we have any)
    set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

    # what to call that directory where we install data too
    set (PKGDATADIR "${DATADIR}/com.github.gijsgoudzwaard.image-optimizer")

    set (EXEC_NAME "com.github.gijsgoudzwaard.image-optimizer")
    set (RELEASE_NAME "A hello world.")
    set (VERSION "0.1")
    set (VERSION_INFO "whats up world")

    # we're about to use pkgconfig to make sure dependencies are installed so let's find pkgconfig first
    find_package(PkgConfig)

    # now let's actually check for the required dependencies
    pkg_check_modules(DEPS REQUIRED gtk+-3.0 granite)

    add_definitions(${DEPS_CFLAGS})
    link_libraries(${DEPS_LIBRARIES})
    link_directories(${DEPS_LIBRARY_DIRS})

    # make sure we have vala
    find_package(Vala REQUIRED)
    # make sure we use vala
    include(ValaVersion)
    # make sure it's the desired version of vala
    ensure_vala_version("0.26.0" MINIMUM)

    # files we want to compile
    include(ValaPrecompile)
    vala_precompile(VALA_C ${EXEC_NAME}
        src/Application.vala
        src/MainWindow.vala
        src/Widgets/Toolbar.vala
        src/Widgets/UploadScreen.vala
        src/Widgets/List.vala
        src/Utils/Utils.vala
        src/Utils/Image.vala
        src/Utils/Optimizer.vala
        src/Utils/JpegOptim.vala
        src/Utils/OptiPng.vala
        src/Constants/Stylesheet.vala

    # tell what libraries to use when compiling
    PACKAGES
        gtk+-3.0
        granite
    )

    # tell cmake what to call the executable we just made
    add_executable(${EXEC_NAME} ${VALA_C})

    # include (GResource)
    # glib_compile_resources (data/icons/icons.xml)

    # install the binaries we just made
    install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/16/com.github.gijsgoudzwaard.image-optimizer.svg DESTINATION share/icons/hicolor/16x16/apps)
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/32/com.github.gijsgoudzwaard.image-optimizer.svg DESTINATION share/icons/hicolor/32x32/apps)
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/48/com.github.gijsgoudzwaard.image-optimizer.svg DESTINATION share/icons/hicolor/48x48/apps)
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/64/com.github.gijsgoudzwaard.image-optimizer.svg DESTINATION share/icons/hicolor/64x64/apps)
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/128/com.github.gijsgoudzwaard.image-optimizer.svg DESTINATION share/icons/hicolor/128x128/apps)

    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/64/com.github.gijsgoudzwaard.image-optimizer.svg DESTINATION share/icons/hicolor/scalable/apps)

    # install our .desktop file so the Applications menu will see it
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.gijsgoudzwaard.image-optimizer.desktop DESTINATION ${DATADIR}/applications/)

    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.gijsgoudzwaard.image-optimizer.contract DESTINATION ~/.local/share/contractor)

    # install our .appdata.xml file so AppCenter will see it
    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.gijsgoudzwaard.image-optimizer.appdata.xml DESTINATION ${DATADIR}/metainfo/)

    install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/upload_icon.svg DESTINATION share/icons/hicolor/scalable/apps)
