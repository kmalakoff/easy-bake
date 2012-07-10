class eb.command.PublishGit
  constructor: (@command_options={}) ->
  run: (options={}, callback) ->
    local_queue = new eb.command.Queue()
    local_queue.push(new eb.command.RunCommand('git', ['add', '-A'], @command_options))
    local_queue.push(new eb.command.RunCommand('git', ['commit'], @command_options))
    local_queue.push(new eb.command.RunCommand('git', ['push'], @command_options))
    local_queue.run(options, (queue) -> callback?(queue.errorCount(), @))

class eb.command.PublishNPM
  constructor: (@command_options={}) ->
  run: (options={}, callback) ->
    local_queue = new eb.command.Queue()
    args = ['publish']
    args.push('--force') if @command_options.force
    local_queue.push(new eb.command.RunCommand('npm', args, @command_options))
    local_queue.run(options, (queue) -> callback?(queue.errorCount(), @))

class eb.command.PublishNuGet
  constructor: (@command_options={}) ->
  run: (options={}, callback) ->
    local_queue = new eb.command.Queue()
    command = fs.realpathSync('node_modules/easy-bake/bin/nuget')
    # NuGet.exe pack
    # args = ['publish']
    # if @command_options.force
    #   local_queue.push(new eb.command.RunCommand('bin/nuget', args, @command_options))
    # local_queue.push(new eb.command.RunCommand('bin/nuget', args, @command_options))
    local_queue.push(new eb.command.RunCommand(command, ['help'], @command_options))
    local_queue.run(options, (queue) -> callback?(queue.errorCount(), @))