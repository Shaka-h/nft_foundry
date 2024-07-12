//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
 //prevents re-entrancy attacks
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; //total number of items ever created
    Counters.Counter private _itemsSold; //total number of items sold
    Counters.Counter private _offerID;

    address payable owner; //mmiliki wa item at any time t
    address payable seller; //anayetengeneza item kwenye market

    constructor(){
        owner = payable(msg.sender);
    }

    struct MarketItem {
        uint itemId;
        address payable nftContract;
        uint256 tokenId;
        address payable seller; 
        address payable owner; 
        uint256 price;
        bool sold;
        uint256 currentBiddingPrice;
    }

    //a way to access values of the MarketItem struct above by passing an integer of the itemID
    mapping(uint256 => MarketItem) public idMarketItem;

    //log message (when Item is sold)
    event MarketItemCreated (
        uint indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address  seller,
        address  owner,
        uint256 price,
        bool sold,
        uint256 currentBiddingPrice
    );
  

    /// @notice function to create market item
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price) public payable nonReentrant{
         require(price > 0, "Price must be above zero");

         _itemIds.increment(); //add 1 to the total number of items ever created
         uint256 itemId = _itemIds.current();

         idMarketItem[itemId] = MarketItem(
             itemId,
             payable (nftContract),
             tokenId,
             payable(msg.sender), //address of the seller putting the nft up for sale
             payable(address(0)), //no owner yet (set owner to empty address)
             price,
             false,
             price
         );

            //transfer ownership of the nft to the contract itself
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

            //log this transaction
            emit MarketItemCreated(
             itemId,
             nftContract,
             tokenId,
             msg.sender,
             address(0),
             price,
             false,
             price);

        }

    struct Offer {
        address nftContract;
        uint256 itemID;
        uint256 offerPrice;
        address payable offerer;
        bool offerAccepted;
        uint256 offerID;
    }

    mapping(uint256 => Offer[]) public offersMadeToItem;

    function makeOffer(uint256 itemID, uint256 offerPrice) public payable nonReentrant {
        require(offerPrice > idMarketItem[itemID].currentBiddingPrice, "Offer price must be greater than the current bidding price");
        // require(msg.value == offerPrice, "Please submit the offer price in order to complete making an offer");


         // seller cannot make offer
        require(msg.sender != idMarketItem[itemID].seller, "Seller can not make offer");

        // Get Item details of a specific offer to know if already sold or not
        require(!idMarketItem[itemID].sold, "Item already sold");


        address nftContractAddress = idMarketItem[itemID].nftContract;

         // Decline the previous offer
        Offer[] storage previousOffers = offersMadeToItem[itemID];
        if (previousOffers.length > 0) {
            previousOffers[previousOffers.length - 1].offerAccepted = false;

            // Transfer payment from contract to previousOfferer
            previousOffers[previousOffers.length - 1].offerer.transfer(previousOffers[previousOffers.length - 1].offerPrice);
        }

        // Update the current highest offer price
        idMarketItem[itemID].currentBiddingPrice = offerPrice;

        _offerID.increment();

        // Store the offer
        offersMadeToItem[itemID].push(Offer({
            nftContract: nftContractAddress, // Use the correct nftContractAddress
            itemID: itemID,
            offerPrice: offerPrice,
            offerer: payable(msg.sender),
            offerAccepted: true,
            offerID: _offerID.current()
        }));
    }


    function getAllOffersMade(uint256 itemID) external view returns (Offer[] memory) {
        Offer[] storage offers = offersMadeToItem[itemID];
        Offer[] memory offersInfo = new Offer[](offers.length);

        for (uint256 i = 0; i < offers.length; i++) {
            offersInfo[i] = Offer({
                nftContract: offers[i].nftContract,
                itemID: offers[i].itemID,
                offerPrice: offers[i].offerPrice,
                offerer: offers[i].offerer,
                offerAccepted: offers[i].offerAccepted,
                offerID: offers[i].offerID
            });
        }

        return offersInfo;
    }

    function acceptOffer(uint256 itemId, address nftContract) external {

        require(idMarketItem[itemId].seller == msg.sender, "only the item creator can accept offer");

        // Get the array of offers made to the item with itemId
        Offer[] storage offers = offersMadeToItem[itemId];

        // Verify if there are any offers made to the item
        require(offers.length > 0, "No offers made to this item");

        // Get the index of the last offer in the array
        uint256 lastIndex = offers.length - 1;

        // Get the last offer in the array
        Offer storage offer = offers[lastIndex];

        // Check if the offer has already been accepted
        require(offer.offerAccepted, "No accepted offer");


        // Extract necessary details
        uint256 tokenId = idMarketItem[itemId].tokenId;
        uint256 offerPrice = offer.offerPrice;
        address payable offerer = offer.offerer;

        // Transfer payment from contract to seller
        idMarketItem[itemId].seller.transfer(offerPrice);

        // Transfer NFT ownership from contract to buyer
        IERC721(nftContract).transferFrom(address(this), offerer, tokenId);

        // Update item ownership and sold status
        idMarketItem[itemId].owner = payable(offerer);
        idMarketItem[itemId].sold = true;
        _itemsSold.increment();
    }



    /// @notice total number of items unsold on our platform
    function fetchMarketItemsUnsold() public view returns (MarketItem[] memory){
        uint itemCount = _itemIds.current(); //total number of items ever created
        //total number of items that are unsold = total items ever created - total items ever sold
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items =  new MarketItem[](unsoldItemCount);

        //loop through all items ever created
        for(uint i = 0; i < itemCount; i++){

            //get only unsold item
            //check if the item has not been sold
            //by checking if the owner field is empty
            if(idMarketItem[i+1].owner == address(0)){
                //yes, this item has never been sold
                uint currentId = idMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;

            }
        }
        return items; //return array of all unsold items
    }

    /// @notice fetch list of NFTS owned/bought by this user
    function fetchMyNFTs() public view returns (MarketItem[] memory){
        //get total number of items ever created
        uint totalItemCount = _itemIds.current();

        uint itemCount = 0;
        uint currentIndex = 0;


        for(uint i = 0; i < totalItemCount; i++){
            //get only the items that this user has bought/is the owner
            if(idMarketItem[i+1].owner == msg.sender){
                itemCount += 1; //total length
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for(uint i = 0; i < totalItemCount; i++){
            if(idMarketItem[i+1].owner == msg.sender){
                uint currentId = idMarketItem[i+1].itemId;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;

    }


        /// @notice fetch list of NFTS owned/bought by this user
    function fetchItemsCreated() public view returns (MarketItem[] memory){
        //get total number of items ever created
        uint totalItemCount = _itemIds.current();

        uint itemCount = 0;
        uint currentIndex = 0;


        for(uint i = 0; i < totalItemCount; i++){
            //get only the items that this user has bought/is the owner
            if(idMarketItem[i+1].seller == msg.sender){
                itemCount += 1; //total length
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for(uint i = 0; i < totalItemCount; i++){
            if(idMarketItem[i+1].seller == msg.sender){
                uint currentId = idMarketItem[i+1].itemId;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;

    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }

}