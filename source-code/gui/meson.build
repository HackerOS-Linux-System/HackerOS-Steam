project('gui', 'vala', 'c',
        version: '0.1.0')

add_project_arguments(
    '--vapidir=' + join_paths(meson.current_source_dir(), 'vapi'),
    language: 'vala'
)

dependencies = [
    dependency('gtk4'),
    dependency('glib-2.0'),
    dependency('gio-2.0'),
]

sources = files('src/main.vala')

executable('gui', sources,
           dependencies: dependencies,
           install: false)
