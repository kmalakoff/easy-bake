{print} = require 'util'
{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
require 'coffee-script/lib/coffee-script/cake' if not global.option # load cake
yaml = require 'js-yaml'
_ = require 'underscore'

RESERVED_SETS = ['postinstall']
TEST_DEFAULT_TIMEOUT = 60000
RUNNERS_ROOT = "#{__dirname}/lib/test_runners"

# export or create eb namespace
eb = @eb = if (typeof(exports) != 'undefined') then exports else {}
eb.utils = require './lib/easy-bake-utils'
eb.command = require './lib/easy-bake-commands'

# helpers
timeLog = (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")

##############################
# The Oven
##############################
class eb.Oven
  constructor: (YAML_filename) ->
    @YAML_dir = path.dirname(fs.realpathSync(YAML_filename))
    @YAML = yaml.load(fs.readFileSync(YAML_filename, 'utf8'))

  publishOptions: ->
    global.option('-c', '--clean',     'cleans the project before running a command')
    global.option('-w', '--watch',     'watches for changes')
    global.option('-b', '--build',     'builds the project (used with test)')
    global.option('-p', '--preview',   'display all of the commands that will be run (without running them!)')
    global.option('-v', '--verbose',   'display additional information')
    global.option('-s', '--silent',    'does not output messages to the console (unless errors occur)')
    @

  publishTasks: (options={}) ->
    @publishOptions()

    tasks =
      postinstall:  ['Called by npm after installing library',  (options) => @postinstall(options)]
      clean:        ['Remove generated JavaScript files',       (options) => @clean(options)]
      build:        ['Build library and tests',                 (options) => @build(options)]
      watch:        ['Watch library and tests',                 (options) => @build(_.defaults({watch: true}, options))]
      test:         ['Test library',                            (options) => @test(options)]
      gitpush:      ['Cleans, builds, tests and if successful, runs git commands to add, commit, and push the project',  (options) => @gitPush(options)]

    # register and optionally namespace the tasks
    task_names = if options.tasks then options.tasks else _.keys(tasks)
    for task_name in task_names
      args = tasks[task_name]
      (console.log("easy-bake: task name not recognized #{task_name}"); continue) unless args
      task_name = "#{options.namespace}.#{task_name}" if options.namespace
      global.task.apply(null, [task_name].concat(args))
    @

  postinstall: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    # collect tests to run
    for set_name, set of @YAML
      continue unless set_name is 'postinstall'

      # run commands
      for name, command_info of set
        # missing the command
        (console.log("postinstall #{set_name}.#{name} is not a command"); continue) unless command_info.command

        # add the command
        if command_info.command is 'cp'
          command_queue.push(new eb.command.Copy(command_info.args, {cwd: @YAML_dir}))
        else
          command_queue.push(new eb.command.RunCommand(command_info.command, command_info.args, _.defaults({cwd: @YAML_dir}, command_info.options)))

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
        command_queue.push(new eb.command.Remove(["#{pathed_build_name}"], {cwd: @YAML_dir}))
        command_queue.push(new eb.command.Remove(["#{eb.utils.compressedName(pathed_build_name)}"], {cwd: @YAML_dir})) if command.isCompressed()

    ###############################
    # cake postinstall
    ###############################
    # get the postinstall commands
    postinstall_queue = new eb.command.Queue()
    @postinstall(_.defaults({clean: false}, options), postinstall_queue)

    for command in postinstall_queue.commands()
      continue unless command instanceof eb.command.RunCommand

      # undo the copy
      if command.command is 'cp'
        args = []
        if command.args[0] is '-r'
          args.push('-r')
          args.push(path.join(@YAML_dir, command.args[2]))
        else
          args.push(path.join(@YAML_dir, command.args[1]))

        # add the command
        command_queue.push(new eb.command.Remove(args, {cwd: @YAML_dir}))

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
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name)

      set_options = eb.utils.extractSetOptions(set, 'build')

      file_groups = eb.utils.getOptionsFileGroups(set_options, @YAML_dir, options)
      for file_group in file_groups
        args = []
        args.push('-w') if options.watch
        args.push('-b') if set_options.bare
        if set_options.join
          args.push('-j')
          args.push(set_options.join)
        args.push('-o')
        if set_options.output then args.push(set_options.output) else args.push(@YAML_dir)
        args.push('-c')
        if file_group.files
          args = args.concat(_.map(file_group.files, (file) -> return path.join(file_group.directory, file)))
        else
          args.push(file_group.directory)

        # add the command
        command_queue.push(new eb.command.Coffee(args, {cwd: file_group.directory, compress: set_options.compress, test: options.test}))

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
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name) or not (set.options and set.options.hasOwnProperty('test'))

      set_options = eb.utils.extractSetOptions(set, 'test')

      # lookup the default runner
      if set_options.runner and not path.existsSync(set_options.runner)
        set_options.runner = "#{RUNNERS_ROOT}/#{set_options.runner}"
        easy_bake_runner_used = true

      file_groups = eb.utils.getOptionsFileGroups(set_options, @YAML_dir, options)
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
          test_queue.push(new eb.command.RunTest(set_options.command, args, {cwd: @YAML_dir}))

    # add footer
    unless options.preview
      test_queue.push({run: (run_options, callback, queue) =>
        unless (options.preview or options.verbose)
          total_error_count = 0
          console.log("\n-------------GROUP TEST RESULTS--------")
          for command in test_queue.commands()
            continue unless (command instanceof eb.command.RunTest)
            total_error_count += if command.exitCode() then 1 else 0
            console.log("#{if command.exitCode() then '✖' else '✔'} #{eb.utils.relativePath(command.fileName(), @YAML_dir)}#{if command.exitCode() then (' (exit code: ' + command.exitCode() + ')') else ''}")
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

  gitPush: (options={}, callback) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'gitpush'))

    # build a chain of commands
    chain_options = _.defaults({queue: test_queue}, options)
    @clean(chain_options).postinstall(chain_options).build(chain_options).test(_.defaults({no_exit: true}, chain_options))
    test_queue.push({run: (run_options, callback, queue) ->

      # don't run because the tests weren't successful
      unless (options.preview or options.verbose)
        if queue.errorCount()
          console.log("gitpush aborted due to #{queue.errorCount()} error(s)")
          callback?(queue.errorCount()); return

      git_command = new eb.command.GitPush({cwd: @YAML_dir})
      git_command.run(options, (code) ->
        console.log("gitpush completed with #{code} error(s)") unless options.verbose
        callback?(code)
      )
    })

    # run
    command_queue.run(options, callback) unless options.queue
    @
