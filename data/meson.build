icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
    )
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i + '@2', 'apps')
    )
endforeach

i18n.merge_file(
    input: meson.project_name() + '.desktop.in',
    output: meson.project_name() + '.desktop',
    po_dir: join_paths(meson.project_source_root(), 'po', 'extra'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

i18n.merge_file(
    input: meson.project_name() + '.appdata.xml.in',
    output: meson.project_name() + '.appdata.xml',
    po_dir: join_paths(meson.project_source_root(), 'po', 'extra'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

desktop_file_validate = find_program('desktop-file-validate', required:false)

if desktop_file_validate.found()
    test (
        'Validate desktop file',
        desktop_file_validate,
        args: join_paths(meson.current_build_dir (), meson.project_name() + '.desktop')
    )
endif
appstreamcli = find_program(['appstreamcli', 'appstream-util'], required:false)
if appstreamcli.found()
    test (
        'Validate appdata file',
        appstreamcli,
        args: ['validate', join_paths(meson.current_build_dir (), meson.project_name() + '.appdata.xml')]
    )
endif
