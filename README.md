# contracts

### Deploy Rift Exchange to Holesky Testnet
```
source .env && forge script --chain holesky scripts/DeployRiftExchange.s.sol:DeployRiftExchange --rpc-url $HOLESKY_RPC_URL --broadcast --sender $TESTNET_SENDER --private-key $TESTNET_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY --ffi -vvvv
```


### Deploy Rift Exchange to Arbitrum Sepolia Testnet
```
source .env && forge script --chain arbitrum-sepolia scripts/DeployRiftExchange.s.sol:DeployRiftExchange --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --sender $TESTNET_SENDER --private-key $TESTNET_PRIVATE_KEY --verify --etherscan-api-key $ARBITRUM_SEPOLIA_ETHERSCAN_API_KEY --ffi -vvvv
```
