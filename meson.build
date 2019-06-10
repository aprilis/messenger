# project name and programming language
project('com.github.aprilis.messenger', 'vala', 'c')

src = [
    'src/App.vala',
    'src/Data.vala',
    'src/Contact.vala',
    'src/Thread.vala',
    'src/SingleThread.vala',
    'src/GroupThread.vala',
    'src/ThreadsViewer.vala',
    'src/Conversation.vala',
    'src/FocusGrabber.vala',
    'src/ConvData.vala',
    'src/ApplicationPopOver.vala',
    'src/PopOver.vala',
    'src/Main.vala',
    'src/HeaderBar.vala',
    'src/MainWindowManager.vala',
    'src/Loading.vala',
    'src/Screen.vala',
    'src/SignIn.vala',
    'src/SignUp.vala',
    'src/Welcome.vala',
    'src/ThreadsScreen.vala',
    'src/PasswordScreen.vala',
    'src/LoadingScreen.vala',
    'src/Utils.vala',
    'src/LoginDialog.vala',
    'src/Version.vala',
    'src/GroupCreator.vala',
    'src/FadeOutBin.vala',
    'src/Shortcut.vala',
    'src/Settings.vala',
    'src/SettingsWindow.vala'
]

libapi = subproject('libapi')
libapi_dep = libapi.get_variable('libapi_dep')

valac = meson.get_compiler('vala')
vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

# Create a new executable, list the files we want to compile, list the dependencies we need, and install
executable(
    meson.project_name(),
    src,
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
    ],
    install: true
)

#Install our .desktop file so the Applications Menu will see it
install_data(
    'data' / meson.project_name() + '.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)
install_data (
    'schemas' / meson.project_name () + '.gschema.xml',
    install_dir: join_paths (get_option ('datadir'), 'glib-2.0', 'schemas'),
)
install_data (
    'script' / meson.project_name () + '-open-chat',
    install_dir: get_option ('bindir'),
)