module_name = 'vim-emulation'

module_files = [
    'vim-emulation.vala'
]

module_deps = [
    dogfood_code_core_dep
]

shared_module(
    module_name,
    module_files,
    dependencies: module_deps,
    install: true,
    install_dir: pluginsdir / module_name,
)

custom_target(module_name + '.plugin_merge',
    input: module_name + '.plugin',
    output: module_name + '.plugin',
    command : [msgfmt,
               '--desktop',
               '--keyword=Description',
               '--keyword=Name',
               '-d' + meson.project_source_root () / 'po' / 'plugins',
               '--template=@INPUT@',
               '-o@OUTPUT@',
               ],
    install : true,
    install_dir: pluginsdir / module_name,
)
