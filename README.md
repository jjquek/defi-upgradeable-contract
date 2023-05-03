# Upgradeable Proxy Contract

## Overview

This repository contains the source code and files for my upgradeable proxy contract developed using OpenZeppelin packages and the truffle framework.

It can be found at...

## Main Features

### Upgradeable
- Implements the Transparent Proxy pattern using OpenZeppelin's upgrade plugins

### Role-Based Access Control
- Address that deploys the proxy contract is designated the sole `MANAGER`
- `MANAGER` can set other addresses as `USER`
- Only `USER`s can make deposits of ethers and ERC20. (***caveat***: the `MANAGER` handles depositing `USER` ERC20; this is to guard against spurious addresses being passed in to the `depositERC20` function.)

### Users Can:
- Deposit/Withdraw ethers
- Deposit/Withdraw ERC20 tokens
- View USD value of their deposited funds

### Managers Can:
- Swap deposited ERC20 tokens on UniswapV2 for users
- Stake ethers for stEth on Lido for users
- View the USD value of all deposited ERC20 tokens
<!-- todo : insert a table here for reference -->

## Challenges/Further Work

- Test coverage must be extended.

