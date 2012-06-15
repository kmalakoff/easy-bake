fs = require 'fs'
path = require 'path'
_ = require 'underscore'
globber = require 'glob-whatev'

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
  if set.modes
    _.extend(set_options, set.modes[mode]) if set.modes[mode]
    delete set_options['modes']
  _.defaults(set_options, defaults) if defaults
  return set_options

eb.utils.extractSetCommands = (set_options, queue, cwd) ->
  return unless set_options.commands

  for command in set_options.commands
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
    else
      queue.push(new eb.command.RunCommand(command_name, command_args, {cwd: cwd}))

eb.utils.extractSetBundles = (set_options, queue, cwd) ->
  return unless set_options.bundles

  for bundle_name, entries of set_options.bundles
    queue.push(new eb.command.Bundle(bundle_name, entries, {cwd: cwd}))

eb.utils.getOptionsFileGroups = (set_options, cwd, options) ->
  file_groups = []
  directories = if set_options.hasOwnProperty('directories') then set_options.directories else (if set_options.files then [cwd] else null)
  return file_groups unless directories # nothing to search

  files = if set_options.hasOwnProperty('files') then set_options.files else null
  no_files_ok = if set_options.hasOwnProperty('no_files_ok') then set_options.no_files_ok

  # build the list of files per directory if there are any matching files
  for unpathed_dir in directories
    directory = eb.utils.resolvePath(unpathed_dir, cwd, true)
    unless path.existsSync(directory)
      console.log("warning: directory is missing #{directory}") # unless options.preview
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
      if not no_files_ok or not _.contains(no_files_ok, rel_directory)
        console.log("warning: file not found #{search_query}. If you are previewing a test, build your project before previewing.") # unless options.preview

    # nothing found
    continue if not target_files.length

    # add all the files with relative paths to the directory
    directory_slashed = "#{directory}/"
    file_groups.push({directory: directory, files: _.map(target_files, (target_file) -> return target_file.replace(directory_slashed, ''))})

  return file_groups

eb.utils.dirIsEmpty = (dir) ->
  (return false if _.contains(KNOWN_SYSTEM_FILES, child)) for child in fs.readdirSync(dir)
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

eb.utils.runInExecDir = (fn, cwd) ->
  if cwd
    original_dirname = fs.realpathSync('.')
    process.chdir(cwd)
    result = fn()
    process.chdir(original_dirname)
  else
    return fn()

eb.utils.safePathNormalize = (target, cwd) ->
  return target if (target.substr(0, process.env.HOME.length) is process.env.HOME)      # already resolved
  return target if cwd and (target.substr(0, cwd.length) is cwd)                        # already resolved

  normalized_target = target
  eb.utils.runInExecDir((->
    try (normalized_target = path.normalize(target)) catch e
  ), cwd)
  return normalized_target

eb.utils.safeRequireResolve = (target, cwd) ->
  return target if (target.substr(0, process.env.HOME.length) is process.env.HOME)      # already resolved
  return target if cwd and (target.substr(0, cwd.length) is cwd)                        # already resolved

  resolved_target = target
  eb.utils.runInExecDir((->
    try (resolved_target = require.resolve(target)) catch e
  ), cwd)
  return resolved_target

eb.utils.resolveArguments = (args, cwd) ->
  return _.map(args, (arg, index) ->
    return arg if arg[0] is '-' or not _.isString(arg)  # skip options and non-string arguments
    # don't use require to reolve the output directory
    return if (args[index-1] is '-o' or args[index-1] is '--output') then eb.utils.resolvePath(arg, cwd, true) else eb.utils.resolvePath(arg, cwd)
  )

eb.utils.relativeArguments = (args, cwd) ->
  return _.map(args, (arg) =>
    return arg if arg[0] is '-' or not _.isString(arg)  # skip options and non-string arguments
    return eb.utils.relativePath(arg, cwd)
  )

eb.utils.resolvePath = (target, cwd, skip_require) ->
  is_file = target.search(/^file:\/\//) >= 0
  target = target.replace(/^file:\/\//, '') if is_file
  target = eb.utils.safeRequireResolve(target, cwd) unless (skip_require or is_file)
  return target if (target.substr(0, process.env.HOME.length) is process.env.HOME)      # already resolved
  return target if cwd and (target.substr(0, cwd.length) is cwd)                        # already resolved

  if target[0] is '.'
    # check that next characters are . or /, but not characters indicating a hidden directory
    (next_char = char; break if char isnt '.' and char isnt '/') for char in target
    if next_char is '.' or '/'
      raw_target = path.join((if cwd then cwd else cwd), target)
    else
      raw_target = path.join(cwd, target)
  else if target[0] is '~'
    raw_target = target.replace(/^~/, process.env.HOME)
  else if cwd
    raw_target = path.join(cwd, target)
  else
    raw_target = target
  return path.normalize(raw_target)

eb.utils.builtName = (output_name) -> return output_name.replace(/\.coffee$/, '.js')
eb.utils.compressedName = (output_name) -> return output_name.replace(/\.js$/, '.min.js')