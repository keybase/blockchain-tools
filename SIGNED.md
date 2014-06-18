##### Signed by https://keybase.io/max
```
-----BEGIN PGP SIGNATURE-----
Version: GnuPG/MacGPG2 v2.0.22 (Darwin)
Comment: GPGTools - https://gpgtools.org

iQEcBAABCgAGBQJTod7OAAoJEJgKPw0B/gTfX/UH/jdPKTtwKG5XmmzzitYTAuH8
Og9VqgIsXS4vFjl/I6jou/lvzngqALevoqNJf9U/1S1lvT3aCtNrq8GPxWdQMfF4
he/xag2qnrE67RctiJp6u4/GC0zOCgVBZJtBgqxY3e+DhsBV4trHSjphXQ8VjGGl
t4AlGM/yaB2ggrNcZ4pEedtUqQ69OnJnRYVW55MHZKI1t+3LtN08EJ6b5j18ChXW
13w5HexOgLaXa8P6lY/zmtfigANyuX6Q779JW0VnMr8NwF/5wT0+IY/7pqcp9pV6
KF2VMW6ETam2udlsYBVXMcNFOh/5I4HMY1/IsxnGHFc5GhiYaAg+ExCOMKn6SoQ=
=S1Ps
-----END PGP SIGNATURE-----

```

<!-- END SIGNATURES -->

### Begin signed statement 

#### Expect

```
size  exec  file                          contents                                                        
            ./                                                                                            
535           .gitignore                  41489da3af786911e0781bf2240573daab3af7fe28bc4220a2c875e4264c5788
1483          LICENSE                     2f688b5985f030e90164903606040718badaf4691285d62e65269afeb3d9808d
109           README.md                   1dd1a441085fba0197389ac5139e13aa1a9cb5ee04ade2e689d7507ddbba3931
              bin/                                                                                        
95    x         insert                    95488dc68859f1846b6d444bda7045980d3e36c3da96da859d6be9a62b378df8
108   x         insert-keybase-root       505a4955f77bf6b442e79ebc75fb077eecac36bd627e0ec7d6fbba39eeaee4c3
97    x         recharge                  eee73645e13b447443c41ca242f639f4ee0359be91191fe4840c9ec46bdb7072
              conf/                                                                                       
280             keybase.json              4a2c59897141b0d2f12b8f576f72b5c5cf009b3e5f52ba81b0c8eed239269278
924           package.json                854af05f4d2e97ad30436db4fb6519428501a7e9b83a0aa6399c0d3c43803024
              src/                                                                                        
4389            base.iced                 f6321c96b34f7f2b76cc229906d0049e70c25e4883454c85830d76f1ef31acf3
3346            insert.iced               56125fd69c050aefbac27474cff84978be19d6b8c193d3a4f16e8e3aa68d9193
2901            insert_keybase_root.iced  1e2ce34a6475de6520bc4594f406b73c027a484aea61af7ccd30f8eb24597c3b
4200            recharge.iced             874bf3688e951b56d071c8f2debaf26870762d08a8fb7aca5236166e3d5cbe2c
```

#### Ignore

```
/SIGNED.md
```

#### Presets

```
git      # ignore .git and anything as described by .gitignore files
dropbox  # ignore .dropbox-cache and other Dropbox-related files    
kb       # ignore anything as described by .kbignore files          
```

<!-- summarize version = 0.0.9 -->

### End signed statement

<hr>

#### Notes

With keybase you can sign any directory's contents, whether it's a git repo,
source code distribution, or a personal documents folder. It aims to replace the drudgery of:

  1. comparing a zipped file to a detached statement
  2. downloading a public key
  3. confirming it is in fact the author's by reviewing public statements they've made, using it

All in one simple command:

```bash
keybase dir verify
```

There are lots of options, including assertions for automating your checks.

For more info, check out https://keybase.io/docs/command_line/code_signing