cmake_minimum_required(VERSION 2.6)
project(messenger)
            
add_library(api STATIC
            http.c
            util.c
            marshal.c
            mqtt.c
            json.c
            thrift.c
            api.c)
            
add_library(api_so SHARED
            http.c
            util.c
            marshal.c
            mqtt.c
            json.c
            thrift.c
            api.c)

find_package(PkgConfig REQUIRED)
pkg_search_module(GLIB_2 REQUIRED glib-2.0)
pkg_search_module(JSON_GLIB REQUIRED json-glib-1.0)
pkg_search_module(SOUP REQUIRED libsoup-2.4)

target_compile_options(api PUBLIC ${GLIB_2_CFLAGS})
target_compile_options(api PUBLIC ${JSON_GLIB_CFLAGS})
target_compile_options(api PUBLIC ${SOUP_CFLAGS})

include_directories(${JSON_GLIB_INCLUDE_DIRS})
include_directories(${GLIB_2_INCLUDE_DIRS})
include_directories(${SOUP_INCLUDE_DIRS})

target_link_libraries(api PUBLIC z)
target_link_libraries(api PUBLIC ${JSON_GLIB_LIBRARIES})
target_link_libraries(api PUBLIC ${GLIB_2_LIBRARIES})
target_link_libraries(api PUBLIC ${SOUP_LIBRARIES})

get_property(includes DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} PROPERTY INCLUDE_DIRECTORIES)
get_target_property(libs api LINK_LIBRARIES)
get_target_property(cflags api COMPILE_OPTIONS)
