fs = require 'fs'
path = require 'path'
existsSync = fs.existsSync || path.existsSync
_ = require 'underscore'
globber = require 'glob-whatev'
mb = require 'module-bundler'

eb = {} unless !!eb; @eb = {} unless !!@eb
eb.command = require './easy-bake-commands'

# export or create eb namespace
eb.utils = @eb.utils = if (typeof(exports) != 'undefined') then exports else {}

KNOWN_SYSTEM_FILES = ['.DS_Store']

##############################
# Utilities
##############################
eb.utils.extractSetOptions = (set, mode, defaults) ->
  set_options = _.clone(set)
  _.extend(set_options, set[mode]) if set[mode]
  _.defaults(set_options, defaults) if defaults
  return set_options

eb.utils.extractSetCommands = (set_options, queue, cwd) ->
  return unless set_options.commands
  commands = if _.isString(set_options.commands) then [set_options.commands] else set_options.commands

  for command in commands
    # the command is named
    if _.isObject(command)
      command_name = command.command
      command_args = command.args
    else
      components = command.split(' ')
      command_name = components[0]
      command_args = components.slice(1)

    # add the command
    if command_name is 'cp'
      queue.push(new eb.command.Copy(command_args, {cwd: cwd}))

    else if command_name is 'cat'
      queue.push(new eb.command.Concatenate(command_args, {cwd: cwd}))

    # default
    else
      queue.push(new eb.command.RunCommand(command_name, command_args, {cwd: cwd}))

eb.utils.getOptionsFileGroups = (set_options, cwd, options) ->
  file_groups = []
  directories = if set_options.hasOwnProperty('directories') then set_options.directories else (if set_options.files then [cwd] else null)
  return file_groups unless directories # nothing to search

  directories  = [directories] if _.isString(directories) # convert optional directory array
  files = if set_options.hasOwnProperty('files') then set_options.files else null
  files = [files] if files and _.isString(files) # convert optional files array

  # build the list of files per directory if there are any matching files
  for unpathed_dir in directories
    directory = mb.resolveSafe(unpathed_dir, {cwd: cwd, skip_require: true})
    unless existsSync(directory)
      console.log("warning: directory is missing #{unpathed_dir}") # unless options.preview
      continue

    directory = fs.realpathSync(directory) # resolve the real target
    rel_directory = directory.replace("#{cwd}/", '')

    # directories only
    (file_groups.push({directory: directory, files:null}); continue) if not files

    target_files = []
    for rel_file in files
      found_files = []
      search_query = path.join(directory.replace(path.dirname(rel_file), ''), rel_file)
      globber.glob(search_query).forEach((target_file) -> found_files.push(target_file))

      target_files = target_files.concat(found_files)  # add these found files
      continue if found_files.length # something found

      console.log("warning: file not found #{search_query}. If you are previewing a test, build your project before previewing.") # unless options.preview

    # nothing found
    continue if not target_files.length

    # add all the files with relative paths to the directory
    directory_slashed = "#{directory}/"
    file_groups.push({directory: directory, files: _.map(target_files, (target_file) -> return target_file.replace(directory_slashed, ''))})

  return file_groups

eb.utils.dirIsEmpty = (dir) ->
  for child in fs.readdirSync(dir)
    return false unless _.contains(KNOWN_SYSTEM_FILES, child)
  return true

eb.utils.rmdirIfEmpty = (dir) ->
  return unless eb.utils.dirIsEmpty(dir)

  children = fs.readdirSync(dir)
  try
    fs.unlinkSync(path.join(dir, child)) for child in children
    fs.rmdirSync(dir)
  catch e

eb.utils.relativePath = (target, cwd) ->
  return target if not cwd or target.search(cwd) isnt 0
  relative_path = target.substr(cwd.length)
  relative_path = relative_path.substr(1) if relative_path[0] is '/'
  return if relative_path.length then relative_path else '.'

eb.utils.extractCWD = (options={}) ->
  return if options.cwd then {cwd: options.cwd} else {}

eb.utils.resolveArguments = (args, cwd) ->
  return _.map(args, (arg, index) ->
    return arg if arg[0] is '-' or not _.isString(arg)  # skip options and non-string arguments
    # don't use require to reolve the output directory
    options = if (args[index-1] is '-o' or args[index-1] is '--output') then {cwd: cwd, skip_require: true} else {cwd: cwd}
    return mb.resolveSafe(arg, options)
  )

eb.utils.relativeArguments = (args, cwd) ->
  return _.map(args, (arg) =>
    return arg if arg[0] is '-' or not _.isString(arg)  # skip options and non-string arguments
    return eb.utils.relativePath(arg, cwd)
  )

eb.utils.builtName = (output_name) -> return output_name.replace(/\.coffee$/, '.js')
eb.utils.compressedName = (output_name) -> return output_name.replace(/\.js$/, '.min.js')