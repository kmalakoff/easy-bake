{print} = require 'util'
{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
_ = require 'underscore'
require 'coffee-script/lib/coffee-script/cake'

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

  publishTasks: (options={}) ->
    ##############################
    # CAKE TASKS
    ##############################
    option '-c', '--clean', 'clean the project'
    option '-w', '--watch', 'watch for changes'
    option '-s', '--silent', 'silence the console output'
    option '-p', '--preview', 'preview the action'
    option '-v', '--verbose', 'display additional information'

    tasks =
      clean:        ['Remove generated JavaScript files',   (options) => @clean(options)]
      build:        ['Build library and tests',             (options) => @build(options)]
      watch:        ['Watch library and tests',             (options) => @watch(options)]
      test:         ['Test library',                        (options) => @test(options)]
      postinstall:  ['Performs postinstall actions',        (options) => @postinstall(options)]

    # register and optionally namespace the tasks
    task_names = if options.tasks then options.tasks else _.keys(tasks)
    for task_name in task_names
      args = tasks[task_name]
      (console.log("easy-bake: task name not recognized #{task_name}"); continue) unless args
      task_name = "#{options.namespace}.#{task_name}" if options.namespace
      task.apply(null, [task_name].concat(args))

  clean: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new eb.command.Queue()

    # add header
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("************clean #{if options.preview then 'started (PREVIEW)' else 'started'}************"); callback?()})

    ###############################
    # cake build
    ###############################
    # get the build commands
    build_queue = new eb.command.Queue()
    @build(_.defaults({clean: false}, options), build_queue)

    for command in build_queue.commands()
      continue unless command instanceof eb.command.RunCoffee

      output_directory = command.targetDirectory()
      output_names = command.targetNames()
      for source_name in output_names
        build_directory = eb.utils.resolvePath(output_directory, path.dirname(source_name), @YAML_dir)
        pathed_build_name = "#{build_directory}/#{eb.utils.builtName(path.basename(source_name))}"

        # add the command
        command_queue.push(new eb.command.RunClean(["#{pathed_build_name}"], {root_dir: @YAML_dir}))
        command_queue.push(new eb.command.RunClean(["#{eb.utils.compressedName(pathed_build_name)}"], {root_dir: @YAML_dir})) if command.isCompressed()

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
        target = "#{@YAML_dir}/#{command.args[1]}"
        args = []
        args.push('-r') unless path.basename(target)
        args.push(target)

        # add the command
        command_queue.push(new eb.command.RunClean(args, {root_dir: @YAML_dir}))

    # add footer
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("clean completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(null, options) if owns_queue

  watch: (options={}, command_queue) -> @build(_.defaults({watch: true}, options), command_queue)
  build: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new eb.command.Queue()

    # add the clean commands
    @clean(options, command_queue) if options.clean

    # add the postinstall commands
    @postinstall(options, command_queue)

    # add header
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("************build #{if options.preview then 'started (PREVIEW)' else 'started'}************"); callback?()})

    # collect files to build
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name)

      set_options = eb.utils.extractSetOptions(set, 'build', {
        directories: ['.']
        files: ['**/*.coffee']
      })

      file_groups = eb.utils.getOptionsFileGroups(set_options, @YAML_dir)
      for file_group in file_groups
        args = []
        args.push('-w') if options.watch
        args.push('-b') if set_options.bare
        if set_options.join
          args.push('-j')
          args.push(set_options.join)
        args.push('-o')
        if set_options.output
          args.push(eb.utils.resolvePath(set_options.output, file_group.directory, @YAML_dir))
        else
          args.push(@YAML_dir)
        args.push('-c')
        args = args.concat(file_group.files)

        # add the command
        command_queue.push(new eb.command.RunCoffee(args, {root_dir: @YAML_dir, compress: set_options.compress}))

    # add footer
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("build completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(null, options) if owns_queue

  test: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new eb.command.Queue()

    # add the build commands (will add clean if specified since 'clean' would be in the options)
    @build(options, command_queue)

    # create a new queue for the tests so we can get a group result
    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, 'tests'))

    # add header
    if options.verbose
      test_queue.push({run: (callback, options, queue) -> console.log("************test #{if options.preview then 'started (PREVIEW)' else 'started'}************"); callback?()})

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

      file_groups = eb.utils.getOptionsFileGroups(set_options, @YAML_dir)
      for file_group in file_groups
        for file in file_group.files
          args = []
          args.push(set_options.runner) if set_options.runner
          if (set_options.command is 'phantomjs') then args.push("file://#{fs.realpathSync(file)}") else args.push(fs.realpathSync(file))
          args = args.concat(set_options.args) if set_options.args
          if easy_bake_runner_used
            length_base = if set_options.runner then 2 else 1
            args.push(TEST_DEFAULT_TIMEOUT) if args.length < (length_base + 1)
            args.push(true) if args.length < (length_base + 2)

          # add the command
          test_queue.push(new eb.command.RunTest(set_options.command, args, {root_dir: @YAML_dir}))

    # add footer
    test_queue.push({run: (callback, options, queue) ->
      console.log("test completed with #{queue.errorCount()} error(s)") if options.verbose
      callback?()

      # done so exit so test runners know the condition of the tests
      process.exit(if (queue.errorCount() > 0) then 1 else 0) unless options.watch
    })

    # run
    command_queue.run(null, options) if owns_queue

  postinstall: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new eb.command.Queue()

    # collect tests to run
    for set_name, set of @YAML
      continue unless set_name is 'postinstall'

      # run commands
      for name, command_info of set
        # missing the command
        (console.log("postinstall #{set_name}.#{name} is not a command"); continue) unless command_info.command

        # add the command
        command_queue.push(new eb.command.RunCommand(command_info.command, command_info.args, _.defaults({root_dir: @YAML_dir}, command_info.options)))

    # add footer
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("postinstall completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(null, options) if owns_queue