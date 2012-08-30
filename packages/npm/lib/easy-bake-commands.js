// Generated by CoffeeScript 1.3.3
(function() {
  var MAX_MESSAGE_LENGTH, eb, et, existsSync, fs, globber, mb, path, spawn, timeLog, uglifyjs, wrench, _;

  fs = require('fs');

  path = require('path');

  existsSync = fs.existsSync || path.existsSync;

  MAX_MESSAGE_LENGTH = 128;

  timeLog = function(message) {
    return console.log("" + ((new Date).toLocaleTimeString()) + " - " + message);
  };

  String.prototype.startsWith = function(start) {
    return this.indexOf(start) === 0;
  };

  if (!eb) {
    eb = {};
  }

  if (!this.eb) {
    this.eb = {};
  }

  eb.utils = require('./easy-bake-utils');

  eb.command = this.eb.command = typeof exports !== 'undefined' ? exports : {};

  eb.command.Queue = (function() {

    function Queue() {
      this._commands = [];
      this.is_running = false;
      this.errors = [];
    }

    Queue.prototype.commands = function() {
      return this._commands;
    };

    Queue.prototype.errorCount = function() {
      return this.errors.length;
    };

    Queue.prototype.push = function(command) {
      return this._commands.push(command);
    };

    Queue.prototype.run = function(run_options, callback) {
      var current_index, done, next,
        _this = this;
      if (this.is_running) {
        throw 'queue is already running';
      }
      this.is_running = true;
      this.errors = [];
      current_index = 0;
      done = function() {
        _this.is_running = false;
        return typeof callback === "function" ? callback(_this) : void 0;
      };
      next = function(code, task) {
        if ((code !== 0) && (arguments.length !== 0)) {
          _this.errors.push({
            code: code,
            task: task
          });
        }
        if (++current_index < _this._commands.length) {
          return _this._commands[current_index].run(run_options, next, _this);
        } else {
          return done();
        }
      };
      if (this._commands.length) {
        return this._commands[current_index].run(run_options, next, this);
      } else {
        return done();
      }
    };

    return Queue;

  })();

  eb.command.RunQueue = (function() {

    function RunQueue(run_queue, name) {
      this.run_queue = run_queue;
      this.name = name;
      if (!this.run_queue) {
        this.run_queue = new eb.command.Queue();
      }
    }

    RunQueue.prototype.queue = function() {
      return this.run_queue;
    };

    RunQueue.prototype.run = function(options, callback) {
      if (options == null) {
        options = {};
      }
      if (options.verbose) {
        console.log("running queue: " + this.name);
      }
      return this.run_queue.run(options, function(queue) {
        return typeof callback === "function" ? callback(queue.errorCount(), this) : void 0;
      });
    };

    return RunQueue;

  })();

  spawn = require('child_process').spawn;

  _ = require('underscore');

  wrench = require('wrench');

  uglifyjs = require('uglify-js');

  globber = require('glob-whatev');

  mb = require('module-bundler');

  et = require('elementtree');

  eb.command.RunCommand = (function() {

    function RunCommand(command, args, command_options) {
      this.command = command;
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunCommand.prototype.run = function(options, callback) {
      var spawned,
        _this = this;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        console.log("" + (this.command_options.cwd ? this.command_options.cwd + ': ' : '') + this.command + " " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      spawned = spawn(this.command, this.args, eb.utils.extractCWD(this.command_options));
      spawned.stderr.on('data', function(data) {
        var message;
        message = data.toString();
        if (message.search('is now called') >= 0) {
          return;
        }
        process.stderr.write(message);
        return typeof callback === "function" ? callback(1, this) : void 0;
      });
      spawned.stdout.on('data', function(data) {
        return process.stderr.write(data.toString());
      });
      return spawned.on('exit', function(code) {
        _this.exit_code = code;
        if (code === 0) {
          if (!options.silent) {
            timeLog("command succeeded '" + _this.command + "'");
          }
        } else {
          timeLog("command failed '" + _this.command + " " + (eb.utils.relativeArguments(_this.args, _this.command_options.cwd).join(' ')) + "' (exit code: " + code + ")");
        }
        return typeof callback === "function" ? callback(code, _this) : void 0;
      });
    };

    return RunCommand;

  })();

  eb.command.Remove = (function() {

    function Remove(args, command_options) {
      if (args == null) {
        args = [];
      }
      this.command_options = command_options != null ? command_options : {};
      this.args = eb.utils.resolveArguments(args, this.command_options.cwd);
    }

    Remove.prototype.target = function() {
      return this.args[this.args.length - 1];
    };

    Remove.prototype.run = function(options, callback) {
      var parent_dir;
      if (options == null) {
        options = {};
      }
      if (!existsSync(this.target())) {
        if (typeof callback === "function") {
          callback(0, this);
        }
        return;
      }
      if (options.preview || options.verbose) {
        console.log("rm " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      parent_dir = path.dirname(this.target());
      if (this.args[0] === '-r') {
        wrench.rmdirSyncRecursive(this.target());
      } else {
        fs.unlinkSync(this.target());
      }
      if (!options.silent) {
        timeLog("removed " + (eb.utils.relativePath(this.target(), this.command_options.cwd)));
      }
      eb.utils.rmdirIfEmpty(parent_dir);
      return typeof callback === "function" ? callback(0, this) : void 0;
    };

    return Remove;

  })();

  eb.command.Copy = (function() {

    function Copy(args, command_options) {
      if (args == null) {
        args = [];
      }
      this.command_options = command_options != null ? command_options : {};
      this.args = eb.utils.resolveArguments(args, this.command_options.cwd);
    }

    Copy.prototype.isRecursive = function() {
      var index;
      return (index = _.indexOf(this.args, '-r')) >= 0;
    };

    Copy.prototype.isVersioned = function() {
      var index;
      return (index = _.indexOf(this.args, '-v')) >= 0;
    };

    Copy.prototype.source = function() {
      return this.args[this.args.length - 2];
    };

    Copy.prototype.target = function() {
      var package_desc, package_desc_path, source_dir, target;
      target = this.args[this.args.length - 1];
      if (this.isVersioned()) {
        source_dir = path.dirname(this.source());
        package_desc_path = path.join(source_dir, 'package.json');
        if (!existsSync(package_desc_path)) {
          console.log("no package.json found for publish_npm: " + (package_desc_path.replace(this.config_dir, '')));
          if (typeof callback === "function") {
            callback(1);
          }
          return;
        }
        package_desc = require(package_desc_path);
        if (target.endsWith('.min.js')) {
          target = target.replace(/.min.js$/, "-" + package_desc.version + ".min.js");
        } else if (target.endsWith('-min.js')) {
          target = target.replace(/-min.js$/, "-" + package_desc.version + "-min.js");
        } else {
          target = target.replace(/.js$/, "-" + package_desc.version + ".js");
        }
      }
      return target;
    };

    Copy.prototype.run = function(options, callback) {
      var source, target, target_dir;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        console.log("cp " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      source = this.source();
      if (!existsSync(source)) {
        console.log("command failed: cp " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')) + ". Source Source '" + source + "' doesn't exist");
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      target = this.target();
      try {
        target_dir = path.dirname(target);
        if (!existsSync(target_dir)) {
          wrench.mkdirSyncRecursive(target_dir, 0x1ff);
        }
      } catch (e) {
        if (e.code !== 'EEXIST') {
          throw e;
        }
      }
      if (this.isRecursive()) {
        wrench.copyDirSyncRecursive(source, target, {
          preserve: true
        });
      } else {
        fs.writeFileSync(target, fs.readFileSync(source, 'utf8'), 'utf8');
      }
      if (!options.silent) {
        timeLog("copied " + (eb.utils.relativePath(target, this.command_options.cwd)));
      }
      return typeof callback === "function" ? callback(0, this) : void 0;
    };

    Copy.prototype.createUndoCommand = function() {
      if (this.args[0] === '-r') {
        return new eb.command.Remove(['-r', this.target()], this.command_options);
      } else {
        return new eb.command.Remove([this.target()], this.command_options);
      }
    };

    return Copy;

  })();

  eb.command.Concatenate = (function() {

    function Concatenate(args, command_options) {
      if (args == null) {
        args = [];
      }
      this.command_options = command_options != null ? command_options : {};
      this.args = eb.utils.resolveArguments(args, this.command_options.cwd);
    }

    Concatenate.prototype.sourceFiles = function() {
      var source_files;
      eb.utils.argsRemoveOutput(source_files = _.clone(this.args));
      return source_files;
    };

    Concatenate.prototype.target = function() {
      return eb.utils.argsRemoveOutput(_.clone(this.args));
    };

    Concatenate.prototype.run = function(options, callback) {
      var error_count, source, source_files, target, target_dir, _i, _len;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        console.log("cat " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      source_files = this.sourceFiles();
      target = this.target();
      try {
        target_dir = path.dirname(target);
        if (!existsSync(target_dir)) {
          wrench.mkdirSyncRecursive(target_dir, 0x1ff);
        }
      } catch (e) {
        if (e.code !== 'EEXIST') {
          throw e;
        }
      }
      if (existsSync(target)) {
        fs.unlinkSync(target);
      }
      error_count = 0;
      for (_i = 0, _len = source_files.length; _i < _len; _i++) {
        source = source_files[_i];
        if (existsSync(source)) {
          fs.appendFileSync(target, fs.readFileSync(source, 'utf8'), 'utf8');
        } else {
          console.log("command failed: cat " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')) + ". Source '" + source + "' doesn't exist");
          error_count++;
        }
      }
      if (error_count) {
        timeLog("failed to concatenat " + (eb.utils.relativePath(target, this.command_options.cwd)));
      } else {
        if (!options.silent) {
          timeLog("concatenated " + (eb.utils.relativePath(target, this.command_options.cwd)));
        }
      }
      return typeof callback === "function" ? callback(error_count, this) : void 0;
    };

    Concatenate.prototype.createUndoCommand = function() {
      if (this.args[0] === '-r') {
        return new eb.command.Remove(['-r', this.target()], this.command_options);
      } else {
        return new eb.command.Remove([this.target()], this.command_options);
      }
    };

    return Concatenate;

  })();

  eb.command.Coffee = (function() {

    function Coffee(args, command_options) {
      if (args == null) {
        args = [];
      }
      this.command_options = command_options != null ? command_options : {};
      this.args = eb.utils.resolveArguments(args, this.command_options.cwd);
    }

    Coffee.prototype.sourceFiles = function() {
      var index, source_files;
      source_files = _.clone(this.args);
      if ((index = _.indexOf(source_files, '-w')) >= 0) {
        source_files.splice(index, 1);
      }
      eb.utils.argsRemoveOutput(source_files);
      if ((index = _.indexOf(source_files, '-j')) >= 0) {
        source_files.splice(index, 2);
      }
      if ((index = _.indexOf(source_files, '-c')) >= 0) {
        source_files.splice(index, 1);
      }
      return source_files;
    };

    Coffee.prototype.targetDirectory = function() {
      return mb.pathNormalizeSafe(eb.utils.argsRemoveOutput(_.clone(this.args)));
    };

    Coffee.prototype.pathedTargets = function() {
      var index, output_directory, output_names, pathed_source_file, pathed_source_files, pathed_targets, source_name, _i, _j, _len, _len1;
      pathed_targets = [];
      output_directory = this.targetDirectory();
      output_names = (index = _.indexOf(this.args, '-j')) >= 0 ? [this.args[index + 1]] : this.args.slice(_.indexOf(this.args, '-c') + 1);
      for (_i = 0, _len = output_names.length; _i < _len; _i++) {
        source_name = output_names[_i];
        if (source_name.match(/\.js$/) || source_name.match(/\.coffee$/)) {
          pathed_targets.push(mb.pathNormalizeSafe("" + output_directory + "/" + (eb.utils.builtName(path.basename(source_name)))));
        } else {
          pathed_source_files = [];
          globber.glob("" + source_name + "/**/*.coffee").forEach(function(pathed_file) {
            return pathed_source_files.push(pathed_file.replace(source_name, ''));
          });
          for (_j = 0, _len1 = pathed_source_files.length; _j < _len1; _j++) {
            pathed_source_file = pathed_source_files[_j];
            pathed_targets.push(mb.pathNormalizeSafe("" + output_directory + (eb.utils.builtName(pathed_source_file))));
          }
        }
      }
      return pathed_targets;
    };

    Coffee.prototype.isCompressed = function() {
      return this.command_options.compress;
    };

    Coffee.prototype.runsTests = function() {
      return this.command_options.test;
    };

    Coffee.prototype.run = function(options, callback) {
      var args, compile, cwd, notify, watchDirectory, watchFile, watchFiles, watch_index, watch_list, watchers,
        _this = this;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        console.log("coffee " + (eb.utils.relativeArguments(this.args, this.command_options.cwd).join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      notify = function(code) {
        var build_directory, output_directory, output_names, pathed_build_name, post_build_queue, source_name, _i, _len;
        output_directory = _this.targetDirectory();
        output_names = _this.pathedTargets();
        if (_this.isCompressed() || (_this.runsTests() && _this.already_run)) {
          post_build_queue = new eb.command.Queue();
        }
        for (_i = 0, _len = output_names.length; _i < _len; _i++) {
          source_name = output_names[_i];
          build_directory = mb.resolveSafe(output_directory, {
            cwd: path.dirname(source_name)
          });
          if (!build_directory) {
            build_directory = output_directory;
          }
          pathed_build_name = "" + build_directory + "/" + (eb.utils.builtName(path.basename(source_name)));
          if (code === 0) {
            if (!options.silent) {
              timeLog("compiled " + (eb.utils.relativePath(pathed_build_name, _this.targetDirectory())));
            }
          } else {
            timeLog("failed to compile " + (eb.utils.relativePath(pathed_build_name, _this.targetDirectory())) + " .... error code: " + code);
            if (typeof callback === "function") {
              callback(code, _this);
            }
            return;
          }
          if (_this.isCompressed()) {
            post_build_queue.push(new eb.command.RunCommand('uglifyjs', ['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], null));
          }
        }
        if (_this.runsTests() && _this.already_run) {
          post_build_queue.push(new eb.command.RunCommand('cake', ['test'], {
            cwd: _this.command_options.cwd
          }));
        }
        _this.already_run = true;
        if (post_build_queue) {
          return post_build_queue.run(options, function() {
            return typeof callback === "function" ? callback(code, _this) : void 0;
          });
        } else {
          return typeof callback === "function" ? callback(0, _this) : void 0;
        }
      };
      watch_index = _.indexOf(this.args, '-w');
      if (watch_index >= 0) {
        args = _.clone(this.args);
        args.splice(watch_index, 1);
        watch_list = this.sourceFiles();
        watchers = {};
      } else {
        args = this.args;
      }
      cwd = eb.utils.extractCWD(this.command_options);
      watchFile = function(file) {
        var stats;
        if (watchers[file]) {
          watchers[file].close();
        }
        stats = fs.statSync(file);
        return watchers[file] = fs.watch(file, function() {
          var now_stats;
          now_stats = fs.statSync(file);
          if (stats.mtime.getTime() === now_stats.mtime.getTime()) {
            return;
          }
          stats = now_stats;
          return compile();
        });
      };
      watchFiles = function(files) {
        var file, source, watcher, _i, _len, _results;
        for (source in watchers) {
          watcher = watchers[source];
          watcher.close();
        }
        watchers = {};
        _results = [];
        for (_i = 0, _len = files.length; _i < _len; _i++) {
          file = files[_i];
          try {
            _results.push(watchFile(file));
          } catch (e) {
            if (e.code !== 'ENOENT') {
              throw e;
            }
            _results.push(process.stderr.write("coffee: " + (file.replace(this.command_options.cwd, '')) + " doesn't exist. Skipping"));
          }
        }
        return _results;
      };
      watchDirectory = function(directory) {
        var update;
        update = function() {
          watch_list = [];
          globber.glob("" + directory + "/**/*.coffee").forEach(function(pathed_file) {
            return watch_list.push(pathed_file);
          });
          return watchFiles(watch_list);
        };
        fs.watch(directory, update);
        return update();
      };
      compile = function() {
        var errors, spawned;
        errors = false;
        spawned = spawn('coffee', args, cwd);
        spawned.stderr.on('data', function(data) {
          var message;
          message = data.toString();
          if (message.search('is now called') >= 0) {
            return;
          }
          if (errors) {
            return;
          }
          errors = true;
          return process.stderr.write(message);
        });
        return spawned.on('exit', function(code) {
          return notify(code);
        });
      };
      if (watch_list) {
        if (watch_list.length === 1 && fs.statSync(watch_list[0]).isDirectory()) {
          watchDirectory(watch_list[0]);
        } else {
          watchFiles(watch_list);
        }
      }
      return compile();
    };

    return Coffee;

  })();

  eb.command.RunTest = (function() {

    function RunTest(command, args, command_options) {
      this.command = command;
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunTest.prototype.usingPhantomJS = function() {
      return this.command === 'phantomjs';
    };

    RunTest.prototype.fileName = function() {
      if (this.usingPhantomJS()) {
        return this.args[1];
      } else {
        return this.args[0];
      }
    };

    RunTest.prototype.exitCode = function() {
      return this.exit_code;
    };

    RunTest.prototype.run = function(options, callback) {
      var scoped_args, scoped_command, spawned,
        _this = this;
      if (options == null) {
        options = {};
      }
      scoped_command = this.usingPhantomJS() ? this.command : path.join('node_modules/.bin', this.command);
      scoped_args = _.clone(this.args);
      if (this.usingPhantomJS()) {
        if (this.args[1].search('file://') !== 0) {
          scoped_args[1] = "file://" + (mb.resolveSafe(this.args[1], {
            cwd: this.command_options.cwd
          }));
        }
      } else {
        scoped_args = eb.utils.relativeArguments(scoped_args, this.command_options.cwd);
      }
      if (this.command === 'nodeunit') {
        scoped_args.unshift('machineout');
        scoped_args.unshift('--reporter');
      }
      if (options.preview || options.verbose) {
        console.log("" + scoped_command + " " + (scoped_args.join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      spawned = spawn(scoped_command, scoped_args);
      spawned.stdout.on('data', function(data) {
        var message;
        message = data.toString();
        if (message.length > MAX_MESSAGE_LENGTH) {
          message = "" + (message.slice(0, MAX_MESSAGE_LENGTH)) + " ...[MORE]\n";
        }
        return process.stdout.write("*test: " + message);
      });
      return spawned.on('exit', function(code) {
        _this.exit_code = code;
        if (code === 0) {
          if (!options.silent) {
            timeLog("tests passed " + (eb.utils.relativePath(_this.fileName(), _this.command_options.cwd)));
          }
        } else {
          timeLog("tests failed " + (eb.utils.relativePath(_this.fileName(), _this.command_options.cwd)) + " (exit code: " + code + ")");
        }
        return typeof callback === "function" ? callback(code, _this) : void 0;
      });
    };

    return RunTest;

  })();

  eb.command.Bundle = (function() {

    function Bundle(entries, command_options) {
      this.entries = entries;
      this.command_options = command_options != null ? command_options : {};
    }

    Bundle.prototype.run = function(options, callback) {
      var bundle_filename, config, _ref, _ref1;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        _ref = this.entries;
        for (bundle_filename in _ref) {
          config = _ref[bundle_filename];
          console.log("bundle " + bundle_filename + " " + (JSON.stringify(config)));
        }
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      _ref1 = this.entries;
      for (bundle_filename in _ref1) {
        config = _ref1[bundle_filename];
        if (mb.writeBundleSync(bundle_filename, config, {
          cwd: this.command_options.cwd
        })) {
          timeLog("bundled " + (eb.utils.relativePath(bundle_filename, this.command_options.cwd)));
        } else {
          timeLog("failed to bundle " + (eb.utils.relativePath(bundle_filename, this.command_options.cwd)));
        }
      }
      return typeof callback === "function" ? callback(0, this) : void 0;
    };

    return Bundle;

  })();

  eb.command.PublishGit = (function() {

    function PublishGit(command_options) {
      this.command_options = command_options != null ? command_options : {};
    }

    PublishGit.prototype.run = function(options, callback) {
      var local_queue;
      if (options == null) {
        options = {};
      }
      local_queue = new eb.command.Queue();
      local_queue.push(new eb.command.RunCommand('git', ['add', '-A'], this.command_options));
      local_queue.push(new eb.command.RunCommand('git', ['commit'], this.command_options));
      local_queue.push(new eb.command.RunCommand('git', ['push'], this.command_options));
      return local_queue.run(options, function(queue) {
        return typeof callback === "function" ? callback(queue.errorCount(), this) : void 0;
      });
    };

    return PublishGit;

  })();

  eb.command.PublishNPM = (function() {

    function PublishNPM(command_options) {
      this.command_options = command_options != null ? command_options : {};
      if (!this.command_options.cwd) {
        throw "publish_nuget missing current working directory (cwd)";
      }
    }

    PublishNPM.prototype.run = function(options, callback) {
      var args, local_queue, package_desc, package_desc_path, package_path;
      if (options == null) {
        options = {};
      }
      package_path = path.join(this.command_options.cwd, 'packages', 'npm');
      if (!existsSync(package_path)) {
        package_path = this.config_dir;
      }
      package_desc_path = path.join(package_path, 'package.json');
      if (!existsSync(package_desc_path)) {
        console.log("no package.json found for publish_npm: " + (package_desc_path.replace(this.config_dir, '')));
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      package_desc = require(package_desc_path);
      if (package_desc.name.startsWith('_')) {
        console.log("skipping publish_npm for: " + package_desc_path + " (name starts with '_')");
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      if (!existsSync(path.join(package_path, package_desc.main))) {
        console.log("skipping publish_npm for: " + package_desc_path + " (main file missing...do you need to build it?)");
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      local_queue = new eb.command.Queue();
      args = ['publish'];
      if (this.command_options.force) {
        args.push('--force');
      }
      local_queue.push(new eb.command.RunCommand('npm', args, {
        cwd: package_path
      }));
      return local_queue.run(options, function(queue) {
        return typeof callback === "function" ? callback(queue.errorCount(), this) : void 0;
      });
    };

    return PublishNPM;

  })();

  eb.command.PublishNuGet = (function() {

    function PublishNuGet(command_options) {
      this.command_options = command_options != null ? command_options : {};
      if (!this.command_options.cwd) {
        throw "publish_nuget missing current working directory (cwd)";
      }
    }

    PublishNuGet.prototype.run = function(options, callback) {
      var command, file, files, local_queue, package_desc, package_desc_path, package_id, package_path, package_version, pathed_filename, _i, _len;
      if (options == null) {
        options = {};
      }
      command = fs.realpathSync('node_modules/easy-bake/bin/nuget');
      package_path = path.join(this.command_options.cwd, 'packages', 'nuget');
      if (!existsSync(package_path)) {
        if (typeof callback === "function") {
          callback(0);
        }
        return;
      }
      package_desc_path = path.join(package_path, 'package.nuspec');
      if (!existsSync(package_desc_path)) {
        console.log("no package.nuspec found for publishNuGet: " + (package_desc_path.replace(this.config_dir, '')));
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      package_desc = et.parse(fs.readFileSync(package_desc_path, 'utf8').toString());
      package_id = package_desc.findtext('./metadata/id');
      if (!package_id) {
        console.log("package.nuspec missing metadata.name: " + (package_desc_path.replace(this.config_dir, '')));
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      if (package_id.startsWith('_')) {
        console.log("skipping publish_npm for: " + package_desc_path + " (name starts with '_')");
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      package_version = package_desc.findtext('./metadata/version');
      if (!package_version) {
        console.log("package.nuspec missing metadata.version: " + (package_desc_path.replace(this.config_dir, '')));
        if (typeof callback === "function") {
          callback(1);
        }
        return;
      }
      files = package_desc.findall('./files/file');
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        file = files[_i];
        pathed_filename = path.join(package_path, file.get('src'));
        pathed_filename = pathed_filename.replace(/\\/g, '\/');
        if (!existsSync(pathed_filename)) {
          console.log("skipping publish_npm for: " + package_desc_path + " (main file missing...do you need to build it?)");
          if (typeof callback === "function") {
            callback(1);
          }
          return;
        }
      }
      local_queue = new eb.command.Queue();
      if (this.command_options.force) {
        local_queue.push(new eb.command.RunCommand(command, ['delete', package_id, package_version, '-NoPrompt'], {
          cwd: package_path
        }));
      }
      local_queue.push(new eb.command.RunCommand(command, ['pack', package_desc_path], {
        cwd: package_path
      }));
      local_queue.push(new eb.command.RunCommand(command, ['push', "" + package_id + "." + package_version + ".nupkg"], {
        cwd: package_path
      }));
      return local_queue.run(options, function(queue) {
        return typeof callback === "function" ? callback(queue.errorCount(), this) : void 0;
      });
    };

    return PublishNuGet;

  })();

}).call(this);
