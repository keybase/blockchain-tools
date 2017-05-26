
{make_esc} = require 'iced-error'
minimist = require 'minimist'
path = require 'path'
fs = require 'fs'
log = require 'iced-logger'
request = require 'request'
{a_json_parse} = require('iced-utils').util
btcjs = require 'keybase-bitcoinjs-lib'
{Client} = require 'bitcoin'

#====================================================================================

exports.SATOSHI_PER_BTC = SATOSHI_PER_BTC = 100 * 1000 * 1000

# Source: https://bitcoin.stackexchange.com/questions/1195/how-to-calculate-transaction-size-before-sending
exports.SUP_MIN_TX_SIZE = SUP_MIN_TX_SIZE = 1*148 + 1*34 + 10 + 1

exports.pexpand = pexpand = (p) -> p?.replace /~/g, process.env.HOME

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
      m : 'min-confirmations'
      d : 'debug'
      v : 'verbose'
    string : [ ]
  }

  #-----------------------------------

  read_and_parse_json : (f, cb) ->
    esc = make_esc cb, "Base::read_and_parse_json"
    await fs.readFile f, esc defer dat
    await a_json_parse dat.toString('utf8'), esc defer out
    cb null, out

  #-----------------------------------

  # Can either pass a split argument vector, or parsed argument array.
  parse_args : (argv, cb) ->
    if (typeof(argv) is 'object') and Array.isArray(argv)
      @args = minimist argv, @get_opts()
    else
      @args = argv
    cb null

  #-----------------------------------

  cfg : (k) -> @args[k] or @config[k]
  pcfg : (k) -> pexpand @cfg(k)

  #-----------------------------------

  tcfg : (k, def, typename, coercer, coercionChecker) ->
    v = @config[k] unless (@args? and v = @args[k])?
    if not v? then def
    else if typeof(v) is typename then v
    else if coercionChecker(v = coercer(v)) then null
    else v

  #-----------------------------------

  icfg : (k, def = null) ->
    @tcfg(k, def, 'number', ((x) -> parseInt(x, 10)), isNaN)

  #-----------------------------------

  fcfg : (k, def = null) ->
    @tcfg(k, def, 'number', parseFloat, isNaN)

  #-----------------------------------

  bcfg : (k, def = null) ->
    @tcfg(k, def, 'boolean', ((b) -> b == 'true'), (k)->false)

  #-----------------------------------

  read_config : (cb) ->
    err = null
    if (f = pexpand @args.config)?
      await @read_and_parse_json f, defer err, @config
    cb err

  #-----------------------------------

  read_bitcoin_config : (cb) ->
    esc = make_esc cb, "Runner:read_bitcoin_config"
    f = @pcfg('bitcoin-config')
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

  # Each Bitcoin transaction needs to be at least dustThresold satoshis
  # for the network to accept it, otherwise the network considers it spam
  # ("dust")
  amount : () -> @icfg('amount', btcjs.networks.bitcoin.dustThreshold+1)
  account : () -> @cfg('account')
  debug : () -> @bcfg('debug')
  verbose : () -> @bcfg('verbose', false)
  logging : () -> @debug() or @verbose()

  fee_per_byte_limit : () -> @icfg('fee-per-byte-limit')
  max_clearance_minutes : () -> @icfg('max-clearance-minutes')
  padding : () -> @fcfg('padding')
  min_confirmations : () -> @icfg('min-confirmations', 3)
  # each small transaction is roughly 180B, so we pay for that plus dust
  min_amount : () -> @amount() + @marginal_fee_per_byte * SUP_MIN_TX_SIZE

  # Some reasonable lower bound on the total cost to transact a 1 input/1output transaction
  # Assuming bitcoin tx fees won't go up 33% in one week
  abs_min_amount : () -> @amount() + @marginal_fee_per_byte * SUP_MIN_TX_SIZE * .75
  # Some reasonable upper bound on the total cost to transact a 1 input/1output transaction
  max_amount : () -> 2 * @marginal_fee_per_byte * SUP_MIN_TX_SIZE

  #-----------------------------------

  aget : (o, k, cb) ->
    if k of o
      return cb null, o[k]
    cb new Error('''Key #{k} not found in object.'''), null

  aassert : (x, cb) ->
    if x == true then cb null else cb new Error('Assertion failed.')

  #-----------------------------------

  # Estimates fee per byte for a specific network type needed to achieve
  # verification before maxClearanceMinutes minutes For bitcoin, returns in
  # satoshis and uses the 21.co API with no fallback.
  marginal_fee_per_byte_estimator: ({type, maxClearanceMinutes}, cb) ->
    esc = make_esc cb,'marginal_fee_per_byte_estimator'
    if type == 'bitcoin'
      apiUrl = 'https://bitcoinfees.21.co/api/v1/fees/list'
      await request apiUrl, esc defer resp, body
      if resp.statusCode == 200
        await a_json_parse body, esc defer body_json
        await @aget body_json, 'fees', esc defer fees
        currentClearanceMinutes = 10000
        await @aassert Array.isArray(fees), esc defer()
        for fee in fees when currentClearanceMinutes >= maxClearanceMinutes
          await @aget fee, 'maxMinutes', esc defer currentClearanceMinutes
          await @aget fee, 'maxFee', esc defer currentFee
          await @aassert Number.isFinite(currentClearanceMinutes), esc defer()
          await @aassert Number.isFinite(currentFee), esc defer()
        cb null, currentFee
      else if resp.statusCode == 429
        cb new Error("API limit has been reached"), 0
    else if type == 'litecoin'
      cb null, 100
    else
      cb new Error("Unknown cryptocurrency " + type), 0

  # Estimates fee needed to send a transaction based on
  # the parameters in @marginal_fee_per_byte_estimator, capped by
  # feePerByteLimit and multiplied by padding.
  fee_estimator : ({tx}, cb) ->
    feePerByte = Math.min @fee_per_byte_limit(), @marginal_fee_per_byte
    byteSize = tx.toBuffer().length
    return feePerByte * byteSize * @padding()

  initialize_marginal_fee_per_byte_estimate : (cb) ->
    esc = make_esc cb,'fee_estimator'
    opts = {
        type: 'bitcoin',
        maxClearanceMinutes: @max_clearance_minutes()
    }
    await @aassert opts.maxClearanceMinutes?, esc defer()
    await @marginal_fee_per_byte_estimator opts, esc defer @marginal_fee_per_byte
    if @logging()
      console.log "Initialized marginal_fee_per_byte at", @marginal_fee_per_byte
    cb null

  satoshi_conversion_estimator : (cb) ->
    esc = make_esc cb,'satoshi_conversion_estimator'
    apiUrl = 'https://blockchain.info/ticker'
    await request apiUrl, esc defer resp, body
    if resp.statusCode == 200
      await a_json_parse body, esc defer body_json
      cb null, body_json.USD['15m'] / SATOSHI_PER_BTC
    else
      cb new Error("Unknown API error"), 0

  initialize_satoshi_conversion_estimate : (cb) ->
    esc = make_esc cb,'initialize_satoshi_conversion_estimate'
    await @satoshi_conversion_estimator esc defer @usd_per_satoshi
    if @logging()
      console.log "Initialized usd_per_satoshi at", @usd_per_satoshi
    cb null

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
    if @logging()
      console.log("Found", txs.length, "unspent transactions")
    best_tx = null
    best_waste = null
    for tx in txs
      if @logging()
        console.log "--------"
        console.log "Considering tx", tx
      if not (waste = @is_good_input_tx(tx))? then
        if @logging()
          console.log "Rejected because was not good."
      else if not(best_waste?) or waste < best_waste
        if @logging()
          console.log "Replacing best_tx with this tx."
          console.log "Previous waste", best_waste
          console.log "New waste", waste
        best_tx = tx
        best_waste = waste
      if @logging()
        console.log "-------"
    if best_tx?
      @input_tx = best_tx
      if @logging()
        console.log "Found best tx", best_tx
    else
      err = new Error "Couldn't find spendable input transaction"
    cb err

  #-----------------------------------

  init : (argv, cb) ->
    esc = make_esc cb, "Runner::main"
    await @parse_args argv, esc defer()
    await @read_config esc defer()
    await @check_args esc defer()
    await @make_bitcoin_client esc defer()
    await @initialize_marginal_fee_per_byte_estimate esc defer()
    await @initialize_satoshi_conversion_estimate esc defer()
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
