// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;
import {ERC721, Strings} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC721OnChain} from "../extensions/operator-filter/ContractAbstract.sol";

contract WOM is ERC721OnChain {
  using Counters for Counters.Counter;
  using Strings for uint256;

  Counters.Counter private _tokenIdCounter;

  string public baseURI = "";
  string public baseExtension = ".json";
  string public customContractURI = "";
  uint256 public maxSupply = 1000;
  uint256 public maxMintAmount = 2;
  uint256 public maxNFTPerAddress = 2;
  bool public paused = false;
  bool public onlyWhitelisted = true;
  mapping(address => uint256) public addressMintedBalance;
  bytes32 public merkleRoot = 0x48b73e1b279cf47e870b8ed17a1257ddecd7beb6492cccf15c13f0a7fbea91a8;

  event Sale(
    uint256 id,
    uint256 cost,
    uint256 timestamp,
    address indexed buyer,
    string indexed tokenURI
  );

  struct SaleStruct {
    uint256 id;
    uint256 cost;
    uint256 timestamp;
    address buyer;
    string metadataURL;
  }

  SaleStruct[] minted;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initBaseURI,
    string memory _contractURI
  ) ERC721OnChain(_name, _symbol, _initBaseURI, _contractURI) {
    setContractURI(_contractURI);
    setBaseURI(_initBaseURI);
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function mint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable {
    require(!paused, "the contract is paused");
    uint256 supply = totalSupply();
    require(_mintAmount > 0, "need to mint at least 1 NFT");
    require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

    if (msg.sender != owner()) {
      uint256 ownerMintedCount = addressMintedBalance[msg.sender];
      require(ownerMintedCount + _mintAmount <= maxNFTPerAddress, "max NFT per address exceeded");
      require(_mintAmount <= maxMintAmount, "max mint amount per session exceeded");

      if(onlyWhitelisted == true) {
          require(isWhitelisted(msg.sender, _merkleProof), "user is not whitelisted");
      }
    }

    for (uint256 i = 1; i <= _mintAmount; i++) {
      addressMintedBalance[msg.sender]++;
      uint256 tokenId = _tokenIdCounter.current() + 1;
      _tokenIdCounter.increment();
      _safeMint(msg.sender, tokenId);

      minted.push(
        SaleStruct(
          tokenId,
          msg.value,
          block.timestamp,
          msg.sender,
          tokenURI(tokenId)
        )
      );
      
      emit Sale(tokenId, msg.value, block.timestamp, msg.sender, tokenURI(tokenId));
    }
  }
  
  function contractURI() public view returns (string memory) {
    return customContractURI;
  }

  function isWhitelisted(address _user, bytes32[] calldata _merkleProof) public view returns (bool) {
    bytes32 leaf = keccak256(abi.encodePacked(_user));
    return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
  }

  function walletOfOwner(address _owner)
    public
    view
    returns (uint256[] memory)
  {
    uint256 ownerTokenCount = balanceOf(_owner);
    uint256[] memory tokenIds = new uint256[](ownerTokenCount);
    for (uint256 i; i < ownerTokenCount; i++) {
      tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
    }
    return tokenIds;
  }

  function tokenURI(uint256 tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
      ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
      : "";
  }

  // Getters

  function getAllNFTs() public view onlyOwner returns (SaleStruct[] memory) {
    return minted;
  }
  
  function getAnNFT(uint256 tokenId) public view onlyOwner returns (SaleStruct memory) {
    return minted[tokenId - 1];
  }
  
  // Setters

  function setMaxMintAmount(uint256 _limit) public onlyOwner {
    maxMintAmount = _limit;
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }
  
  function setMaxNFTPerAddress(uint256 _limit) public onlyOwner {
    maxNFTPerAddress = _limit;
  }

  function setBaseURI(string memory _newBaseURI) public onlyOwner {
    baseURI = _newBaseURI;
  }

  function setContractURI(string memory _newContractURI) public onlyOwner {
    customContractURI = _newContractURI;
  }

  function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
    baseExtension = _newBaseExtension;
  }

  function pause(bool _state) public onlyOwner {
    paused = _state;
  }
  
  function setOnlyWhitelisted(bool _state) public onlyOwner {
    onlyWhitelisted = _state;
  }

  function withdraw() public payable onlyOwner {
    // This will payout the contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}("");
    assert(os);
    // =============================================================================
  }
}