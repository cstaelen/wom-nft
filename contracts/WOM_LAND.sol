// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import {DefaultOperatorFilterer} from "../extensions/operator-filter/DefaultOperatorFilterer.sol";
import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract WomLand is ERC721A, DefaultOperatorFilterer, Ownable {
    string public baseURI;
    uint256 public maxSupply = 1000;
    uint256 public publicMaxNFTPerAddress = 1;
    uint256 public publicPriceMint = 0.04 ether;
    bool public paused = false;
    bool public publicMint = false;
    address public signerAddress = 0x4E99031f4C39cd1AE173Bc32e397dE77ac6D6395;
    mapping(address => uint256) public alreadyMinted;

    using ECDSA for bytes32;

    constructor() ERC721A("Lands of Mythesda", "LOM") {}

    function mint(
        uint256 quantity,
        uint256 maxMint,
        uint256 unitPrice,
        bytes memory signature
    ) public payable {
        require(!paused, "The contract is paused");
        uint256 supply = totalSupply();
        require(quantity > 0, "Need to mint at least 1 NFT");
        require(supply + quantity <= maxSupply, "Max NFT limit exceeded");

        uint256 ownerMintedCount = alreadyMinted[msg.sender];

        if (!publicMint) {
            verifyCoupon(maxMint, unitPrice, msg.sender, signature);
            require(
                ownerMintedCount + quantity <= maxMint,
                "Max NFT for address exceeded"
            );
            require(msg.value >= unitPrice * quantity, "Insufficient founds");
        } else {
            require(
                ownerMintedCount + quantity <= publicMaxNFTPerAddress,
                "Max NFT for address exceeded"
            );
            require(
                msg.value >= publicPriceMint * quantity,
                "Insufficient founds"
            );
        }

        alreadyMinted[msg.sender] = alreadyMinted[msg.sender] + quantity;

        _mint(msg.sender, quantity);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function burn(uint256 tokenId) public onlyOwner {
        super._burn(tokenId);
    }

    function setBaseUri(string memory baseuri_) public onlyOwner {
        baseURI = baseuri_;
    }

    function ownerMint(address to, uint256 quantity) public onlyOwner {
        _mint(to, quantity);
    }

    function setSignerAddress(address signerAddress_) public onlyOwner {
        signerAddress = signerAddress_;
    }

    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    function setPublicMint(bool _state) public onlyOwner {
        publicMint = _state;
    }

    function setPublicMaxNFTPerAddress(uint256 _state) public onlyOwner {
        publicMaxNFTPerAddress = _state;
    }

    function setPublicPrice(uint256 _state) public onlyOwner {
        publicPriceMint = _state;
    }

    function verifyCoupon(
        uint256 maxMint,
        uint256 unitPrice,
        address minterAddress,
        bytes memory signature
    ) public view virtual {
        bytes32 inputHash = keccak256(
            abi.encodePacked(maxMint, unitPrice, minterAddress)
        );

        bytes32 ethSignedMessageHash = inputHash.toEthSignedMessageHash();
        address recoveredAddress = ethSignedMessageHash.recover(signature);
        require(recoveredAddress == signerAddress, "Bad signature");
    }

    function withdraw() public payable onlyOwner {
        // This will payout the contract balance to the owner.
        // Do not remove this otherwise you will not be able to withdraw the funds.
        // =============================================================================
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        assert(os);
        // =============================================================================
    }

    // OPERATOR FILTER OVERRIDES

    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
    super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public payable override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public payable override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
