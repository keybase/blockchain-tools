
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
{a_json_parse} = require('iced-utils').util
btcjs = require 'keybase-bitcoinjs-lib'
{Client} = require 'bitcoin'

#====================================================================================

exports.Runner = class Runner 

  #-----------------------------------

  constructor : () ->
    @config = {}
    @bitcoin_config = {}

  #-----------------------------------

  parse_args : (argv, cb) -> 
    @args = minimist argv, {
      alias :
        c : 'config'
        d : 'data'
        k : 'key'
        a : 'amount'
        l : 'data-log'
        b : 'bitcoin-config'
        u : 'bitcoin-user'
        p : 'bitcoin-password'
      string : [ 'a', 'l', 'b' ]
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

  read_bitcoin_config : (cb) ->
    esc = make_esc cb, "Runner:read_bitcoin_config"
    f = @cfg('bitcoin-config')
    if (p = @cfg('bitcoin-password'))? and (u = @cfg('bitcoin-user'))?
      @bitcoin_config.rpcuser = u
      @bitcoin_config.rpcpassword = p
    else if not(f?)
      f = path.join process.env.HOME, ".bitcoin", "bitcoin.conf"
    if f?
      await fs.readFile f, esc defer dat
      lines = dat.toString('utf8').split /\n+/
      for line in lines
        [a,v] = line.split /\s*=\s*/
        @bitcoin_config[a] = v
    cb null

  #-----------------------------------

  get_amount : () ->
    @cfg('amount') or (btcjs.networks.bitcoin.dustThreshold+1)

  #-----------------------------------

  make_bitcoin_client : (cb) ->
    esc = make_esc cb, "Runner::make_bitcoin_client"
    await @read_bitcoin_config esc defer()
    cfg = {
      user : @bitcoin_config.rpcuser
      pass : @bitcoin_config.rpcpassword
    }
    @client = new Client cfg
    cb null

  #-----------------------------------

  find_transaction : (cb) ->
    cb null


  #-----------------------------------

  run : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @parse_args argv, esc defer()
    await @read_config esc defer()
    await @make_bitcoin_client esc defer()
    await @find_transaction esc defer()
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
