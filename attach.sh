THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATADIR=$THIS_DIR/data
########

GETH="$HOME/code/eth/go-ethereum/build/bin/geth"
$GETH attach http://localhost:8545

