{print} = require 'util'
{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
_ = require 'underscore'
require 'coffee-script/lib/coffee-script/cake' if not global.option # load cake

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

  postinstall: (options={}, command_queue) ->
    owns_queue = !command_queue; command_queue or= new eb.command.Queue()

    # collect tests to run
    for set_name, set of @YAML
      continue unless set_name is 'postinstall'

      # run commands
      for name, command_info of set
        # missing the command
        (console.log("postinstall #{set_name}.#{name} is not a command"); continue) unless command_info.command

        # add the command
        command_queue.push(new eb.command.Command(command_info.command, command_info.args, _.defaults({root_dir: @YAML_dir}, command_info.options)))

    # add footer
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("postinstall completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(options) if owns_queue
    @

  clean: (options={}, command_queue) ->
    owns_queue = !command_queue; command_queue or= new eb.command.Queue()

    # add header
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("------------clean #{if options.preview then 'started (PREVIEW)' else 'started'}------------"); callback?()})

    ###############################
    # cake build
    ###############################
    # get the build commands
    build_queue = new eb.command.Queue()
    @build(_.defaults({clean: false}, options), build_queue)

    for command in build_queue.commands()
      continue unless command instanceof eb.command.Coffee

      output_directory = command.targetDirectory()
      output_names = command.targetNames()
      for source_name in output_names
        build_directory = eb.utils.resolvePath(output_directory, {cwd: path.dirname(source_name), root_dir: @YAML_dir})
        pathed_build_name = "#{build_directory}/#{eb.utils.builtName(path.basename(source_name))}"

        # add the command
        command_queue.push(new eb.command.Clean(["#{pathed_build_name}"], {root_dir: @YAML_dir}))
        command_queue.push(new eb.command.Clean(["#{eb.utils.compressedName(pathed_build_name)}"], {root_dir: @YAML_dir})) if command.isCompressed()

    ###############################
    # cake postinstall
    ###############################
    # get the postinstall commands
    postinstall_queue = new eb.command.Queue()
    @postinstall(_.defaults({clean: false}, options), postinstall_queue)

    for command in postinstall_queue.commands()
      continue unless command instanceof eb.command.Command

      # undo the copy
      if command.command is 'cp'
        target = "#{@YAML_dir}/#{command.args[1]}"
        args = []
        args.push('-r') unless path.basename(target)
        args.push(target)

        # add the command
        command_queue.push(new eb.command.Clean(args, {root_dir: @YAML_dir}))

    # add footer
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("clean completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(options) if owns_queue
    @

  build: (options={}, command_queue) ->
    owns_queue = !command_queue; command_queue or= new eb.command.Queue()

    # add the clean commands
    @clean(options, command_queue) if options.clean

    # add the postinstall commands
    @postinstall(options, command_queue)

    # add header
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("------------build #{if options.preview then 'started (PREVIEW)' else 'started'}------------"); callback?()})

    # collect files to build
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name)

      set_options = eb.utils.extractSetOptions(set, 'build', {
        directories: ['.']
        files: ['**/*.coffee']
      })

      file_groups = eb.utils.getOptionsFileGroups(set_options, @YAML_dir, options)
      for file_group in file_groups
        args = []
        args.push('-w') if options.watch
        args.push('-b') if set_options.bare
        if set_options.join
          args.push('-j')
          args.push(set_options.join)
        args.push('-o')
        if set_options.output
          args.push(eb.utils.resolvePath(set_options.output, {cwd: file_group.directory, root_dir: @YAML_dir}))
        else
          args.push(@YAML_dir)
        args.push('-c')
        args.push(file) for file in file_group.files

        # add the command
        command_queue.push(new eb.command.Coffee(args, {root_dir: @YAML_dir, compress: set_options.compress, test: options.test}))

    # add footer
    if options.verbose
      command_queue.push({run: (run_options, callback, queue) -> console.log("build completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(options) if owns_queue
    @

  test: (options={}, command_queue) ->
    owns_queue = !command_queue; command_queue or= new eb.command.Queue()

    # add the build commands (will add clean if specified since 'clean' would be in the options)
    @build(_.defaults({test: true}, options), command_queue)  if options.build or options.watch

    # create a new queue for the tests so we can get a group result
    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'tests'))

    # add header
    if options.verbose
      test_queue.push({run: (run_options, callback, queue) -> console.log("------------test #{if options.preview then 'started (PREVIEW)' else 'started'}------------"); callback?()})

    # collect tests to run
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name) or not (set.options and set.options.hasOwnProperty('test'))

      set_options = eb.utils.extractSetOptions(set, 'test', {
        directories: ['.']
        files: ['**/*.html']
      })

      # lookup the default runner
      if set_options.runner and not path.existsSync(set_options.runner)
        set_options.runner = "#{RUNNERS_ROOT}/#{set_options.runner}"
        easy_bake_runner_used = true

      file_groups = eb.utils.getOptionsFileGroups(set_options, @YAML_dir, options)
      for file_group in file_groups
        for file in file_group.files
          args = []
          args.push(set_options.runner) if set_options.runner
          args.push(eb.utils.resolvePath(file, {cwd: file_group.directory, root_dir: @YAML_dir}))
          args = args.concat(set_options.args) if set_options.args
          if easy_bake_runner_used
            length_base = if set_options.runner then 2 else 1
            args.push(TEST_DEFAULT_TIMEOUT) if args.length < (length_base + 1)
            args.push(true) if args.length < (length_base + 2)

          # add the command
          test_queue.push(new eb.command.Test(set_options.command, args, {root_dir: @YAML_dir}))

    # add footer
    unless options.preview
      test_queue.push({run: (run_options, callback, queue) ->
        unless (options.preview or options.verbose)
          total_error_count = 0
          console.log("\n-------------GROUP TEST RESULTS--------")
          for command in test_queue.commands()
            continue unless (command instanceof eb.command.Test)
            total_error_count += if command.exitCode() then 1 else 0
            console.log("#{if command.exitCode() then '✖' else '✔'} #{command.fileName()}#{if command.exitCode() then (' (exit code: ' + command.exitCode() + ')') else ''}")
          console.log("--------------------------------------")
          console.log(if total_error_count then "All tests ran with with #{total_error_count} error(s)" else "All tests ran successfully!")
          console.log("--------------------------------------")

        callback?(0)

        # done so exit so test runners know the condition of the tests
        if not options.watch and not options.no_exit
          process.exit(if (queue.errorCount() > 0) then 1 else 0)
      })

    # run
    command_queue.run(options) if owns_queue
    @

  gitPush: (options={}, command_queue) ->
    owns_queue = !command_queue; command_queue or= new eb.command.Queue()

    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'gitpush'))

    # build a chain of commands
    @clean(options, test_queue).postinstall(options, test_queue).build(options, test_queue).test(_.defaults({no_exit: true}, options), test_queue)
    test_queue.push({run: (run_options, callback, queue) ->

      # don't run because the tests weren't successful
      unless (options.preview or options.verbose)
        if queue.errorCount()
          console.log("gitpush aborted due to #{queue.errorCount()} error(s)")
          callback?(queue.errorCount()); return

      git_command = new eb.command.GitPush()
      git_command.run(options, (code) ->
        console.log("gitpush completed with #{code} error(s)") unless options.verbose
        callback?(code)
      )
    })

    # run
    command_queue.run(options) if owns_queue
    @
