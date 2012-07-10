eb = {} unless !!eb; @eb = {} unless !!@eb
eb.utils = require './easy-bake-utils'

# export or create eb namespace
eb.command = @eb.command = if (typeof(exports) != 'undefined') then exports else {}

##############################
# Queue
##############################

class eb.command.Queue
  constructor: ->
    @_commands = []
    @is_running = false
    @errors = []

  commands: -> return @_commands
  errorCount: -> return @errors.length
  push: (command) -> @_commands.push(command)
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
      if (++current_index < @_commands.length) then@_commands[current_index].run(run_options, next, @) else done()

    # run or done
    if @_commands.length then @_commands[current_index].run(run_options, next, @) else done()

class eb.command.RunQueue
  constructor: (@run_queue, @name) -> @run_queue = new eb.command.Queue() unless @run_queue
  queue: -> return @run_queue

  run: (options={}, callback) ->
    # display
    console.log("running queue: #{@name}") if options.verbose

    # execute
    @run_queue.run(options, (queue) -> callback?(queue.errorCount(), @))
