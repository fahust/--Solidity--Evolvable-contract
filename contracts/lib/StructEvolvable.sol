// SPDX-License-Identifier: MIT
// EnterpriseLib contract
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

library EvolvableLib {

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

}