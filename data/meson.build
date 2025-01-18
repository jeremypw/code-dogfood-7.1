icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach i : icon_sizes
    install_data(
        'icons' / i + '.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i / 'apps',
        rename: install_name + '.svg'
    )
    install_data(
        'icons' / i + '.svg',
        install_dir: get_option('datadir') / 'icons' / 'hicolor' / i + 'x' + i + '@2' / 'apps',
        rename: install_name + '.svg'
    )
endforeach

install_data([
  'styles/elementary-dark.xml',
  'styles/elementary-light.xml',
], install_dir: get_option('datadir') / 'gtksourceview-4' / 'styles')

install_data([
  'fonts/BuilderBlocks.ttf',
], install_dir: get_option('datadir') / install_name / 'fonts')

install_data(
    'com.github.jeremypw.dogfood-code-flatpak-7.gschema.xml',
    'com.github.jeremypw.dogfood-code-7.plugins.spell.gschema.xml',
    install_dir: get_option('prefix') / get_option('datadir') / 'glib-2.0' / 'schemas'
)

config_data = configuration_data()
config_data.set('EXEC_NAME', install_name)

if (branch != '')
    config_data.set('NAME', 'Dogfood Code Flatpak 7 - ' + branch)
else
    config_data.set('NAME', 'Dogfood Code Flatpak 7')
endif

# Set the executable name and translate the desktop files
desktop_in_file = configure_file(
    input: 'io.elementary.code.desktop.in.in',
    output: '@BASENAME@',
    configuration: config_data
)

desktop_file = i18n.merge_file(
    input: desktop_in_file,
    output: install_name + '.desktop',
    po_dir: meson.project_source_root () / 'po' / 'extra',
    type: 'desktop',
    install_dir: get_option('datadir') / 'applications',
    install: true
)

i18n.merge_file(
    input: 'code.metainfo.xml.in',
    output: install_name + '.metainfo.xml',
    po_dir: meson.project_source_root() / 'po' / 'extra',
    type: 'xml',
    install: true,
    install_dir: get_option('datadir') / 'metainfo',
)

config_data = configuration_data()
config_data.set('install_prefix', get_option('prefix'))
config_data.set('bin_dir', get_option('bindir'))
config_data.set('exec_name', install_name)

install_man(
    'io.elementary.code.1'
)
