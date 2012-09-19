fs = require 'fs'
path = require 'path'
existsSync = fs.existsSync || path.existsSync

MAX_MESSAGE_LENGTH = 128

# helpers
timeLog = (message) -> console.log("#{(new Date).toLocaleTimeString()} - #{message}")

String::startsWith = (start) ->
  return @indexOf(start) is 0

String::endsWith = (end) ->
  return @indexOf(end) is @length - end.length