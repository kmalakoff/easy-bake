##############################
# Utilities
##############################
class eb.Utils
  @removeString: (string, remove_string) -> return string.replace(remove_string, '')

  @extractSetOptions: (set, mode, defaults) ->
    set_options = _.clone(set)
    if set.options
      _.extend(set_options, set.options['global']) if set.options['global']
      _.extend(set_options, set.options[mode]) if set.options[mode]
      delete set_options['options']
    _.defaults(set_options, defaults) if defaults
    return set_options

  @setOptionsFileGroups: (set_options, YAML_dir) ->
    file_groups = []

    directories = if set_options.hasOwnProperty('directories') then set_options.directories else ['.']
    files = if set_options.hasOwnProperty('files') then set_options.files else ['**/*']
    no_files_ok = if set_options.hasOwnProperty('no_files_ok') then set_options.no_files_ok

    # build the list of files per directory if there are any matching files
    for directory in directories
      if not path.existsSync(directory)
        console.log("warning: directory is missing #{directory}")
        continue
      directory = fs.realpathSync(directory) # resolve the real path

      pathed_files = []
      _.each(files, (rel_file) ->
        count = pathed_files.length
        globber.glob("#{directory}/#{rel_file}").forEach((pathed_file) -> pathed_files.push(pathed_file))
        if count == pathed_files.length
          rel_directory = eb.Utils.removeString(directory, "#{YAML_dir}/")
          console.log("warning: files not found #{directory}/#{rel_file}") if not no_files_ok or not _.contains(no_files_ok, rel_directory)
      )
      continue if not pathed_files.length
      file_groups.push(directory: directory, files:pathed_files)

    return file_groups

  @afterWithCollect: (count, callback) ->
    return (code) ->
      result = code if _.isUndefined(result)
      result != code
      return result if --count>0
      result |= callback(result)
      return result
