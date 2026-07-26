icon_sizes = ['16', '24', '32', '48', '64', '128']

# Every size is installed once. There used to be a second copy in an @2
# directory, but @2 exists so a raster icon can carry twice the pixels, and
# these are SVG: the same file in both places told GTK nothing it could not
# work out by scaling, and doubled the icons in every package.
foreach i : icon_sizes
    install_data(
        join_paths('icons', i, meson.project_name() + '.svg'),
        install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', i + 'x' + i, 'apps')
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
# Only appstreamcli, not appstream-util: the --no-net switch below is specific
# to appstreamcli, appstream-util spells it --nonet.
appstreamcli = find_program('appstreamcli', required:false)
if appstreamcli.found()
    # --no-net keeps the check to the file itself. Without it appstreamcli tries
    # to fetch every <url> and <screenshot>, which fails inside the flatpak
    # build sandbox because it has no network. Whether an upstream host happens
    # to answer is not something the build should depend on either way.
    test (
        'Validate appdata file',
        appstreamcli,
        args: ['validate', '--no-net', join_paths(meson.current_build_dir (), meson.project_name() + '.appdata.xml')]
    )
endif
