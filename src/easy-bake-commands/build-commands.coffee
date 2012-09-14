class eb.command.Coffee
  constructor: (args=[], @command_options={}) ->
    @args = eb.utils.resolveArguments(args, @command_options.cwd)
  sourceFiles: ->
    source_files = _.clone(@args)
    eb.utils.argsRemoveOutput(source_files)
    source_files.splice(index, 2) if ((index = _.indexOf(source_files, '-j')) >= 0)
    source_files.splice(index, 1) if ((index = _.indexOf(source_files, '-c')) >= 0)
    return source_files
  targetDirectory: ->
    return mb.pathNormalizeSafe(eb.utils.argsRemoveOutput(_.clone(@args)))
  pathedTargets: ->
    pathed_targets = []
    output_directory = @targetDirectory()
    output_names = if ((index = _.indexOf(@args, '-j')) >= 0) then [@args[index+1]] else @args.slice(_.indexOf(@args, '-c')+1)
    for source_name in output_names
      # files being compiled
      if source_name.match(/\.js$/) or source_name.match(/\.coffee$/)
        pathed_targets.push(mb.pathNormalizeSafe("#{output_directory}/#{eb.utils.builtName(path.basename(source_name))}"))

      # directories being compiled
      else
        pathed_source_files = []
        globber.glob("#{source_name}/**/*.coffee").forEach((pathed_file) -> pathed_source_files.push(pathed_file.replace(source_name, '')))
        for pathed_source_file in pathed_source_files
          pathed_targets.push(mb.pathNormalizeSafe("#{output_directory}#{eb.utils.builtName(pathed_source_file)}"))
    return pathed_targets

  isCompressed: -> return @command_options.compress
  runsTests: -> return @command_options.test

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("coffee #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    notify = (code) =>
      output_directory = @targetDirectory()
      output_names = @pathedTargets()

      post_build_queue = new eb.command.Queue()

      for source_name in output_names
        build_directory = mb.resolveSafe(output_directory, {cwd: path.dirname(source_name)})
        build_directory = output_directory unless build_directory
        pathed_build_name = "#{build_directory}/#{eb.utils.builtName(path.basename(source_name))}"

        if code is 0
          timeLog("compiled #{eb.utils.relativePath(pathed_build_name, @targetDirectory())}") unless options.silent
        else
          timeLog("failed to compile #{eb.utils.relativePath(pathed_build_name, @targetDirectory())} .... error code: #{code}")
          callback?(code, @)
          return

        # wrap the result
        if @command_options.wrapper
          post_build_queue.push(new eb.command.Wrap(@command_options.wrapper, pathed_build_name, {cwd: @command_options.cwd}))

        # add to the compress queue
        if @isCompressed()
          post_build_queue.push(new eb.command.RunCommand('uglifyjs', ['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], null))

      # add the test command
      if @runsTests() and @already_run
        post_build_queue.push(new eb.command.RunCommand('cake', ['test'], {cwd: @command_options.cwd}))
      @already_run = true

      # run the post build queue
      post_build_queue.run(options, => callback?(code, @))

    # set up command parameters
    if @command_options.watch
      watch_list = @sourceFiles()
      watchers = {}
    args = _.clone(@args)
    args.unshift('-b') if @command_options.bare or @command_options.wrapper
    cwd = eb.utils.extractCWD(@command_options)

    watchFile = (file) ->
      watchers[file].close() if watchers[file]
      stats = fs.statSync(file)
      watchers[file] = fs.watch(file, ->
        now_stats = fs.statSync(file)
        # process.stderr.write "#{file} stats: \n"
        return if stats.mtime.getTime() is now_stats.mtime.getTime() # no change
        stats = now_stats
        compile()
      )

    watchFiles = (files) ->
      # unwatch any files
      watcher.close() for source, watcher of watchers; watchers = {}

      # watch each file
      for file in files
        try
          watchFile(file)
        catch e
          throw e if e.code isnt 'ENOENT'
          process.stderr.write "coffee: #{file.replace(@command_options.cwd, '')} doesn't exist. Skipping"

    watchDirectory = (directory) ->
      update = ->
        watch_list = []; globber.glob("#{directory}/**/*.coffee").forEach((pathed_file) -> watch_list.push(pathed_file))
        watchFiles(watch_list)
      fs.watch(directory, update) # watch for directory changes
      update() # watch the files in the directory

    compile = ->
      errors = false
      spawned = spawn 'coffee', args, cwd
      spawned.stderr.on 'data', (data) ->
        message = data.toString()
        return if message.search('is now called') >= 0
        return if errors; errors = true # filter errors
        process.stderr.write message
      spawned.on('exit', (code) -> notify(code))

    # watch if exists
    if watch_list
      # extract directory contents
      if watch_list.length is 1 and fs.statSync(watch_list[0]).isDirectory()
        watchDirectory(watch_list[0])
      else
        watchFiles(watch_list)

    compile() # compile now

class eb.command.Wrap
  constructor: (@wrapper, @file, @command_options) ->

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("wrap #{@file} with #{@wrapper}")
      (callback?(0, @); return) if options.preview

    pathed_wrapper = mb.resolveSafe(@wrapper, @command_options)
    pathed_file = mb.resolveSafe(@file, @command_options)

    wrapper_content = fs.readFileSync(pathed_wrapper, 'utf8')
    file_content = fs.readFileSync(pathed_file, 'utf8')

    wrapped_file = wrapper_content.toString().replace("'__REPLACE__'", file_content)
    fs.writeFile(pathed_file, wrapped_file, 'utf8', -> callback(0))