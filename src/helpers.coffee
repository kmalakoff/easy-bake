fs = require 'fs'
path = require 'path'
existsSync = fs.existsSync || path.existsSync

# helpers
timeLog = (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")

String::startsWith = (start) ->
  return this.indexOf(start) is 0