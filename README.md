# UpgradeableProxy Contract

This repository contains the source code for the Upgradeable Proxy Contract I deployed on the Goerli Testnet.

## Overview

In this README.md, I provide an overview of the design and functionality of the contract. I also document the reasons for specific implementation decisions where such comments would bloat the source file for the Contract. These comments are organised according to the various 'sections' of the contract's source code.

## The Aim of the Contract

I designed the contract to facilitate something akin to an active fund for deposited Ether and ERC20 tokens. 

The sole Manager who deploys the contract acts as an intermediary between depositors (users in the contract's terminology) and Uniswap and the Lido protocol. The contract allows for users to deposit their ether or ERC20 tokens to be managed by the Manager. The Manager uses deposited funds to swap and stake on the aforementioned protocols for gains. The dollar value of deposited assets can be calculated and read by invoking the contract.

More details on the implementation details and decisions I made can be found [below](#implementation-decisions).

## Implementation Decisions

### Tools Used / Dependencies

The various dependencies of the project can be broadly categorised into:
- Implementation Utilities
- Testing Utilities

Implementation Utilties stem mainly from OpenZeppelin; other implementation utilities consist of packages/APIs exposed by the various protocols involved with our functionality (e.g. contract instances from Uniswap). Testing Utilities include Truffle, Chai, and the Web3 library.

### Source Code 

#### Writing Upgradeable Contracts

#### State Structure

#### Viewability

#### Depositing

#### Withdrawing

#### Trades/Swapping

#### Staking

#### Dollar Value Calculation
