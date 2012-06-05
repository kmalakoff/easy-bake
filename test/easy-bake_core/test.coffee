PROJECT_ROOT = "#{__dirname}/../../.."

# EasyBake
eb = if not @eb and (typeof(require) != 'undefined') then require("#{PROJECT_ROOT}/easy-bake") else @eb
baker = null

exports.easy_bake_core =
  'TEST DEPENDENCY MISSING': (test) ->
    test.ok(!!eb)
    test.done()

  'Loading a YAML': (test) ->
    baker = new eb.Oven("#{__dirname}/../../sample_library/easy-bake-config-test.yaml")
    test.done()

  'Build': (test) ->
    baker.build({preview: true})
    baker.build()
    test.done()

  'Clean': (test) ->
    baker.clean({preview: true})
    baker.clean()
    test.done()

  'Clean and Build': (test) ->
    baker.build({clean: true, preview: true})
    baker.build({clean: true})
    test.done()

  'Error cases': (test) ->
    # TODO
    test.done()