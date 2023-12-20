# Util [![Github Actions][gha-badge]][gha] [![Hardhat][hardhat-badge]][hardhat] [![License: MIT][license-badge]][license]

[gha]: https://github.com/paulrberg/hardhat-template/actions
[gha-badge]: https://github.com/paulrberg/hardhat-template/actions/workflows/ci.yml/badge.svg
[hardhat]: https://hardhat.org/
[hardhat-badge]: https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

A Solidity implementation of the Util protocol. The protocol is currently deployed on the Rootstock testnet. An interactive frontend can be found at [https://testnet.theutil.org](https://testnet.theutil.org) or built locally using [this repository](https://github.com/joshdoman/util-frontend). Learn more at [https://theutil.org/util.pdf](https://theutil.org/util.pdf)

## Motivation

The internet would benefit from a native monetary system that has price stability. Many argue that bitcoin is the natural basis for this monetary system, but bitcoin's fixed supply makes BTC a poor unit of account, particularly as a [standard of deferred payment](https://en.wikipedia.org/wiki/Standard_of_deferred_payment). As economic conditions change, demand for BTC rises and falls, forcing merchants to update their prices. This is problematic for transactions where payment is due in the future (i.e., wages, subscriptions, purchases made on credit, etc.), which are critical for an economy to flourish.

## What is the Util?

The util is designed to be a stabilizing unit of account for the Bitcoin economy, which can offer price stability and facilitate these types of deferred transactions. This unit of account is entirely opt-in and does not require trusted third parties or changes to the Bitcoin protocol.

### Key Ideas

1. Bitcoin remains the medium of exchange and store of value in the economy.
2. Goods and services are priced in "utils" instead of BTC.
3. Sats map to "utils" through an intermediary unit of account called an "e-bond." The number of "e-bonds" per sat grows at an interest rate $r$, and there are $1/r$ "utils" per e-bond.
4. The interest rate $r$ is continuously set through the relative quantity of two convertible tokens, Tighten and Ease, rather than through token voting or a central authority.
5. The price level in the economy will stabilize if the interest rate equals bitcoin's required real rate of return.

<br/>
<p align="center">
  <img width="735" alt="Screenshot 2023-12-19 at 3 51 36 PM" src="https://github.com/joshdoman/util-solidity/assets/22065307/a3cb5f03-fa67-487b-8494-fa012f83dcac">
</p>

<sup><sub>E-bond icon created by Smashicons - [Flaticon](https://www.flaticon.com/free-icons/stock-market)</sub></sup>

### Use Case

Let's suppose Alice wishes to engage Bob's services for some ongoing work that she needs help with. Both Alice and Bob keep their savings in bitcoin, and they would like to settle their transactions directly in BTC. Rather than pay Bob upfront, however, Alice wishes to pay Bob once each week, with the expectation that the work will last several months.

Bob is open to this arrangement, but he doesn't want to renegogiate his rate with Alice every week. The problem they face is deciding on the unit of account to price the work in. Neither Alice or Bob wants to price the work in fiat (they live in different countries and there is volatile inflation in their home currencies), but pricing the work in BTC is not acceptable to either party. A fixed rate leaves Alice expecting to pay more each week for the same amount of work (since bitcoin's expected real rate of return is non-zero), and bitcoin's fixed supply leaves the value of BTC vulnerable to a positive or negative economic shock, adding risk for both Alice and Bob.

Instead of pricing the work directly in BTC, Alice and Bob agree to price the work in "utils" of BTC, since each "util" is expected to be worth the same in the future as it is today.

<p align="center">
  <img width="710" alt="Screenshot 2023-12-20 at 4 12 00 PM" src="https://github.com/joshdoman/util-solidity/assets/22065307/9e3c36f4-e6c0-49cc-824c-0a593c843aa5">
</p>

The "util" offers price stability because the number of "utils" per BTC expands and contracts in line with bitcoin's value in the "util" economy, if the interest rate $r$ approximates bitcoin's required real rate of return. Holders of Tighten and Ease are incentivized to set $r$ at this rate so that the "util" is competitive as a unit of account (otherwise their holdings have no value). While Alice or Bob could try to change the interest rate by converting between Tighten and Ease, doing so will only have a lasting effect if the new conversion rate reflects the relative market price, which requires building consensus within the wider market.

## Protocol Specification

This protocol is intended to eventually live directly on Bitcoin as a lightweight metaprotocol, akin to the [Runes](https://rodarmor.com/blog/runes/) protocol proposed by Casey Rodarmor. In the short-run, however, due to ease of implementation, it has been implemented as a smart contract on Rootstock, an EVM sidechain merge-mined with Bitcoin. Migrating to a metaprotocol may occur in the future, but it will require a hardfork of Tighten and Ease balances.

### Tighten and Ease

The interest rate $r$ is controlled by the holders of Tighten and Ease by converting between the two tokens. Conversions are governed by the constant sum-of-squares invariant $A^2+B^2=K^2$, where $A$ and $B$ are the outstanding quantity of Tighten and Ease, respectively, and $K$ is some constant before and after the conversion. The current interest rate $r = (A-B)/(A+B)$, but $r = 0$ if $A < B$.

Users can safely convert between Tighten and Ease using the functions `swapExactTokensForTokens` and `swapTokensForExactTokens`.

### Auctions

Tighten and Ease are auctioned off once every 30 minutes. This is done such that the fully converted quantity $K$ increases by 150 each auction, decreasing by 50% every 70,000 auctions. The split between Tighten and Ease matches the relative supply at the time the auction is settled, and the current split can be obtained using the function `mintableAmount`.

Bids are placed using the function `bid`, requiring the transfer of RBTC. For a bid to be valid, it must exceed `currentBid` by 1%. The previous bidder is then refunded.

Auctions are settled using the function `settle`. Anyone can call this function if 30 minutes have elapsed since the last auction was settled. Tighten and Ease are issued to the winning bidder (if present), but if there is no bidder or 35 minutes have elapsed, Tighten and Ease are issued to `msg.sender`. Any RBTC held by the contract is then transferred to `block.coinbase`.

Auctions serve a second purpose: updating the average interest rate. While the number of "e-bonds" per sat grows at the current interest rate $r$, the number of "utils" per "e-bond" is a function of the average interest rate over the previous 8 hours. This is updated each auction using the average interest rate over the previous 16 auctions.

### Quote

The current number of "utils" per sat can be obtained using the function `quote`. The current number of "e-bonds" per sat can be obtained using `latestAccumulator`. To safely transfer "utils" worth of RBTC, users are encouraged to use the `transfer` function in [Util.sol](./contracts/Util.sol).

## Usage

### Pre Requisites

Before being able to run any command, you need to create a `.env` file and set a BIP-39 compatible mnemonic as the `MNEMONIC` environment
variable. You can follow the example in `.env.example`. If you don't already have a mnemonic, you can use this [website](https://iancoleman.io/bip39/) to generate one.

Then, proceed with installing dependencies:

```sh
$ yarn install
```

### Compile

Compile the smart contracts with Hardhat:

```sh
$ yarn compile
```

### TypeChain

Compile the smart contracts and generate TypeChain bindings:

```sh
$ yarn typechain
```

### Test

Run the tests with Hardhat:

```sh
$ yarn test
```

### Lint Solidity

Lint the Solidity code:

```sh
$ yarn lint:sol
```

### Lint TypeScript

Lint the TypeScript code:

```sh
$ yarn lint:ts
```

### Coverage

Generate the code coverage report:

```sh
$ yarn coverage
```

### Report Gas

See the gas usage per unit test and average gas per method call:

```sh
$ REPORT_GAS=true yarn test
```

### Clean

Delete the smart contract artifacts, the coverage reports and the Hardhat cache:

```sh
$ yarn clean
```

### Deploy

Deploy the contracts to Hardhat Network:

```sh
$ yarn deploy
```

## License

[MIT](./LICENSE.md) © Josh Doman
