# PhantomJS QUnit Test Runner
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
          # if there are still things to process on the QUnit queue, we are not done
          stats = page.evaluate(-> return QUnit.config.stats if (QUnit.config.queue.length==0) )
          return if not stats # not done

          clearInterval(interval)
          code = if (stats.bad > 0) then 1 else 0
          console.log("phantomjs-qunit-runner.js: exiting (#{code})") unless silent
          phantom.exit(code)
      ), 500)
  )
catch e
  console.error("QUnit exception: #{e}")
  phantom.exit(1)