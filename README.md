## Deploy Sepolia Raffle

1. Create a `.env` file in the root directory of the project.
2. Create Makefile in the root directory of the project.
3. Rune `make deploy ARGS="--network sepolia"`.
4. Check VRF Coordinator and Link Token balance in [vrf.chain.link](https://vrf.chain.link/).
    - Create subscription and set it in HelperConfig.sol.
    - Fetch the Link Token on [faucets.chain.link](https://faucets.chain.link/arbitrum-sepolia).
    - Fund subscription. (Not enough links to pay for the subscription can result in a pending subscription.)
5. Check Raffle contract on [sepolia.etherscan.io](https://sepolia.etherscan.io/) use contract address.
6. Use Automation to run the Raffle contract.
    - Reigister a new Upkeep that utilizes a custom logic trigger mechanism. (A cron schedule have been set in contract.)
    - Check the active item.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

