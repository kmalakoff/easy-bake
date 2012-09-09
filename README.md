[![Build Status](https://secure.travis-ci.org/kmalakoff/easy-bake.png)](http://travis-ci.org/kmalakoff/easy-bake)

````
                                    ,--.           ,--.
 ,---.  ,--,--. ,---.,--. ,--.,-----.|  |-.  ,--,--.|  |,-. ,---.
| .-. :' ,-.  |(  .-' \  '  / '-----'| .-. '' ,-.  ||     /| .-. :
\   --.\ '-'  |.-'  `) \   '         | `-' |\ '-'  ||  \  \\   --.
 `----' `--`--'`----'.-'  /           `---'  `--`--'`--'`--'`----'
                     `---'
````

EasyBake provides Coffeescript config file-based Cakefile helpers for common CoffeeScript library packaging functionality (build & joining, headless testing, etc).


Commands Supplied by EasyBake
-----------------------

- **bake postinstall**: runs postinstall steps like copying dependent client scripts to vendor directory, etc.
- **bake clean**: cleans the project of all compiled files
- **bake build**: performs a single build
- **bake watch**: automatically scans for and builds the project when changes are detected
- **bake test**: runs tests (you might need to install phantomjs: http://phantomjs.org/ or if you use homebrew: 'brew install phantomjs')
- **bake publish_git**: cleans, builds, tests and if successful, runs git commands to add, commit, and push the project.
- **bake publish_npm**: cleans, builds, tests and if successful, runs git commands to add, commit, and push the project to node registry.
- **bake publish_nuget**: cleans, builds, tests and if successful, runs git commands to add, commit, and push the project to NuGet Gallery.
- **bake publish_all**: cleans, builds, tests and if successful, runs git commands to add, commit, and push the project to all relevant repositories.

Command Options:
-----------------------

For example: 'bake test -c -w' will first clean your project, build it, run your tests, and re-build and re-run your tests when source files change

Some common options:

- **-c**/**--clean** (build, watch, test): cleans the project before running a command
- **-p'**/**'--preview** (all): display all of the commands that will be run (without running them!)
- **-f'**/**'--force** (publish): overwrite the existing repository version (if possible)

To see all of the options for each command, just run 'bake command_name --help'.

Sample Config File
-----------------------

Here is an example of a CoffeeScript config file (JavaScript is also supported):

```
module.exports =
  library:
    files: 'src/easy-bake.coffee'

  lib_test_runners:
    output: '../../lib/test_runners'
    directories: 'src/test_runners'

  tests:
    _build
      output: 'build'
      bare: true
      directories: 'test/easy-bake_core'
    _test:
      command: 'nodeunit'
      files: '**/*.js'
```

###Directories vs Files

Because CoffeeScript will retain the file hierarchy if an output directory is given, easy-bake allows you to flatten the hierarchy or to preserve it using directories + files vs directories-only.

For example, because directories are only specified in this case, the full directory structure will be preserved when the CoffeeScripts are compiled:

```
my_set_hierarchical:
  output: '../js'
  directories: 'my_directory'
```

Whereas, by specifying the files, you can compile them all into the output directory:

```
my_set_flat:
  output: '../js'
  directories: 'my_directory'
  files: '**/*.coffee'
```

So if the hierarchy is like:

```
- my_directory
  - sub_directory
    - file1.coffee
  - app.coffee
```

The results would be as follows for my_set_hierarchical:

```
- js
  - sub_directory
    - file1.js
  - app.js
- my_directory
  - sub_directory
    - file1.coffee
  - app.coffee
```

and for my_set_flat:

```
- js
  - app.js
  - file1.js
- my_directory
  - sub_directory
    - file1.coffee
  - app.coffee
```

###Relative Directories

All output directories are relative to a set's directory.

For example, the output directory in this example is resolved to be the same directory as the CoffeeScript config file root because 'src/test_runners' is two directories down the hierarchy:

```
lib_test_runners:
  output: '../../lib/test_runners'
  directories: 'src/test_runners'
```

Whereas, the output in this case will be in a new folder under 'test/easy-bake_core' (output to 'test/easy-bake_core/build'):

```
tests:
  _build
    output: 'build'
    bare: true
    directories: 'test/easy-bake_core'
```


Project Configuration
-----------------------

It is best to preinstall a specific version of easy-bake in your package.json (to lock a specific version until the configuration format is locked at a major release):

```
"scripts": {
  "postinstall": "bake postinstall"
},
"devDependencies": {
  "coffee-script": ">=1.3.3",
  "easy-bake": "0.1.7"
},
```

Install it:

```
npm install
```

Add a Bakefile.coffee or Bakefile.js to your root directory like:

```
module.exports =
  library:
    files: 'src/easy-bake.coffee'
```

And run it:

```
bake build
```

###Known Issues

1. if commands like bake, mbundle, or uglify give you errors, make sure 'node_modules/.bin' and 'node_modules/easy-bake/node_modules/.bin' are added to your PATH. For example in zsh, just add the following to ~/.zshrc:

```
export PATH=node_modules/.bin:node_modules/easy-bake/node_modules/.bin:$PATH
```


And that's it! You will have access to the following bake commands and options in your projects...

Testing
-----------------------
If you are using TravisCI, you should add something like this to your project.json file:

```
"scripts": {
  "postinstall": "bake postinstall",
  "clean": "bake clean",
  "build": "bake build",
  "watch": "bake watch",
  "test": "bake test -c"
},
```

and a .travis.yaml to your project root file like:

```
language: node_js
node_js:
  - 0.7 # development version of 0.8, may be unstable

before_script:
  - "export PATH=node_modules/.bin:node_modules/easy-bake/node_modules/.bin:$PATH"
  - "export DISPLAY=:99.0"
  - "sh -e /etc/init.d/xvfb start"
```

and add test options to the set you want to test:

```
some_testing_group:
  output: 'build'
  directories: [
    'test/some_tests'
    'test/some_more_tests'
  ]
  _test:
    command: 'phantomjs'
    runner: 'phantomjs-qunit-runner.js'
    args: [60000]
    files: '**/*.html'
```


###Testing With PhantomJS

You will need to install phantom yourself since there is no npm package for it. Look here for the instructions: http://phantomjs.org/ or if you use homebrew: 'brew install phantomjs'

```
some_testing_group:
  ...
  _test:
    command: 'phantomjs'
    runner: 'phantomjs-qunit-runner.js'
    files: '**/*.html'
```

**Note:** currently the library only has a test-runner for phantomjs-qunit-runner.js and phantomjs-jasmine-runner.js. Feel free to add more and to submit a pull request.

###Testing With NodeUnit

Just include it as a development dependency to your package.json:

```
"devDependencies": {
  "coffee-script": ">=1.3.3",
  "nodeunit": "latest"
},
```

```
some_testing_group:
  ...
  _test:
    command: 'nodeunit'
    files: '**/*.js'
```

###Post Install

You can add commands to run after npm install. For example, you can copy and rename a file from a node module into a vendor directory:

```
  _postinstall:
    commands: [
      'cp underscore vendor/underscore-latest.js'
    ]

```

###Publishing

Publishing to npm registry and NuGet Gallery are currently supported.

Using a post _build command, you should copy your files into the directories as follows:

```
- project_root
  - package.json (for building)
  - packages
    - npm
      - package.json (for distribution)
      - your files
    - nuget
      - package.nuspec
      - Content
        - Scripts
          - your files
```

The reason for this multiple layered structure is so you can separate your building environment (as project_root) from your distribution packages, which for example, may not require all of postinstall and build steps.

#NPM

Set up an account on npm registry: http://search.npmjs.org/

#NuGet

Currently, NuGet has only been tested on Mac using Mono. If anyone would like to test and update on Windows or Linux, please submit a pull request.

Also, NuGet doesn't seem to handle removing and reinstalling packages from the command line so you might need to still perform some manual steps.

*Installation*

- Download and install mono: http://www.go-mono.com/mono-downloads/download.html
- Get easy-bake using 'npm install' (you need to list it in your package.json file)
- Register on NuGet Gallery: https://nuget.org
- Set up your API key. Get your key from your profile in NuGet (show your API key on your account page: https://nuget.org/account) and run 'node_modules/easy-bake/bin/nuget setApiKey YOUR_SECRET_KEY'

*Known Issues*

- If your package has never been created on Nuget Gallery, the first time, you may need to upload it manually: https://nuget.org/packages.
- Your package may not be deleted when using the --force option. You may need to go to the Gallery website and delete it.
- Your package may not be public after a push. You may need to go to the package page on the Gallery website and 'change its listing settings'


Release Notes
-----------------------

### 0.1.6
- moved from cake commands to bake commands. Was: 'cake -c test' now: 'bake test -c'
- introduced convention of Bakefile.coffee or Bakefile.js for configuration
- removed options scoping

### 0.1.5
- added NuGet publishing support (requires Mono on Mac) - see above section "Publishing to NuGet"
- added publish_all command to publish to all locations
- renamed publish commands to: publish_git. publish_npm
- removed no_files_ok option
- made a test with clean automatically add a build option. Was: 'cake -c -b test' now: 'cake -c test'

### 0.1.4
- removed modes block and used _reserved} convention instead to reduce verbosity (means instead of {modes: test: options} -> {_test: options})
- renamed postinstall to _postinstall using _{reserved} convention

### 0.1.3
- refactored functionality and spun off module-bundler project (and reversed arguments order of _publish)
- made dependent on a previous version of easy-bake
- allow an object + current working directory (cwd) instead of a filename to be used

Building the library
-----------------------

###Installing:

1. install node.js: http://nodejs.org
2. install node packages: 'npm install'

###Commands:

Easy-bake uses easy-bake! Just use the above commands...