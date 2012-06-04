##############################
# Commands
##############################
class ebc.RunQueue
  constructor: (@run_queue, @name) ->
  queue: -> return @run_queue
  run: (callback, options={}) ->
    # display
    console.log("running queue: #{@name}") if options.verbose

    # execute
    @run_queue.run(callback, options)

class ebc.RunCommand
  constructor: (@command, @args=[], @command_options={}) ->
  run: (callback, options={}) ->
    # display
    if options.preview or options.verbose
      message = "#{@command} #{@args.join(' ')}"
      message = "#{if @command_options.root_dir then @command_options.cwd.replace(@command_options.root_dir, '') else @command_options.cwd}: #{message}" if @command_options.cwd
      console.log(message)
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn @command, @args, @command_options
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) ->
      callback?(code, @)

class ebc.RunClean
  constructor: (@args=[], @command_options={}) ->
  target: -> @args[@args.length-1]
  run: (callback, options={}) ->
    (callback?(0, @); return) unless path.existsSync(@target()) # nothing to delete

    # display
    if options.preview or options.verbose
      unscoped_args = _.map(@args, (arg) => return arg.replace(@command_options.root_dir, ''))
      unscoped_args = _.map(unscoped_args, (arg) => return if not arg.length then '.' else (if arg[0]=='/' then arg.substr(1) else arg))
      console.log("rm #{unscoped_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    if @args[0]=='-r' then wrench.rmdirSyncRecursive(@args[1]) else fs.unlink(@args[0])
    callback?(0, @)

class ebc.RunCoffee
  constructor: (@args=[], @command_options={}) ->
  targetDirectory: -> if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else ''
  targetNames: ->
    return if ((index = _.indexOf(@args, '-j')) >= 0) then [@args[index+1]] else @args.slice(_.indexOf(@args, '-c')+1)

  run: (callback, options={}) ->
    # display
    if options.preview or options.verbose
      unscoped_args = _.map(@args, (arg) => return arg.replace(@command_options.root_dir, ''))
      unscoped_args = _.map(unscoped_args, (arg) => return if not arg.length then '.' else (if arg[0]=='/' then arg.substr(1) else arg))
      console.log("coffee #{unscoped_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn 'coffee', @args
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    notify = (code) =>
      for output_name in @targetNames()
        if code is 0
          timeLog("built #{output_name.replace(@command_options.root_dir, '')}") unless options.silent
        else
          timeLog("failed to build #{output_name.replace(@command_options.root_dir, '')} .... error code: #{code}")
      callback?(code, @)

    # watch vs build callbacks are slightly different
    if options.watch then spawned.stdout.on('data', (data) -> notify(0)) else spawned.on('exit', (code) -> notify(code))

class ebc.RunUglifyJS
  constructor: (@args=[], @command_options={}) ->
  outputName: -> if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else ''
  run: (callback, options={}) ->
    scoped_command = "node_modules/.bin/uglifyjs"

    # display
    if options.preview or options.verbose
      unscoped_args = _.map(@args, (arg) => return arg.replace(@command_options.root_dir, ''))
      unscoped_args = _.map(unscoped_args, (arg) => return if not arg.length then '.' else (if arg[0]=='/' then arg.substr(1) else arg))
      console.log("#{scoped_command} #{unscoped_args.join(' ')}")
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
      timeLog("minified #{@outputName().replace(@command_options.root_dir, '')}") unless options.silent
      callback?(0, @)
    catch e
      timeLog("failed to minify #{@outputName().replace(@command_options.root_dir, '')} .... error code: #{e.code}")
      callback?(e.code, @)

class ebc.RunTest
  constructor: (@command, @args=[], @command_options={}) ->
  run: (callback, options={}) ->
    scoped_command = if (@command is 'phantomjs') then @command else "node_modules/.bin/#{command}"

    # display
    if options.preview or options.verbose
      unscoped_args = if (@args.length == 4) then @args.slice(0, @args.length-1) else @args   # drop the silent argument
      console.log("#{scoped_command} #{unscoped_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn scoped_command, @args
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      test_filename = (if (@command is 'phantomjs') then @args[1] else @args[0])
      test_filename = test_filename.replace("file://#{@command_options.root_dir}/", '')
      if code is 0
        timeLog("tests passed #{test_filename}") unless options.silent
      else
        timeLog("tests failed #{test_filename} .... error code: #{code}")
      callback?(code, @)
