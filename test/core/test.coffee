path = require 'path'

PROJECT_ROOT = "#{__dirname}/../../.."
SAMPLE_LIBRARY_ROOT = "#{__dirname}/../../sample_library/"

# EasyBake
eb = if not @eb and (typeof(require) != 'undefined') then require("#{PROJECT_ROOT}/easy-bake") else @eb
oven = null

check_build = (test) ->
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'core.js')), 'build: library root')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, '/build/core.js')), 'build: library relative')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, '.hidden/core.js')), 'build: library hidden')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'home/core.js')), 'build: library home')

  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib1.js')), 'build: utils 1')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib1.min.js')), 'build: utils 1 min')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib2.js')), 'build: utils 2')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib2.min.js')), 'build: utils 2 min')

  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'test/test1/build/test.js')), 'build: test1')
  test.ok(path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'test/test2/build/test.js')), 'build: test2')

check_clean = (test) ->
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'core.js')), 'clean: library root')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, '/build/core.js')), 'clean: library relative')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, '.hidden/core.js')), 'clean: library hidden')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'home/core.js')), 'clean: library home')

  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib1.js')), 'clean: utils 1')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib1.min.js')), 'clean: utils 1 min')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib2.js')), 'clean: utils 2')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'lib/lib2.min.js')), 'clean: utils 2 min')

  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'test/test1/build/test.js')), 'clean: test1')
  test.ok(not path.existsSync(path.join(SAMPLE_LIBRARY_ROOT, 'test/test2/build/test.js')), 'clean: test2')

exports.easy_bake_core =
  'TEST DEPENDENCY MISSING': (test) ->
    test.ok(not !eb)
    test.done()

  'Loading a YAML': (test) ->
    oven = new eb.Oven(path.join(SAMPLE_LIBRARY_ROOT, 'easy-bake-config-test.yml'))
    oven.publishOptions().publishTasks()  # chaining
    test.done()

  'Build': (test) ->
    oven.build({preview: true}, ->
      oven.build(null, ->
        check_build(test)
        test.done()
      )
    )

  'Clean': (test) ->
    oven.clean({preview: true}, ->
      oven.clean(null, ->
        check_clean(test)
        test.done()
      )
    )

  'Clean and Build': (test) ->
    oven.build({clean: true, preview: true}, ->
      oven.build({clean: true}, ->
        check_build(test)
        test.done()
      )
    )

  'Chaining': (test) ->
    oven = new eb.Oven(path.join(SAMPLE_LIBRARY_ROOT, 'easy-bake-config-test.yml')).publishOptions()
    command_queue = new eb.command.Queue()
    oven.clean({queue: command_queue}).build({queue: command_queue}).clean({queue: command_queue})
    command_queue.run(null, ->
      console.log('chaining worked')
      check_clean(test)
      test.done()
    )

  'Manual Tests': (test) ->
    callback = ->
      check_clean(test)
      test.done()

    oven = new eb.Oven(path.join(SAMPLE_LIBRARY_ROOT, 'easy-bake-config-test.yml')).publishOptions()
    task 'build', 'Build library and tests', (options) -> oven.build(options)
    task 'clean', 'Clean library and tests', (options) -> oven.clean(options, callback)

    global.invoke('clean')

  'Error cases': (test) ->
    # TODO
    test.done()