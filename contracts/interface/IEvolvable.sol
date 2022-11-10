// SPDX-License-Identifier: MIT

// Into the Metaverse NFTs are governed by the following terms and conditions: https://a.did.as/into_the_metaverse_tc

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/structs/BitMaps.sol";


interface EVOLVABLEPHOENIX {
  struct ClaimCondition {
    uint256 startTimestamp;
    uint256 endTimestamp;
    uint256 maxClaimableSupply;
    uint256 supplyClaimed;
    uint256 quantityLimitPerTransaction;
    uint256 waitTimeInSecondsBetweenClaims;
    uint256 pricePerToken;
    bytes32 merkleRoot;
    address currency;
    uint256[] cardIdToMint;
    uint256[] cardIdToRedeem;
    address[] ERC721Required;
    address ERC1155Required;
    uint256 ERC1155IdRequired;
  }

  struct ClaimConditionList {
    uint256 currentStartId;
    uint256 count;
    mapping(uint256 => ClaimCondition) phases;
    mapping(uint256 => mapping(address => uint256)) limitLastClaimTimestamp;
    mapping(uint256 => BitMaps.BitMap) limitMerkleProofClaim;
  }

  /// @notice return Opensea contract level metadata
  /// @return _contractURI URI of json contract level metadatas
  function contractURI() external view returns (string memory);

  /// @notice get token URI for metadatas token
  /// @param _tokenId id of token URI you want return
  /// @return URI uri of token
  function tokenURI(uint256 _tokenId) external view returns (string memory);

  /// @notice Prepare datas for mint tokens with base uri for tokens and optional revealable encrypted uri
  /// @param _amount quantity of token you want to prepared mint
  /// @param _baseURIForTokens real uri for your token if not _encryptedBaseURI or flask if encrypt _encryptedBaseURI exist
  function lazyMint(uint256 _amount, string calldata _baseURIForTokens) external;

  /// @notice Lets a contract owner set claim conditions.
  /// @param _phases array of new claim conditions updated
  /// @param _resetClaimEligibility reset all value of claim conditions
  function setClaimConditions(
    ClaimCondition[] calldata _phases,
    bool _resetClaimEligibility
  ) external;

  /// @notice Lets an account claim NFTs.
  /// @param _quantity quantity of token you want to claim
  /// @param _currency currency of token claimCondition
  /// @param _pricePerToken price in wei per token for transaction
  /// @param _proofs merkle proof
  /// @param _proofMaxQuantityPerTransaction quantity of token into merkle proof
  function claim(
    uint256 _quantity,
    address _currency,
    uint256 _pricePerToken,
    bytes32[] calldata _proofs,
    uint256 _proofMaxQuantityPerTransaction,
    uint256 cardIdToRedeem, //If > 0 check exists token id, burn them, and mint cardIdToMint from phases
    uint256 cardIdToMint //Token you want to mint in this claim
  ) external payable;

  /// @notice Checks a request to claim NFTs against the active claim condition's criteria.
  /// @param _conditionId id collection where you want to claim
  /// @param _claimer address wallet of claimer
  /// @param _quantity quantity of token you want to claim
  /// @param _currency currency of token claimCondition
  /// @param _pricePerToken price in wei per token for transaction
  /// @param verifyMaxQuantityPerTransaction verify max quantity per transaction
  function verifyClaim(
    uint256 _conditionId,
    address _claimer,
    uint256 _quantity,
    address _currency,
    uint256 _pricePerToken,
    bool verifyMaxQuantityPerTransaction
  ) external view;

  /// @notice Checks whether a claimer meets the claim condition's allowlist criteria.
  /// @param _conditionId id collection where you want to claim
  /// @param _claimer address wallet of claimer
  /// @param _quantity quantity of token you want to claim
  /// @param _proofs merkle proof
  /// @param _proofMaxQuantityPerTransaction quantity of token into merkle proof
  function verifyClaimMerkleProof(
    uint256 _conditionId,
    address _claimer,
    uint256 _quantity,
    bytes32[] calldata _proofs,
    uint256 _proofMaxQuantityPerTransaction
  ) external view returns (bool validMerkleProof, uint256 merkleProofIndex);

  /// @notice owner mint a reserve of tokens to specific address
  function mintOwner(uint256[] calldata quantities, uint256[] calldata ids) external;

  /// @notice Return timestamp for next valid claim for only one claimer
  /// @param _conditionId id of collection you wan to get claim timestamp
  /// @param _claimer address wallet of one claimer
  function getClaimTimestamp(
    uint256 _conditionId,
    address _claimer
  ) external view returns (uint256 lastClaimTimestamp, uint256 nextValidClaimTimestamp);

  /// @notice Returns the claim condition at the given uid.
  /// @param _conditionId if of collection you want to return
  /// @return condition claim condition structure
  function getClaimConditionById(
    uint256 _conditionId
  ) external view returns (ClaimCondition memory condition);

  /// @notice Returns the amount of stored baseURIs
  /// @return length length of baseURIIndices
  function getBaseURICount() external view returns (uint256);

  /// @notice Lets a contract admin set a claim count for a wallet.
  /// @param _claimer address of claimer
  /// @param _count current count of claim for one wallet
  function setWalletClaimCount(address _claimer, uint256 _count) external;

  /// @notice Lets a contract admin set a maximum number of NFTs that can be claimed by any wallet.
  /// @param _count max claim for each wallet
  function setMaxWalletClaimCount(uint256 _count) external;

  /// @notice Lets a module admin set a max total supply for token.
  /// @param _maxTotalSupply max supply of contract
  function setMaxTotalSupply(uint256 _maxTotalSupply) external;

  /// @notice Lets a module admin set a lower id to mint for lock transfer token.
  function setBlockLowerIdToMint(uint256 _blockLowerIdToMint) external;

  /// @notice Temporarily lock the contract
  function pause() external;
}
