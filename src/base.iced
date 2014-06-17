
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
{a_json_parse} = require('iced-utils').util
btcjs = require 'keybase-bitcoinjs-lib'
{Client} = require 'bitcoin'

#====================================================================================

exports.SATOSHI_PER_BTC = 100 * 1000 * 1000

#====================================================================================

exports.Base = class Base

  #-----------------------------------

  constructor : () ->
    @config = {}
    @bitcoin_config = {}
    @input_tx = null

  #-----------------------------------

  get_opts_base : () -> {
    alias : 
      c : 'config'
      a : 'amount'
      A : 'account'
      b : 'bitcoin-config'
      u : 'bitcoin-user'
      p : 'bitcoin-password'
      n : 'confirmations'
    string : [ ]
  }

  #-----------------------------------

  parse_args : (argv, cb) -> 
    @args = minimist argv, @get_opts()
    cb null

  #-----------------------------------

  cfg : (k) -> @args[k] or @config[k]

  #-----------------------------------

  icfg : (k, def = null) ->
    v = @config[k] unless (v = @args[k])?
    if not v? then def
    else if typeof(v) is 'number' then v
    else if isNaN(v = parseInt(v, 10)) then null
    else v

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

  amount : () -> @icfg('amount', btcjs.networks.bitcoin.dustThreshold+1)
  account : () -> @cfg('account') 
  min_amount : () -> @amount() + btcjs.networks.bitcoin.feePerKb - 800
  max_amount : () -> 2*btcjs.networks.bitcoin.feePerKb
  min_confirmations : () -> @icfg('confirmations', 3)

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
    esc = make_esc cb, "Runner::find_transaction"
    await @client.listUnspent esc defer txs
    best_tx = null
    best_waste = null
    for tx in txs
      if not (waste = @is_good_input_tx(tx))? then # noop
      else if not(best_waste?) or waste < best_waste
        best_tx = tx
        best_waste = waste
    if best_tx?
      @input_tx = best_tx
    else
      err = new Error "Couldn't find spendable input transaction"
    cb err


  #-----------------------------------

  init : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @parse_args argv, esc defer()
    await @read_config esc defer()
    await @check_args esc defer()
    cb null

  #-----------------------------------

#====================================================================================

exports.run = (klass) ->
  r = new klass
  await r.run process.argv[2...], defer err
  rc = 0
  if err?
    log.error err.message
    rc = err.rc or 2
  process.exit rc

#====================================================================================
