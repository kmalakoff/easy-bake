{print} = require 'util'
{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
coffeescript = require 'coffee-script'
require 'coffee-script/lib/coffee-script/cake' if not global.option # load cake
_ = require 'underscore'

TEST_DEFAULT_TIMEOUT = 60000
RUNNERS_ROOT = "#{__dirname}/lib/test_runners"

# export or create eb scope
eb = @eb = if (typeof(exports) != 'undefined') then exports else {}
eb.utils = require './lib/easy-bake-utils'
eb.command = require './lib/easy-bake-commands'

# add coffeescript compiling
require.extensions['.coffee'] ?= (module, filename) ->
  content = coffeescript.compile fs.readFileSync filename, 'utf8', {filename}
  module._compile content, filename

##############################
# The Oven
##############################
class eb.Oven
  constructor: (config, options={}) ->
    if _.isString(config)
      config_pathed_filename = fs.realpathSync(config)
      @config_dir = path.dirname(config_pathed_filename)
      try
        @config = require(config_pathed_filename)
      catch error
        throw "couldn\'t load config #{config}. #{error}"
    else
      throw "options are missing current working directory (cwd)" unless options.cwd
      @config = config
      @config_dir = path.normalize(options.cwd)
      length = @config_dir.length
      @config_dir = @config_dir.slice(0,length-1) if @config_dir[length-1] is '/'

    console.log("warning: an empty config file was loaded: #{config_pathed_filename}") unless _.size(@config)

  publishOptions: ->
    global.option('-c', '--clean',     'cleans the project before running a command')
    global.option('-w', '--watch',     'watches for changes')
    global.option('-b', '--build',     'builds the project (used with test)')
    global.option('-p', '--preview',   'display all of the commands that will be run (without running them!)')
    global.option('-v', '--verbose',   'display additional information')
    global.option('-s', '--silent',    'does not output messages to the console (unless errors occur)')
    global.option('-f', '--force',     'forces the action to occur')
    global.option('-q', '--quick',     'performs minimal task')
    @

  publishTasks: (options={}) ->
    @publishOptions()

    tasks =
      postinstall:    ['Called by npm after installing library',  (options) => @postinstall(options)]
      clean:          ['Remove generated JavaScript files',       (options) => @clean(options)]
      build:          ['Build library and tests',                 (options) => @build(options)]
      watch:          ['Watch library and tests',                 (options) => @build(_.defaults({watch: true}, options))]
      test:           ['Test library',                            (options) => @test(options)]
      publishgit:     ['Cleans, builds, tests and if successful, runs git commands to add, commit, and push the project',  (options) => @publishGit(options)]
      publishnpm:     ['Cleans, builds, tests and if successful, runs npm commands to publish the project',  (options) => @publishNPM(options)]
      publish_nuget:   ['Cleans, builds, tests and if successful, runs nuget commands to publish the project',  (options) => @publishNuGet(options)]
      publishall:     ['Cleans, builds, tests and if successful, commands to publish the project in all available repositories',  (options) => @publishAll(options)]

    # register and optionally scope the tasks
    task_names = if options.tasks then options.tasks else _.keys(tasks)
    for task_name in task_names
      args = tasks[task_name]
      (console.log("easy-bake: task name not recognized #{task_name}"); continue) unless args
      task_name = "#{options.scope}.#{task_name}" if options.scope
      global.task.apply(null, [task_name].concat(args))
    @

  postinstall: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    # collect tests to run
    for set_name, set of @config
      continue unless set_name is '_postinstall'
      eb.utils.extractSetCommands(set, command_queue, @config_dir)

    # add footer
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("postinstall completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(options, callback) unless options.queue
    @

  clean: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    # add header
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("------------clean #{if options.preview then 'started (PREVIEW)' else 'started'}------------"); callback?()})

    ###############################
    # cake build
    ###############################
    # get the build commands
    build_queue = new eb.command.Queue()
    @build(_.defaults({clean: false, queue: build_queue}, options))

    for command in build_queue.commands()
      continue unless command instanceof eb.command.Coffee

      output_directory = command.targetDirectory()
      pathed_targets = command.pathedTargets()
      for pathed_build_name in pathed_targets
        # add the command
        command_queue.push(new eb.command.Remove(["#{pathed_build_name}"], {cwd: @config_dir}))
        command_queue.push(new eb.command.Remove(["#{eb.utils.compressedName(pathed_build_name)}"], {cwd: @config_dir})) if command.isCompressed()

    ###############################
    # cake postinstall
    ###############################
    # get the postinstall commands
    postinstall_queue = new eb.command.Queue()
    @postinstall(_.defaults({clean: false, queue: postinstall_queue}, options))

    for command in postinstall_queue.commands()
      continue unless command.createUndoCommand # there is a reverse
      command_queue.push(command.createUndoCommand()) # add the command

    # add footer
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("clean completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(options, callback) unless options.queue
    @

  build: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    # add the clean commands
    @clean(_.defaults({queue: command_queue}, options)) if options.clean

    # add the postinstall commands
    @postinstall(options, command_queue)

    # add header
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("------------build #{if options.preview then 'started (PREVIEW)' else 'started'}------------"); callback?()})

    # collect files to build
    for set_name, set of @config
      continue if set_name.startsWith('_')

      set_options = eb.utils.extractSetOptions(set, '_build')
      file_groups = eb.utils.getOptionsFileGroups(set_options, @config_dir, options)

      for file_group in file_groups
        args = []
        args.push('-w') if options.watch
        args.push('-b') if set_options.bare
        if set_options.join
          args.push('-j')
          args.push(set_options.join)
        args.push('-o')
        if set_options.output then args.push(set_options.output) else args.push(@config_dir)
        args.push('-c')
        if file_group.files
          args = args.concat(_.map(file_group.files, (file) -> return path.join(file_group.directory, file)))
        else
          args.push(file_group.directory)

        # add the command
        command_queue.push(new eb.command.Coffee(args, {cwd: file_group.directory, compress: set_options.compress, test: options.test}))

      # add commands
      eb.utils.extractSetCommands(set_options, command_queue, @config_dir)

      # add bundles
      command_queue.push(new eb.command.Bundle(set_options.bundles, {cwd: @config_dir})) if set_options.bundles

    # add footer
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("build completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(options, callback) unless options.queue
    @

  test: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    # add the build commands (will add clean if specified since 'clean' would be in the options)
    @build(_.defaults({test: true, queue: command_queue}, options))  if options.build or options.watch

    # create a new queue for the tests so we can get a group result
    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'tests'))

    # add header
    if options.verbose
      test_queue.push({run: (run_options, callback, queue) -> console.log("------------test #{if options.preview then 'started (PREVIEW)' else 'started'}------------"); callback?()})

    # collect tests to run
    for set_name, set of @config
      continue if set_name.startsWith('_') or not set.hasOwnProperty('_test')

      set_options = eb.utils.extractSetOptions(set, '_test')
      file_groups = eb.utils.getOptionsFileGroups(set_options, @config_dir, options)

      # lookup the default runner
      if set_options.runner and not path.existsSync(set_options.runner)
        set_options.runner = "#{RUNNERS_ROOT}/#{set_options.runner}"
        easy_bake_runner_used = true

      for file_group in file_groups
        throw "missing files for test in set: #{set_name}" unless file_group.files

        for file in file_group.files
          args = []
          args.push(set_options.runner) if set_options.runner
          args.push(path.join(file_group.directory, file))
          args = args.concat(set_options.args) if set_options.args
          if easy_bake_runner_used
            length_base = if set_options.runner then 2 else 1
            args.push(TEST_DEFAULT_TIMEOUT) if args.length < (length_base + 1)
            args.push(true) if args.length < (length_base + 2)

          # add the command
          test_queue.push(new eb.command.RunTest(set_options.command, args, {cwd: @config_dir}))

      # add commands
      eb.utils.extractSetCommands(set, command_queue, @config_dir)

    # add footer
    unless options.preview
      test_queue.push({run: (run_options, callback, queue) =>
        unless (options.preview or options.verbose)
          total_error_count = 0
          console.log("\n-------------GROUP TEST RESULTS--------")
          for command in test_queue.commands()
            continue unless (command instanceof eb.command.RunTest)
            total_error_count += if command.exitCode() then 1 else 0
            console.log("#{if command.exitCode() then '✖' else '✔'} #{eb.utils.relativePath(command.fileName(), @config_dir)}#{if command.exitCode() then (' (exit code: ' + command.exitCode() + ')') else ''}")
          console.log("--------------------------------------")
          console.log(if total_error_count then "All tests ran with with #{total_error_count} error(s)" else "All tests ran successfully!")
          console.log("--------------------------------------")

        callback?(0)

        # done so exit so test runners know the condition of the tests
        if not options.watch and not options.no_exit
          process.exit(if (queue.errorCount() > 0) then 1 else 0)
      })

    # run
    command_queue.run(options, callback) unless options.queue
    @

  publishGit: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'publishgit'))

    # build a chain of commands
    unless options.quick
      chain_options = _.defaults({queue: test_queue}, options)
      @clean(chain_options).postinstall(chain_options).build(chain_options).test(_.defaults({no_exit: true}, chain_options))
    test_queue.push({run: (run_options, callback, queue) =>

      # don't run because the tests weren't successful
      unless (options.preview or options.verbose)
        if queue.errorCount()
          console.log("publishgit aborted due to #{queue.errorCount()} error(s)")
          callback?(queue.errorCount()); return

      git_command = new eb.command.PublishGit({cwd: @config_dir})
      git_command.run(options, (code) ->
        console.log("publishgit completed with #{code} error(s)") unless options.verbose
        callback?(code)
      )
    })

    # run
    command_queue.run(options, callback) unless options.queue
    @

  publishNPM: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'publish_npm'))

    # build a chain of commands
    unless options.quick
      chain_options = _.defaults({queue: test_queue}, options)
      @clean(chain_options).postinstall(chain_options).build(chain_options).test(_.defaults({no_exit: true}, chain_options))
    test_queue.push({run: (run_options, callback, queue) =>

      # don't run because the tests weren't successful
      unless (options.preview or options.verbose)
        if queue.errorCount()
          console.log("publish_npm aborted due to #{queue.errorCount()} error(s)")
          callback?(queue.errorCount()); return

      # CONVENTION: try a nested package in the form 'packages/npm' first
      package_path = path.join(@config_dir, 'packages', 'npm')
      package_path = @config_dir unless path.existsSync(package_path) # fallback to this project

      # CONVENTION: safe guard...do not publish packages that starts in _ or missing the main file
      package_desc_path = path.join(package_path, 'package.json')
      (console.log("no package.json found for publishNPM: #{package_desc_path.replace(@config_dir, '')}"); return) unless path.existsSync(package_desc_path) # fallback to this project
      package_desc = require(package_desc_path)
      (console.log("skipping publishnpm for: #{package_desc_path} (name starts with '_')"); return) if package_desc.name.search(/^_/) >= 0
      (console.log("skipping publishnpm for: #{package_desc_path} (main file missing...do you need to build it?)"); return) unless path.existsSync(path.join(package_path, package_desc.main))

      git_command = new eb.command.PublishNPM({force: options.force, cwd: package_path})
      git_command.run(options, (code) ->
        console.log("publish_npm completed with #{code} error(s)") unless options.verbose
        callback?(code)
      )
    })

    # run
    command_queue.run(options, callback) unless options.queue
    @

  publishNuGet: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'publish_nuget'))

    # build a chain of commands
    unless options.quick
      chain_options = _.defaults({queue: test_queue}, options)
      @clean(chain_options).postinstall(chain_options).build(chain_options).test(_.defaults({no_exit: true}, chain_options))
    test_queue.push({run: (run_options, callback, queue) =>

      # don't run because the tests weren't successful
      unless (options.preview or options.verbose)
        if queue.errorCount()
          console.log("publish_nuget aborted due to #{queue.errorCount()} error(s)")
          callback?(queue.errorCount()); return

      # CONVENTION: try a nested package in the form 'packages/npm' first
      package_path = path.join(@config_dir, 'packages', 'npm')
      package_path = @config_dir unless path.existsSync(package_path) # fallback to this project

      # CONVENTION: safe guard...do not publish packages that starts in _ or missing the main file
      package_desc_path = path.join(package_path, 'package.json')
      (console.log("no package.json found for publishNuGet: #{package_desc_path.replace(@config_dir, '')}"); return) unless path.existsSync(package_desc_path) # fallback to this project
      package_desc = require(package_desc_path)
      (console.log("skipping publishnpm for: #{package_desc_path} (name starts with '_')"); return) if package_desc.name.search(/^_/) >= 0
      (console.log("skipping publishnpm for: #{package_desc_path} (main file missing...do you need to build it?)"); return) unless path.existsSync(path.join(package_path, package_desc.main))

      git_command = new eb.command.publishNuGet({force: options.force, cwd: package_path})
      git_command.run(options, (code) ->
        console.log("publish_nuget completed with #{code} error(s)") unless options.verbose
        callback?(code)
      )
    })

    # run
    command_queue.run(options, callback) unless options.queue
    @

    @clean(chain_options).postinstall(chain_options).build(chain_options).test(_.defaults({no_exit: true}, chain_options))
