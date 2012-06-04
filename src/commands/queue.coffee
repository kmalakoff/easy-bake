{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
_ = require 'underscore'
wrench = require 'wrench'
uglifyjs = require 'uglify-js'

# export or create eb namespace
ebc = @ebc = if (typeof(exports) != 'undefined') then exports else {}

# helpers
timeLog = (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")

##############################
# Queue
##############################

class ebc.Queue
  constructor: ->
    @commands_queue = []
    @is_running = false
    @errors = []

  commands: -> return @commands_queue
  errorCount: -> return @errors.length
  push: (command) -> @commands_queue.push(command)
  run: (callback, run_options) ->
    throw 'queue is already running' if @is_running

    @is_running = true
    @errors = []
    current_index = 0

    done = =>
      @is_running = false
      callback?(@errors.length, @)

    next = (code, task) =>
      @errors.push({code: code, task: task}) if (code isnt 0) and (arguments.length isnt 0)
      if (++current_index < @commands_queue.length) then @commands_queue[current_index].run(next, run_options, @) else done()

    # run or done
    if @commands_queue.length then @commands_queue[current_index].run(next, run_options, @) else done()
