{make_esc} = require 'iced-error'
recharge = require('../../src/recharge')
btcjs = require('keybase-bitcoinjs-lib')

exports.test_marginal_fee_estimator = (T,cb) ->
  esc = make_esc cb, "test_marginal_fee_estimator"
  r = new recharge.Runner

  opts = {type: 'bitcoin',  maxClearanceMins: '1000'}

  await r.marginal_fee_estimator opts, esc defer(fee)
  T.assert typeof fee == "number", "Fee is a number"
  T.assert fee > 0, "Fee is positive"
  
  alt_opts = {type: 'altcoin',  maxClearanceMins: '1000'}
  await r.marginal_fee_estimator alt_opts, defer(err,fee)
  T.assert err?, "got an error back"
  T.assert (err.message.indexOf('Unknown cryptocurrency altcoin') >= 0), "found right error message"
  
  cb()

exports.test_fee_estimator = (T,cb) ->
  esc = make_esc cb, "test_fee_estimator"
  r = new recharge.Runner

  opts = {
      type: 'bitcoin',
      maxClearanceMins: 1000,
      tx: new btcjs.Transaction,
      feePerByteLimit: 1000,
      padding: 1.1
  }

  await r.fee_estimator opts, esc defer fee
  T.assert typeof fee == "number", "Fee is a number"
  T.assert fee > 0, "Fee is positive"
  
  alt_opts = {
      type: 'bitcoin',
      maxClearanceMins: 1000,
      tx: new btcjs.Transaction,
      feePerByteLimit: 0,
      padding: 1.1
  }
  await r.fee_estimator alt_opts, esc defer fee
  T.assert fee == 0, "Limit overrides data from API"
  
  cb()
