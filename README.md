# Upgradeable Proxy Contract

![Screenshot of Etherscan record of deployed upgradeable proxy](https://user-images.githubusercontent.com/96500919/235949491-350da30b-931f-44a5-96e2-383d2fffaaaf.png)

## Overview

This repository contains the source code and files for my upgradeable proxy contract developed using [OpenZeppelin Contracts](https://docs.openzeppelin.com/)  and the [Truffle framework](https://trufflesuite.com/blog/a-sweet-upgradeable-contract-experience-with-openzeppelin-and-truffle/)
The upgradeable proxy is available on the Goerli testnet at this address: `0x26776BDBF78b300BFeeD22A498f6747bf698aFcb`. It can be viewed on [Etherscan](https://goerli.etherscan.io/address/0x26776BDBF78b300BFeeD22A498f6747bf698aFcb).

It's implementation contraction is at this address: `0xdfC01330214c0613C2548E600c696bA909FFd098` 
The ProxyAdmin contract is at this address: `0x858A7F835030B53AaC0D3619cd56f2F012035116` 

Like the upgradeable proxy, they can be viewed on Etherscan by searching their addresses.

For more information on the proxy upgrade pattern, see [this](https://docs.openzeppelin.com/learn/upgrading-smart-contracts).

For how to actually facilitate an upgrade using Truffle and Gnosis Safe, see [this](https://forum.openzeppelin.com/t/openzeppelin-upgrades-step-by-step-tutorial-for-truffle/3579) 

## Run Locally

First, install the dependencies by running

```
npm i
```

Then, start the dev environment by running

```
truffle develop
```

Truffle commands can be issued without the `truffle` prefix whilst `truffle develop` runs.

To deploy, run

```
migrate
```

## Main Features

### Upgradeable

- Implements the Transparent Proxy pattern using OpenZeppelin's upgrade plugins

### Role-Based Access Control

- Address that deploys the proxy contract is designated the sole `MANAGER`
- `MANAGER` can set other addresses as `USER`
- Only `USER`s can make deposits of ethers and ERC20. (**_caveat_**: the `MANAGER` handles depositing `USER` ERC20; this is to guard against spurious addresses being passed in to the `depositERC20` function.)

### Users Can:

- Deposit/Withdraw ethers
- Deposit/Withdraw ERC20 tokens
- View USD value of their deposited funds

### Managers Can:

- Swap deposited ERC20 tokens on [UniswapV2](https://uniswap.org/) for users
- Stake ethers for stEth on [Lido](https://docs.lido.fi/) for users
- View the USD value of all deposited ERC20 tokens using [Chainlink's Price Feed](https://docs.chain.link/data-feeds/price-feeds/addresses/?network=ethereum#Goerli%20Testnet)

## Reflections/Further Work

- **Greater Test Coverage** 

Testing beyond basic access control and ether depositing, we should try to validate the Manager functions in particular. On reflection, TDD/BDD would've been a better approach.

- **Systems Thinking** 

I should have considered the contract functionality as a 'whole system' in the initial stages of my planning as to better define how funds would flow in and out of the contract.

- **Hardhat Over Truffle** 

Should have used Hardhat instead of Truffle e.g. for ease of [running automated tests on a fork of mainnet](https://stackoverflow.com/questions/70965282/how-do-i-interact-with-uniswap-v2-in-a-truffle-test-suite). This would have been beneficial for testing the `swap` and `stake` functionality, for example.
