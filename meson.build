project('com.github.gijsgoudzwaard.image-optimizer', 'vala', 'c',
  version: '0.2.0',
  meson_version: '>= 0.59.0')

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
    'src/Widgets/UploadScreen.vala',
    'src/Widgets/List.vala',
    'src/Widgets/ImageRow.vala',
    'src/Utils/Utils.vala',
    'src/Utils/Image.vala',
    'src/Utils/Optimizer.vala',
    'src/Utils/JpegOptim.vala',
    'src/Utils/OptiPng.vala',
    'src/Constants/Stylesheet.vala',
    dependencies: [
        dependency('glib-2.0'),
        dependency('gtk4', version: '>= 4.12'),
        meson.get_compiler('c').find_library('m', required : false)
    ],
    install: true
)
subdir('data')
subdir('po')

gnome.post_install(
    gtk_update_icon_cache: true,
    update_desktop_database: true
)
