// SPDX-License-Identifier: MIT

// Into the Metaverse NFTs are governed by the following terms and conditions: https://a.did.as/into_the_metaverse_tc

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import "./lib/PaymentSplitter.sol";

import "./lib/MerkleProof.sol";
import "./lib/CurrencyTransferLib.sol";

contract EVOLVABLEPHOENIX is
  ERC1155Supply,
  ERC1155Burnable,
  Ownable,
  ReentrancyGuard,
  ERC2981,
  PaymentSplitter
{
  using BitMaps for BitMaps.BitMap;
  using Strings for uint256;

  /*///////////////////////////////////////////////////////////////
                                Structure
    //////////////////////////////////////////////////////////////*/
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

  /// @dev Largest tokenId of each batch of tokens with the same baseURI
  uint256[] public baseURIIndices;
  /**
   *  @dev Mapping from 'Largest tokenId of a batch of tokens with the same baseURI'
   *       to base URI for the respective batch of tokens.
   **/
  mapping(uint256 => string) private baseURI;
  /// @dev The next token ID of the NFT to "lazy mint".
  uint256 public nextTokenIdToMint;

  /// @dev Max bps in the system.
  uint256 private constant MAX_BPS = 10000;

  /// @dev The max number of NFTs a wallet can claim.
  uint256 public maxWalletClaimCount;

  /// @dev Total circulating supply of tokens with that ID.
  uint256 public _totalSupply;

  /// @dev Global max total supply of NFTs.
  uint256 public maxTotalSupply;

  /// @dev The set of all claim conditions, at any given moment.
  ClaimConditionList private claimCondition;

  /// @dev Mapping from address => total number of NFTs a wallet has claimed.
  mapping(address => uint256) public walletClaimCount;

  /// @dev open sea contract level metadata
  string public _contractURI;
  /// @dev pause the transfer only by owner
  bool public paused;
  /// @dev INTERFACE SUPPORTED
  bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
  bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

  /// @dev The address of receiver fees of beneficiaries BRAND for each claim
  address[] private payeesBeneficiaries;
  /// @dev The amount % of receiver fees of beneficiaries BRAND (10000 = 100 %) for each claim
  uint256[] private sharesBeneficiaries;

  /// @dev The address of receiver fees of EVOLVABLE
  address private evolvableAddressFees;

  /// @dev The amount % of receiver fees of EVOLVABLE (10000 = 100 %)
  uint256 private evolvableFeesBeneficiaries;

  /// @dev block transfer of token if is not in current phase cardIdToMint
  uint256 public blockLowerIdToMint;

  /// @dev max mintable token total
  uint256 public maxSupply;

  /// @dev current count of minted token
  uint256 public countTokenClaimed;

  /// @dev Type of contract
  bytes32 public constant MODULE_TYPE = bytes32("EVOLVABLEPHOENIX");
  /// @dev Version of contract
  uint256 public constant VERSION = 1;

  event RedeemedForCard(
    uint256 indexed indexToRedeem,
    uint256 indexed indexToMint,
    address indexed account,
    uint256 amount
  );

  event Pause(bool indexed paused);

  event TokensClaimed(
    uint256 indexed claimConditionIndex,
    address indexed claimer,
    uint256 indexed quantityClaimed,
    uint256 _pricePerToken
  );

  /// @dev Emitted when tokens are lazy minted.
  event TokensLazyMinted(
    uint256 indexed startTokenId,
    uint256 indexed endTokenId,
    string indexed baseURI
  );

  /// @dev Emitted when new claim conditions are set for a token.
  event ClaimConditionsUpdated(ClaimCondition[] claimConditions);

  /// @dev Emitted when the global max supply of a token is updated.
  event MaxTotalSupplyUpdated(uint256 indexed maxTotalSupply);

  /// @dev Emitted when the wallet claim count.
  event WalletClaimCountUpdated(address indexed wallet, uint256 indexed count);

  /// @dev Emitted when the max wallet claim count.
  event MaxWalletClaimCountUpdated(uint256 indexed count);

  /// @dev Emitted when the lowerIdToMint is updated.
  event BlockLowerIdToMintUpdated(uint256 indexed lowerIdToMintUpdated);

  event Mints(uint256[] indexed ids, address indexed minter, uint256[] indexed quantity);

  event Transfered(
    address indexed from,
    address indexed to,
    uint256[] indexed ids,
    uint256[] quantity
  );

  error UpMaxMint(uint256 countTokenClaimed, uint256 quantity, uint256 maxSupply);

  error AmountNotAllowed(
    uint256 cardIdToRedeem,
    uint256 balance,
    uint256 quantityBeingClaimed,
    address sender
  );

  error ERC721RequiredBalance(address erc721Required, address claimer);

  error ERC1155RequiredBalance(
    address erc721Required,
    uint256 erc721IdRequired,
    address claimer
  );

  error StartTimeStamp(
    uint256 index,
    uint256 lastConditionStartTimestamp,
    uint256 startTimestamp
  );

  error MaxSupply(uint256 supplyClaimedAlready, uint256 maxClaimableSupply);

  error PriceNotGood(uint256 value, uint256 totalPrice);

  error InvalidPriceOrCurrency(
    address currency,
    address phaseCurrency,
    uint256 pricePerToken,
    uint256 phasePricePerToken
  );

  error InvalidQuantityClaimed(
    uint256 quantity,
    bool verifyMaxQuantityPerTransaction,
    uint256 quantityLimitPerTransaction
  );

  error ExceedMaxMintSupply(
    uint256 quantity,
    uint256 supplyClaimed,
    uint256 maxClaimableSupply
  );

  error ExceedClaimLimitForWallet(
    uint256 quantity,
    uint256 walletClaimCountClaimer,
    address claimer,
    uint256 maxWalletClaimCount
  );

  error CannotClaimYet(
    uint256 lastClaimTimestamp,
    uint256 blockTimestamp,
    uint256 nextValidClaimTimestamp
  );

  error NotInWhitelist(bool validMerkleProof);

  error ProofClaimed(
    uint256 conditionId,
    uint256 merkleProofIndex,
    bool limitMerkleProofClaim
  );

  error InvalidQuantityProof(uint256 proofMaxQuantityPerTransaction, uint256 quantity);

  error Paused(bool paused);

  constructor(
    uint96 _royaltyFeesInBips,
    address _evolvableAddressFees,
    uint256 _evolvableFeesBeneficiaries,
    address[] memory payees,
    uint256[] memory shares_,
    address[] memory _payeesBeneficiaries,
    uint256[] memory _sharesBeneficiaries,
    address reserveMintAddress,
    uint256 reserveMintAmount,
    string memory __contractURI,
    uint256 _maxSupply
  ) ERC1155("") PaymentSplitter(payees, shares_) {
    require(payees.length > 0, "Royalty: no payees provided");
    require(payees.length == shares_.length, "Unequal number of payees/shares provided");
    if (reserveMintAmount > 0 && reserveMintAddress != address(0))
      _mint(reserveMintAddress, 0, reserveMintAmount, "");
    uint256 totalSharesBeneficiaries;
    for (uint256 index = 0; index < _sharesBeneficiaries.length; index++) {
      totalSharesBeneficiaries += _sharesBeneficiaries[index];
    }
    maxSupply = _maxSupply;
    totalSharesBeneficiaries += _evolvableFeesBeneficiaries;
    require(totalSharesBeneficiaries == MAX_BPS, "Shares not equal MAX_BPS");

    payeesBeneficiaries = _payeesBeneficiaries; //dispatch address of royalties platform (open sea rarible ect)
    sharesBeneficiaries = _sharesBeneficiaries; //percent of royalties platform (open sea rarible ect)

    evolvableAddressFees = _evolvableAddressFees;
    evolvableFeesBeneficiaries = _evolvableFeesBeneficiaries;

    _setDefaultRoyalty(payable(address(this)), _royaltyFeesInBips);
    _contractURI = __contractURI;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155, ERC2981)
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
  function tokenURI(uint256 _tokenId) external view returns (string memory) {
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

  /// @notice Prepare datas for mint tokens with base uri for tokens and optional revealable encrypted uri
  /// @param _amount quantity of token you want to prepared mint
  /// @param _baseURIForTokens real uri for your token if not _encryptedBaseURI or flask if encrypt _encryptedBaseURI exist
  function lazyMint(uint256 _amount, string calldata _baseURIForTokens)
    external
    onlyOwner
  {
    uint256 startId = nextTokenIdToMint;
    uint256 baseURIIndex = startId + _amount;

    nextTokenIdToMint = baseURIIndex;
    baseURI[baseURIIndex] = _baseURIForTokens;
    baseURIIndices.push(baseURIIndex);

    emit TokensLazyMinted(startId, startId + _amount - 1, _baseURIForTokens);
  }

  /// @notice Lets a contract owner set claim conditions.
  /// @param _phases array of new claim conditions updated
  /// @param _resetClaimEligibility reset all value of claim conditions
  function setClaimConditions(
    ClaimCondition[] calldata _phases,
    bool _resetClaimEligibility
  ) external onlyOwner {
    ClaimConditionList storage condition = claimCondition;
    uint256 existingStartIndex = condition.currentStartId;
    uint256 existingPhaseCount = condition.count;
    uint256 newStartIndex = existingStartIndex;
    if (_resetClaimEligibility) {
      newStartIndex = existingStartIndex + existingPhaseCount;
    }

    condition.count = _phases.length;
    condition.currentStartId = newStartIndex;

    uint256 lastConditionStartTimestamp;
    for (uint256 i = 0; i < _phases.length; i++) {
      if (i != 0 && lastConditionStartTimestamp >= _phases[i].startTimestamp)
        revert StartTimeStamp({
          index: i,
          lastConditionStartTimestamp: lastConditionStartTimestamp,
          startTimestamp: _phases[i].startTimestamp
        });

      uint256 supplyClaimedAlready = condition.phases[i].supplyClaimed;
      if (supplyClaimedAlready > _phases[i].maxClaimableSupply)
        revert MaxSupply({
          supplyClaimedAlready: supplyClaimedAlready,
          maxClaimableSupply: _phases[i].maxClaimableSupply
        });

      condition.phases[newStartIndex + i] = _phases[i];
      condition.phases[newStartIndex + i].supplyClaimed = supplyClaimedAlready;

      lastConditionStartTimestamp = _phases[i].startTimestamp;
    }
    if (_resetClaimEligibility) {
      for (uint256 i = existingStartIndex; i < newStartIndex; i++) {
        delete condition.phases[i];
        delete condition.limitMerkleProofClaim[i];
      }
    } else {
      if (existingPhaseCount > _phases.length) {
        for (uint256 i = _phases.length; i < existingPhaseCount; i++) {
          delete condition.phases[i];
          delete condition.limitMerkleProofClaim[i];
        }
      }
    }

    emit ClaimConditionsUpdated(_phases);
  }

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
  ) external payable nonReentrant {
    // Get the active claim condition index.
    uint256 activeConditionId = getActiveClaimConditionId();
    /**
     *  We make allowlist checks (i.e. verifyClaimMerkleProof) before verifying the claim's general
     *  validity (i.e. verifyClaim) because we give precedence to the check of allow list quantity
     *  restriction over the check of the general claim condition's quantityLimitPerTransaction
     *  restriction.
     */
    // Verify inclusion in allowlist.
    (bool validMerkleProof, uint256 merkleProofIndex) = verifyClaimMerkleProof(
      activeConditionId,
      _msgSender(),
      _quantity,
      _proofs,
      _proofMaxQuantityPerTransaction
    );
    // Verify claim validity. If not valid, revert.
    bool toVerifyMaxQuantityPerTransaction = _proofMaxQuantityPerTransaction == 0;
    verifyClaim(
      activeConditionId,
      _msgSender(),
      _quantity,
      _currency,
      _pricePerToken,
      toVerifyMaxQuantityPerTransaction
    );
    if (validMerkleProof && _proofMaxQuantityPerTransaction > 0) {
      /**
       *  Mark the claimer's use of their position in the allowlist. A spot in an allowlist
       *  can be used only once.
       */
      claimCondition.limitMerkleProofClaim[activeConditionId].set(merkleProofIndex);
    }
    // If there's a price, collect price.
    collectClaimPrice(_quantity, _currency, _pricePerToken);
    // check token id user want to mint is in phase

    checkClaim(
      activeConditionId,
      _quantity,
      cardIdToRedeem,
      cardIdToMint,
      _pricePerToken
    );
  }

  /**
   * @notice check if token can be burned and mint
   */
  function checkClaim(
    uint256 activeConditionId,
    uint256 _quantity,
    uint256 cardIdToRedeem, //If > 0 check exists token id, burn them, and mint cardIdToMint from phases
    uint256 cardIdToMint, //Token you want to mint in this claim
    uint256 _pricePerToken
  ) internal {
    bool IdInArray;
    for (
      uint256 index = 0;
      index < claimCondition.phases[activeConditionId].cardIdToMint.length;
      index++
    ) {
      if (claimCondition.phases[activeConditionId].cardIdToMint[index] == cardIdToMint)
        IdInArray = true;
    }

    require(IdInArray == true, "token you want to mint is not in phase");
    // Mint the relevant tokens to claimer.
    if (claimCondition.phases[activeConditionId].cardIdToRedeem.length == 0) {
      if (countTokenClaimed + _quantity > maxSupply)
        revert UpMaxMint({
          countTokenClaimed: countTokenClaimed,
          quantity: _quantity,
          maxSupply: maxSupply
        });
      countTokenClaimed += _quantity;
      mintClaimedTokens(cardIdToMint, activeConditionId, _quantity);
      emit TokensClaimed(activeConditionId, _msgSender(), _quantity, _pricePerToken);
    } else {
      IdInArray = false;
      for (
        uint256 index = 0;
        index < claimCondition.phases[activeConditionId].cardIdToRedeem.length;
        index++
      ) {
        if (
          claimCondition.phases[activeConditionId].cardIdToRedeem[index] == cardIdToRedeem
        ) IdInArray = true;
      }
      require(IdInArray == true, "token you want to burn is not in phase");
      redeemTokenForOther(cardIdToRedeem, cardIdToMint, activeConditionId, _quantity);
    }
  }

  /**
   * @notice burn token with previous id, and mint to a new cardIdToMint
   */
  function redeemTokenForOther(
    uint256 cardIdToRedeem,
    uint256 cardIdToMint,
    uint256 activeConditionId,
    uint256 _quantityBeingClaimed
  ) internal {
    if (
      balanceOf(_msgSender(), cardIdToRedeem) < _quantityBeingClaimed ||
      _quantityBeingClaimed <= 0
    )
      revert AmountNotAllowed({
        cardIdToRedeem: cardIdToRedeem,
        balance: balanceOf(_msgSender(), cardIdToRedeem),
        quantityBeingClaimed: _quantityBeingClaimed,
        sender: _msgSender()
      });
    // Update the supply minted under mint condition.
    claimCondition.phases[activeConditionId].supplyClaimed += _quantityBeingClaimed;

    // if transfer claimed tokens is called when to != msg.sender, it'd use msg.sender's limits.
    // behavior would be similar to msg.sender mint for itself, then transfer to `to`.
    claimCondition.limitLastClaimTimestamp[activeConditionId][_msgSender()] = block
      .timestamp;

    walletClaimCount[_msgSender()] += _quantityBeingClaimed;

    _burn(_msgSender(), cardIdToRedeem, _quantityBeingClaimed);
    _mint(_msgSender(), cardIdToMint, _quantityBeingClaimed, "");

    emit RedeemedForCard(
      cardIdToRedeem,
      cardIdToMint,
      _msgSender(),
      _quantityBeingClaimed
    );
  }

  /// @notice Collects and distributes the primary sale value of NFTs being claimed.
  /// @param _quantityToClaim quantity user gonna be claimed
  /// @param _currency currency of token claimCondition
  /// @param _pricePerToken price in wei per token for transaction
  function collectClaimPrice(
    uint256 _quantityToClaim,
    address _currency,
    uint256 _pricePerToken
  ) internal {
    if (_pricePerToken == 0) {
      return;
    }

    uint256 totalPrice = _quantityToClaim * _pricePerToken;
    if (msg.value != totalPrice && _currency == CurrencyTransferLib.NATIVE_TOKEN)
      revert PriceNotGood({ value: msg.value, totalPrice: totalPrice });
    if (evolvableFeesBeneficiaries != 0) {
      uint256 inFee = (totalPrice * evolvableFeesBeneficiaries) / MAX_BPS;
      CurrencyTransferLib.transferCurrency(
        _currency,
        _msgSender(),
        evolvableAddressFees,
        inFee
      );
    }

    for (uint256 index = 0; index < payeesBeneficiaries.length; index++) {
      uint256 feeBeneficiarie = ((totalPrice) * sharesBeneficiaries[index]) / MAX_BPS;
      CurrencyTransferLib.transferCurrency(
        _currency,
        _msgSender(),
        payeesBeneficiaries[index],
        feeBeneficiarie
      );
    }
  }

  /// @notice Transfers the NFTs being claimed.
  function mintClaimedTokens(
    uint256 _cardIdToMint,
    uint256 activeConditionId,
    uint256 _quantityBeingClaimed
  ) internal {
    // Update the supply minted under mint condition.
    claimCondition.phases[activeConditionId].supplyClaimed += _quantityBeingClaimed;

    // if transfer claimed tokens is called when to != msg.sender, it'd use msg.sender's limits.
    // behavior would be similar to msg.sender mint for itself, then transfer to `to`.
    claimCondition.limitLastClaimTimestamp[activeConditionId][_msgSender()] = block
      .timestamp;

    walletClaimCount[_msgSender()] += _quantityBeingClaimed;

    _mint(_msgSender(), _cardIdToMint, _quantityBeingClaimed, "");
  }

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
  ) public view {
    ClaimCondition memory currentClaimPhase = claimCondition.phases[_conditionId];
    if (
      _currency != currentClaimPhase.currency ||
      _pricePerToken != currentClaimPhase.pricePerToken
    )
      revert InvalidPriceOrCurrency({
        currency: _currency,
        phaseCurrency: currentClaimPhase.currency,
        pricePerToken: _pricePerToken,
        phasePricePerToken: currentClaimPhase.pricePerToken
      });
    // If we're checking for an allowlist quantity restriction, ignore the general quantity restriction.
    if (
      _quantity == 0 ||
      (verifyMaxQuantityPerTransaction &&
        _quantity > currentClaimPhase.quantityLimitPerTransaction)
    )
      revert InvalidQuantityClaimed({
        quantity: _quantity,
        verifyMaxQuantityPerTransaction: verifyMaxQuantityPerTransaction,
        quantityLimitPerTransaction: currentClaimPhase.quantityLimitPerTransaction
      });
    if (
      currentClaimPhase.supplyClaimed + _quantity > currentClaimPhase.maxClaimableSupply
    )
      revert ExceedMaxMintSupply({
        quantity: _quantity,
        supplyClaimed: currentClaimPhase.supplyClaimed,
        maxClaimableSupply: currentClaimPhase.maxClaimableSupply
      });
    if (maxTotalSupply != 0 && _totalSupply + _quantity > maxTotalSupply)
      revert MaxSupply({
        supplyClaimedAlready: _totalSupply,
        maxClaimableSupply: maxTotalSupply
      });

    if (
      maxWalletClaimCount != 0 &&
      walletClaimCount[_claimer] + _quantity > maxWalletClaimCount
    )
      revert ExceedClaimLimitForWallet({
        quantity: _quantity,
        walletClaimCountClaimer: walletClaimCount[_claimer],
        claimer: _claimer,
        maxWalletClaimCount: maxWalletClaimCount
      });
    (uint256 lastClaimTimestamp, uint256 nextValidClaimTimestamp) = getClaimTimestamp(
      _conditionId,
      _claimer
    );
    if (lastClaimTimestamp != 0 && block.timestamp < nextValidClaimTimestamp)
      revert CannotClaimYet({
        lastClaimTimestamp: lastClaimTimestamp,
        blockTimestamp: block.timestamp,
        nextValidClaimTimestamp: nextValidClaimTimestamp
      });

    if (currentClaimPhase.ERC721Required.length > 0) {
      for (uint256 index = 0; index < currentClaimPhase.ERC721Required.length; index++) {
        if (IERC721(currentClaimPhase.ERC721Required[index]).balanceOf(_claimer) <= 0)
          revert ERC721RequiredBalance({
            erc721Required: currentClaimPhase.ERC721Required[index],
            claimer: _claimer
          });
      }
    }

    if (currentClaimPhase.ERC1155Required != address(0)) {
      if (
        IERC1155(currentClaimPhase.ERC1155Required).balanceOf(
          _claimer,
          currentClaimPhase.ERC1155IdRequired
        ) <= 0
      )
        revert ERC1155RequiredBalance({
          erc721Required: currentClaimPhase.ERC1155Required,
          erc721IdRequired: currentClaimPhase.ERC1155IdRequired,
          claimer: _claimer
        });
    }
  }

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
  ) public view returns (bool validMerkleProof, uint256 merkleProofIndex) {
    ClaimCondition memory currentClaimPhase = claimCondition.phases[_conditionId];

    if (currentClaimPhase.merkleRoot != bytes32(0)) {
      (validMerkleProof, merkleProofIndex) = MerkleProofLib.verify(
        _proofs,
        currentClaimPhase.merkleRoot,
        keccak256(abi.encodePacked(_claimer, _proofMaxQuantityPerTransaction))
      );
      if (!validMerkleProof)
        revert NotInWhitelist({ validMerkleProof: validMerkleProof });
      if (claimCondition.limitMerkleProofClaim[_conditionId].get(merkleProofIndex))
        revert ProofClaimed({
          conditionId: _conditionId,
          merkleProofIndex: merkleProofIndex,
          limitMerkleProofClaim: claimCondition.limitMerkleProofClaim[_conditionId].get(
            merkleProofIndex
          )
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

  /// @notice owner mint a reserve of tokens to specific address
  function mintOwner(uint256[] calldata quantities, uint256[] calldata ids)
    external
    onlyOwner
  {
    uint256 countTokenClaimedLocal = countTokenClaimed;
    for (uint256 index = 0; index < quantities.length; index++) {
      if (quantities[index] > countTokenClaimedLocal + quantities[index])
        revert UpMaxMint({
          countTokenClaimed: countTokenClaimedLocal,
          quantity: quantities[index],
          maxSupply: maxSupply
        });
      countTokenClaimedLocal += quantities[index];
    }
    countTokenClaimed = countTokenClaimedLocal;
    _mintBatch(_msgSender(), ids, quantities, "");
    emit Mints(ids, _msgSender(), quantities);
  }

  /// @notice Return current claim condition
  function getActiveClaimConditionId() public view returns (uint256) {
    ClaimConditionList storage conditionList = claimCondition;
    for (uint256 i = conditionList.count; i > 0; i--) {
      if (
        block.timestamp >= conditionList.phases[i - 1].startTimestamp &&
        (block.timestamp <= conditionList.phases[i - 1].endTimestamp ||
          conditionList.phases[i - 1].endTimestamp == 0)
      ) {
        return i - 1;
      }
    }
    revert("no active mint condition.");
  }

  /// @notice Return timestamp for next valid claim for only one claimer
  /// @param _conditionId id of collection you wan to get claim timestamp
  /// @param _claimer address wallet of one claimer
  function getClaimTimestamp(uint256 _conditionId, address _claimer)
    public
    view
    returns (uint256 lastClaimTimestamp, uint256 nextValidClaimTimestamp)
  {
    lastClaimTimestamp = claimCondition.limitLastClaimTimestamp[_conditionId][_claimer];

    unchecked {
      nextValidClaimTimestamp =
        lastClaimTimestamp +
        claimCondition.phases[_conditionId].waitTimeInSecondsBetweenClaims;

      if (nextValidClaimTimestamp < lastClaimTimestamp) {
        nextValidClaimTimestamp = type(uint256).max;
      }
    }
  }

  /// @notice Returns the claim condition at the given uid.
  /// @param _conditionId if of collection you want to return
  /// @return condition claim condition structure
  function getClaimConditionById(uint256 _conditionId)
    external
    view
    returns (ClaimCondition memory condition)
  {
    condition = claimCondition.phases[_conditionId];
  }

  /// @notice Returns the amount of stored baseURIs
  /// @return length length of baseURIIndices
  function getBaseURICount() external view returns (uint256) {
    return baseURIIndices.length;
  }

  /*///////////////////////////////////////////////////////////////
                        Setter functions
    //////////////////////////////////////////////////////////////*/

  /// @notice Lets a contract admin set a claim count for a wallet.
  /// @param _claimer address of claimer
  /// @param _count current count of claim for one wallet
  function setWalletClaimCount(address _claimer, uint256 _count) external onlyOwner {
    walletClaimCount[_claimer] = _count;
    emit WalletClaimCountUpdated(_claimer, _count);
  }

  /// @notice Lets a contract admin set a maximum number of NFTs that can be claimed by any wallet.
  /// @param _count max claim for each wallet
  function setMaxWalletClaimCount(uint256 _count) external onlyOwner {
    maxWalletClaimCount = _count;
    emit MaxWalletClaimCountUpdated(_count);
  }

  /// @notice Lets a module admin set a max total supply for token.
  /// @param _maxTotalSupply max supply of contract
  function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyOwner {
    maxTotalSupply = _maxTotalSupply;
    emit MaxTotalSupplyUpdated(_maxTotalSupply);
  }

  /// @notice Lets a module admin set a lower id to mint for lock transfer token.
  function setBlockLowerIdToMint(uint256 _blockLowerIdToMint) external onlyOwner {
    blockLowerIdToMint = _blockLowerIdToMint;
    emit BlockLowerIdToMintUpdated(_blockLowerIdToMint);
  }

  /// @notice Temporarily lock the contract
  function pause() external onlyOwner {
    paused = !paused;
    emit Pause(paused);
  }

  /// @notice emit event when token is transfered
  /// @param operator address of from transfer
  /// @param from address of from transfer
  /// @param to address of to transfer
  /// @param ids id of start token
  /// @param amounts quantity of transfered token
  /// @param data quantity of transfered token
  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual override(ERC1155, ERC1155Supply) {
    if (paused) revert Paused({ paused: paused });
    if (blockLowerIdToMint != 0) {
      for (uint256 index = 0; index < ids.length; index++) {
        require(ids[index] >= blockLowerIdToMint, "Your token is not transferable");
      }
    }
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    emit Transfered(from, to, ids, amounts);
  }
}
