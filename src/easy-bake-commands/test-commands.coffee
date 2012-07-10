class eb.command.RunTest
  constructor: (@command, @args=[], @command_options={}) ->
  usingPhantomJS: -> return (@command is 'phantomjs')
  fileName: -> return if @usingPhantomJS() then @args[1] else @args[0]
  exitCode: -> return @exit_code

  run: (options={}, callback) ->
    # command scoping is required because the test suite may not be installed globally
    scoped_command = if @usingPhantomJS() then @command else path.join('node_modules/.bin', @command)
    scoped_args = _.clone(@args)
    if @usingPhantomJS()
      scoped_args[1] = "file://#{mb.resolveSafe(@args[1], {cwd: @command_options.cwd})}" if @args[1].search('file://') isnt 0
    else
      scoped_args = eb.utils.relativeArguments(scoped_args, @command_options.cwd)

    # display
    if options.preview or options.verbose
      console.log("#{scoped_command} #{scoped_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn scoped_command, scoped_args
    spawned.on 'exit', (code) =>
      @exit_code = code
      if code is 0
        timeLog("tests passed #{eb.utils.relativePath(@fileName(), @command_options.cwd)}") unless options.silent
      else
        timeLog("tests failed #{eb.utils.relativePath(@fileName(), @command_options.cwd)} (exit code: #{code})")
      callback?(code, @)
