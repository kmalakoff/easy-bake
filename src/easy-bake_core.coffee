{print} = require 'util'
{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
wrench = require 'wrench'
_ = require 'underscore'
globber = require 'glob-whatev'
uglifyjs = require 'uglify-js'
cake = require 'coffee-script/lib/coffee-script/cake'

RESERVED_SETS = ['postinstall']
TEST_DEFAULT_TIMEOUT = 60000
PROJECT_ROOT = "#{__dirname}/.."
RUNNERS_ROOT = "#{PROJECT_ROOT}/lib/test_runners"

# export or create eb namespace
eb = @eb = if (typeof(exports) != 'undefined') then exports else {}

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

  timeLog: (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")
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

  YAMLRelative: (pathed_filename) -> return eb.Utils.removeString(pathed_filename, "#{@YAML_dir}/")

  runClean: (array, directory, options) =>
    for item in array
      continue unless path.existsSync(item)

      @timeLog("cleaned #{item}")
      if directory then wrench.rmdirSyncRecursive(item) else fs.unlink(item) unless options.preview

  clean: (options={}, command_queue) ->
    owns_queue = !!command_queue
    command_queue or= new eb.CommandQueue()
    directories_to_delete = []
    files_to_delete = []

    # collect files and directories to clean
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name)

      set_options = eb.Utils.extractSetOptions(set, 'build', {
        directories: [@YAML_dir]
      })
      _.extend(set_options, set.options.clean) if set.options and set.options.clean

      for directory in set_options.directories
        if set_options.output
          if set_options.output[0]=='.'
            resolved_path = then @resolveDirectory(set_options.output, directory)
          else
            continue unless path.existsSync(set_options.output) # doesn't exist so skip
            resolved_path = fs.realpathSync(set_options.output)
          directories_to_delete.push(resolved_path)
        else
          resolved_path = @YAML_dir
        if set_options.join
          files_to_delete.push("#{resolved_path}/#{set_options.join}")
          files_to_delete.push("#{resolved_path}/#{@minifiedName(set_options.join)}") if set_options.minimize

    # execute or preview
    console.log('************clean preview*************') if options.preview
    @runClean(directories_to_delete, true, options)
    @runClean(files_to_delete, false, options)
    options.callback?(0)

    # run
    command_queue.run(((code)->console.log("done: #{code}")), options.preview) if owns_queue

  minify: (output_name, options={}, code) ->
    result = code
    args = ['-o', @minifiedName(output_name), output_name]

    if options.preview
      console.log("uglifyjs #{args.join(' ')}")
      options.callback?(result)

    else
      try
        src = fs.readFileSync(args[2], 'utf8')
        header = if ((header_index = src.indexOf('*/'))>0) then src.substr(0, header_index+2) else ''
        ast = uglifyjs.parser.parse(src)
        ast = uglifyjs.uglify.ast_mangle(ast)
        ast = uglifyjs.uglify.ast_squeeze(ast)
        src = header + uglifyjs.uglify.gen_code(ast) + ';'
        fs.writeFileSync(args[1], src, 'utf8')
        @timeLog("minified #{@YAMLRelative(output_name)}") unless options.silent
        options.callback?(result)
      catch e
        @timeLog("failed to minify #{@YAMLRelative(output_name)} .... error code: #{e.code}")
        options.callback?(result | e.code)

  runCoffee: (args, options={}) ->
    spawned = spawn 'coffee', args
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()

    notify = (code) =>
      output_directory = if ((index = _.indexOf(args, '-o')) >= 0) then "#{args[index+1]}" else ''
      filenames = if ((index = _.indexOf(args, '-j')) >= 0) then [args[index+1]] else filenames = args.slice(_.indexOf(args, '-c')+1)

      original_callback = options.callback; options = _.clone(options); options.callback = null
      options.callback = eb.Utils.afterWithCollect(filenames.length, (result) =>
        result |= original_callback(result) if original_callback
        return result
      )
      for source_name in filenames
        output_name = @minifiedOutputName(output_directory, source_name)
        build_filename = @YAMLRelative(output_name)
        if code is 0
          @timeLog("built #{build_filename}") unless options.silent
        else
          @timeLog("failed to build #{build_filename} .... error code: code")
        @minify(output_name, options, code) if options.minimize
      original_callback?(code) unless options.minimize

    # watch vs build callbacks are slightly different
    if options.watch then spawned.stdout.on('data', (data) -> notify(0)) else spawned.on('exit', (code) -> notify(code))

  build: (options={}, command_queue) ->
    owns_queue = !!command_queue
    command_queue or= new eb.CommandQueue()

    coffee_commands_to_run = []

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
        coffee_commands_to_run.push({args: _.flatten(args), minimize: set_options.minimize})

    # execute or preview callback
    original_callback = options.callback; options = _.clone(options); options.callback = null
    run_build_fn = (code) =>
      if options.preview
        console.log('************build preview*************')
        for coffee_command in coffee_commands_to_run
          args = coffee_command.args
          minimize = coffee_command
          console.log("coffee #{args.join(' ')}")

          if coffee_command.minimize
            output_directory = if ((index = _.indexOf(args, '-o')) >= 0) then "#{args[index+1]}" else ''
            filenames = if ((index = _.indexOf(args, '-j')) >= 0) then [args[index+1]] else filenames = args.slice(_.indexOf(args, '-c')+1)
            for source_name in filenames
              output_name = @minifiedOutputName(output_directory, source_name)
              console.log(output_name)
              @minify(output_name, options, code) if minimize

        spawned = spawn 'uglifyjs',
        original_callback?(0)

      else
        options.callback = eb.Utils.afterWithCollect(coffee_commands_to_run.length, (result) =>
          result |= original_callback(result) if original_callback
          return result
        )
        for coffee_command in coffee_commands_to_run
          @runCoffee(coffee_command.args, _.extend(_.clone(options), {minimize: coffee_command.minimize}))

    # start the execution chain
    if options.clean
      @clean(_.extend(_.clone(options), {callback: run_build_fn}))
    else
      run_build_fn(0)

    # run
    command_queue.run(((code)->console.log("done: #{code}")), options.preview) if owns_queue

  watch: (options={}) ->
    @build(_.extend(options, {watch: true}))

  runTest: (command, args, options={}) ->
    spawned = spawn (if (command is 'phantomjs') then command else "node_modules/.bin/#{command}"), args
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      test_filename = eb.Utils.removeString((if (command is 'phantomjs') then args[1] else args[0]), "file://#{@YAML_dir}/")
      if code is 0
        @timeLog("tests passed #{test_filename}") unless options.silent
      else
        @timeLog("tests failed #{test_filename} .... error code: #{code}")
      code != options.callback?(code)
      return code

  test: (options={}, command_queue) ->
    owns_queue = !!command_queue
    command_queue or= new eb.CommandQueue()
    tests_to_run = []

    # collect tests to run
    for set_name, set of @YAML
      continue if _.contains(RESERVED_SETS, set_name) or not (set.options and set.options.hasOwnProperty('test'))

      set_options = eb.Utils.extractSetOptions(set, 'test', {
        directories: ['.']
        command: 'phantomjs'
        files: ['**/*.html']
      })

      # (console.log("Missing runner for tests: #{set_name}"); continue) unless set_options.runner
      if set_options.runner
        set_options.runner = "#{RUNNERS_ROOT}/#{set_options.runner}" unless path.existsSync(set_options.runner)

      file_groups = eb.Utils.setOptionsFileGroups(set_options, @YAML_dir)
      for file_group in file_groups
        for file in file_group.files
          args = []
          args.push(set_options.runner) if set_options.runner
          if (set_options.command is 'phantomjs') then args.push("file://#{fs.realpathSync(file)}") else args.push(@YAMLRelative(file))
          args.push(set_options.timeout) if set_options.timeout
          tests_to_run.push({command: set_options.command, args: args})

    # execute or preview callback
    original_callback = options.callback; options = _.clone(options); options.callback = null
    run_tests_fn = =>
      if options.preview
        console.log('************test preview**************')
        for test_to_run in tests_to_run
          console.log("#{test_to_run.command} #{test_to_run.args.join(' ')}")
        original_callback?(0)

      else
        @timeLog("************tests started*************")
        options.callback = eb.Utils.afterWithCollect(tests_to_run.length, (result) =>
          if result then @timeLog("************tests failed**************") else @timeLog("************tests succeeded***********")
          result |= original_callback(result) if original_callback
          process.exit(result) unless options.watch
          return result
        )

        for test_to_run in tests_to_run
          @runTest(test_to_run.command, test_to_run.args, options)

    # start the execution chain
    @build(_.extend(_.clone(options), {callback: run_tests_fn, clean: options.clean}))

    # run
    command_queue.run(((code)->console.log("done: #{code}")), options.preview) if owns_queue

  postinstall: (options={}, command_queue) ->
    owns_queue = !!command_queue
    command_queue or= new eb.CommandQueue()

    # collect tests to run
    for set_name, set of @YAML
      continue unless set_name is 'postinstall'

      # set up vendor directory
      if set.options.vendor
        set_options = eb.Utils.extractSetOptions(set, 'vendor', {output: 'vendor'})

        # copy vendor files
        file_groups = eb.Utils.setOptionsFileGroups(set_options, @YAML_dir)
        for file_group in file_groups
          for file in file_group.files
            command_queue.push(new eb.command.CopyFile(this, file, set_options.output))

    # run
    command_queue.run(((code)->console.log("done: #{code}")), options.preview) if owns_queue