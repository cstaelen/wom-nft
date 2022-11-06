// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract WOM is ERC721Enumerable, Ownable, ERC721Burnable {
  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIdCounter;

  string public baseURI = "";
  string public baseExtension = ".json";
  string public customContractURI = "";
  uint256 public maxSupply = 100; // @TODO set to 1000
  uint256 public maxMintAmount = 2;
  uint256 public maxNFTPerAddress = 2;
  bool public paused = false;
  bool public onlyWhitelisted = true;
  address[] public whitelistedAddresses;
  mapping(address => uint256) public addressMintedBalance;

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
  ) ERC721(_name, _symbol) {
    setContractURI(_contractURI);
    setBaseURI(_initBaseURI);
  }

  // internal
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }

  // public
  function mint(uint256 _mintAmount) public payable {
    require(!paused, "the contract is paused");
    uint256 supply = totalSupply();
    require(_mintAmount > 0, "need to mint at least 1 NFT");
    require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

    if (msg.sender != owner()) {
      uint256 ownerMintedCount = addressMintedBalance[msg.sender];
      require(ownerMintedCount + _mintAmount <= maxNFTPerAddress, "max NFT per address exceeded");
      require(_mintAmount <= maxMintAmount, "max mint amount per session exceeded");

      if(onlyWhitelisted == true) {
          require(isWhitelisted(msg.sender), "user is not whitelisted");
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

  function isWhitelisted(address _user) public view returns (bool) {
    for (uint i = 0; i < whitelistedAddresses.length; i++) {
      if (whitelistedAddresses[i] == _user) {
          return true;
      }
    }
    return false;
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

  function getWhitelistedUsers() public view onlyOwner returns (address[] memory) {
    return whitelistedAddresses;
  }

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
  
  function whitelistUsers(address[] calldata _users) public onlyOwner {
    delete whitelistedAddresses;
    whitelistedAddresses = _users;
  }
 
  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(address from, address to, uint256 tokenId)
      internal
      override(ERC721, ERC721Enumerable)
  {
      super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
      return super.supportsInterface(interfaceId);
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