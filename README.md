# contracts

### Deploy to Rift Exchange to Holesky 
```
source .env && forge script --chain holesky scripts/DeployRiftExchange.s.sol:DeployRiftExchange --rpc-url $HOLESKY_RPC_URL --broadcast --sender $TESTNET_SENDER --private-key $TESTNET_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --ffi -vvvv
```

