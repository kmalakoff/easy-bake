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