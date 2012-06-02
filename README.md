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
"devDependencies": {
  "coffee-script": ">=1.3.3",
  "easy-bake": ">=0.1.0"
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
  minimize: true
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
require('easy-bake')('easy-bake-config.yaml')
```

And that's it! You will have access to the following cake commands and options in your projects...

Commands Supplied by EasyBake
-----------------------

1. 'cake clean' - cleans the project of all compiled files
2. 'cake build' - performs a single build
3. 'cake watch' - automatically scans for and builds the project when changes are detected
3. 'cake test' - cleans, builds, and runs tests. Note: the tests require installing phantomjs: ('brew install phantomjs' or http://phantomjs.org/)

Options:

1. '-c' or '--clean'  - cleans the project before running a new command
2. '-w' or '--watch'  - watches for changes
3. '-s' or '--silent' - does not output messages to the console (unless errors occur)
4. '-p' or '--preview' - preview the action


Testing
-----------------------
EasyBake is designed to use phantomjs but you will need to install it yourself since there is no npm package for it. Look here for the instructions: http://phantomjs.org/

Also, if you are using TravisCI, you should add something like this to your project.json file:

```
"scripts": {
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
      timeout: 60000
      runner: phantomjs-qunit-runner.js
```

by default, easy-bake looks for .html files in each each directory like, but you can list files individually if you like:

```
some_testing_group:
  ...
  options:
    test:
      timeout: 60000
      runner: phantomjs-qunit-runner.js
    files:
      - **/*.html
```


**Note:** currently the library only has a test-runner for phantomjs-qunit-runner.js and phantomjs-jasmine-runner.js. Feel free to add more and to submit a pull request.


Building the library
-----------------------

###Installing:

1. install node.js: http://nodejs.org
2. install node packages: (sudo) 'npm install'

###Commands:

1. 'cake clean' - cleans the project of all compiled files
2. 'cake build' - performs a single build
3. 'cake watch' - automatically scans for and builds the project when changes are detected