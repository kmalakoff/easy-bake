PROJECT_ROOT = "#{__dirname}/../../.."

# EasyBake
eb = if not @eb and (typeof(require) != 'undefined') then require("#{PROJECT_ROOT}/easy-bake") else @eb
oven = null

exports.easy_bake_core =
  'TEST DEPENDENCY MISSING': (test) ->
    test.ok(!!eb)
    test.done()

  'Loading a YAML': (test) ->
    oven = new eb.Oven("#{__dirname}/../../sample_library/easy-bake-config-test.yaml")
    oven.publishOptions().publishTasks()  # chaining
    test.done()

  'Build': (test) ->
    oven.build({preview: true})
    oven.build()
    test.done()

  'Clean': (test) ->
    oven.clean({preview: true})
    oven.clean()
    test.done()

  'Clean and Build': (test) ->
    oven.build({clean: true, preview: true})
    oven.build({clean: true})
    test.done()

  'Chaining': (test) ->
    oven = (new eb.Oven("#{__dirname}/../../sample_library/easy-bake-config-test.yaml")).publishOptions()
    command_queue = new eb.command.Queue()
    oven.clean(null, command_queue).build(null, command_queue).clean(null, command_queue)
    command_queue.run(null, ->console.log('chaining worked'); test.done())

  'Manual Tests': (test) ->
    oven = (new eb.Oven("#{__dirname}/../../sample_library/easy-bake-config-test.yaml")).publishOptions()
    task 'build', 'Build library and tests', (options) -> oven.build(options)
    test.done()

  'Error cases': (test) ->
    # TODO
    test.done()