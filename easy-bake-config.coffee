module.exports =
  library:
    files: 'src/easy-bake.coffee'

  lib_utils:
    output: 'lib'
    files: 'src/easy-bake-utils.coffee'

  lib_commands:
    join: 'easy-bake-commands.js'
    output: 'lib'
    files: [
      'src/commands/queue.coffee'
      'src/commands/commands.coffee'
    ]

  lib_test_runners:
    output: '../../lib/test_runners'
    directories: 'src/test_runners'

  tests:
    output: 'build'
    bare: true
    directories: 'test/core'
    modes:
      test:
        command: 'nodeunit'
        files: '**/*.js'