project('com.github.gijsgoudzwaard.image-optimizer', 'vala', 'c',
  meson_version: '>= 0.56.0')

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="' + meson.project_name() + '"', language:'c')

asresources = gnome.compile_resources(
    'as-resources', 'data/' + meson.project_name() + '.gresource.xml',
    source_dir: 'data',
    c_name: 'as'
)

executable(
    meson.project_name(),
    asresources,
    'src/Application.vala',
    'src/MainWindow.vala',
    'src/Widgets/Toolbar.vala',
    'src/Widgets/UploadScreen.vala',
    'src/Widgets/List.vala',
    'src/Utils/Utils.vala',
    'src/Utils/Image.vala',
    'src/Utils/Optimizer.vala',
    'src/Utils/JpegOptim.vala',
    'src/Utils/OptiPng.vala',
    'src/Constants/Stylesheet.vala',
    dependencies: [
        dependency('gee-0.8'),
        dependency('glib-2.0'),
        dependency('gtk+-3.0'),
        dependency('granite'),
        meson.get_compiler('c').find_library('m', required : false)
    ],
    install: true
)
subdir('data')
subdir('po')

meson.add_install_script('meson/post_install.py')
