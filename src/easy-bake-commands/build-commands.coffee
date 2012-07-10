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

    spawned = spawn 'coffee', @args, eb.utils.extractCWD(@command_options)
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
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
          post_build_queue.push(new eb.command.UglifyJS(['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], {cwd: @targetDirectory()}))

      # add the test command
      if @runsTests() and @already_run
        post_build_queue.push(new eb.command.RunCommand('cake', ['test'], {cwd: @command_options.cwd}))
      @already_run = true

      # run the post build queue
      if post_build_queue then post_build_queue.run(options, => callback?(code, @)) else callback?(0, @)

    # watch vs build callbacks are slightly different
    if options.watch then spawned.stdout.on('data', (data) -> notify(0)) else spawned.on('exit', (code) -> notify(code))

class eb.command.UglifyJS
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  outputName: -> return if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else ''

  run: (options={}, callback) ->
    scoped_command = 'node_modules/.bin/uglifyjs'

    # display
    if options.preview or options.verbose
      console.log("#{scoped_command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    try
      src = fs.readFileSync(@args[2], 'utf8')
      header = if ((header_index = src.indexOf('*/'))>0) then src.substr(0, header_index+2) else ''
      ast = uglifyjs.parser.parse(src)
      ast = uglifyjs.uglify.ast_mangle(ast)
      ast = uglifyjs.uglify.ast_squeeze(ast)
      src = header + uglifyjs.uglify.gen_code(ast) + ';'
      fs.writeFileSync(@args[1], src, 'utf8')
      timeLog("compressed #{eb.utils.relativePath(@outputName(), @command_options.cwd)}") unless options.silent
      callback?(0, @)
    catch e
      timeLog("failed to minify #{eb.utils.relativePath(@outputName(), @command_options.cwd)} .... error code: #{e.code}")
      callback?(e.code, @)
