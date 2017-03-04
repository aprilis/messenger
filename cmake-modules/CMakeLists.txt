project (cmake-elementary)
cmake_minimum_required (VERSION 2.8.9)

file (GLOB_RECURSE SRC_FILES "src/*.cmake")

install (FILES ${SRC_FILES} DESTINATION ${CMAKE_ROOT}/Modules/)
