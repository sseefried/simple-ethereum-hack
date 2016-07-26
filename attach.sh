THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DATADIR=$THIS_DIR/data
########

which geth > /dev/null 2>&1
if [ ${PIPESTATUS[0]} -ne 0 ]; then
  echo "Could not find 'geth' on path"
  exit 1
fi

geth attach http://localhost:8545

