class eb.command.Remove
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  target: -> return @args[@args.length-1]

  run: (options={}, callback) ->
    (callback?(0, @); return) unless existsSync(@target()) # nothing to delete

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
  isRecursive: -> return ((index = _.indexOf(@args, '-r')) >= 0)
  isVersioned: -> return ((index = _.indexOf(@args, '-v')) >= 0)
  source: -> return @args[@args.length-2]
  target: ->
    target = @args[@args.length-1]
    if @isVersioned()
      source_dir = path.dirname(@source())
      package_desc_path = path.join(source_dir, 'package.json')
      # try to find package.json one directory up, eg. /lib
      unless existsSync(package_desc_path)
        source_dir_components = source_dir.split('/')
        source_dir_components.pop()
        source_dir = source_dir_components.join('/')
        package_desc_path = path.join(source_dir, 'package.json')
        (console.log("no package.json found for cp: #{package_desc_path.replace(@config_dir, '')}"); return target) unless existsSync(package_desc_path)

      package_desc = require(package_desc_path)
      extension = path.extname(target)
      if target.endsWith(".min#{extension}")
        extension = ".min#{extension}"
      else if target.endsWith("-min#{extension}")
        extension = "-min#{extension}"
      target = target.replace(extension, "-#{package_desc.version}#{extension}")
    return target

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("cp #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # get the source
    source = @source()
    (console.log("command failed: cp #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}. Source '#{source}' doesn't exist"); callback?(1); return) unless existsSync(source)

    # make the destination directory
    target = @target()
    try
      target_dir = path.dirname(target)
      wrench.mkdirSyncRecursive(target_dir, 0o0777) unless existsSync(target_dir)
    catch e
      throw e if e.code isnt 'EEXIST'

    # do the copy
    if @isRecursive()
      wrench.copyDirSyncRecursive(source, target, {preserve: true})
    else
      fs.writeFileSync(target, fs.readFileSync(source, 'utf8'), 'utf8')
    timeLog("copied #{eb.utils.relativePath(target, @command_options.cwd)}") unless options.silent
    callback?(0, @)

  createUndoCommand: ->
    if @args[0]=='-r'
      return new eb.command.Remove(['-r', @target()], @command_options)
    else
      return new eb.command.Remove([@target()], @command_options)

class eb.command.Concatenate
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  sourceFiles: ->
    eb.utils.argsRemoveOutput(source_files = _.clone(@args))
    return source_files
  target: ->
    return eb.utils.argsRemoveOutput(_.clone(@args))
  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("cat #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # get the source files
    source_files = @sourceFiles()

    # make the destination directory
    target = @target()
    try
      target_dir = path.dirname(target)
      wrench.mkdirSyncRecursive(target_dir, 0o0777) unless existsSync(target_dir)
    catch e
      throw e if e.code isnt 'EEXIST'
    fs.unlinkSync(target) if existsSync(target) # remove the old

    # do the concatenation
    error_count = 0
    for source in source_files
      if existsSync(source)
        data = fs.readFileSync(source, 'utf8')
        data += '\n' unless data[data.length-1] is '\n'
        fs.appendFileSync(target, data, 'utf8')
      else
        (console.log("command failed: cat #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}. Source '#{source}' doesn't exist"); error_count++)

    if error_count
      timeLog("failed to concatenat #{eb.utils.relativePath(target, @command_options.cwd)}")
    else
      timeLog("concatenated #{eb.utils.relativePath(target, @command_options.cwd)}") unless options.silent
    callback?(error_count, @)

  createUndoCommand: ->
    if @args[0]=='-r'
      return new eb.command.Remove(['-r', @target()], @command_options)
    else
      return new eb.command.Remove([@target()], @command_options)