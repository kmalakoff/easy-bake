{print} = require 'util'
{spawn} = require 'child_process'
coffeescript = require 'coffee-script'
require 'coffee-script/lib/coffee-script/cake' if not global.option # load cake
_ = require 'underscore'

TEST_DEFAULT_TIMEOUT = 60000
RUNNERS_ROOT = "#{__dirname}/lib/test_runners"

INTERNAL_SETS = ['_postinstall']
INTERNAL_MODES = ['_build', '_test']

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

    # validate
    @_validateConfig()

  _validateConfig: ->
    console.log("warning: an empty config file was loaded: #{config_pathed_filename}") unless _.size(@config)

    # check for unrecognized sets
    for set_name, set of @config
      console.log("warning: set name '#{set_name}' is not a recognized internal set. It will be skipped.") if set_name.startsWith('_') and not _.contains(INTERNAL_SETS, set_name)

      # check for unrecognized modes
      for mode_name of set
        console.log("warning: mode name '#{mode_name}' is not a recognized internal mode. It will be skipped.") if mode_name.startsWith('_') and not _.contains(INTERNAL_MODES, mode_name)
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
        command_queue.push(new eb.command.Coffee(args, _.defaults(_.defaults({cwd: file_group.directory}, set_options), options)))

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
    options = _.defaults({build: true}, options) if options.clean
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
      if set_options.runner and not existsSync(set_options.runner)
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

  publishPrepare: (options={}, callback, name, success_fn) ->
    command_queue = if options.queue then options.queue else new eb.command.Queue()

    test_queue = new eb.command.Queue()
    command_queue.push(new eb.command.RunQueue(test_queue, name))

    # build a chain of commands
    unless options.quick
      test_options = _.defaults({queue: test_queue}, options)
      delete test_options['quick']
      @clean(test_options).postinstall(test_options).build(test_options).test(_.defaults({no_exit: true}, test_options))
    test_queue.push({run: (run_options, local_callback, queue) =>

      # don't run because the tests weren't successful
      unless (options.preview or options.verbose)
        if queue.errorCount()
          console.log("#{name} aborted due to #{queue.errorCount()} error(s)")
          local_callback?(queue.errorCount()); return

      # let the command start
      success_fn()
    })

    # run
    command_queue.run(options, callback) unless options.queue
    @

  publishGit: (options={}, callback) ->
    @publishPrepare(options, callback, 'publish_git', =>
      command = new eb.command.PublishGit({cwd: @config_dir})
      command.run(options, (code) =>
        console.log("publish_git completed with #{code} error(s)") unless options.verbose
      )
    )
    @

  publishNPM: (options={}, callback) ->
    @publishPrepare(options, callback, 'publish_npm', =>
      command = new eb.command.PublishNPM({cwd: @config_dir, force: options.force})
      command.run(options, (code) =>
        console.log("publish_npm completed with #{code} error(s)") unless options.verbose
      )
    )
    @

  publishNuGet: (options={}, callback) ->
    @publishPrepare(options, callback, 'publish_nuget', =>
      command = new eb.command.PublishNuGet({cwd: @config_dir, force: options.force})
      command.run(options, (code) =>
        console.log("publish_nuget completed with #{code} error(s)") unless options.verbose
      )
    )
    @

  publishAll: (options={}, callback) ->
    @publishPrepare(options, callback, 'publish_all', =>
      local_queue = new eb.command.Queue()
      local_queue.push(new eb.command.PublishNPM({cwd: @config_dir, force: options.force}))
      local_queue.push(new eb.command.PublishGit({cwd: @config_dir, force: options.force}))
      local_queue.push(new eb.command.PublishNuGet({cwd: @config_dir, force: options.force}))
      local_queue.run(options, (queue) -> callback?(queue.errorCount(), @))
    )
    @