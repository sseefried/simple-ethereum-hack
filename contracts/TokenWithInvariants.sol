contract TokenWithInvariants {
  event Log(string msg ,address from, address to, uint value);
  mapping(address => uint) public balanceOf;
  uint public totalSupply;
  /* 1 token = 1 szabo */
  uint public conversion = 1 szabo;

  modifier checkInvariants {
    _
    if (this.balance/conversion < totalSupply) throw;
  }

  /* intentionally vulnerable */
  function deposit(uint amount) checkInvariants {
    Log("deposit", msg.sender, 0x0, amount);
    /* Throw if not enough value has been sent to "buy" token */
    if (msg.value / conversion < amount) throw;
    balanceOf[msg.sender] += amount;
    totalSupply += amount;
  }

  function transfer(address to, uint value) checkInvariants {
    Log("transfer", msg.sender, to, value);
    if (balanceOf[msg.sender] >= value) {
      balanceOf[to] += value;
      balanceOf[msg.sender] -= value;
    }
  }

  /* intentionally vulnerable */
  function withdraw() checkInvariants {
    uint balance = balanceOf[msg.sender];
    Log("withdraw", 0x0, msg.sender, balance);
    if (msg.sender.call.value(balance*conversion)()) {
      totalSupply -= balance;
      balanceOf[msg.sender] = 0;
    }
  }
}