from web3 import Web3

errors = [
    "DepositTooLow()",
    "DepositTooHigh()",
    "DepositFailed()",
    "exchangeRateZero()",
    "WithdrawFailed()",
    "LpDoesntExist()",
    "NotVaultOwner()",
    "TooManyLps()",
    "NotEnoughLiquidity()",
    "ReservationAmountTooLow()",
    "InvalidOrder()",
    "NotEnoughLiquidityConsumed()",
    "LiquidityReserved(uint256)",
    "LiquidityNotReserved()",
    "InvalidLpIndex()",
    "NoLiquidityToReserve()",
    "OrderComplete()",
    "ReservationFeeTooLow()",
    "InvalidVaultIndex()",
    "WithdrawalAmountError()",
    "InvalidEthereumAddress()",
    "InvalidBitcoinAddress()",
    "InvalidProof()",
    "InvaidSameExchangeRatevaultIndex()",
    "InvalidVaultUpdate()",
    "ReservationNotExpired()",
    "InvalidUpdateWithActiveReservations()",
    "StillInChallengePeriod()",
    "ReservationNotUnlocked()"
]

# Function to calculate the error selector hash
def get_error_selector(error):
    hashed = Web3.keccak(text=error)
    return hashed.hex()[:10]  # Get the first four bytes (8 hex digits + '0x' prefix)

selectors = {error: get_error_selector(error) for error in errors}

# Print the selectors
for error, selector in selectors.items():
    print(f"{error}: {selector}")

