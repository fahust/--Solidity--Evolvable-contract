# Inverse smart contracts

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

this.buyReveal = await KANJIDROPERC721A.new(
    'Name',
    'Symbol',
    500,//Fees royalties for superrare
    account2,//Address of Arkania fees
    500,//5% fees of arkania
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

We added the token burn and mint principle: an NFT owner can burn his token and redeem another one with an other ID, as seen on the [Adidas original contract](https://etherscan.io/address/0x28472a58a490c5e09a238847f66a68a47cc76f0f#code).

This contract aims to allow a brand to sell tokens during a period determined by the brand and then let the users who own this token update it during another period.

For a specific phase (**ClaimCondition** struct) the brand can set up 2 arrays **cardIdToMint** and **cardIdToRedeem**: the ids in **cardIdToMint** are the token ids a NFT owner can burn to redeem an oher token with an id (of his choice) in **cardIdToMint**

We want the brands to be as free as possible to customize parameters:

- Possibility to make a phase exclusively accessible to pre-defined NFT owners (ERC721 or ERC1155).
- Possibility to freeze the token if its ID is smaller than the **blockLowerIdToMint** variable.
- Possibility to add a price to the burn-and-mint process (**redeemTokenForOther()**)
- Possibility for the user to choose the token he wants to burn in a list of **cardIdToRedeem** linked to the **claimCondition** active.
- Possibility for the user to choose the token he wants to mint in a list of **cardIdToMint** linked to the **claimCondition** active.
- Possibility to ask for a burn or not (if the array **cardIdToRedeem** linked to the active **claimCondition** is empty)
- Possibility to make the user pay for a burn/mint (**redeemTokenForOther()**) or a mint if the variable **pricePerToken** linked to the **claimCondition** active is > 0

**Most of the functions are identical to our drop contract summarized above. Here are the only added functions :**

### function claim
Allows a brand’s client to mint a new token, according to the current ClaimCondition (fixed by the current timestamp), in exchange of one of his token or a given price (or both), then send the funds to the beneficiaries.

- If the active **ClaimCondition** contains a Merkle root, then the brand's client will need to send a hexadecimal proof of his address..

- If **cardIdToRedeem** array in the **ClaimCondition** length is equal to 0, **claim()** function call **mintClaimedTokens()** function for automaticaly mint token.

- If **cardIdToRedeem** array in the **ClaimCondition** length is greater than 0, **claim()** function call **redeemTokenForOther()** function to automatically burn and mint token whose id is chosen by the client in cardIdToMint of the active ClaimCondition.

**And add them:**

### function redeemTokenForOther
This function allows the brand's customers to burn one of his token to redeem an other token.

