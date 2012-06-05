##############################
# Commands
##############################
class eb.command.RunQueue
  constructor: (@run_queue, @name) ->
  queue: -> return @run_queue

  run: (callback, options={}) ->
    # display
    console.log("running queue: #{@name}") if options.verbose

    # execute
    @run_queue.run(callback, options)

class eb.command.RunCommand
  constructor: (@command, @args=[], @command_options={}) ->

  run: (callback, options={}) ->
    # display
    if options.preview or options.verbose
      display_args = _.map(@args, (arg) => return eb.utils.relativePath(arg, @command_options.root_dir))
      console.log("#{if @command_options.cwd then (@command_options.cwd + ': ') else ''}#{@command} #{display_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn @command, @args, @command_options
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) ->
      callback?(code, @)

class eb.command.RunClean
  constructor: (@args=[], @command_options={}) ->
  target: -> @args[@args.length-1]

  run: (callback, options={}) ->
    (callback?(0, @); return) unless path.existsSync(@target()) # nothing to delete

    # display
    if options.preview or options.verbose
      display_args = _.map(@args, (arg) => return eb.utils.relativePath(arg, @command_options.root_dir))
      console.log("rm #{display_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    if @args[0]=='-r' then wrench.rmdirSyncRecursive(@args[1]) else fs.unlink(@args[0])
    callback?(0, @)

class eb.command.RunCoffee
  constructor: (@args=[], @command_options={}) ->
  targetDirectory: -> if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else ''
  targetNames: -> return if ((index = _.indexOf(@args, '-j')) >= 0) then [@args[index+1]] else @args.slice(_.indexOf(@args, '-c')+1)
  isCompressed: -> return @command_options.compress
  runsTests: -> return @command_options.test

  run: (callback, options={}) ->
    # display
    if options.preview or options.verbose
      display_args = _.map(@args, (arg) => return eb.utils.relativePath(arg, @command_options.root_dir))
      console.log("coffee #{display_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn 'coffee', @args
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    notify = (code) =>
      output_directory = @targetDirectory()
      output_names = @targetNames()

      if @isCompressed() or (@runsTests() and @already_run)
        post_build_queue = new eb.command.Queue()

      for source_name in output_names
        build_directory = eb.utils.resolvePath(output_directory, {cwd: path.dirname(source_name), root_dir: @command_options.root_dir})
        pathed_build_name = "#{build_directory}/#{eb.utils.builtName(path.basename(source_name))}"

        if code is 0
          timeLog("compiled #{pathed_build_name.replace("#{@command_options.root_dir}/", '')}") unless options.silent
        else
          timeLog("failed to compile #{pathed_build_name.replace("#{@command_options.root_dir}/", '')} .... error code: #{code}")

        # add to the compress queue
        if @isCompressed()
          post_build_queue.push(new eb.command.RunUglifyJS(['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], {root_dir: @command_options.root_dir}))

      # add the test command
      if @runsTests() and @already_run
        post_build_queue.push(new eb.command.RunCommand('cake', ['test'], {root_dir: @command_options.root_dir}))
      @already_run = true

      # run the post build queue
      if post_build_queue
        post_build_queue.run((=> callback?(code, @)), options)
      else
        callback?(0, @)

    # watch vs build callbacks are slightly different
    if options.watch then spawned.stdout.on('data', (data) -> notify(0)) else spawned.on('exit', (code) -> notify(code))

class eb.command.RunUglifyJS
  constructor: (@args=[], @command_options={}) ->
  outputName: -> if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else ''

  run: (callback, options={}) ->
    scoped_command = "node_modules/.bin/uglifyjs"

    # display
    if options.preview or options.verbose
      display_args = _.map(@args, (arg) => return eb.utils.relativePath(arg, @command_options.root_dir))
      console.log("#{scoped_command} #{display_args.join(' ')}")
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
      timeLog("compressed #{@outputName().replace("#{@command_options.root_dir}/", '')}") unless options.silent
      callback?(0, @)
    catch e
      timeLog("failed to minify #{@outputName().replace("#{@command_options.root_dir}/", '')} .... error code: #{e.code}")
      callback?(e.code, @)

class eb.command.RunTest
  constructor: (@command, @args=[], @command_options={}) ->
  usingPhantomJS: -> return (@command is 'phantomjs')
  fileName: -> return eb.utils.relativePath((if @usingPhantomJS() then @args[1] else @args[0]), @command_options.root_dir)
  exitCode: -> return @exit_code

  run: (callback, options={}) ->
    if @usingPhantomJS()
      scoped_command = @command
      scoped_args = _.clone(@args)
      scoped_args[1] = "file://#{@args[1]}"
    else
      scoped_command = "node_modules/.bin/#{@command}"
      scoped_args = @args

    # display
    if options.preview or options.verbose
      display_args = if (scoped_args.length == 4) then scoped_args.slice(0, scoped_args.length-1) else scoped_args   # drop the silent argument
      display_args = _.map(display_args, (arg) => return eb.utils.relativePath(arg, @command_options.root_dir)) unless @usingPhantomJS()
      console.log("#{scoped_command} #{display_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # make files relative
    scoped_args = _.map(scoped_args, (arg) => return eb.utils.relativePath(arg, @command_options.root_dir)) unless @usingPhantomJS()
    console.log(scoped_args.join(' '))

    # execute
    spawned = spawn scoped_command, scoped_args
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      @exit_code = code
      if code is 0
        timeLog("tests passed #{@fileName()}") unless options.silent
      else
        timeLog("tests failed #{@fileName()} (exit code: #{code})")
      callback?(code, @)
