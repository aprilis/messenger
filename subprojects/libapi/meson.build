project('com.github.aprilis.messenger.api', 'c')
gnome = import('gnome')

sources = [
    'api/http.c',
    'api/util.c',
    'api/marshal.c',
    'api/mqtt.c',
    'api/json.c',
    'api/thrift.c',
    'api/api.c'
]

headers = [
    'api/http.h',
    'api/util.h',
    'api/marshal.h',
    'api/mqtt.h',
    'api/json.h',
    'api/thrift.h',
    'api/api.h',
    'api/id.h',
    'api/internal.h'
]

libapi = shared_library(
    meson.project_name(),
    sources,
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('libsoup-2.4'),
        dependency('json-glib-1.0')
    ],
    install: true
)

include = include_directories('.')

libapi_dep = declare_dependency(link_with: libapi, include_directories: include)