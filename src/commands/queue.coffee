eb = {} unless !!eb; @eb = {} unless !!@eb
eb.utils = require './easy-bake-utils'

# export or create eb namespace
eb.command = @eb.command = if (typeof(exports) != 'undefined') then exports else {}

# helpers
timeLog = (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")

##############################
# Queue
##############################

class eb.command.Queue
  constructor: ->
    @commands_queue = []
    @is_running = false
    @errors = []

  commands: -> return @commands_queue
  errorCount: -> return @errors.length
  push: (command) -> @commands_queue.push(command)
  run: (run_options, callback) ->
    throw 'queue is already running' if @is_running

    @is_running = true
    @errors = []
    current_index = 0

    done = =>
      @is_running = false
      callback?(@)

    next = (code, task) =>
      # record errors
      @errors.push({code: code, task: task}) if (code isnt 0) and (arguments.length isnt 0)

      # next or done
      if (++current_index < @commands_queue.length) then@commands_queue[current_index].run(run_options, next, @) else done()

    # run or done
    if @commands_queue.length then @commands_queue[current_index].run(run_options, next, @) else done()
