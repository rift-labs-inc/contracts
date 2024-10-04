# contracts

### Deploy Rift Exchange to Arbitrum Sepolia Testnet
```
npm i @openzeppelin/upgrades-core@1.39.0 -g
source .env && forge clean && forge build --via-ir && forge script --chain arbitrum-sepolia scripts/DeployRiftExchange.s.sol:DeployRiftExchange --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --broadcast --sender $SENDER --private-key $SENDER_PRIVATE_KEY --verify --etherscan-api-key $ARBITRUM_ETHERSCAN_API_KEY --ffi -vvvv --via-ir
```

### Deploy Rift Exchange To Arbitrum Mainnet
```
npm i @openzeppelin/upgrades-core@1.39.0 -g

source .env && forge clean && forge build --via-ir && forge script --chain arbitrum scripts/DeployRiftExchange.s.sol:DeployRiftExchange --rpc-url $ARBITRUM_RPC_URL --broadcast --sender $SENDER --private-key $SENDER_PRIVATE_KEY --verify --etherscan-api-key $ARBITRUM_ETHERSCAN_API_KEY --ffi -vvvv --via-ir
```

### Tests
```
forge test --via-ir
```