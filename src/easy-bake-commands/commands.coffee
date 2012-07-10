{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
_ = require 'underscore'
wrench = require 'wrench'
uglifyjs = require 'uglify-js'
globber = require 'glob-whatev'
mb = require 'module-bundler'

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
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      @exit_code = code
      if code is 0
        timeLog("command succeeded '#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}'") unless options.silent
      else
        timeLog("command failed '#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}' (exit code: #{code})")
      callback?(code, @)
