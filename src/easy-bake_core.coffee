{print} = require 'util'
{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
_ = require 'underscore'
ebc = require './lib/easy-bake-commands'
require 'coffee-script/lib/coffee-script/cake'

RESERVED_SETS = ['postinstall']
TEST_DEFAULT_TIMEOUT = 60000
RUNNERS_ROOT = "#{__dirname}/lib/test_runners"

# export or create eb namespace
eb = @eb = if (typeof(exports) != 'undefined') then exports else {}

# helpers
timeLog = (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")

##############################
# The Baker
##############################
class eb.Baker
  constructor: (YAML, options={}) ->
    @YAML_dir = path.dirname(fs.realpathSync(YAML))
    @YAML = yaml.load(fs.readFileSync(YAML, 'utf8'))

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

  resolveDirectory: (directory, current_root) ->
    if (directory.match(/^\.\//))
      stripped_directory = directory.substr('./'.length)
      return if directory == './' then current_root else "#{current_root}/#{stripped_directory}"
    else if (directory == '.')
      stripped_directory = directory.substr('.'.length)
      return "#{current_root}/#{stripped_directory}"
    else if (directory[0]=='/')
      return directory
    else if (directory.match(/^\{root\}/))
      stripped_directory = directory.substr('{root}'.length)
      return if directory == '{root}' then @YAML_dir else "#{@YAML_dir}/#{stripped_directory}"
    else
      return "#{@YAML_dir}/#{directory}"

  minifiedOutputName: (output_directory, source_name) ->
    output_directory = @resolveDirectory(output_directory, path.dirname(source_name))
    return "#{output_directory}/#{path.basename(source_name).replace(/\.coffee$/, ".js")}"
  minifiedName: (output_name) -> return output_name.replace(/\.js$/, ".min.js")

  clean: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new ebc.Queue()

    # add header
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("************clean #{if options.preview then 'started (PREVIEW)' else 'started'}************"); callback?()})

    # collect files and directories to clean
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name)

      set_options = eb.Utils.extractSetOptions(set, 'build', {
        directories: [@YAML_dir]
      })
      _.extend(set_options, set.options.clean) if set.options and set.options.clean

      for directory in set_options.directories
        if set_options.output
          if (set_options.output[0]=='.') or (set_options.output.match(/^\{root\}/))
            resolved_path = then @resolveDirectory(set_options.output, directory)
          else
            continue unless path.existsSync(set_options.output) # doesn't exist so skip
            resolved_path = fs.realpathSync(set_options.output)

          # add the command
          command_queue.push(new ebc.RunClean(['-r', resolved_path], {root_dir: @YAML_dir}))
        else
          resolved_path = @YAML_dir

        # cleanup join commands
        if set_options.join
          command_queue.push(new ebc.RunClean(["#{resolved_path}/#{set_options.join}"], {root_dir: @YAML_dir}))
          command_queue.push(new ebc.RunClean(["#{resolved_path}/#{@minifiedName(set_options.join)}"], {root_dir: @YAML_dir})) if set_options.minimize

    # add footer
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("clean completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(null, options) if owns_queue

  watch: (options={}, command_queue) -> @build(_.defaults({watch: true}, options), command_queue)
  build: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new ebc.Queue()

    # add the clean commands
    @clean(options, command_queue) if options.clean

    # add header
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("************build #{if options.preview then 'started (PREVIEW)' else 'started'}************"); callback?()})

    # collect files to build
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name)

      set_options = eb.Utils.extractSetOptions(set, 'build', {
        directories: ['.']
        files: ['**/*.coffee']
      })

      file_groups = eb.Utils.setOptionsFileGroups(set_options, @YAML_dir)
      for file_group in file_groups
        args = []
        args.push('-w') if options.watch
        args.push('-b') if set_options.bare
        args.push(['-j', set_options.join]) if set_options.join
        if set_options.output
          args.push(['-o', @resolveDirectory(set_options.output, file_group.directory)])
        else
          args.push(['-o', @YAML_dir])
        args.push(['-c', file_group.files])

        # add the command
        coffee_command = new ebc.RunCoffee(_.flatten(args), {root_dir: @YAML_dir})
        command_queue.push(coffee_command)

        # add a minimize command
        if set_options.minimize
          output_directory = coffee_command.targetDirectory()
          for source_name in coffee_command.targetNames()
            output_name = @minifiedOutputName(output_directory, source_name)

            # add the command
            command_queue.push(new ebc.RunUglifyJS(['-o', @minifiedName(output_name), output_name], {root_dir: @YAML_dir}))

    # add footer
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("build completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(null, options) if owns_queue

  test: (options={}, command_queue) ->
    owns_queue = !command_queue
    command_queue or= new ebc.Queue()

    # add the build commands (will add clean if specified since 'clean' would be in the options)
    @build(options, command_queue)

    # create a new queue for the tests so we can get a group result
    test_queue = new ebc.Queue()
    command_queue.push(new ebc.RunQueue(test_queue, 'tests'))

    # add header
    if options.verboe
      test_queue.push({run: (callback, options, queue) -> console.log("************test #{if options.preview then 'started (PREVIEW)' else 'started'}************"); callback?()})

    # collect tests to run
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name) or not (set.options and set.options.hasOwnProperty('test'))

      set_options = eb.Utils.extractSetOptions(set, 'test', {
        directories: ['.']
        files: ['**/*.html']
      })

      # lookup the default runner
      if set_options.runner and not path.existsSync(set_options.runner)
        set_options.runner = "#{RUNNERS_ROOT}/#{set_options.runner}"
        easy_bake_runner_used = true

      file_groups = eb.Utils.setOptionsFileGroups(set_options, @YAML_dir)
      for file_group in file_groups
        for file in file_group.files

          # resolve the arguments
          args = []
          args.push(set_options.runner) if set_options.runner
          if (set_options.command is 'phantomjs') then args.push("file://#{fs.realpathSync(file)}") else args.push(file.replace(@YAML_dir, ''))
          if easy_bake_runner_used
            args.push(if set_options.timeout then set_options.timeout else TEST_DEFAULT_TIMEOUT)
            args.push(true)
          else
            args.push(set_options.timeout) if set_options.timeout
            args.push(set_options.silent) if set_options.silent

          # add the command
          test_queue.push(new ebc.RunTest(set_options.command, args, {root_dir: @YAML_dir}))

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
    command_queue or= new ebc.Queue()

    # collect tests to run
    for set_name, set of @YAML
      continue unless set_name is 'postinstall'

      # run commands
      for name, command_info of set
        # missing the command
        (console.log("postinstall #{set_name}.#{name} is not a command"); continue) unless command_info.command

        # add the command
        command_queue.push(new ebc.RunCommand(command_info.command, command_info.args, _.defaults({root_dir: @YAML_dir}, command_info.options)))

    # add footer
    if options.verbose
      command_queue.push({run: (callback, options, queue) -> console.log("postinstall completed with #{queue.errorCount()} error(s)"); callback?()})

    # run
    command_queue.run(null, options) if owns_queue