[![Build Status](https://secure.travis-ci.org/kmalakoff/easy-bake.png)](http://travis-ci.org/kmalakoff/easy-bake)

````
                                    ,--.           ,--.
 ,---.  ,--,--. ,---.,--. ,--.,-----.|  |-.  ,--,--.|  |,-. ,---.
| .-. :' ,-.  |(  .-' \  '  / '-----'| .-. '' ,-.  ||     /| .-. :
\   --.\ '-'  |.-'  `) \   '         | `-' |\ '-'  ||  \  \\   --.
 `----' `--`--'`----'.-'  /           `---'  `--`--'`--'`--'`----'
                     `---'
````

EasyBake provides YAML-based Cakefile helpers for common CoffeeScript library packaging functionality.


Commands Supplied by EasyBake
-----------------------

- **cake clean**: cleans the project of all compiled files
- **cake build**: performs a single build
- **cake watch**: automatically scans for and builds the project when changes are detected
- **cake test**: runs tests (you might need to install phantomjs: http://phantomjs.org/ or if you use homebrew: 'brew install phantomjs')
- **cake postinstall**: runs postinstall steps like copying dependent client scripts to vendor directory, etc.
- **cake gitpush**: cleans, builds, tests and if successful, runs git commands to add, commit, and push the project.

Command Options:
-----------------------

For example: 'cake -c -w test' will first clean your project, build it, run your tests, and re-build and re-run your tests when source files change

Here are the options with the relevant commands:

- **-c**/**--clean** (build, watch, test): cleans the project before running a command

- **-w**/**--watch** (build, test): watches for changes

- **-b'**/**'--build** (test): builds the project (used with test)

- **-p'**/**'--preview** (all): display all of the commands that will be run (without running them!)

- **-v'**/**'--verbose** (all): display additional information

- **-s**/**--silent** (all): does not output messages to the console (unless errors occur)

Sample YAML
-----------------------

```
library:
  files:
    - src/easy-bake.coffee

lib_test_runners:
  output: lib/test_runners
  directories:
    - src/test_runners

tests:
  output: ./build
  bare: true
  directories:
    - test/easy-bake_core
  options:
    test:
      command: nodeunit
      files:
        - '**/*.js'
```


Project Configuration
-----------------------

Just include it as a development dependency to your package.json:

```
"scripts": {
  "postinstall": "node_modules/.bin/cake postinstall"
},

"devDependencies": {
  "coffee-script": "latest",
  "easy-bake": "0.1.2"
},
```

Install it:

```
npm install
```

Include it in your Cakefile:

```
easybake = require('easy-bake')
(new easybake.Oven('easy-bake-config.yaml')).publishTasks()
```

or if you want finer control:

```
easybake = require('easy-bake')
oven = (new easybake.Oven('easy-bake-config.yaml')).publishOptions()

task 'build', 'Build library and tests', (options) -> myBuildFunction(); oven.build(options)
task 'postinstall', 'Called by npm after installing library', (options) -> myPostInstallFunction(); oven.postinstall(options)
```

###Oven.publishTasks() Options

- **tasks**: an array of tasks to include (in case you want to use only a subset)
- **namespace**: provides a namespace for the tasks like 'cake namspace.build' instead of just 'cake build'



And that's it! You will have access to the following cake commands and options in your projects...

Testing
-----------------------
If you are using TravisCI, you should add something like this to your project.json file:

```
"scripts": {
  "postinstall": "node_modules/.bin/cake postinstall",
  "test": "node_modules/.bin/cake -c -b test"
},
```

and a .travis.yaml to your project root file like:

```
language: node_js
node_js:
  - 0.7 # development version of 0.8, may be unstable

before_script:
  - "export DISPLAY=:99.0"
  - "sh -e /etc/init.d/xvfb start"
```

and add test options to the set you want to test:

```
some_testing_group:
  output: build
  directories:
    - test/some_tests
    - test/some_more_tests
  options:
    test:
      command: phantomjs
      runner: phantomjs-qunit-runner.js
      args: [60000]
      files:
        - **/*.html
```


###Testing With PhantomJS

You will need to install phantom yourself since there is no npm package for it. Look here for the instructions: http://phantomjs.org/ or if you use homebrew: 'brew install phantomjs'

```
some_testing_group:
  ...
  options:
    test:
      command: phantomjs
      runner: phantomjs-qunit-runner.js
      args: [60000]
    files:
      - **/*.html
```

**Note:** currently the library only has a test-runner for phantomjs-qunit-runner.js and phantomjs-jasmine-runner.js. Feel free to add more and to submit a pull request.

###Testing With NodeUnit

Just include it as a development dependency to your package.json:

```
"devDependencies": {
  "coffee-script": "latest",
  "easy-bake": "0.1.2",
  "nodeunit": "latest"
},
```

```
some_testing_group:
  ...
  options:
    test:
      command: nodeunit
    files:
      - **/*.js
```


Building the library
-----------------------

###Installing:

1. install node.js: http://nodejs.org
2. install node packages: (sudo) 'npm install'

###Commands:

Easy-bake uses easy-bake! Just use the above commands...
