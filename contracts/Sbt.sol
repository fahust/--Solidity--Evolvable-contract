// SPDX-License-Identifier: MIT
// SBTERC721A.sol
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import "./lib/UERC721A.sol";

import "./lib/PaymentSplitter.sol";
import "./lib/MerkleProof.sol";

contract SBTERC721A is UERC721A, Ownable, ReentrancyGuard, ERC2981, PaymentSplitter {
  using Strings for uint256;
  using BitMaps for BitMaps.BitMap;

  /// @dev Largest tokenId of each batch of tokens with the same baseURI
  uint256[] private baseURIIndices;
  /**
   *  @dev Mapping from 'Largest tokenId of a batch of tokens with the same baseURI'
   *       to base URI for the respective batch of tokens.
   **/
  mapping(uint256 => string) private baseURI;
  /// @dev Version of contract
  uint256 public constant VERSION = 1;
  /// @dev Max bps in the system.
  uint256 private constant MAX_BPS = 10000;
  /// @dev The next token ID of the NFT to "lazy mint".
  uint256 public nextTokenIdToMint;
  /// @dev count total of token minted
  uint256 public countToken;
  /// @dev open sea contract level metadata
  string public _contractURI;
  /// @dev pause the transfer only by owner
  bool public paused;
  /// @dev max mintable token of this contract (set only at deployment)
  uint16 public immutable _maxSupply;

  bytes32 merkleRoot;

  BitMaps.BitMap limitMerkleProofClaim;

  /// @dev INTERFACE SUPPORTED
  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;


  event Mints(uint256 id, address minter, address receiver, uint256 quantity);

  event Pause(bool paused);

  event SetUri(string _baseURIForTokens, uint256 quantity);

  error NoneTransferable(address ownerOf, address to);

  error UpMaxMint(uint256 countTotal, uint256 quantity, uint256 maxSupply);

  error TokenAlreadyMinted(uint256 idToken);

  error Paused(bool paused, address ownerOf);

  error LazyMintMustBeOneOrTwo(uint8 currentLazyMint, uint8 newLazyMint);

  error ContractNotSettedLazy(uint8 lazyMint);

  error InvalidQuantityProof(uint256 proofMaxQuantityPerTransaction, uint256 quantity);

  error ProofClaimed(uint256 merkleProofIndex, bool limitMerkleProofClaim);

  error NotInWhitelist(bool validMerkleProof);

  constructor(
    string memory name,
    string memory symbol,
    uint16 __maxSupply,
    uint96 _royaltyFeesInBips,
    address[] memory _payeesRoyalties,
    uint256[] memory _sharesRoyalties,
    string memory __contractURI
  ) PaymentSplitter(_payeesRoyalties, _sharesRoyalties) UERC721A(name, symbol) {
    require(
      _payeesRoyalties.length == _sharesRoyalties.length,
      "Unequal length payees and shares"
    );
    require(_payeesRoyalties.length > 0, "Royalty: no payees provided.");
    _maxSupply = __maxSupply;

    _contractURI = __contractURI; //contain this address smart contract for royalties

    _setDefaultRoyalty(payable(address(this)), _royaltyFeesInBips);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(UERC721A, ERC2981)
    returns (bool)
  {
    if (interfaceId == _INTERFACE_ID_ERC2981) {
      return true;
    }
    if (interfaceId == _INTERFACE_ID_ERC165) {
      return true;
    }
    return super.supportsInterface(interfaceId);
  }

  /// @notice return Opensea contract level metadata
  /// @return _contractURI URI of json contract level metadatas
  function contractURI() external view returns (string memory) {
    return _contractURI;
  }

  /// @notice get token URI for metadatas token
  /// @param _tokenId id of token URI you want return
  /// @return URI uri of token
  function tokenURI(uint256 _tokenId) public view override returns (string memory) {
    for (uint256 i = 0; i < baseURIIndices.length; i += 1) {
      if (_tokenId < baseURIIndices[i]) {
        return
          string(
            abi.encodePacked(baseURI[baseURIIndices[i]], _tokenId.toString(), ".json")
          );
      }
    }
    return "";
  }

  /// @notice Prepare pack of token uri for metadatas token
  /// @param _amount quantity of token you want to prepared mint
  /// @param _baseURIForTokens real uri for your token if not _encryptedBaseURI or flask if encrypt _encryptedBaseURI exist
  function setUri(uint256 _amount, string calldata _baseURIForTokens) external onlyOwner {
    uint256 startId = nextTokenIdToMint;
    uint256 baseURIIndex = startId + _amount;
    if (baseURIIndex > _maxSupply)
      revert UpMaxMint({
        countTotal: baseURIIndex,
        quantity: _amount,
        maxSupply: _maxSupply
      });

    nextTokenIdToMint = baseURIIndex;
    baseURI[baseURIIndex] = _baseURIForTokens;
    baseURIIndices.push(baseURIIndex);

    emit SetUri(_baseURIForTokens, _amount);
  }

  /// @notice Temporarily lock the contract
  function pause() external onlyOwner {
    paused = !paused;
    emit Pause(paused);
  }

  /// @notice mint quantity of token with ERC721A only if lazy mint == false
  /// @param _quantity quantity you want to mint
  /// @param _proofs expected proof for claim
  /// @param _proofMaxQuantityPerTransaction expected proof max quantity
  function claim(
    address receiver,
    uint256 _quantity,
    bytes32[] calldata _proofs,
    uint256 _proofMaxQuantityPerTransaction
  ) external {
    (bool validMerkleProof, uint256 merkleProofIndex) = verifyClaimMerkleProof(
      _msgSender(),
      _quantity,
      _proofs,
      _proofMaxQuantityPerTransaction
    );
    uint256 countTotal = countToken + _quantity;
    emit Mints(countToken, _msgSender(), receiver, _quantity);
    countToken = countTotal;
    _safeMint(receiver, _quantity);
  }

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
  ) public view returns (bool validMerkleProof, uint256 merkleProofIndex) {
    if (merkleRoot != bytes32(0) && _claimer != owner()) {
      (validMerkleProof, merkleProofIndex) = MerkleProofLib.verify(
        _proofs,
        merkleRoot,
        keccak256(abi.encodePacked(_claimer, _proofMaxQuantityPerTransaction))
      );
      if (!validMerkleProof)
        revert NotInWhitelist({ validMerkleProof: validMerkleProof });
      if (limitMerkleProofClaim.get(merkleProofIndex))
        revert ProofClaimed({
          merkleProofIndex: merkleProofIndex,
          limitMerkleProofClaim: limitMerkleProofClaim.get(merkleProofIndex)
        });
      if (
        _proofMaxQuantityPerTransaction != 0 &&
        _quantity > _proofMaxQuantityPerTransaction
      )
        revert InvalidQuantityProof({
          proofMaxQuantityPerTransaction: _proofMaxQuantityPerTransaction,
          quantity: _quantity
        });
    }
  }

  /// @notice Burn a token (Useless for this project, but it's always good to have one)
  /// @param tokenId token id you want to burn
  function burn(uint256 tokenId) external onlyOwner {
    _burn(tokenId);
  }

  /// @notice Temporarily lock the contract
  /// @param from address of from transfer
  /// @param to address of to transfer
  /// @param startTokenId id of start token
  /// @param quantity quantity of transfered token
  function _beforeTokenTransfers(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual override(UERC721A) {
    if (paused && ownerOf(startTokenId) != owner())
      revert Paused({ paused: paused, ownerOf: ownerOf(startTokenId) });
    if (ownerOf(startTokenId) != address(0) && to != address(0))
      revert NoneTransferable({ ownerOf: ownerOf(startTokenId), to: to });
    super._beforeTokenTransfers(from, to, startTokenId, quantity);
  }
}
