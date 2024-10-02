/*  

 /$$$$$$$  /$$$$$$$$  /$$$$$$  /$$       /$$$$$$$$  /$$$$$$  /$$   /$$ /$$   /$$ /$$$$$$$ 
| $$__  $$| $$_____/ /$$__  $$| $$      | $$_____/ /$$__  $$| $$$ | $$| $$  | $$| $$__  $$
| $$  \ $$| $$      | $$  \__/| $$      | $$      | $$  \ $$| $$$$| $$| $$  | $$| $$  \ $$
| $$  | $$| $$$$$   | $$      | $$      | $$$$$   | $$$$$$$$| $$ $$ $$| $$  | $$| $$$$$$$/
| $$  | $$| $$__/   | $$      | $$      | $$__/   | $$__  $$| $$  $$$$| $$  | $$| $$____/ 
| $$  | $$| $$      | $$    $$| $$      | $$      | $$  | $$| $$\  $$$| $$  | $$| $$      
| $$$$$$$/| $$$$$$$$|  $$$$$$/| $$$$$$$$| $$$$$$$$| $$  | $$| $$ \  $$|  $$$$$$/| $$      
|_______/ |________/ \______/ |________/|________/|__/  |__/|__/  \__/ \______/ |__/      
                                                                                          
                                                                                                                                                                           
 /$$   /$$ /$$$$$$$$ /$$$$$$$$ /$$      /$$  /$$$$$$  /$$$$$$$  /$$   /$$
| $$$ | $$| $$_____/|__  $$__/| $$  /$ | $$ /$$__  $$| $$__  $$| $$  /$$/
| $$$$| $$| $$         | $$   | $$ /$$$| $$| $$  \ $$| $$  \ $$| $$ /$$/ 
| $$ $$ $$| $$$$$      | $$   | $$/$$ $$ $$| $$  | $$| $$$$$$$/| $$$$$/  
| $$  $$$$| $$__/      | $$   | $$$$_  $$$$| $$  | $$| $$__  $$| $$  $$  
| $$\  $$$| $$         | $$   | $$$/ \  $$$| $$  | $$| $$  \ $$| $$\  $$ 
| $$ \  $$| $$$$$$$$   | $$   | $$/   \  $$|  $$$$$$/| $$  | $$| $$ \  $$
|__/  \__/|________/   |__/   |__/     \__/ \______/ |__/  |__/|__/  \__/
                                                                                                                                                                                                               

                                                                                                  */

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract DCU is ERC721Enumerable, AccessControl, Ownable, ReentrancyGuard {
    using Strings for uint256;
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");

    mapping(address => bool) public whitelistedAddresses;

    bytes32 public merkleRootWhitelist;

    mapping(address => uint256) public addressMintedBalanceWL;

    string private BASE_URI;
	
	mapping(uint256 => string) private _tokenURIs;

    uint256 public PRICE = 0 ether;

    uint256 public SALE_STEP = 0;

    uint256 public INDEX = 0;

    uint256 public MAX_SUPPLY = 100;

    uint256 public maxMintAmountWL = 1;

    constructor() ERC721("DeCleanup Rewards", "DCU") Ownable(msg.sender) {_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(METADATA_ROLE, msg.sender);}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //************* MINT *************

    function mint(uint256 _mintAmount) external payable onlyOwner {
        require(SALE_STEP >= 1, "Mint is not opened");
        require(INDEX + _mintAmount <= MAX_SUPPLY + 1, "Exceeds Max Common Supply");
        require(PRICE * _mintAmount <= msg.value, "ETH not enough");
        _mintLoop(msg.sender, _mintAmount);
    }

    function mintWL(uint256 _mintAmount , bytes32[] calldata _merkleProof) external payable {
        uint256 ownerMintedCount = addressMintedBalanceWL[msg.sender];
        require(SALE_STEP >= 1, "Mint is not opened");
        require(INDEX + _mintAmount <= MAX_SUPPLY + 1, "Exceeds Max Common Supply");
        require(PRICE * _mintAmount <= msg.value, "ETH not enough");
        require(isWhitelisted(msg.sender, _merkleProof),"user is not whitelisted");
        require(ownerMintedCount + _mintAmount <= maxMintAmountWL,"max NFT per address exceeded");
        require(_mintAmount <= maxMintAmountWL,"max mint amount per session exceeded");
        _mintLoop(msg.sender, _mintAmount);
    }


    function _mintLoop(address _receiver, uint256 _mintAmount) internal {
        for (uint256 i = 0; i < _mintAmount; i++) {
            _safeMint(_receiver, INDEX + i);
        }
        INDEX += _mintAmount;
    }

    function isWhitelisted(address _user, bytes32[] calldata _merkleProof)
        public
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_user));
        return MerkleProof.verify(_merkleProof, merkleRootWhitelist, leaf);
    }




    //************* VIEWS *************
    
    function _baseURI() internal view virtual override returns (string memory) {
        return BASE_URI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is a specific token URI, return it
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }

        // Otherwise, concatenate the base URI and tokenId
        return bytes(base).length > 0 ? string(abi.encodePacked(base, tokenId.toString(), ".json")) : "";
    }

    //************* ADMIN *************
	
	function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyRole(METADATA_ROLE) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function airdrop(address[] memory _airdropAddresses, uint256 _mintAmount) external onlyOwner {
        require(INDEX + _airdropAddresses.length * _mintAmount <= MAX_SUPPLY + 1, "Exceeds Max Common Supply");

        for (uint256 i = 0; i < _airdropAddresses.length; i++) {
            address to = _airdropAddresses[i];
            _mintLoop(to, _mintAmount);
        }
    }

    function setPRICE(uint256 _newprice) external onlyOwner {
        PRICE = _newprice;
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        BASE_URI = _newBaseURI;
    }

    function pause() external onlyOwner {
        SALE_STEP = 0;
    }

    function openMint() external onlyOwner {
        SALE_STEP = 1;
    }

    //************* WITHDRAW *************

    function clearstuckEth() external onlyOwner nonReentrant {
        uint256 curBalance = address(this).balance;
        require(curBalance > 0, "Nothing to withdraw");
        bool success;
        (success, ) = payable(owner()).call{value: curBalance}('Transaction Unsuccessful');
        require(success);
    }

    function grantMetadataRole(address account) external onlyOwner {
        grantRole(METADATA_ROLE, account);
    }

    function revokeMetadataRole(address account) external onlyOwner {
        revokeRole(METADATA_ROLE, account);
    }
    function setWhitelistMerkleRoot(bytes32 _merkleRoot) public onlyRole(METADATA_ROLE) {
        merkleRootWhitelist = _merkleRoot;
    }

    function setmaxMintAmountWL(uint256 _newmaxMintAmount) public onlyOwner {
        maxMintAmountWL = _newmaxMintAmount;
    }

}