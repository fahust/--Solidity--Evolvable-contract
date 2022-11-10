// SPDX-License-Identifier: MIT
// SBTERC721A.sol
pragma solidity ^0.8.6;

interface ISBTERC1155 {
  /// @notice return Opensea contract level metadata
  /// @return _contractURI URI of json contract level metadatas
  function contractURI() external view returns (string memory);

  /// @notice Prepare pack of token uri for metadatas token
  /// @param _amount quantity of token you want to prepared mint
  /// @param _baseURIForTokens real uri for your token if not _encryptedBaseURI or flask if encrypt _encryptedBaseURI exist
  function setUri(uint256 _amount, string calldata _baseURIForTokens) external;

  /// @notice Temporarily lock the contract
  function pause() external;

  /// @notice mint quantity of token with ERC721A only if lazy mint == false
  /// @param _quantity quantity you want to mint
  /// @param _proofs expected proof for claim
  /// @param _proofMaxQuantityPerTransaction expected proof max quantity
  function claim(
    address receiver,
    uint256 _quantity,
    bytes32[] calldata _proofs,
    uint256 _proofMaxQuantityPerTransaction
  ) external;

  /// @notice Checks whether a claimer meets the claim condition's allowlist criteria.
  /// @param _claimer address wallet of claimer
  /// @param _quantity quantity of token you want to claim
  /// @param _proofs merkle proof
  /// @param _proofMaxQuantityPerTransaction quantity of token into merkle proof
  function verifyClaimMerkleProof(
    address _claimer,
    uint256 _quantity,
    bytes32[] calldata _proofs,
    uint256 _proofMaxQuantityPerTransaction
  ) external view returns (bool validMerkleProof, uint256 merkleProofIndex);

  /// @notice Burn a token (Useless for this project, but it's always good to have one)
  /// @param tokenId token id you want to burn
  function burn(uint256 tokenId) external;
}
