module.exports =
  library:
    files: 'src/easy-bake.coffee'
    modes:
      build:
        commands: [
          'cp easy-bake.js packages/npm/easy-bake.js'
        ]

  lib_utils:
    output: 'lib'
    files: 'src/easy-bake-utils.coffee'
    modes:
      build:
        commands: [
          'cp lib/easy-bake-utils.js packages/npm/lib/easy-bake-utils.js'
        ]

  lib_commands:
    join: 'easy-bake-commands.js'
    output: 'lib'
    files: [
      'src/commands/queue.coffee'
      'src/commands/commands.coffee'
    ]
    modes:
      build:
        commands: [
          'cp lib/easy-bake-commands.js packages/npm/lib/easy-bake-commands.js'
        ]

  lib_test_runners:
    output: '../../lib/test_runners'
    directories: 'src/test_runners'
    modes:
      build:
        commands: [
          'cp -r lib/test_runners packages/npm/lib/test_runners'
        ]

  tests:
    output: 'build'
    directories: 'test/core'
    modes:
      test:
        command: 'nodeunit'
        files: '**/*.js'