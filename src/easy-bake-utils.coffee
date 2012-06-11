fs = require 'fs'
path = require 'path'
_ = require 'underscore'
globber = require 'glob-whatev'

eb = {} unless !!eb; @eb = {} unless !!@eb

# export or create eb namespace
eb.utils = @eb.utils = if (typeof(exports) != 'undefined') then exports else {}

##############################
# Utilities
##############################
eb.utils.extractSetOptions = (set, mode, defaults) ->
  set_options = _.clone(set)
  if set.options
    _.extend(set_options, set.options['global']) if set.options['global']
    _.extend(set_options, set.options[mode]) if set.options[mode]
    delete set_options['options']
  _.defaults(set_options, defaults) if defaults
  return set_options

eb.utils.getOptionsFileGroups = (set_options, cwd, options) ->
  file_groups = []
  directories = if set_options.hasOwnProperty('directories') then set_options.directories else (if set_options.files then [cwd] else null)
  return file_groups unless directories # nothing to search

  files = if set_options.hasOwnProperty('files') then set_options.files else null
  no_files_ok = if set_options.hasOwnProperty('no_files_ok') then set_options.no_files_ok

  # build the list of files per directory if there are any matching files
  for unpathed_dir in directories
    directory = eb.utils.resolvePath(unpathed_dir, cwd)
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
  return _.map(args, (arg) ->
    return arg if arg[0] is '-' or not _.isString(arg)  # skip options and non-string arguments
    return eb.utils.resolvePath(arg, cwd)
  )

eb.utils.relativeArguments = (args, cwd) ->
  return _.map(args, (arg) => return eb.utils.relativePath(arg, cwd))

eb.utils.resolvePath = (target, cwd) ->
  target = eb.utils.safeRequireResolve(target, cwd)
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