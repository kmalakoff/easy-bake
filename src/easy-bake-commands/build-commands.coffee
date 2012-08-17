class eb.command.Coffee
  constructor: (args=[], @command_options={}) ->
    @args = eb.utils.resolveArguments(args, @command_options.cwd)
  targetDirectory: -> return mb.pathNormalizeSafe(if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else '')
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

      if @isCompressed() or (@runsTests() and @already_run)
        post_build_queue = new eb.command.Queue()

      for source_name in output_names
        build_directory = mb.resolveSafe(output_directory, {cwd: path.dirname(source_name)})
        build_directory = output_directory unless build_directory
        pathed_build_name = "#{build_directory}/#{eb.utils.builtName(path.basename(source_name))}"

        if code is 0
          timeLog("compiled #{eb.utils.relativePath(pathed_build_name, @targetDirectory())}") unless options.silent
        else
          timeLog("failed to compile #{eb.utils.relativePath(pathed_build_name, @targetDirectory())} .... error code: #{code}")

        # add to the compress queue
        if @isCompressed()
          post_build_queue.push(new eb.command.RunCommand('uglifyjs', ['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], null))

      # add the test command
      if @runsTests() and @already_run
        post_build_queue.push(new eb.command.RunCommand('cake', ['test'], {cwd: @command_options.cwd}))
      @already_run = true

      # run the post build queue
      if post_build_queue then post_build_queue.run(options, => callback?(code, @)) else callback?(0, @)

    spawned = spawn 'coffee', @args, eb.utils.extractCWD(@command_options)
    spawned.stderr.on 'data', (data) ->
      message = data.toString()
      if message.search('is now called') < 0 
        console.log(message)
        process.stderr.write message
        notify(1) 
  
    # watch vs build callbacks are slightly different
    if options.watch then spawned.stdout.on('data', (data) -> notify(0)) else spawned.on('exit', (code) -> notify(code))
