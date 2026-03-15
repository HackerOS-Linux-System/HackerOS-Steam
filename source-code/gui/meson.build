project(
  'hackeros-steam-gui',
  'vala', 'c',
  version: '2.0.0',
  meson_version: '>= 0.62.0',
  default_options: ['warning_level=2'],
)

fs = import('fs')

# ── Dependencies ──────────────────────────────────────────────────────────────
gtk4_dep = dependency('gtk4',    version: '>= 4.8')
glib_dep = dependency('glib-2.0')
gio_dep  = dependency('gio-2.0')

deps = [gtk4_dep, glib_dep, gio_dep]

# ── Sources ───────────────────────────────────────────────────────────────────
sources = files('src/main.vala')

# ── Executable ────────────────────────────────────────────────────────────────
executable(
  'hackeros-steam-gui',
  sources,
  dependencies: deps,
  vala_args: [
    '--target-glib=2.74',
    '--enable-experimental',
  ],
  install: true,
  install_dir: get_option('bindir'),
)

# ── Desktop entry ─────────────────────────────────────────────────────────────
install_data(
  'data/io.hackeros.steam.desktop',
  install_dir: get_option('datadir') / 'applications',
)

# ── App icon (optional) ───────────────────────────────────────────────────────
icon_dir = get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
if fs.exists('data/io.hackeros.steam.svg')
  install_data(
    'data/io.hackeros.steam.svg',
    install_dir: icon_dir,
  )
endif
