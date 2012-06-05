[![Build Status](https://secure.travis-ci.org/kmalakoff/easy-bake.png)](http://travis-ci.org/kmalakoff/easy-bake)

````
                                    ,--.           ,--.
 ,---.  ,--,--. ,---.,--. ,--.,-----.|  |-.  ,--,--.|  |,-. ,---.
| .-. :' ,-.  |(  .-' \  '  / '-----'| .-. '' ,-.  ||     /| .-. :
\   --.\ '-'  |.-'  `) \   '         | `-' |\ '-'  ||  \  \\   --.
 `----' `--`--'`----'.-'  /           `---'  `--`--'`--'`--'`----'
                     `---'
````

EasyBake provides YAML-based Cakefile helpers for common CoffeeScript library packaging functionality

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

Create a YAML file to specify what needs to be built (for example easy-bake-config.yaml):

```
some_group:
  join: your_library_name.js
  compress: true
  files:
    - src/knockback_core.coffee
    - src/lib/**.*coffee

some_other_group:
  join: helpers.js
  output: build
  directories:
    - lib/your_helpers1
    - lib/your_helpers2
```

Include it in your Cakefile:

```
easybake = require('easy-bake')
(new easybake.Oven('easy-bake-config.yaml')).publishTasks({})
```

Options include:

1. tasks - an array of tasks to include (in case you want to use only a subset)
2. namespace - provides a namespace for the tasks like namspace.build

And that's it! You will have access to the following cake commands and options in your projects...

Commands Supplied by EasyBake
-----------------------

1. 'cake clean' - cleans the project of all compiled files
2. 'cake build' - performs a single build
3. 'cake watch' - automatically scans for and builds the project when changes are detected
3. 'cake test' - cleans, builds, and runs tests. Note: the tests require installing phantomjs
3. 'cake postinstall' - runs postintall steps like copying dependent client scripts to vendor, etc.

Options:

1. '-c' or '--clean'  - cleans the project before running a new command
2. '-w' or '--watch'  - watches for changes
3. '-s' or '--silent' - does not output messages to the console (unless errors occur)
4. '-p' or '--preview' - preview the action


Testing
-----------------------
If you are using TravisCI, you should add something like this to your project.json file:

```
"scripts": {
  "postinstall": "node_modules/.bin/cake postinstall",
  "test": "node_modules/.bin/cake -c test"
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
