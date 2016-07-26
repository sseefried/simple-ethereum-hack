#!/bin/bash

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATADIR=$THIS_DIR/data
#############


GETH="$HOME/code/eth/go-ethereum/build/bin/geth --datadir $DATADIR"
rm -rf $DATADIR
mkdir -p $DATADIR
ID="SeanGeth"
NETID=1000
LOG=mining-node.log

################

function getAddr {
  RES=$($GETH --password password.txt account import $1)
  echo "$RES" | sed 's/^[^{]*{\([a-f0-9]*\)}.*$/\1/'
}

echo "[+] Creating genesis block" | tee $LOG
$GETH init ./genesis.json 2>&1 | tee -a $LOG
echo "test" > password.txt
echo >> password.txt


COINBASE_ADDR=$(getAddr coinbase.key)
STEAL_ADDR=$(getAddr stealy.key)

echo "[+] Creating accounts" | tee -a $LOG
echo "coinbase: $COINBASE_ADDR" > addresses.txt
echo "stealy:"  $STEAL_ADDR >> addresses.txt
cat addresses.txt | tee -a $LOG

echo
echo
echo

$GETH \
  --identity=$ID  \
  --port=30303   \
  --rpc \
  --etherbase $COINBASE_ADDR \
  --rpcapi "admin,db,eth,debug,miner,net,shh,txpool,personal,web3" \
  --rpcport=8545 \
  --rpccorsdomain='*' \
  --networkid $NETID \
  --mine \
  --minerthreads 1 \
  --nodiscover \
  --ipcapi \
  --maxpeers 0 \
  --nat "any" \
  --autodag \
  --unlock "$ADDR" \
  --password ./password.txt \
  console 2>&1 | tee -a $LOG
