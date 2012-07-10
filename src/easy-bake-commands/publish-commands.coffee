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
    throw "publish_nuget missing current working directory (cwd)" unless @command_options.cwd

  run: (options={}, callback) ->
    # CONVENTION: try a nested package in the form 'packages/npm' first
    package_path = path.join(@command_options.cwd, 'packages', 'npm')
    package_path = @config_dir unless path.existsSync(package_path) # fallback to this project

    # CONVENTION: safe guard...do not publish packages that starts in _ or missing the main file
    package_desc_path = path.join(package_path, 'package.json')
    (console.log("no package.json found for publish_npm: #{package_desc_path.replace(@config_dir, '')}"); callback?(1); return) unless path.existsSync(package_desc_path) # fallback to this project

    package_desc = require(package_desc_path)
    (console.log("skipping publish_npm for: #{package_desc_path} (name starts with '_')"); callback?(1); return) if package_desc.name.startsWith('_')
    (console.log("skipping publish_npm for: #{package_desc_path} (main file missing...do you need to build it?)"); callback?(1); return) unless path.existsSync(path.join(package_path, package_desc.main))

    local_queue = new eb.command.Queue()
    args = ['publish']
    args.push('--force') if @command_options.force
    local_queue.push(new eb.command.RunCommand('npm', args, {cwd: package_path}))
    local_queue.run(options, (queue) -> callback?(queue.errorCount(), @))

class eb.command.PublishNuGet
  constructor: (@command_options={}) ->
    throw "publish_nuget missing current working directory (cwd)" unless @command_options.cwd

  run: (options={}, callback) ->
    command = fs.realpathSync('node_modules/easy-bake/bin/nuget')

    # CONVENTION: try a nested package in the form 'packages/nuget' first
    package_path = path.join(@command_options.cwd, 'packages', 'nuget')
    (callback?(0); return) unless path.existsSync(package_path) # nothing to publish

    # CONVENTION: safe guard...do not publish packages that starts in _ or missing the main file
    package_desc_path = path.join(package_path, 'package.nuspec')
    (console.log("no package.nuspec found for publishNuGet: #{package_desc_path.replace(@config_dir, '')}"); callback?(1); return) unless path.existsSync(package_desc_path) # fallback to this project

    package_desc = et.parse(fs.readFileSync(package_desc_path, 'utf8').toString())
    package_id = package_desc.findtext('./metadata/id')
    (console.log("package.nuspec missing metadata.name: #{package_desc_path.replace(@config_dir, '')}"); callback?(1); return) unless package_id
    (console.log("skipping publish_npm for: #{package_desc_path} (name starts with '_')"); callback?(1); return) if package_id.startsWith('_')
    package_version = package_desc.findtext('./metadata/version')
    (console.log("package.nuspec missing metadata.version: #{package_desc_path.replace(@config_dir, '')}"); callback?(1); return) unless package_version

    files = package_desc.findall('./files/file')
    for file in files
      pathed_filename = path.join(package_path, file.get('src'))
      pathed_filename = pathed_filename.replace(/\\/g, '\/')
      (console.log("skipping publish_npm for: #{package_desc_path} (main file missing...do you need to build it?)"); callback?(1); return) unless path.existsSync(pathed_filename)

    local_queue = new eb.command.Queue()
    if @command_options.force
      local_queue.push(new eb.command.RunCommand(command, ['delete', package_id, package_version, '-NoPrompt'], {cwd: package_path}))
    local_queue.push(new eb.command.RunCommand(command, ['pack', package_desc_path], {cwd: package_path}))
    local_queue.push(new eb.command.RunCommand(command, ['push', "#{package_id}.#{package_version}.nupkg"], {cwd: package_path}))
    # local_queue.push(new eb.command.RunCommand(command, ['publish', package_id, package_version], {cwd: package_path}))
    local_queue.run(options, (queue) ->callback?(queue.errorCount(), @))