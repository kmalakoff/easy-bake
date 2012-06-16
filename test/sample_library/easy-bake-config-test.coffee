module.exports =
  library_root:
    output: '.'
    join: 'core.js'
    files: [
      'src/core.coffee'
      'src/core_helpers.coffee'
    ]

  library_relative:
    output: './build'
    join: 'core.js'
    files: [
      'src/core.coffee'
      'src/core_helpers.coffee'
    ]

  library_hidden:
    output: '.hidden'
    join: 'core.js'
    files: [
      'src/core.coffee'
      'src/core_helpers.coffee'
    ]

  lib_utils:
    output: '../../lib'
    compress: true
    directories: 'src/lib'
    files: '**/*.coffee'

  tests:
    output: 'build'
    bare: true
    directories: [
      'test/test1'
      'test/test2'
    ]
    files: [
      '**/*.coffee'
    ]