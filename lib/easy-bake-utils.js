// Generated by CoffeeScript 1.6.3
(function() {
  var KNOWN_SYSTEM_FILES, eb, existsSync, fs, globber, mb, path, _;

  fs = require('fs');

  path = require('path');

  existsSync = fs.existsSync || path.existsSync;

  _ = require('underscore');

  globber = require('glob-whatev');

  mb = require('module-bundler');

  if (!eb) {
    eb = {};
  }

  if (!this.eb) {
    this.eb = {};
  }

  eb.command = require('./easy-bake-commands');

  eb.utils = this.eb.utils = typeof exports !== 'undefined' ? exports : {};

  KNOWN_SYSTEM_FILES = ['.DS_Store'];

  eb.utils.extractSetOptions = function(set, mode, defaults) {
    var set_options;
    set_options = _.clone(set);
    if (set[mode]) {
      _.extend(set_options, set[mode]);
    }
    if (defaults) {
      _.defaults(set_options, defaults);
    }
    return set_options;
  };

  eb.utils.extractSetCommands = function(set_options, queue, cwd) {
    var command, command_args, command_name, commands, components, _i, _len, _results;
    if (!set_options.commands) {
      return;
    }
    commands = _.isString(set_options.commands) ? [set_options.commands] : set_options.commands;
    _results = [];
    for (_i = 0, _len = commands.length; _i < _len; _i++) {
      command = commands[_i];
      if (_.isObject(command)) {
        command_name = command.command;
        command_args = command.args;
      } else {
        components = command.split(' ');
        command_name = components[0];
        command_args = components.slice(1);
      }
      if (command_name === 'cp') {
        queue.push(new eb.command.Copy(command_args, {
          cwd: cwd
        }));
      } else if (command_name === 'cat') {
        queue.push(new eb.command.Concatenate(command_args, {
          cwd: cwd
        }));
      } else {
        queue.push(new eb.command.RunCommand(command_name, command_args, {
          cwd: cwd
        }));
      }
      _results.push(this);
    }
    return _results;
  };

  eb.utils.argsHasOutput = function(args) {
    var index;
    ((index = args.indexOf('-o')) >= 0) || ((index = args.indexOf('--output')) >= 0) || ((index = args.indexOf('>')) >= 0);
    return index >= 0;
  };

  eb.utils.argsRemoveOutput = function(args) {
    var index;
    ((index = args.indexOf('-o')) >= 0) || ((index = args.indexOf('--output')) >= 0) || ((index = args.indexOf('>')) >= 0);
    if (index < 0) {
      return '';
    }
    return args.splice(index, 2)[1];
  };

  eb.utils.getOptionsFileGroups = function(set_options, cwd, options) {
    var directories, directory, directory_slashed, file_groups, files, found_files, rel_directory, rel_file, search_query, target_files, unpathed_dir, _i, _j, _len, _len1;
    file_groups = [];
    directories = set_options.hasOwnProperty('directories') ? set_options.directories : (set_options.files ? [cwd] : null);
    if (!directories) {
      return file_groups;
    }
    if (_.isString(directories)) {
      directories = [directories];
    }
    files = set_options.hasOwnProperty('files') ? set_options.files : null;
    if (files && _.isString(files)) {
      files = [files];
    }
    for (_i = 0, _len = directories.length; _i < _len; _i++) {
      unpathed_dir = directories[_i];
      directory = mb.resolveSafe(unpathed_dir, {
        cwd: cwd,
        skip_require: true
      });
      if (!existsSync(directory)) {
        console.log("warning: directory is missing " + unpathed_dir);
        continue;
      }
      directory = fs.realpathSync(directory);
      rel_directory = directory.replace("" + cwd + "/", '');
      if (!files) {
        file_groups.push({
          directory: directory,
          files: null
        });
        continue;
      }
      target_files = [];
      for (_j = 0, _len1 = files.length; _j < _len1; _j++) {
        rel_file = files[_j];
        found_files = [];
        search_query = path.join(directory.replace(path.dirname(rel_file), ''), rel_file);
        globber.glob(search_query).forEach(function(target_file) {
          return found_files.push(target_file);
        });
        target_files = target_files.concat(found_files);
        if (found_files.length) {
          continue;
        }
        console.log("warning: file not found " + search_query + ". If you are previewing a test, build your project before previewing.");
      }
      if (!target_files.length) {
        continue;
      }
      directory_slashed = "" + directory + "/";
      file_groups.push({
        directory: directory,
        files: _.map(target_files, function(target_file) {
          return target_file.replace(directory_slashed, '');
        })
      });
    }
    return file_groups;
  };

  eb.utils.dirIsEmpty = function(dir) {
    var child, _i, _len, _ref;
    _ref = fs.readdirSync(dir);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      child = _ref[_i];
      if (!_.contains(KNOWN_SYSTEM_FILES, child)) {
        return false;
      }
    }
    return true;
  };

  eb.utils.rmdirIfEmpty = function(dir) {
    var child, children, e, _i, _len;
    if (!eb.utils.dirIsEmpty(dir)) {
      return;
    }
    children = fs.readdirSync(dir);
    try {
      for (_i = 0, _len = children.length; _i < _len; _i++) {
        child = children[_i];
        fs.unlinkSync(path.join(dir, child));
      }
      return fs.rmdirSync(dir);
    } catch (_error) {
      e = _error;
    }
  };

  eb.utils.relativePath = function(target, cwd) {
    var relative_path;
    if (!cwd || target.search(cwd) !== 0) {
      return target;
    }
    relative_path = target.substr(cwd.length);
    if (relative_path[0] === '/') {
      relative_path = relative_path.substr(1);
    }
    if (relative_path.length) {
      return relative_path;
    } else {
      return '.';
    }
  };

  eb.utils.extractCWD = function(options) {
    if (options == null) {
      options = {};
    }
    if (options.cwd) {
      return {
        cwd: options.cwd
      };
    } else {
      return {};
    }
  };

  eb.utils.resolveArguments = function(args, cwd) {
    return _.map(args, function(arg, index) {
      var is_output, options;
      if ((arg[0] === '-') || (arg[0] === '>') || !_.isString(arg)) {
        return arg;
      }
      is_output = eb.utils.argsHasOutput(args);
      options = is_output ? {
        cwd: cwd,
        skip_require: true
      } : {
        cwd: cwd
      };
      return mb.resolveSafe(arg, options);
    });
  };

  eb.utils.relativeArguments = function(args, cwd) {
    var _this = this;
    return _.map(args, function(arg) {
      if (arg[0] === '-' || !_.isString(arg)) {
        return arg;
      }
      return eb.utils.relativePath(arg, cwd);
    });
  };

  eb.utils.builtName = function(output_name) {
    return output_name.replace(/\.coffee$/, '.js');
  };

  eb.utils.compressedName = function(output_name) {
    return output_name.replace(/\.js$/, '.min.js');
  };

}).call(this);
