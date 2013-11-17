{spawn} = require 'child_process'
_ = require 'underscore'
wrench = require 'wrench'
uglifyjs = require 'uglify-js'
globber = require 'glob-whatev'
mb = require 'module-bundler'
et = require 'elementtree'

##############################
# Commands
##############################

class eb.command.RunCommand
  constructor: (@command, @args=[], @command_options={}) ->

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("#{if @command_options.cwd then (@command_options.cwd + ': ') else ''}#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn @command, @args, eb.utils.extractCWD(@command_options)
    spawned.on 'error', (err) -> console.log "Failed to run command: #{@command}, args: #{@args.join(', ')}. Error: #{err.message}"
    spawned.stderr.on 'data', (data) ->
      message = data.toString()
      return if message.search('is now called') >= 0
      process.stderr.write message
      callback?(1, @)
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      @exit_code = code
      if code is 0
        timeLog("command succeeded '#{@command}'") unless options.silent
      else
        timeLog("command failed '#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}' (exit code: #{code})")
      callback?(code, @)
