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

eb.utils.getOptionsFileGroups = (set_options, root_dir, options) ->
  file_groups = []

  directories = if set_options.hasOwnProperty('directories') then set_options.directories else ['.']
  files = if set_options.hasOwnProperty('files') then set_options.files else ['**/*']
  no_files_ok = if set_options.hasOwnProperty('no_files_ok') then set_options.no_files_ok

  # build the list of files per directory if there are any matching files
  for directory in directories
    unless path.existsSync(directory)
      console.log("warning: directory is missing #{directory}") # unless options.preview
      continue

    directory = fs.realpathSync(directory) # resolve the real path

    pathed_files = []
    _.each(files, (rel_file) ->
      count = pathed_files.length
      globber.glob("#{directory}/#{rel_file}").forEach((pathed_file) -> pathed_files.push(pathed_file))
      if count == pathed_files.length
        rel_directory = directory.replace("#{root_dir}/", '')
        if not no_files_ok or not _.contains(no_files_ok, rel_directory)
          console.log("warning: file not found #{directory}/#{rel_file}. If you are previewing a test, build your project before previewing.") # unless options.preview
    )
    continue if not pathed_files.length
    file_groups.push(directory: directory, files:pathed_files)

  return file_groups

eb.utils.relativePath = (target, root_dir) ->
  relative_target = target.replace(root_dir, '')
  return if not relative_target.length then '.' else (if relative_target[0]=='/' then relative_target.substr(1) else relative_target)

eb.utils.resolvePath = (target, options) ->
  if (target.match(/^\.\//))
    stripped_target = target.substr(2)
    return if target == './' then options.cwd else "#{options.cwd}/#{stripped_target}"
  else if (target == '.')
    stripped_target = target.substr(1)
    return "#{options.cwd}/#{stripped_target}"
  else if (target[0]=='/')
    return target
  else if (target.match(/^\{root\}/))
    stripped_target = target.substr(6)
    return if target == '{root}' then options.root_dir else "#{options.root_dir}/#{stripped_target}"
  else
    return "#{options.root_dir}/#{target.replace(options.root_dir, '')}"

eb.utils.builtName = (output_name) -> return output_name.replace(/\.coffee$/, '.js')
eb.utils.compressedName = (output_name) -> return output_name.replace(/\.js$/, '.min.js')