class eb.command.Remove
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  target: -> return @args[@args.length-1]

  run: (options={}, callback) ->
    (callback?(0, @); return) unless path.existsSync(@target()) # nothing to delete

    # display
    if options.preview or options.verbose
      console.log("rm #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    parent_dir = path.dirname(@target())
    if @args[0]=='-r' then wrench.rmdirSyncRecursive(@target()) else fs.unlinkSync(@target())
    timeLog("removed #{eb.utils.relativePath(@target(), @command_options.cwd)}") unless options.silent

    # remove the parent directory if it is empty
    eb.utils.rmdirIfEmpty(parent_dir)

    callback?(0, @)

class eb.command.Copy
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  source: -> return @args[@args.length-2]
  target: -> return @args[@args.length-1]

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("cp #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # make the destination directory
    try
      target_dir = path.dirname(@target())
      wrench.mkdirSyncRecursive(target_dir, 0o0777) unless path.existsSync(target_dir)
    catch e
      throw e if e.code isnt 'EEXIST'

    # do the copy
    if @args[0]=='-r' then wrench.copyDirSyncRecursive(@source(), @target(), {preserve: true}) else fs.writeFileSync(@target(), fs.readFileSync(@source(), 'utf8'), 'utf8')
    timeLog("copied #{eb.utils.relativePath(@target(), @command_options.cwd)}") unless options.silent
    callback?(0, @)

  createUndoCommand: ->
    if @args[0]=='-r'
      return new eb.command.Remove(['-r', @target()], @command_options)
    else
      return new eb.command.Remove([@target()], @command_options)
