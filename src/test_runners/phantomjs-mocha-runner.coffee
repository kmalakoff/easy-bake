# PhantomJS Jasmine Test Runner
try
  args = phantom.args
  if (args.length < 1 || args.length > 3)
    console.log("Usage: " + phantom.scriptName + " <URL> <timeout> <silent>")
    phantom.exit(1)

  page_filename = args[0]
  timeout = parseInt(args[1], 10) || 60000
  silent = if args.length >= 2 then !!args[2] else false
  start = Date.now()

  page = require('webpage').create()

  page.onConsoleMessage = (msg) -> console.log(msg) if(msg.indexOf('warning')!=0) # filter warnings

  page.onInitialized = =>
    page.evaluate ->
      class window.MochaReporter
        constructor: (runner) ->
          @failedCount = 0
          @totalCount = 0

          runner.on 'pass', (test) => @totalCount++
          runner.on 'fail', (test, err) => @failedCount++; @totalCount++
          runner.on 'end', =>
            console.log "tests end: #{@totalCount-@failedCount}/#{@totalCount}"
            window.mocha_results = {totalCount: @totalCount, failedCount: @failedCount}

  page.open(page_filename, (status) ->
    if (status != 'success')
      console.error("Unable to access network")
      phantom.exit(1)
    else
      interval = setInterval((->
        if (Date.now() > start + timeout)
          console.error("Tests timed out")
          phantom.exit(124)
        else
          return unless stats = page.evaluate -> window.mocha_results
          clearInterval(interval)

          (phantom.exit(-1); return) if stats.totalCount <= 0 # nothing run
          code = if (stats.failedCount > 0) then 1 else 0
          console.log("phantomjs-mocha-runner.js: exiting (#{code})") unless silent
          phantom.exit(code)
      ), 500)
  )
catch e
  console.error("Mocha exception: #{e}")
  phantom.exit(1)
