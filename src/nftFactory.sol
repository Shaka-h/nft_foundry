// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract MyCollection is ERC721URIStorage {
    // Payable fallback function
    fallback() external payable {}

    // Payable receive function (Solidity version >= 0.6.0)
    receive() external payable {}
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    string public logo;
    string public description;

    address public marketContractAddress;


    string[] public allCollectionTokens;
    mapping (uint256 => string) tokenURIById;

    event tokenCreated(string tokenURI, uint256 itemId, uint256 time);

    constructor(address _marketContractAddress, string memory name, string memory symbol, string memory _logo, string memory _description) ERC721(name, symbol) {
        marketContractAddress = _marketContractAddress;
        logo = _logo;
        description = _description;
    }


    function createToken(string memory tokenURI) public returns (uint) {
        _tokenIds.increment(); // Increment the token ID counter
        uint256 newItemId = _tokenIds.current(); // Get the new token ID

        _mint(msg.sender, newItemId); // Mint the token to the caller
        _setTokenURI(newItemId, tokenURI); // Set the token URI

        allCollectionTokens.push(tokenURI); // Add the new token ID to the array
        tokenURIById[newItemId] = tokenURI; // Store the token URI in the mapping
        setApprovalForAll(marketContractAddress, true); //grant transaction permission to marketplace
        emit tokenCreated(tokenURI, newItemId, block.timestamp);

        return newItemId; // Return the new token ID
    }

    function getAllCollectionTokens() external view returns (string[] memory) {
        return allCollectionTokens; 
    }

    function getTokenURIById (uint256 tokenId) external view returns (string memory) {
        return tokenURIById[tokenId];
    }
}



contract NFTFactory {
    struct MyNFTCollection {
        address owner;
        address NftContract;
        string name;
        string symbol;
        string logo;
        string description;
    }

    mapping(address => MyNFTCollection) public nftCollectionsByAddress; // Mapping from contract address to NFT collection
    mapping(address => MyNFTCollection[]) public collectionsByOwner;
    mapping(address => address[]) private collectionsBy;

    MyNFTCollection[] public allNFTCollections;


    event NFTDeployed(address indexed owner, address indexed nftContract, string name, string symbol, string logo, string description, uint256 time);

    function deployNFTContract(address _marketContractAddress, string memory _name, string memory _symbol, string memory _logo, string memory _description) external returns (address) {
        MyCollection nftContract = new MyCollection(_marketContractAddress, _name, _symbol, _logo, _description);
        MyNFTCollection memory newCollection = MyNFTCollection(msg.sender, address(nftContract), _name, _symbol, _logo, _description);
        nftCollectionsByAddress[address(nftContract)] = newCollection;
        collectionsByOwner[msg.sender].push(newCollection);
        allNFTCollections.push(newCollection);
        collectionsBy[msg.sender].push(address(nftContract));
        emit NFTDeployed(msg.sender, address(nftContract), _name, _symbol, _logo, _description, block.timestamp);
        return address(nftContract);
    }

    function getNFTCollectionByAddress(address _contractAddress) external view returns (MyNFTCollection memory) {
        return nftCollectionsByAddress[_contractAddress];
    }

    function getAllDeployedNFTCollections() external view returns (MyNFTCollection[] memory) {
        return allNFTCollections;
    }
    
    function getCollectionsByOwner() external view returns (MyNFTCollection[] memory) {
        return collectionsByOwner[msg.sender];
    }


}
