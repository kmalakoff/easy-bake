PROJECT_ROOT = "#{__dirname}/../../.."

# EasyBake
eb = if not @eb and (typeof(require) != 'undefined') then require("#{PROJECT_ROOT}/lib/easy-bake") else @eb

exports.easy_bake_core =
  'TEST DEPENDENCY MISSING': (test) ->
    test.ok(!!eb)
    test.done()

  'Loading a YAML': (test) ->
    new eb.Baker('easy-bake-config.yaml')
    test.done()

  'Error cases': (test) ->
    # TODO
    test.done()