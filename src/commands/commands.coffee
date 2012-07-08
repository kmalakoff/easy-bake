{spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'
_ = require 'underscore'
wrench = require 'wrench'
uglifyjs = require 'uglify-js'
globber = require 'glob-whatev'

##############################
# Commands
##############################
class eb.command.RunQueue
  constructor: (@run_queue, @name) -> @run_queue = new eb.command.Queue() unless @run_queue
  queue: -> return @run_queue

  run: (options={}, callback) ->
    # display
    console.log("running queue: #{@name}") if options.verbose

    # execute
    @run_queue.run(options, (queue) -> callback?(queue.errorCount(), @))

class eb.command.RunCommand
  constructor: (@command, @args=[], @command_options={}) ->

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("#{if @command_options.cwd then (@command_options.cwd + ': ') else ''}#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn @command, @args, eb.utils.extractCWD(@command_options)
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      @exit_code = code
      if code is 0
        timeLog("command succeeded '#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}'") unless options.silent
      else
        timeLog("command failed '#{@command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}' (exit code: #{code})")
      callback?(code, @)

class eb.command.Remove
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  target: -> return @args[@args.length-1]

  run: (options={}, callback) ->
    (callback?(0, @); return) unless path.existsSync(@target()) # nothing to delete

    # display
    if options.preview or options.verbose
      console.log("rm #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    parent_dir = path.dirname(@target())
    if @args[0]=='-r' then wrench.rmdirSyncRecursive(@target()) else fs.unlinkSync(@target())
    timeLog("removed #{eb.utils.relativePath(@target(), @command_options.cwd)}") unless options.silent

    # remove the parent directory if it is empty
    eb.utils.rmdirIfEmpty(parent_dir)

    callback?(0, @)

class eb.command.Copy
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  source: -> return @args[@args.length-2]
  target: -> return @args[@args.length-1]

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("cp #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # make the destination directory
    try
      target_dir = path.dirname(@target())
      wrench.mkdirSyncRecursive(target_dir, 0o0777) unless path.existsSync(target_dir)
    catch e
      throw e if e.code isnt 'EEXIST'

    # do the copy
    if @args[0]=='-r' then wrench.copyDirSyncRecursive(@source(), @target(), {preserve: true}) else fs.writeFileSync(@target(), fs.readFileSync(@source(), 'utf8'), 'utf8')
    timeLog("copied #{eb.utils.relativePath(@target(), @command_options.cwd)}") unless options.silent
    callback?(0, @)

class eb.command.Bundle
  constructor: (@bundle_name, @entries, @command_options={}) ->
  target: -> return @bundle_name

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("bundle #{@bundle_name} #{JSON.stringify(@entries)}")
      (callback?(0, @); return) if options.preview

    # make the destination directory
    try
      target_dir = path.dirname(@target())
      wrench.mkdirSyncRecursive(target_dir, 0o0777) unless path.existsSync(target_dir)
    catch e
      throw e if e.code isnt 'EEXIST'

    # start the bundle
    bundle = """
      (function() {
        // a require implementation doesn't already exist
        if (!this.require) {
          var root = this;
          var modules = {};
          this.require = function(module_name) {
            if (!modules.hasOwnProperty(module_name)) throw "required module missing: " + module_name;
            if (!modules[module_name].exports) {
              modules[module_name].exports = {};
              modules[module_name].loader.call(root, modules[module_name].exports, this.require, modules[module_name]);
            }
            return modules[module_name].exports;
          };
          this.require.define = function(obj) {
            for (var module_name in obj) {
              modules[module_name] = {loader: obj[module_name]};
            };
          };
          this.require.resolve = function(module_name) {
            return !!modules[module_name] ? module_name : null;
          };
        }\n
      """
    for module_name, entry of @entries
      # publish symbols
      if module_name is '_publish'
        for module_name, symbol of entry
          bundle += "if (!this['#{symbol}']) {this['#{symbol}'] = this.require('#{module_name}');}\n"

      # publish symbols
      else if module_name is '_load'
        entry = [entry] if _.isString(entry)
        for module_name in entry
          bundle += "this.require('#{module_name}');\n"

      # embed a file
      else
        pathed_file = eb.utils.resolvePath(entry, @command_options.cwd)
        try
          file_contents = fs.readFileSync(pathed_file, 'utf8')
        catch e
          console.log "couldn't bundle #{entry}. Does it exist?"
        bundle += """
          this.require.define({
            '#{module_name}': function(exports, require, module) {\n#{file_contents}\n}
          });\n
          """

    bundle += "})(this);"

    fs.writeFileSync(@target(), bundle, 'utf8')
    timeLog("bundled #{eb.utils.relativePath(@target(), @command_options.cwd)}")
    callback?(0, @)

class eb.command.Coffee
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  targetDirectory: -> return eb.utils.safePathNormalize(if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else '')
  pathedTargets: ->
    pathed_targets = []
    output_directory = @targetDirectory()
    output_names = if ((index = _.indexOf(@args, '-j')) >= 0) then [@args[index+1]] else @args.slice(_.indexOf(@args, '-c')+1)
    for source_name in output_names
      # files being compiled
      if source_name.match(/\.js$/) or source_name.match(/\.coffee$/)
        pathed_targets.push(eb.utils.safePathNormalize("#{output_directory}/#{eb.utils.builtName(path.basename(source_name))}"))

      # directories being compiled
      else
        pathed_source_files = []
        globber.glob("#{source_name}/**/*.coffee").forEach((pathed_file) -> pathed_source_files.push(pathed_file.replace(source_name, '')))
        for pathed_source_file in pathed_source_files
          pathed_targets.push(eb.utils.safePathNormalize("#{output_directory}#{eb.utils.builtName(pathed_source_file)}"))
    return pathed_targets

  isCompressed: -> return @command_options.compress
  runsTests: -> return @command_options.test

  run: (options={}, callback) ->
    # display
    if options.preview or options.verbose
      console.log("coffee #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    spawned = spawn 'coffee', @args, eb.utils.extractCWD(@command_options)
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    notify = (code) =>
      output_directory = @targetDirectory()
      output_names = @pathedTargets()

      if @isCompressed() or (@runsTests() and @already_run)
        post_build_queue = new eb.command.Queue()

      for source_name in output_names
        build_directory = eb.utils.resolvePath(output_directory, path.dirname(source_name))
        pathed_build_name = "#{build_directory}/#{eb.utils.builtName(path.basename(source_name))}"

        if code is 0
          timeLog("compiled #{eb.utils.relativePath(pathed_build_name, @targetDirectory())}") unless options.silent
        else
          timeLog("failed to compile #{eb.utils.relativePath(pathed_build_name, @targetDirectory())} .... error code: #{code}")

        # add to the compress queue
        if @isCompressed()
          post_build_queue.push(new eb.command.UglifyJS(['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], {cwd: @targetDirectory()}))

      # add the test command
      if @runsTests() and @already_run
        post_build_queue.push(new eb.command.RunCommand('cake', ['test'], {cwd: @command_options.cwd}))
      @already_run = true

      # run the post build queue
      if post_build_queue then post_build_queue.run(options, => callback?(code, @)) else callback?(0, @)

    # watch vs build callbacks are slightly different
    if options.watch then spawned.stdout.on('data', (data) -> notify(0)) else spawned.on('exit', (code) -> notify(code))

class eb.command.UglifyJS
  constructor: (args=[], @command_options={}) -> @args = eb.utils.resolveArguments(args, @command_options.cwd)
  outputName: -> return if ((index = _.indexOf(@args, '-o')) >= 0) then "#{@args[index+1]}" else ''

  run: (options={}, callback) ->
    scoped_command = 'node_modules/.bin/uglifyjs'

    # display
    if options.preview or options.verbose
      console.log("#{scoped_command} #{eb.utils.relativeArguments(@args, @command_options.cwd).join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    try
      src = fs.readFileSync(@args[2], 'utf8')
      header = if ((header_index = src.indexOf('*/'))>0) then src.substr(0, header_index+2) else ''
      ast = uglifyjs.parser.parse(src)
      ast = uglifyjs.uglify.ast_mangle(ast)
      ast = uglifyjs.uglify.ast_squeeze(ast)
      src = header + uglifyjs.uglify.gen_code(ast) + ';'
      fs.writeFileSync(@args[1], src, 'utf8')
      timeLog("compressed #{eb.utils.relativePath(@outputName(), @command_options.cwd)}") unless options.silent
      callback?(0, @)
    catch e
      timeLog("failed to minify #{eb.utils.relativePath(@outputName(), @command_options.cwd)} .... error code: #{e.code}")
      callback?(e.code, @)

class eb.command.RunTest
  constructor: (@command, @args=[], @command_options={}) ->
  usingPhantomJS: -> return (@command is 'phantomjs')
  fileName: -> return if @usingPhantomJS() then @args[1] else @args[0]
  exitCode: -> return @exit_code

  run: (options={}, callback) ->
    # command scoping is required because the test suite may not be installed globally
    scoped_command = if @usingPhantomJS() then @command else path.join('node_modules/.bin', @command)
    scoped_args = _.clone(@args)
    if @usingPhantomJS()
      scoped_args[1] = "file://#{eb.utils.resolvePath(@args[1], @command_options.cwd)}" if @args[1].search('file://') isnt 0
    else
      scoped_args = eb.utils.relativeArguments(scoped_args, @command_options.cwd)

    # display
    if options.preview or options.verbose
      console.log("#{scoped_command} #{scoped_args.join(' ')}")
      (callback?(0, @); return) if options.preview

    # execute
    spawned = spawn scoped_command, scoped_args
    spawned.stderr.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.stdout.on 'data', (data) ->
      process.stderr.write data.toString()
    spawned.on 'exit', (code) =>
      @exit_code = code
      if code is 0
        timeLog("tests passed #{eb.utils.relativePath(@fileName(), @command_options.cwd)}") unless options.silent
      else
        timeLog("tests failed #{eb.utils.relativePath(@fileName(), @command_options.cwd)} (exit code: #{code})")
      callback?(code, @)

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