// Generated by CoffeeScript 1.3.3
(function() {
  var RESERVED_SETS, RUNNERS_ROOT, TEST_DEFAULT_TIMEOUT, eb, fs, path, print, spawn, timeLog, yaml, _;

  print = require('util').print;

  spawn = require('child_process').spawn;

  fs = require('fs');

  path = require('path');

  yaml = require('js-yaml');

  _ = require('underscore');

  require('coffee-script/lib/coffee-script/cake');

  RESERVED_SETS = ['postinstall'];

  TEST_DEFAULT_TIMEOUT = 60000;

  RUNNERS_ROOT = "" + __dirname + "/lib/test_runners";

  eb = this.eb = typeof exports !== 'undefined' ? exports : {};

  eb.utils = require('./lib/easy-bake-utils');

  eb.command = require('./lib/easy-bake-commands');

  timeLog = function(message) {
    return console.log("" + ((new Date).toLocaleTimeString()) + " - " + message);
  };

  eb.Oven = (function() {

    function Oven(YAML_filename) {
      this.YAML_dir = path.dirname(fs.realpathSync(YAML_filename));
      this.YAML = yaml.load(fs.readFileSync(YAML_filename, 'utf8'));
    }

    Oven.prototype.publishTasks = function(options) {
      var args, task_name, task_names, tasks, _i, _len, _results,
        _this = this;
      if (options == null) {
        options = {};
      }
      option('-c', '--clean', 'clean the project');
      option('-w', '--watch', 'watch for changes');
      option('-s', '--silent', 'silence the console output');
      option('-p', '--preview', 'preview the action');
      option('-v', '--verbose', 'display additional information');
      option('-b', '--build', 'builds the project (used with test)');
      tasks = {
        clean: [
          'Remove generated JavaScript files', function(options) {
            return _this.clean(options);
          }
        ],
        build: [
          'Build library and tests', function(options) {
            return _this.build(options);
          }
        ],
        watch: [
          'Watch library and tests', function(options) {
            return _this.build(_.defaults({
              watch: true
            }, options));
          }
        ],
        test: [
          'Test library', function(options) {
            return _this.test(options);
          }
        ],
        postinstall: [
          'Performs postinstall actions', function(options) {
            return _this.postinstall(options);
          }
        ]
      };
      task_names = options.tasks ? options.tasks : _.keys(tasks);
      _results = [];
      for (_i = 0, _len = task_names.length; _i < _len; _i++) {
        task_name = task_names[_i];
        args = tasks[task_name];
        if (!args) {
          console.log("easy-bake: task name not recognized " + task_name);
          continue;
        }
        if (options.namespace) {
          task_name = "" + options.namespace + "." + task_name;
        }
        _results.push(task.apply(null, [task_name].concat(args)));
      }
      return _results;
    };

    Oven.prototype.clean = function(options, command_queue) {
      var args, build_directory, build_queue, command, output_directory, output_names, owns_queue, pathed_build_name, postinstall_queue, source_name, target, _i, _j, _k, _len, _len1, _len2, _ref, _ref1;
      if (options == null) {
        options = {};
      }
      owns_queue = !command_queue;
      command_queue || (command_queue = new eb.command.Queue());
      if (options.verbose) {
        command_queue.push({
          run: function(callback, options, queue) {
            console.log("************clean " + (options.preview ? 'started (PREVIEW)' : 'started') + "************");
            return typeof callback === "function" ? callback() : void 0;
          }
        });
      }
      build_queue = new eb.command.Queue();
      this.build(_.defaults({
        clean: false
      }, options), build_queue);
      _ref = build_queue.commands();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        command = _ref[_i];
        if (!(command instanceof eb.command.RunCoffee)) {
          continue;
        }
        output_directory = command.targetDirectory();
        output_names = command.targetNames();
        for (_j = 0, _len1 = output_names.length; _j < _len1; _j++) {
          source_name = output_names[_j];
          build_directory = eb.utils.resolvePath(output_directory, {
            cwd: path.dirname(source_name),
            root_dir: this.YAML_dir
          });
          pathed_build_name = "" + build_directory + "/" + (eb.utils.builtName(path.basename(source_name)));
          command_queue.push(new eb.command.RunClean(["" + pathed_build_name], {
            root_dir: this.YAML_dir
          }));
          if (command.isCompressed()) {
            command_queue.push(new eb.command.RunClean(["" + (eb.utils.compressedName(pathed_build_name))], {
              root_dir: this.YAML_dir
            }));
          }
        }
      }
      postinstall_queue = new eb.command.Queue();
      this.postinstall(_.defaults({
        clean: false
      }, options), postinstall_queue);
      _ref1 = postinstall_queue.commands();
      for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
        command = _ref1[_k];
        if (!(command instanceof eb.command.RunCommand)) {
          continue;
        }
        if (command.command === 'cp') {
          target = "" + this.YAML_dir + "/" + command.args[1];
          args = [];
          if (!path.basename(target)) {
            args.push('-r');
          }
          args.push(target);
          command_queue.push(new eb.command.RunClean(args, {
            root_dir: this.YAML_dir
          }));
        }
      }
      if (options.verbose) {
        command_queue.push({
          run: function(callback, options, queue) {
            console.log("clean completed with " + (queue.errorCount()) + " error(s)");
            return typeof callback === "function" ? callback() : void 0;
          }
        });
      }
      if (owns_queue) {
        return command_queue.run(null, options);
      }
    };

    Oven.prototype.build = function(options, command_queue) {
      var args, file, file_group, file_groups, owns_queue, set, set_name, set_options, _i, _j, _len, _len1, _ref, _ref1;
      if (options == null) {
        options = {};
      }
      owns_queue = !command_queue;
      command_queue || (command_queue = new eb.command.Queue());
      if (options.clean) {
        this.clean(options, command_queue);
      }
      this.postinstall(options, command_queue);
      if (options.verbose) {
        command_queue.push({
          run: function(callback, options, queue) {
            console.log("************build " + (options.preview ? 'started (PREVIEW)' : 'started') + "************");
            return typeof callback === "function" ? callback() : void 0;
          }
        });
      }
      _ref = this.YAML;
      for (set_name in _ref) {
        set = _ref[set_name];
        if (_.contains(RESERVED_SETS, set_name)) {
          continue;
        }
        set_options = eb.utils.extractSetOptions(set, 'build', {
          directories: ['.'],
          files: ['**/*.coffee']
        });
        file_groups = eb.utils.getOptionsFileGroups(set_options, this.YAML_dir, options);
        for (_i = 0, _len = file_groups.length; _i < _len; _i++) {
          file_group = file_groups[_i];
          args = [];
          if (options.watch) {
            args.push('-w');
          }
          if (set_options.bare) {
            args.push('-b');
          }
          if (set_options.join) {
            args.push('-j');
            args.push(set_options.join);
          }
          args.push('-o');
          if (set_options.output) {
            args.push(eb.utils.resolvePath(set_options.output, {
              cwd: file_group.directory,
              root_dir: this.YAML_dir
            }));
          } else {
            args.push(this.YAML_dir);
          }
          args.push('-c');
          _ref1 = file_group.files;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            file = _ref1[_j];
            args.push(file);
          }
          command_queue.push(new eb.command.RunCoffee(args, {
            root_dir: this.YAML_dir,
            compress: set_options.compress,
            test: options.test
          }));
        }
      }
      if (options.verbose) {
        command_queue.push({
          run: function(callback, options, queue) {
            console.log("build completed with " + (queue.errorCount()) + " error(s)");
            return typeof callback === "function" ? callback() : void 0;
          }
        });
      }
      if (owns_queue) {
        return command_queue.run(null, options);
      }
    };

    Oven.prototype.test = function(options, command_queue) {
      var args, easy_bake_runner_used, file, file_group, file_groups, length_base, owns_queue, set, set_name, set_options, test_queue, _i, _j, _len, _len1, _ref, _ref1;
      if (options == null) {
        options = {};
      }
      owns_queue = !command_queue;
      command_queue || (command_queue = new eb.command.Queue());
      if (options.build || options.watch) {
        this.build(_.defaults({
          test: true
        }, options), command_queue);
      }
      test_queue = new eb.command.Queue();
      command_queue.push(new eb.command.RunQueue(test_queue, 'tests'));
      if (options.verbose) {
        test_queue.push({
          run: function(callback, options, queue) {
            console.log("************test " + (options.preview ? 'started (PREVIEW)' : 'started') + "************");
            return typeof callback === "function" ? callback() : void 0;
          }
        });
      }
      _ref = this.YAML;
      for (set_name in _ref) {
        set = _ref[set_name];
        if (_.contains(RESERVED_SETS, set_name) || !(set.options && set.options.hasOwnProperty('test'))) {
          continue;
        }
        set_options = eb.utils.extractSetOptions(set, 'test', {
          directories: ['.'],
          files: ['**/*.html']
        });
        if (set_options.runner && !path.existsSync(set_options.runner)) {
          set_options.runner = "" + RUNNERS_ROOT + "/" + set_options.runner;
          easy_bake_runner_used = true;
        }
        file_groups = eb.utils.getOptionsFileGroups(set_options, this.YAML_dir, options);
        for (_i = 0, _len = file_groups.length; _i < _len; _i++) {
          file_group = file_groups[_i];
          _ref1 = file_group.files;
          for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
            file = _ref1[_j];
            args = [];
            if (set_options.runner) {
              args.push(set_options.runner);
            }
            args.push(eb.utils.resolvePath(file, {
              cwd: file_group.directory,
              root_dir: this.YAML_dir
            }));
            if (set_options.args) {
              args = args.concat(set_options.args);
            }
            if (easy_bake_runner_used) {
              length_base = set_options.runner ? 2 : 1;
              if (args.length < (length_base + 1)) {
                args.push(TEST_DEFAULT_TIMEOUT);
              }
              if (args.length < (length_base + 2)) {
                args.push(true);
              }
            }
            test_queue.push(new eb.command.RunTest(set_options.command, args, {
              root_dir: this.YAML_dir
            }));
          }
        }
      }
      if (!options.preview) {
        test_queue.push({
          run: function(callback, options, queue) {
            var command, total_error_count, _k, _len2, _ref2;
            total_error_count = 0;
            console.log("\n************GROUP TEST RESULTS********");
            _ref2 = test_queue.commands();
            for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
              command = _ref2[_k];
              if (!(command instanceof eb.command.RunTest)) {
                continue;
              }
              total_error_count += command.exitCode() ? 1 : 0;
              console.log("" + (command.exitCode() ? '✖' : '✔') + " " + (command.fileName()) + (command.exitCode() ? ' (exit code: ' + command.exitCode() + ')' : ''));
            }
            console.log("**************************************");
            console.log(total_error_count ? "All tests ran with with " + total_error_count + " error(s)" : "All tests ran successfully!");
            console.log("**************************************");
            if (!options.watch) {
              process.exit(queue.errorCount() > 0 ? 1 : 0);
            }
            return typeof callback === "function" ? callback(0) : void 0;
          }
        });
      }
      if (owns_queue) {
        return command_queue.run(null, options);
      }
    };

    Oven.prototype.postinstall = function(options, command_queue) {
      var command_info, name, owns_queue, set, set_name, _ref;
      if (options == null) {
        options = {};
      }
      owns_queue = !command_queue;
      command_queue || (command_queue = new eb.command.Queue());
      _ref = this.YAML;
      for (set_name in _ref) {
        set = _ref[set_name];
        if (set_name !== 'postinstall') {
          continue;
        }
        for (name in set) {
          command_info = set[name];
          if (!command_info.command) {
            console.log("postinstall " + set_name + "." + name + " is not a command");
            continue;
          }
          command_queue.push(new eb.command.RunCommand(command_info.command, command_info.args, _.defaults({
            root_dir: this.YAML_dir
          }, command_info.options)));
        }
      }
      if (options.verbose) {
        command_queue.push({
          run: function(callback, options, queue) {
            console.log("postinstall completed with " + (queue.errorCount()) + " error(s)");
            return typeof callback === "function" ? callback() : void 0;
          }
        });
      }
      if (owns_queue) {
        return command_queue.run(null, options);
      }
    };

    return Oven;

  })();

}).call(this);
