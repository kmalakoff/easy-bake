// Generated by CoffeeScript 1.3.3
(function() {
  var eb, fs, path, spawn, timeLog, uglifyjs, wrench, _;

  spawn = require('child_process').spawn;

  fs = require('fs');

  path = require('path');

  _ = require('underscore');

  wrench = require('wrench');

  uglifyjs = require('uglify-js');

  if (!eb) {
    eb = {};
  }

  if (!this.eb) {
    this.eb = {};
  }

  eb.utils = require('./easy-bake-utils');

  eb.commands = this.eb.commands = typeof exports !== 'undefined' ? exports : {};

  timeLog = function(message) {
    return console.log("" + ((new Date).toLocaleTimeString()) + " - " + message);
  };

  eb.commands.Queue = (function() {

    function Queue() {
      this.commands_queue = [];
      this.is_running = false;
      this.errors = [];
    }

    Queue.prototype.commands = function() {
      return this.commands_queue;
    };

    Queue.prototype.errorCount = function() {
      return this.errors.length;
    };

    Queue.prototype.push = function(command) {
      return this.commands_queue.push(command);
    };

    Queue.prototype.run = function(callback, run_options) {
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
        return typeof callback === "function" ? callback(_this.errors.length, _this) : void 0;
      };
      next = function(code, task) {
        if ((code !== 0) && (arguments.length !== 0)) {
          _this.errors.push({
            code: code,
            task: task
          });
        }
        if (++current_index < _this.commands_queue.length) {
          return _this.commands_queue[current_index].run(next, run_options, _this);
        } else {
          return done();
        }
      };
      if (this.commands_queue.length) {
        return this.commands_queue[current_index].run(next, run_options, this);
      } else {
        return done();
      }
    };

    return Queue;

  })();

  eb.commands.RunQueue = (function() {

    function RunQueue(run_queue, name) {
      this.run_queue = run_queue;
      this.name = name;
    }

    RunQueue.prototype.queue = function() {
      return this.run_queue;
    };

    RunQueue.prototype.run = function(callback, options) {
      if (options == null) {
        options = {};
      }
      if (options.verbose) {
        console.log("running queue: " + this.name);
      }
      return this.run_queue.run(callback, options);
    };

    return RunQueue;

  })();

  eb.commands.RunCommand = (function() {

    function RunCommand(command, args, command_options) {
      this.command = command;
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunCommand.prototype.run = function(callback, options) {
      var message, spawned;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        message = "" + this.command + " " + (this.args.join(' '));
        if (this.command_options.cwd) {
          message = "" + (this.command_options.root_dir ? this.command_options.cwd.replace("" + this.command_options.root_dir + "/", '') : this.command_options.cwd) + ": " + message;
        }
        console.log(message);
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      spawned = spawn(this.command, this.args, this.command_options);
      spawned.stderr.on('data', function(data) {
        return process.stderr.write(data.toString());
      });
      spawned.stdout.on('data', function(data) {
        return process.stderr.write(data.toString());
      });
      return spawned.on('exit', function(code) {
        return typeof callback === "function" ? callback(code, this) : void 0;
      });
    };

    return RunCommand;

  })();

  eb.commands.RunClean = (function() {

    function RunClean(args, command_options) {
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunClean.prototype.target = function() {
      return this.args[this.args.length - 1];
    };

    RunClean.prototype.run = function(callback, options) {
      var unscoped_args,
        _this = this;
      if (options == null) {
        options = {};
      }
      if (!path.existsSync(this.target())) {
        if (typeof callback === "function") {
          callback(0, this);
        }
        return;
      }
      if (options.preview || options.verbose) {
        unscoped_args = _.map(this.args, function(arg) {
          return arg.replace(_this.command_options.root_dir, '');
        });
        unscoped_args = _.map(unscoped_args, function(arg) {
          if (!arg.length) {
            return '.';
          } else {
            if (arg[0] === '/') {
              return arg.substr(1);
            } else {
              return arg;
            }
          }
        });
        console.log("rm " + (unscoped_args.join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      if (this.args[0] === '-r') {
        wrench.rmdirSyncRecursive(this.args[1]);
      } else {
        fs.unlink(this.args[0]);
      }
      return typeof callback === "function" ? callback(0, this) : void 0;
    };

    return RunClean;

  })();

  eb.commands.RunCoffee = (function() {

    function RunCoffee(args, command_options) {
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunCoffee.prototype.targetDirectory = function() {
      var index;
      if ((index = _.indexOf(this.args, '-o')) >= 0) {
        return "" + this.args[index + 1];
      } else {
        return '';
      }
    };

    RunCoffee.prototype.targetNames = function() {
      var index;
      if ((index = _.indexOf(this.args, '-j')) >= 0) {
        return [this.args[index + 1]];
      } else {
        return this.args.slice(_.indexOf(this.args, '-c') + 1);
      }
    };

    RunCoffee.prototype.isCompressed = function() {
      return this.command_options.compress;
    };

    RunCoffee.prototype.run = function(callback, options) {
      var notify, spawned, unscoped_args,
        _this = this;
      if (options == null) {
        options = {};
      }
      if (options.preview || options.verbose) {
        unscoped_args = _.map(this.args, function(arg) {
          return arg.replace(_this.command_options.root_dir, '');
        });
        unscoped_args = _.map(unscoped_args, function(arg) {
          if (!arg.length) {
            return '.';
          } else {
            if (arg[0] === '/') {
              return arg.substr(1);
            } else {
              return arg;
            }
          }
        });
        console.log("coffee " + (unscoped_args.join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      spawned = spawn('coffee', this.args);
      spawned.stderr.on('data', function(data) {
        return process.stderr.write(data.toString());
      });
      notify = function(code) {
        var build_directory, compress_queue, output_directory, output_names, pathed_build_name, source_name, _i, _len;
        output_directory = _this.targetDirectory();
        output_names = _this.targetNames();
        if (_this.isCompressed()) {
          compress_queue = new eb.commands.Queue();
        }
        for (_i = 0, _len = output_names.length; _i < _len; _i++) {
          source_name = output_names[_i];
          build_directory = eb.utils.resolvePath(output_directory, path.dirname(source_name), _this.command_options.root_dir);
          pathed_build_name = "" + build_directory + "/" + (eb.utils.builtName(path.basename(source_name)));
          if (code === 0) {
            if (!options.silent) {
              timeLog("compiled " + (pathed_build_name.replace("" + _this.command_options.root_dir + "/", '')));
            }
          } else {
            timeLog("failed to compile " + (pathed_build_name.replace("" + _this.command_options.root_dir + "/", '')) + " .... error code: " + code);
          }
          if (compress_queue) {
            compress_queue.push(new eb.commands.RunUglifyJS(['-o', eb.utils.compressedName(pathed_build_name), pathed_build_name], {
              root_dir: _this.command_options.root_dir
            }));
          }
        }
        if (compress_queue) {
          return compress_queue.run((function() {
            return typeof callback === "function" ? callback(code, _this) : void 0;
          }), options);
        } else {
          return typeof callback === "function" ? callback(0, _this) : void 0;
        }
      };
      if (options.watch) {
        return spawned.stdout.on('data', function(data) {
          return notify(0);
        });
      } else {
        return spawned.on('exit', function(code) {
          return notify(code);
        });
      }
    };

    return RunCoffee;

  })();

  eb.commands.RunUglifyJS = (function() {

    function RunUglifyJS(args, command_options) {
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunUglifyJS.prototype.outputName = function() {
      var index;
      if ((index = _.indexOf(this.args, '-o')) >= 0) {
        return "" + this.args[index + 1];
      } else {
        return '';
      }
    };

    RunUglifyJS.prototype.run = function(callback, options) {
      var ast, header, header_index, scoped_command, src, unscoped_args,
        _this = this;
      if (options == null) {
        options = {};
      }
      scoped_command = "node_modules/.bin/uglifyjs";
      if (options.preview || options.verbose) {
        unscoped_args = _.map(this.args, function(arg) {
          return arg.replace(_this.command_options.root_dir, '');
        });
        unscoped_args = _.map(unscoped_args, function(arg) {
          if (!arg.length) {
            return '.';
          } else {
            if (arg[0] === '/') {
              return arg.substr(1);
            } else {
              return arg;
            }
          }
        });
        console.log("" + scoped_command + " " + (unscoped_args.join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      try {
        src = fs.readFileSync(this.args[2], 'utf8');
        header = (header_index = src.indexOf('*/')) > 0 ? src.substr(0, header_index + 2) : '';
        ast = uglifyjs.parser.parse(src);
        ast = uglifyjs.uglify.ast_mangle(ast);
        ast = uglifyjs.uglify.ast_squeeze(ast);
        src = header + uglifyjs.uglify.gen_code(ast) + ';';
        fs.writeFileSync(this.args[1], src, 'utf8');
        if (!options.silent) {
          timeLog("compressed " + (this.outputName().replace("" + this.command_options.root_dir + "/", '')));
        }
        return typeof callback === "function" ? callback(0, this) : void 0;
      } catch (e) {
        timeLog("failed to minify " + (this.outputName().replace("" + this.command_options.root_dir + "/", '')) + " .... error code: " + e.code);
        return typeof callback === "function" ? callback(e.code, this) : void 0;
      }
    };

    return RunUglifyJS;

  })();

  eb.commands.RunTest = (function() {

    function RunTest(command, args, command_options) {
      this.command = command;
      this.args = args != null ? args : [];
      this.command_options = command_options != null ? command_options : {};
    }

    RunTest.prototype.run = function(callback, options) {
      var scoped_command, spawned, unscoped_args,
        _this = this;
      if (options == null) {
        options = {};
      }
      scoped_command = this.command === 'phantomjs' ? this.command : "node_modules/.bin/" + command;
      if (options.preview || options.verbose) {
        unscoped_args = this.args.length === 4 ? this.args.slice(0, this.args.length - 1) : this.args;
        console.log("" + scoped_command + " " + (unscoped_args.join(' ')));
        if (options.preview) {
          if (typeof callback === "function") {
            callback(0, this);
          }
          return;
        }
      }
      spawned = spawn(scoped_command, this.args);
      spawned.stderr.on('data', function(data) {
        return process.stderr.write(data.toString());
      });
      spawned.stdout.on('data', function(data) {
        return process.stderr.write(data.toString());
      });
      return spawned.on('exit', function(code) {
        var test_filename;
        test_filename = (_this.command === 'phantomjs' ? _this.args[1] : _this.args[0]);
        test_filename = test_filename.replace("file://" + _this.command_options.root_dir + "/", '');
        if (code === 0) {
          if (!options.silent) {
            timeLog("tests passed " + test_filename);
          }
        } else {
          timeLog("tests failed " + test_filename + " .... error code: " + code);
        }
        return typeof callback === "function" ? callback(code, _this) : void 0;
      });
    };

    return RunTest;

  })();

}).call(this);