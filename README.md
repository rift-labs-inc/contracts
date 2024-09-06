# contracts

### Deploy
```
source .env && forge script --chain sepolia scripts/DeployRiftExchange.s.sol:DeployRiftExchange --rpc-url $SEPOLIA_RPC_URL --broadcast --sender $SEPOLIA_SENDER --private-key $SEPOLIA_PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_API_KEY 
```

