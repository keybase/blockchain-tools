
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
{a_json_parse} = require('iced-utils').util

#====================================================================================

exports.Runner = class Runner 

  #-----------------------------------

  constructor : () ->
    @config = {}

  #-----------------------------------

  parse_args : (argv, cb) -> 
    @args = minimist argv, {
      alias :
        c : 'config'
        d : 'data'
        k : 'key'
        a : 'amount'
      string : [ 'a' ]
    }
    cb null

  #-----------------------------------

  cfg : (k) -> @args[k] or @config[k]

  #-----------------------------------

  read_config : (cb) ->
    esc = make_esc cb, "Runner::read_config"
    if (f = @args.config)?
      await fs.readFile f, esc defer dat
      await a_json_parse dat.toString('utf8'), esc defer @config
    cb null

  #-----------------------------------

  run : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @parse_args argv, esc defer()
    await @read_config esc defer()
    #await @find_transaction esc defer()
    #await @find_post_data esc defer()
    #await @get_private_key esc defer()
    #await @make_transaction esc defer()
    #await @submit_transaction esc defer()
    cb null

  #-----------------------------------

#====================================================================================

exports.run = () ->
  r = new Runner
  await r.run process.argv[2...], defer err
  rc = 0
  if err?
    log.error err.message
    rc = err.rc or 2
  process.exit rc

#====================================================================================
