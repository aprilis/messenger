cmake_minimum_required(VERSION 2.6)
project(messenger)

# tell cmake where its modules can be found in our project directory
list (APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake-modules/src)

# where we install data directory (if we have any)
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

set (EXEC_NAME "messenger")

add_subdirectory(${CMAKE_SOURCE_DIR}/src/api)

find_package(PkgConfig REQUIRED)

# make sure we have vala
find_package(Vala REQUIRED)
# make sure we use vala
include(ValaVersion)
# make sure it's the desired version of vala
ensure_vala_version("0.26" MINIMUM)

# files we want to compile
include(ValaPrecompile)
vala_precompile(VALA_C messenger
    src/App.vala
    src/Data.vala
    src/Contact.vala
    src/Thread.vala
    src/SingleThread.vala
    src/GroupThread.vala
    src/ThreadsViewer.vala
    src/Conversation.vala
    src/FocusGrabber.vala
    src/ConvData.vala
    src/PopOver.vala
    src/Main.vala
    src/HeaderBar.vala
    src/MainWindow.vala
    src/Loading.vala
    src/Screen.vala
    src/SignIn.vala
    src/SignUp.vala
    src/Welcome.vala
    src/ThreadsScreen.vala
    src/PasswordScreen.vala
    src/LoadingScreen.vala
    src/Utils.vala
    src/LoginDialog.vala
    src/Version.vala
    src/GroupCreator.vala
    src/FadeOutBin.vala
    src/Shortcut.vala
    src/Settings.vala
    src/SettingsWindow.vala

# tell what libraries to use when compiling
PACKAGES
    gobject-2.0
    glib-2.0
    gio-2.0
    libsoup-2.4
    json-glib-1.0
    gtk+-3.0
    gee-0.8
    webkit2gtk-4.0
    granite
    unity
    plank
    libnotify
    
CUSTOM_VAPIS
    vapi/Fb.vapi
    
OPTIONS
    -g
)

# tell cmake what to call the executable we just made
add_executable(${EXEC_NAME} ${VALA_C})

target_link_libraries(${EXEC_NAME} PUBLIC api)
target_include_directories(${EXEC_NAME} PUBLIC ${CMAKE_SOURCE_DIR}/src)

pkg_search_module(GDK_PIXBUF REQUIRED gdk-pixbuf-2.0)
target_compile_options(${EXEC_NAME} PUBLIC ${GDK_PIXBUF_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${GDK_PIXBUF_LIBRARIES})

pkg_search_module(GEE REQUIRED gee-0.8)
target_compile_options(${EXEC_NAME} PUBLIC ${GEE_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${GEE_LIBRARIES})

pkg_search_module(GTK REQUIRED gtk+-3.0)
target_compile_options(${EXEC_NAME} PUBLIC ${GTK_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${GTK_LIBRARIES})

pkg_search_module(WEBKIT REQUIRED webkit2gtk-4.0)
target_compile_options(${EXEC_NAME} PUBLIC ${WEBKIT_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${WEBKIT_LIBRARIES})

pkg_search_module(GRANITE REQUIRED granite)
target_compile_options(${EXEC_NAME} PUBLIC ${GRANITE_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${GRANITE_LIBRARIES})

pkg_search_module(UNITY REQUIRED unity)
target_compile_options(${EXEC_NAME} PUBLIC ${UNITY_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${UNITY_LIBRARIES})

pkg_search_module(PLANK REQUIRED plank)
target_compile_options(${EXEC_NAME} PUBLIC ${PLANK_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${PLANK_LIBRARIES})

pkg_search_module(LIBNOTIFY REQUIRED libnotify)
target_compile_options(${EXEC_NAME} PUBLIC ${LIBNOTIFY_CFLAGS})
target_link_libraries(${EXEC_NAME} PUBLIC ${LIBNOTIFY_LIBRARIES})

# install the binaries we just made
install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

# install open chat script
install (PROGRAMS ${CMAKE_CURRENT_SOURCE_DIR}/script/messenger-open-chat DESTINATION bin)

# install our .desktop file so the Applications menu will see it
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.aprilis.messenger.desktop DESTINATION ${DATADIR}/applications/)

include(GSettings)
add_schema("schemas/com.github.aprilis.messenger.gschema.xml")
