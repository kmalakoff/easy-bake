module.exports =
  library:
    join: 'easy-bake.js'
    files: [
      'src/helpers.coffee'
      'src/easy-bake.coffee'
    ]
    _build:
      commands: [
        'cp easy-bake.js packages/npm/easy-bake.js'
        'cp README.md packages/npm/README.md'
        'cp -r bin packages/npm/bin'
      ]

  lib_utils:
    output: 'lib'
    files: 'src/easy-bake-utils.coffee'
    _build:
      commands: [
        'cp lib/easy-bake-utils.js packages/npm/lib/easy-bake-utils.js'
      ]

  lib_commands:
    join: 'easy-bake-commands.js'
    output: 'lib'
    files: [
      'src/helpers.coffee'
      'src/easy-bake-commands/queue.coffee'
      'src/easy-bake-commands/commands.coffee'
      'src/easy-bake-commands/file-system-commands.coffee'
      'src/easy-bake-commands/build-commands.coffee'
      'src/easy-bake-commands/test-commands.coffee'
      'src/easy-bake-commands/bundle-commands.coffee'
      'src/easy-bake-commands/publish-commands.coffee'
    ]
    _build:
      commands: [
        'cp lib/easy-bake-commands.js packages/npm/lib/easy-bake-commands.js'
      ]

  lib_test_runners:
    output: '../../lib/test_runners'
    directories: 'src/test_runners'
    _build:
      commands: [
        'cp -r lib/test_runners packages/npm/lib/test_runners'
      ]

  tests:
    directories: 'test/core'
    _build:
      output: 'build'
    _test:
      command: 'nodeunit'
      files: '**/*.js'