##############################
# Commands
##############################
eb.command or={}

class eb.CommandQueue
  constructor: ->
    @commands = []
    @is_running = false

  push: (command) -> @commands.push(command)
  run: (callback, preview) ->
    throw 'queue is already running' if @is_running

    @is_running = true
    @errors = []
    current_index = 0

    done = =>
      @is_running = false
      if @errors.length
        console.log('commands failed')
      callback?(@errors.length)

    next = (code, task) =>
      errors.push({code: code, task: task}) unless code is 0
      if (++current_index < @commands.length) then @commands[current_index].run(next, preview) else done()

    # run or done
    if @commands.length then @commands[current_index].run(next, preview) else done()

class eb.command.CopyFile
  constructor: (@baker, @src, @to_directory) ->
  run: (callback, preview) ->
    if preview
      console.log("cp #{@src} #{@to_directory}")
      callback?(0, @)
    else
      spawned = spawn 'cp', [@src, @to_directory]
      spawned.stderr.on 'data', (data) ->
        process.stderr.write data.toString()
        callback?(code, @)
      spawned.on 'exit', (code) =>
        console.log("copied #{@baker.YAMLRelative(@src)} #{@to_directory}")
        callback?(code, @)
