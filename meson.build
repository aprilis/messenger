project('com.github.aprilis.messenger', 'vala', 'c', version: '0.2.3')

i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
    language: 'c'
)

libapi = subproject('libapi')
libapi_dep = libapi.get_variable('libapi_dep')

valac = meson.get_compiler('vala')
vapi_dir = join_paths(meson.current_source_dir(), 'vapi')

add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

subdir('src')

executable(
    meson.project_name(),
    sources,
    dependencies: [
        dependency('gtk+-3.0'),
        dependency('libsoup-2.4'),
        dependency('json-glib-1.0'),
        dependency('gio-2.0'),
        dependency('gee-0.8'),
        dependency('webkit2gtk-4.0'),
        dependency('granite'),
        dependency('unity'),
        dependency('plank'),
        dependency('libbamf3'),
        dependency('libnotify'),
        libapi_dep,
        valac.find_library('Fb', dirs: [vapi_dir]),
        valac.find_library('posix')
    ],
    install: true
)

subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')