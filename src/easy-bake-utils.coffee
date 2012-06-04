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

eb.utils.getOptionsFileGroups = (set_options, root_dir) ->
  file_groups = []

  directories = if set_options.hasOwnProperty('directories') then set_options.directories else ['.']
  files = if set_options.hasOwnProperty('files') then set_options.files else ['**/*']
  no_files_ok = if set_options.hasOwnProperty('no_files_ok') then set_options.no_files_ok

  # build the list of files per directory if there are any matching files
  for directory in directories
    (console.log("warning: directory is missing #{directory}"); continue) if not path.existsSync(directory)
      
    directory = fs.realpathSync(directory) # resolve the real path

    pathed_files = []
    _.each(files, (rel_file) ->
      count = pathed_files.length
      globber.glob("#{directory}/#{rel_file}").forEach((pathed_file) -> pathed_files.push(pathed_file))
      if count == pathed_files.length
        rel_directory = directory.replace("#{root_dir}/", '')
        console.log("warning: files not found #{directory}/#{rel_file}") if not no_files_ok or not _.contains(no_files_ok, rel_directory)
    )
    continue if not pathed_files.length
    file_groups.push(directory: directory, files:pathed_files)

  return file_groups

eb.utils.resolvePath = (directory, current_root, root_dir) ->
  if (directory.match(/^\.\//))
    stripped_directory = directory.substr(2)
    return if directory == './' then current_root else "#{current_root}/#{stripped_directory}"
  else if (directory == '.')
    stripped_directory = directory.substr(1)
    return "#{current_root}/#{stripped_directory}"
  else if (directory[0]=='/')
    return directory
  else if (directory.match(/^\{root\}/))
    stripped_directory = directory.substr(6)
    return if directory == '{root}' then root_dir else "#{root_dir}/#{stripped_directory}"
  else
    return "#{root_dir}/#{directory}"

eb.utils.builtName = (output_name) -> return output_name.replace(/\.coffee$/, ".js")
eb.utils.compressedName = (output_name) -> return output_name.replace(/\.js$/, ".min.js")