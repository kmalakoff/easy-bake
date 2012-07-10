class eb.command.Bundle
  constructor: (@entries, @command_options={}) ->
  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      for bundle_filename, config of @entries
        console.log("bundle #{bundle_filename} #{JSON.stringify(config)}")
      (callback?(0, @); return) if options.preview

    # success
    for bundle_filename, config of @entries
      if mb.writeBundleSync(bundle_filename, config, {cwd: @command_options.cwd})
        timeLog("bundled #{eb.utils.relativePath(bundle_filename, @command_options.cwd)}")
      else
        timeLog("failed to bundle #{eb.utils.relativePath(bundle_filename, @command_options.cwd)}")
    callback?(0, @)

class eb.command.ModuleBundle
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)

  run: (options={}, callback) ->
    scoped_command = 'node_modules/easy-bake/node_modules/.bin/mbundle'

    # display
    if options.preview or options.verbose
      console.log("#{scoped_command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    try
      for filename in @args
        if mb.writeBundlesSync(filename, {cwd: @command_options.cwd})
          timeLog("bundled #{filename}") unless options.silent
        else
          timeLog("failed to bundle #{filename}") unless options.silent
      callback?(0, @)
