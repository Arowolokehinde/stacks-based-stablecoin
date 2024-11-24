# Stacks-Based Stablecoin: Comprehensive README

## Overview

The Stacks-Based Stablecoin project implements a decentralized, collateralized stablecoin on the Stacks blockchain. It ensures stability by pegging its value to an external currency (USD), backed by collateralized STX tokens. This smart contract leverages decentralized price feeds and implements robust mechanisms for minting, burning, and liquidating the stablecoin to ensure stability and security.

## Features

- **Collateralization Mechanism**: Maintain a collateralization ratio to ensure the stablecoin's backing.
- **Liquidation Mechanism**: Liquidates under-collateralized positions to safeguard the system.
- **Stability Fee**: A fee applied to outstanding debt, collected periodically.
- **Dynamic Supply**: Users can mint and burn stablecoins based on their STX collateral and debt.
- **Price Feed Integration**: Fetches the STX/USD price from a decentralized oracle.

## Contract Constants

- **CONTRACT_OWNER**: The creator/owner of the contract.
- **PRICE_FEED_CONTRACT**: The contract sproviding STX/USD price data.
- **collateralization-ratio**: Minimum collateralization ratio (default: 150%).
- **liquidation-ratio**: Threshold ratio for liquidation (default: 120%).
- **stability-fee**: Daily interest rate applied to outstanding debt (default: 1%).
- **total-supply**: Tracks the total amount of stablecoin in circulation.

## Key Components

### Data Structures

- **Vaults**: Tracks individual user vaults with:
    - **collateral**: Amount of STX collateralized.
    - **debt**: Amount of stablecoin debt.
    - **last-fee-update**: Block height of the last stability fee application.

### Public Functions

- **Initialize Contract**:
    - `initialize (initial-stx-price uint)`: Initializes the contract with an initial STX price.

- **Mint Stablecoin**:
    - `mint (amount uint)`: Mints stablecoins by locking collateralized STX tokens.

- **Burn Stablecoin**:
    - `burn (amount uint)`: Burns stablecoins and releases the equivalent collateral.

- **Add Collateral**:
    - `add-collateral (amount uint)`: Adds STX collateral to an existing vault.

- **Remove Collateral**:
    - `remove-collateral (amount uint)`: Removes collateral, ensuring the collateralization ratio remains valid.

- **Liquidate Vaults**:
    - `liquidate (user principal)`: Liquidates vaults that fall below the liquidation ratio.

- **Stability Fee Management**:
    - `update-stability-fee (new-fee uint)`: Updates the global stability fee (owner-only).
    - `collect-stability-fee`: Collects stability fees from a user's debt.

- **Block Height Management**:
    - `set-block-height (new-height uint)`: Allows the contract owner to simulate block height changes for testing.

- **Price Fetching**:
    - `get-stx-price`: Fetches the current STX price from the price feed.

- **Collateral Ratio Calculation**:
    - `get-collateral-ratio (user principal)`: Computes the collateral ratio of a user's vault.

## Error Codes

- **ERR_UNAUTHORIZED (u100)**: Unauthorized access.
- **ERR_INSUFFICIENT_COLLATERAL (u101)**: Insufficient collateral for minting.
- **ERR_INSUFFICIENT_BALANCE (u102)**: Insufficient balance to burn stablecoin.
- **ERR_INVALID_AMOUNT (u103)**: Invalid input amount.
- **ERR_BELOW_LIQUIDATION_RATIO (u104)**: Removal of collateral would breach liquidation ratio.

## Usage Examples

### Minting Stablecoins

```clarity
(mint u100) ;; Mints 100 stablecoins by locking collateralized STX
```

### Burning Stablecoins

```clarity
(burn u50) ;; Burns 50 stablecoins, releasing equivalent collateral
```

### Adding Collateral

```clarity
(add-collateral u5000000) ;; Adds 5 STX to the user's collateral
```

### Liquidating a Vault

```clarity
(liquidate 'SP1234567890) ;; Liquidates an under-collateralized vault
```

## Testing

### Unit Tests

- Minting and burning functionality.
- Liquidation and stability fee calculation.

### Integration Tests

- Interaction with the price feed.
- Multi-user vault operations.

### Edge Cases

- Vault under-collateralization.
- Stability fee collection over extended periods.

## Future Enhancements

- Integration with additional price feeds for redundancy.
- Support for multiple collateral types.
- Enhanced liquidation mechanisms with partial debt recovery.

## Security Considerations

- Ensure the price feed contract is trusted and secure.
- Regular audits of the smart contract.
- Implement safeguards against excessive minting.

This README provides an overview of the Stacks-Based Stablecoin. For detailed implementation and testing guidelines, refer to the code comments and documentation.