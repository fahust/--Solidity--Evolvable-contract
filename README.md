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



# What is Kanji ?

Kanji is a plug & play plateform from which brands can create entire collections in a few clicks and deploy their own Marketplace contracts through the front end of our plateform. We want them to be 100% owner of their contracts, being the deployer address of their contracts.

We aim to be only a SAAS platform, not a trusted third-party, we do not have any rights on their contracts.

In all the following, we will thus quote 3 different types of addresses:

- Kanji (our own wallet address)
- Brands (which are our clients) and will be creators/owners of contracts
- Brands’ clients: the potential buyers of brands’ NFTs


# Introduction/problems we would like to solve


• The way we implement auctions and direct sales listings in our **MarketPlace.sol** contract contract requires massive writing in the contract, this enables us to list only approximately 150 NFTs with a single transaction, ideally we want to be able to list an entire collection (<=10 000 NFTs) in a single transaction.

• We want our NFTs to generate royalties on a wide variety of secondary-hand Marketplace (opensea, looksrare,rarible). This is why we implemented ERC2981 and **contractURI()** function. ( [see contract level metadata of opensea](https://docs.opensea.io/docs/contract-level-metadata) ). We want brands to be able to split royalties between different addresses (**payeesRoyalties**).

To do this we set as the royalty beneficiary the NFT contract itself (see *) and implemented 2 options:

    • inheriting in our NFT contracts from PayementSplitter extension, so that the royalties funds can be redeamed with releaseAll() function. We do not like this solution because it is not “automatic” someone will have to trigger this function periodically to deliver the royalties to beneficiaries.

    • implementing a receive() function in the contracts that split automatically the incoming royalties funds between the beneficiaries. This solution is “automatic”, no need of extra calls to deliver royalties. However, we are not sure this solution is scalable or efficient because it uses a loop of transfer calls, which costs significant gas. We do not know how much gas secondary-hand Marketplace (opensea, looksrare,rarible) attach to their transfers and the receive function might not be triggered in case of unsufficient amount of gas from them. What do you think? You can find the corresponding contracts in contracts/contractWithReceiveSplitRoyalties folder.


(*)We had to specify the address of the NFT contract in the JSON pointed by **_contractURI** in the constructor. However a problem arose, how to add the address of the contract in a json even before the contract is deployed? For that we decided to use the following method:

- precalculate the address of the contract just before its deployment with nonce and public address of deployer of contract (see line 44  in **test/0-testwithreceive.js**)
- Set the obtained address as **fee_recepient** in the contract level metadata json file
- send the json to ipfs
- get this ipfs address and use it in **_contractURI**


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


# MarketPlace.sol
The **MarketPlace.sol** contract is based on the [MarketPlace.sol from thirdweb](https://github.com/thirdweb-dev/contracts/blob/main/contracts/marketplace/Marketplace.sol).

The **MarketPlace.sol** contract allows the brands to create LISTs that are either auctions or direct sales, in wich you can list **ERC721** or **ERC1155** tokens it is deployed and owned by the brand. 

The tokens in direct sales can then be bought directly by an external user by a brand's client. 

The tokens in auctions can be outbided by an brand's client until the end date of the sale is passed. At the end of an auction the function endAuction can be called by anyone to transfer tokens and funds or just transfer token or just fund (depending on transact argument).


### function createList (onlyowner)
Function allowing the creation of a list respecting the **LIST** structure found in **struct.sol**.

### function updateList (onlyowner)
Function allowing the update of a list respecting the **LIST** structure found in **struct.sol** as long as it has not started.

### function addTokenToList (onlyowner)
Function to add an array of struct TOKEN to a struct **LIST**, requiring that the type of the token respect the same type of tokens in the **LIST**.

### function buy
Function to immediately purchase a token contained in a **LIST** for a **minPrice** value, sending the funds directly to the beneficiaries of the sales set up in the **LIST**.

:warning: **minPrice** has two meanings depending on type of lists, it means the price of the NFT in direct sale, or starting price in an auction.

### function bidding
Function allowing to bid on a token contained in a **LIST** (**minPrice** being starting price of the auction).

### function endAuction
Function allowing to receive the token after the end of an auction. It is callable by anyone. It sends the funds directly to the beneficiaries of the auction and the NFT directly to the winner of the auction but the payment and the transfer of token can also be done individually (depending on transact argument).

**Note: Any idea?**
We would prefer to avoid this function because we would prefer to avoid an extra call from the brand (in case the last bidder do not claim his NFT) However it seems to be the only secure way to end an auction. We thought of allowing our address to end the auction but :

- it would cost us gas fees
- we do not want to be trust-party

### function transferListingTokens (internal)
Internal function of the contract allowing to transfer tokens from one address to another.

### function checkBeneficiaries (internal)
Internal function of the contract to check that the length of the array of beneficiaries addresses and shares of the beneficiaries correspond and that shares do not exceed 100 %.

### function payBeneficiaries (internal)
Internal function of the contract to calculate and send the shares to the beneficiaries at the end of a sale/auction.

## GETTERS


### function getLists
Returns the array of LISTS contained in the **MarketPlace.sol** contract.

### function getTokensInList
Returns the array of TOKENS contained in a specific **LIST**.


## Making marketplace Upgradeable with KANJIFACTORY.sol

We want our Marketplace contract to be upgradeable. We want brands to be able to upgrade the source code of our functions and add new functions. For this, we used the [UUPS Transparent Proxy](https://r48b1t.medium.com/universal-upgrade-proxy-proxyfactory-a-modern-walkthrough-22d293e369cb).



Kanji will deploy a unique **KANJIFACTORY.sol** contract that is the admin of every proxys that will be deployed.

```javascript
this.factory = await KANJIFACTORY.new({from:kanji_account});
```

When a brand will deploy its first **MarketPlace.sol** contract (MarketPlaceV1), it will be able to call the **registerToFactoryProxy()** function in MarketPlace.sol which calls the **KANJIFACTORY** contract and creates a proxy for MarketPlaceV1 (with proxy admin being the Marketplace contract itself), (the owner role of MarketPlaceV1 will be correctly assigned to the brand address thanks to **transferOwnership(sender)** in initializer).

```javascript
this.Marketplace = await MarketPlace.new(account_three,500,500,{from:brand_account});
await this.Marketplace.registerToFactoryProxy(this.factory.address,{from:brand_account});
```

When the brand or one brand's client will want to perform a function from **MarketPlace.sol** contract, they will call the proxy contract that fallbacks the function calls to the **MarketPlace.sol** contract.
Please see in the below diagram the workflow.

```javascript
let proxies = await this.factory.proxies(this.Marketplace.address,{from: brand_account});
this.MarketplaceDelegate = await MarketPlace.at(proxies);
///Exemple of brand calls
await this.MarketplaceDelegate.VERSION.call({from: brand_account})
///Exemple of brand's client calls
await this.MarketplaceDelegate.VERSION.call({from: user_account})
```

When the brand wants to upgrade its contract with a new contract (MarketPlaceV2), it needs to:

- deploy MarktplaceV2 contract
- call **upgradeTo()** function from the proxy contract which takes as argument the address of MarketPlaceV2

```javascript
this.MarketplaceV2 = await MarketPlaceV2.new({from: brand_account});
await this.MarketplaceDelegate.upgradeTo(this.MarketplaceV2.address,{from:brand_account});
```

![schema](https://github.com/Inv3rsexyz/contracts/blob/main/SchemaUpgradable.png?raw=true)

Please see test in our file **test/2-deployAndUpgradeByKanji.js**


# KANJIERC721A.sol

The **KANJIERC721A.sol** contract allows brand to create **ERC721A**, these tokens can then be auctioned or sold in the **MarketPlace.sol** contract. The NFTs can be lazyminted (only set the URI) or minted by owner. It is deployed and owned by the brand address.
Only a mapping allowedminters addresses are allowed to mint lazyminted tokens (in particular it can be a Marketplace.sol contract or the owner of the **ERC721A** contract for example).
At deployement of the contract, the **_lazyMint** parameter is initiated to 0 and its final value will be determined at first call of **setUri()** function:

- it gets equal to 1 if the first tokens are minted, in this case, the brand will only be able to mint tokens after (no lazyminting possible anymore)
- it gets equal to 2 if the tokens are lazyminted (only the uri are registered), in this case, the brand will only be able to lazymint tokens after. The tokens will then be minted by one of the address in allowedminters (using **lazyMint()** function)


### Variables

```javascript
///Largest tokenId of each batch of tokens with the same baseURI
uint256[] private baseURIIndices;
///Mapping from 'Largest tokenId of a batch of tokens with the same baseURI' to base URI for the respective batch of tokens.
mapping(uint256 => string) private baseURI;
```

Indeed when the brand wants to create (either lazy minting or minting) a batch of tokens it will pass a corresponding URI that will be stored in baseURIIndices/baseURI.

## SETTER

### function paused (onlyOwner)
Putting on pause will block token transfers.

### function setUri (onlyOwner)
Function to perform lazyminting or minting depending on the value of **_lazymint**.

### function lazyMint
Function to perform minting of lazyminted tokens by **allowedminters** adresses.

### function batchTransferQuantity (onlyOwner)
Function to transfer a large amount of tokens from the owner to a wallet address.

### function setAllowedMinters (onlyOwner)
Updating the allowed addresses to mint tokens from this contract.


## GETTER
### function contractURI
The function that returns the metadatas of the contract level metadata for opensea.

### function tokenURI
The function that returns the metadata of the token based on its corresponding baseURI index found in **baseURIIndices**.

# UERC721A.sol
We overrided [ERC721A](https://github.com/chiru-labs/ERC721A) to allow batch minting from a specific starting token id.
We simply added a function called **_mintSpecificToken** based on native **_mint** function (instead of using "uint256 startTokenId = _currentIndex;" as next tokenID to mint we added **uint256 startTokenId** as an argument of the function).
This library is only use in **KANJIERC721A.sol** because we needed a way to mint token from a certain range ID when we are performing minting from the **MarketPlace.sol** contract.

```javascript
function _mintSpecificToken(
    address to,
    uint256 quantity,
    uint256 startTokenId,//this argument has added
    bytes memory _data,
    bool safe
) internal {
    if (to == address(0)) revert MintToZeroAddress();
    if (quantity == 0) revert MintZeroQuantity();

    _beforeTokenTransfers(address(0), to, startTokenId, quantity);

    // Overflows are incredibly unrealistic.
    // balance or numberMinted overflow if current value of either + quantity > 1.8e19 (2**64) - 1
    // updatedIndex overflows if _currentIndex + quantity > 1.2e77 (2**256) - 1
    unchecked {
        _addressData[to].balance += uint64(quantity);
        _addressData[to].numberMinted += uint64(quantity);

        _ownerships[startTokenId].addr = to;
        _ownerships[startTokenId].startTimestamp = uint64(block.timestamp);

        uint256 updatedIndex = startTokenId;
        uint256 end = updatedIndex + quantity;

        if (safe && to.isContract()) {
            do {
                emit Transfer(address(0), to, updatedIndex);
                if (!_checkContractOnERC721Received(address(0), to, updatedIndex++, _data)) {
                    revert TransferToNonERC721ReceiverImplementer();
                }
            } while (updatedIndex != end);
            // Reentrancy protection
            if (_currentIndex != startTokenId) revert("Reentrancy protection");
        } else {
            do {
                emit Transfer(address(0), to, updatedIndex++);
            } while (updatedIndex != end);
        }
        _currentIndex = updatedIndex;
    }
    _afterTokenTransfers(address(0), to, startTokenId, quantity);
}
```

# KANJIDROPERC721A.sol
The drop contract is based on the **dropERC721.sol** from thirdweb [see reference here](https://github.com/thirdweb-dev/contracts/blob/main/contracts/drop/DropERC721.sol), we added the extension **ERC721A** and modified some functions. It allows the brand make direct sales of tokens, the real tokens metadata can be encrypted and stored in **encryptedBaseURI** mapping, encrypted by password until the brand reveals them with same password (when **reveal()** function is called).
The tokens are lazyminted and only minted during purchase by the brand's client. It is possible to fix different “claim phases”.
A claimPhases is a time window during wich a batch of tokens is sold for a specific price (pricePerToken). It is defined by several parameter (visible in structure **ClaimCondition**)
This contract also implements whitelisting by merkle tree.

### To perform encryption we use the following function:

```javascript
let password = "password"
let tokenToMint = 1000;
let hidedUri = "ipfs://ipfsHash/mybaseuri/";
let fakeURI = "ipfs://ipfsHash/";

//Retrieve next token id to mint
let nextTokenId = await this.KANJIDROPERC721A.nextTokenIdToMint({from: accounts[0]});
//hash with (nextTokenId+tokenToLazyMint , password , address , blockchainId)
let hash = await hashDelayRevealPasword(parseInt(nextTokenId+"")+tokenToMint,password,this.KANJIDROPERC721A.address);
//use encryptDecrypt function of drop contract
const encryptedBaseUri = await this.KANJIDROPERC721A.encryptDecrypt(
    ethers.utils.toUtf8Bytes(
        hidedUri,
    ),
    hash
);
//call lazy mint function of drop contract and send it encryptedBaseUri 
await this.KANJIDROPERC721A.lazyMint(
    tokenToMint,
    fakeURI,
    encryptedBaseUri,
    {from: accounts[0]}
)
```

### To perform reveal we decrypt with password and test validity :

```javascript
let password = "password"

//call the index of the base uri you want to decrypt 
let indexEncrypt = await this.KANJIDROPERC721A.baseURIIndices(1,{from: accounts[0]});
//retrieve the encrypted baseURI corresponding to this index
let encryptedBaseURI = await this.KANJIDROPERC721A.encryptedBaseURI(indexEncrypt+"",{from: accounts[0]});
//retrieve hash with (indexEncrypt , password , address , blockchainId)
let hash = await hashDelayRevealPasword(indexEncrypt+"",password,this.KANJIDROPERC721A.address);
//call contract drop function to decrypt hashed URI
let decryptedUri = await this.KANJIDROPERC721A.encryptDecrypt(
    encryptedBaseURI,
    hash,
);
//decode hex to ascii
decryptedUri =  web3.utils.hexToAscii(decryptedUri)
//test validity of address uri decrypted
if (!decryptedUri.includes("://") || !decryptedUri.endsWith("/")) {
    throw new Error("invalid password");
}
//if all is valid, reveal with this hash
await this.KANJIDROPERC721A.reveal(
    1,//Index of baseURIIndices to reveal
    hash,
    {from: accounts[0]}
)
```

### Function hashDelayedRevealPassword
```javascript
async function hashDelayRevealPasword(
    batchTokenIndex,//Key of array encryptedURI mapping
    password,//Password for reveal
    contractAddress//Address of drop contract
) {
    const chainId = await web3.eth.getChainId();
    return ethers.utils.solidityKeccak256(
        ["string", "uint256", "uint256", "address"],
        [password, chainId, batchTokenIndex+"", contractAddress],
    );
}
```

## SETTERS

### function lazyMint (onlyowner)
Lazymint one or more tokens to be sold with their metadatas, if the variable **_encryptedBaseURI** is set then the real metadatas will be hidden, until reveal is done.

### function reveal (onlyowner)
Reveals a previously hidden set of tokens metadatas by decrypting the relevant encrypted URI found in **encryptedBaseURI**, moving it to baseURI and then deleting it from **encryptedBaseURI**.

## function setClaimConditions (onlyowner)
Update the **claimCondition** list. You can add a merkle root in the claim conditions that will force brand's client to send a merkle proof when claiming a token.

### MERKLE ROOT EXEMPLE
```javascript
///Create a merkle tree
const hashedLeaves = whitelistedAddress.map((i) =>
    hashLeafNode(
    i,
    0,
    )
);
this.tree = new MerkleTree(hashedLeaves, keccak256, {
    sort: true,
});
```

```javascript
///Function hashLeafNode used for create leaves of merkle tree
function hashLeafNode(
    address,
    maxClaimableAmount,
) {
    return ethers.utils.solidityKeccak256(
        ["address", "uint256"],
        [address, BigNumber.from(maxClaimableAmount)],
    );
}
```
### setClaimConditions with merkle tree exemple
```javascript
const claimConditions = [
    {
        startTimestamp : Math.floor(Date.now()/1000)-5,
        maxClaimableSupply : 200,//bigger than last 
        supplyClaimed : 0,
        quantityLimitPerTransaction : 100,
        waitTimeInSecondsBetweenClaims : 10,
        merkleRoot : this.tree.getHexRoot(),
        pricePerToken : 100,
        currency : "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",//MATIC
    }
]
await this.buyReveal.setClaimConditions(claimConditions, {from: accounts[0]})
```

### function claim
Claim a token offered for sale, sending the amount of tokens according to the current **ClaimCondition** (according to the current date), mint the requested number of tokens to the brand's client, then send the funds to the beneficiaries.
If the **ClaimCondition** contains a merkle root, then you will need to send a hexadecimal proof of his address.

### CLAIM WITH WHITELIST EXEMPLE
```javascript
const expectedProof = this.tree.getHexProof(
    ethers.utils.solidityKeccak256(["address", "uint256"], [accountClaimer, 0]),
);

await this.buyReveal.claim(
    accountClaimer,
    1,
    "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",///Native Token
    100,
    expectedProof,
    0,
    {from: accountClaimer,value:100}
).catch(() => {
    console.log("whitelist not approved")
});
```

### function setWalletClaimCount (onlyowner)
Define a quantity of claimable tokens for a wallet address.

### function setMaxWalletClaimCount (onlyowner)
Let the contract admin (the brand) set a maximum number of NFTs that can be claimed by any wallet.

### function setMaxTotalSupply (onlyowner)
Let the brand sets the global maximum supply of NFTs in the collection.

### function collectClaimPrice (internal)
This internal function will send the revenues of the sales to the different beneficiaries, as well the share of kanji to its address.

### function transferClaimedTokens (internal)
Once a claim is done and validated, the tokens are minted directly to the claimer.


## GETTERS


### function verifyClaim (public)
Allows to verify that a claimer is authorized to claim tokens and verify that the claim quantity is not exceeded and that the conditions are respected.

### function verifyClaimMerkleProof (public)
Allows to verify that a claimer is authorized to claim tokens and checks the merkle proof if the claim condition has a merkle root.

### function getActiveClaimConditionId
Retrieves the id of the current condition.

### function getClaimTimestamp
Verifies that the latency between two claim calls is respected for a given wallet address.

### function getClaimConditionById
Get the parameters of a **claimCondition** with respect to its id.

### function contractURI
The function that returns the contract level metadata for opensea.

### function tokenURI
The function that returns the metadata of a token, if the **encryptedBaseURI** mapping linked to the token is populated and the token is not revealed, the metadata returned is the fake URI (until the token is revealed).

# KANJIDROPERC1155
The drop contract is based on the **dropERC1155.sol** from thirdweb [see reference here](https://github.com/thirdweb-dev/contracts/blob/main/contracts/drop/DropERC1155.sol).

It allows the brand make direct sales of tokens, the real tokens metadata can be encrypted and stored in **encryptedBaseURI** mapping, encrypted by password until the brand reveals them with same password (when **reveal()** function is called).
The tokens are lazyminted and only minted during purchase by the brand's client. It is possible to fix different “claim phases”.
A claimPhases is a time window during wich a batch of tokens is sold for a specific price (**pricePerToken**). It is defined by several parameter (visible in structure **ClaimCondition**)
This contract also implements whitelisting by merkle tree.

**KANJIDROPERC1155** contract functions are exactly the same as the **KANJIDROPERC721A** contract - but the difference is to be found in the number of tokenID mintable at each phase. 

For the **KANJIDROPERC1155**, only one tokenID can be minted for a predetermined number whereas you can mint a predetermined number of tokenID at each phase for the **KANJIDROPERC721A**.

# KANJIPHOENIX
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


# KANJIDROPERC721R
This contract is based on [ThirdWeb's ERC1155 drop contract](https://github.com/thirdweb-dev/contracts/blob/main/contracts/drop/DropERC721.sol).
We added the randomization of mint of tokens with [ERC721R](https://github.com/exo-digital-labs/ERC721R), this allows a brand to put on sale / distribute a number of tokens determined randomly, obliging the users of the brands to claim their tokens without knowing what they are going to get.

The only differences are that the max supply must be set in the constructor and cannot be changed afterward.

And that we call the function **_mintRandom()** instead of calling the function **_mint()**.