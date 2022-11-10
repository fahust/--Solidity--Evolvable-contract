# Customs smart contracts

### Install library dependancies for local test

```bash
yarn
```

### Start local network with ganache

```bash
yarn ganache
```

### All available commands

The package.json file contains a set of scripts to help on the development phase. Below is a short description for each

- **"ganache"** run local node (development network) with ganache-cli
- **"migrate"** run migration on development network
- **"test"** run tests locally
- **"test:ci"** run tests in CI system
- **"lint:sol"** lint solidity code according to rules
- **"lint:js"** lint javascript code according to rules
- **"lint"** lint solidity code
- **"truffle test -- -g "name of test""** run specific test

### Solhint

[You can find rules and explanations here](https://github.com/protofire/solhint/blob/master/docs/rules.md)


```javascript
let nonceME = await web3.eth.getTransactionCount(addressDeployer);
var preGeneratedAddressContract = "0x" + web3.utils.sha3(
RLP.encode(
    [addressDeployer,nonceME]
)).slice(12)
.substring(14)

let contractLevelMetada = {
    "name": "OpenSea Creatures",
    "description": "OpenSea Creatures are adorable aquatic beings primarily for demonstrating what can be done using the OpenSea platform. Adopt one today to try out all the OpenSea buying, selling, and bidding feature set.",
    "image": "external-link-url/image.png",
    "external_link": "external-link-url",
    "seller_fee_basis_points": 100, # Indicates a 1% seller fee.
    "fee_recipient": preGeneratedAddressContract # Where royalties fees will be paid to
}

let URIContractLevelMetadat = await sendToPinata(contractLevelMetada);

this.buyReveal = await EVOLVABLE.new(
    'Name',
    'Symbol',
    500,//Fees royalties for superrare
    account2,//Address of fees
    500,//5% fees of
    cloneAccountsfiltered,//accounts royalties for fees open sea (by payment splitter)
    cloneAccountsValue,//% royalties for fees open sea (by payment splitter)
    [account1,account2,account3,account4],//accounts beneficiaries
    [2500,2500,2500,2500],//% fees beneficiaries
    URIContractLevelMetadat,
);// we deploy contract
```


# CONTRACTS


# Evolvable
This contract is based on [ThirdWeb's ERC1155 drop contract](https://github.com/thirdweb-dev/contracts/blob/main/contracts/drop/DropERC1155.sol).

I added the token burn and mint principle: an NFT owner can burn his token and redeem another one with an other ID, as seen on the [Adidas original contract](https://etherscan.io/address/0x28472a58a490c5e09a238847f66a68a47cc76f0f#code).

