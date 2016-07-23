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

# Trace

    personal.unlockAccount("0xc96aaa54e2d44c299564da76e1cd3184a2386b8d")


    eth.sendTransaction({from: "0xc96aaa54e2d44c299564da76e1cd3184a2386b8d", to: "0x5f80f153589d71c91e5937fbee2a198b43be581e", value: 1000000})


    var tiwSource = 'contract TokenWithInvariants {   mapping(address => uint) public balanceOf;   uint public totalSupply;    modifier checkInvariants {     _     if (this.balance < totalSupply) throw;   }    function deposit(uint amount) checkInvariants {     balanceOf[msg.sender] += amount;     totalSupply += amount;   }    function transfer(address to, uint value) checkInvariants {     if (balanceOf[msg.sender] >= value) {       balanceOf[to] += value;       balanceOf[msg.sender] -= value;     }   }    function withdraw() checkInvariants {     uint balance = balanceOf[msg.sender];     if (msg.sender.call.value(balance)()) {       totalSupply -= balance;       balanceOf[msg.sender] = 0;     }   } }'


    var tiwCompiled = web3.eth.compile.solidity(tiwSource)

    var tiwContract = web3.eth.contract(tiwCompiled.TokenWithInvariants.info.abiDefinition);

    var tiw = tiwContract.new({from:web3.eth.accounts[0], data: tiwCompiled.TokenWithInvariants.code, gas: 300000}, function(e, contract){
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
    })


Send some ether to the contract

    eth.sendTransaction({from: "0xc96aaa54e2d44c299564da76e1cd3184a2386b8d", to: <contract address>, value: 1000000})

Now deposit into the contract

    tiw.deposit(100, { from: "0xc96aaa54e2d44c299564da76e1cd3184a2386b8d", gasPrice: 2 })

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