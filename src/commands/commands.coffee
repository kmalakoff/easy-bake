{spawn} = require 'child_process'

##############################
# Commands
##############################

class ebc.RunQueue
  constructor: (@run_queue, @name) ->
  queue: -> return @run_queue
  run: (callback, run_options={}) ->
    # display
    if run_options.verbose
      console.log("running queue: #{@name}")

    # execute
    @run_queue.run(callback, run_options)

class ebc.RunCommand
  constructor: (@command, @args=[], @options={}) ->
  run: (callback, run_options={}) ->
    # display
    if run_options.preview or run_options.verbose
      message = "#{@command} #{@args.join(' ')}"
      message = "#{if @options.root_dir then @options.cwd.replace(@options.root_dir, '') else @options.cwd}: #{message}" if @options.cwd
      console.log(message)
      (callback?(0, @); return) if run_options.preview

    # execute
    spawned = spawn @command, @args, @options
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) ->
      callback?(code, @)

class ebc.CopyFile
  constructor: (@src, @to_directory, @options={}) ->
  run: (callback, run_options={}) ->
    # display
    if run_options.preview or run_options.verbose
      console.log("cp #{@src} #{@to_directory}")
      (callback?(0, @); return) if run_options.preview

    # execute
    spawned = spawn 'cp', [@src, @to_directory]
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
      callback(code, @)
    spawned.on 'exit', (code) =>
      console.log("copied #{@baker.YAMLRelative(@src)} #{@to_directory}")
      callback(code, @)
