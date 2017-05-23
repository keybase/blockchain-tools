{make_esc} = require 'iced-error'
recharge = require('../../src/recharge')
btcjs = require('keybase-bitcoinjs-lib')

exports.test_marginal_fee_per_byte_estimator = (T,cb) ->
  esc = make_esc cb, "test_marginal_fee_per_byte_estimator"
  r = new recharge.Runner

  opts = {type: 'bitcoin',  maxClearanceMinutes: 3600}

  await r.marginal_fee_per_byte_estimator opts, esc defer(fee)
  T.assert typeof fee == "number", "Fee #{fee} is a number"
  T.assert fee > 0, "Fee #{fee} is positive"
  
  alt_opts = {type: 'altcoin',  maxClearanceMinutes: '1000'}
  await r.marginal_fee_per_byte_estimator alt_opts, defer(err,fee)
  T.assert err?, "got an error back"
  T.assert (err.message.indexOf('Unknown cryptocurrency altcoin') >= 0), "found right error message"
  
  cb()

exports.test_fee_estimator = (T,cb) ->
  esc = make_esc cb, "test_fee_estimator"

  r = new recharge.Runner
  r.fee_per_byte_limit = () -> 1000
  r.max_clearance_minutes = () -> 3600
  r.padding = () -> 1
  await r.initialize_marginal_fee_per_byte_estimate esc defer()
  fee = r.fee_estimator {tx:new btcjs.Transaction}
  T.assert typeof fee == "number", "Fee #{fee} is a number"
  T.assert fee > 0, "Fee #{fee} is positive"
  
  r = new recharge.Runner
  r.fee_per_byte_limit = () -> 1000
  r.max_clearance_minutes = () -> 3600
  r.padding = () -> 1.1
  await r.initialize_marginal_fee_per_byte_estimate esc defer()
  fee_padded = r.fee_estimator {tx:new btcjs.Transaction}

  T.assert fee_padded = 1.1 * fee, "padding setting multiplies expected fee"

  r = new recharge.Runner
  r.fee_per_byte_limit = () -> 0
  r.max_clearance_minutes = () -> 3600
  r.padding = () -> 1.1
  await r.initialize_marginal_fee_per_byte_estimate esc defer()
  fee = r.fee_estimator {tx:new btcjs.Transaction}
  T.assert fee == 0, "Limit overrides data from API"
  
  cb()
