//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
 //prevents re-entrancy attacks
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./DSCEngine.sol";

contract NFTMarket is ReentrancyGuard, AccessControl {

    error Price_Must_Be_Above_Zero();


    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; //total number of items ever created
    Counters.Counter private _itemsSold; //total number of items sold
    Counters.Counter private _offerID;
    Counters.Counter private _auctionID;
    Counters.Counter private _auctionsClosed;
    uint256 public _totalTax;  // Change to uint256 for accumulated tax
    address payable current_owner; //mmiliki wa item at any time t
    address payable seller; //anayetengeneza item kwenye market
    address payable TRA = payable(0x435C67b768aEDF84c9E6B00a4E8084dD7f1bc5FF);
    DSCEngine private coin;

    struct MarketItem {
        uint itemId;
        address payable nftContract;
        uint256 tokenId;
        address payable seller; 
        address payable owner; 
        uint256 price;
        uint256 tax;
        uint256 total;
        bool sold;
    }

    struct AuctionItem {
        uint auctionID;
        address payable nftContract;
        uint256 tokenId;
        address payable seller; 
        address payable owner; 
        uint256 price;
        uint256 tax;
        uint256 total;
        bool sold;
        uint256 currentBiddingPrice;
    }
    
    struct Buyer {
        address nftContract;
        uint256 itemID;
        uint256 actualPayment;
        uint256 tax;
        uint256 total;
        address buyer;
        address payable seller;
        uint256 time;
    }

    struct Offer {
        address nftContract;
        uint256 auctionID;
        uint256 offerPrice;
        address payable offerer;
        bool offerAccepted;
        uint256 offerID;
    }

    struct sales {
        uint256 itemId;
        uint256 tokenId;
        address owner;
        uint price;
    }

    struct taxes{
        uint256 itemId;
        uint256 tokenId;
        address from;
        address to;
        uint256 price; 
        uint256 tax;
        uint256 total;
        uint256 time;
    }


    //a way to access values of the MarketItem struct above by passing an integer of the itemID
    mapping(uint256 => MarketItem) public idMarketItem;
    mapping(uint256 => AuctionItem) public idAuctionItem;
    mapping(uint256 => Offer[]) public offersMadeToItem;
    mapping (address => sales[]) public mySales;
    mapping(uint256 => Buyer[]) public buyersMadeToItem;
    mapping (address => taxes[]) public mytaxes;
    mapping (address => uint256[]) private myItemsID;

    taxes[] public allTaxes;

    //log message (when Item is sold)
    event MarketItemCreated (
        uint indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address  seller,
        address  owner,
        uint256 price,
        bool sold, 
        uint256 time
    );

    event AuctionItemCreated (
        uint indexed auctionID,
        address indexed nftContract,
        uint256 indexed tokenId,
        address  seller,
        address  owner,
        uint256 price,
        bool sold,
        uint256 currentBiddingPrice
    );

    event itemSold (
        uint256 Id,
        address seller,
        address buyer,
        uint256 price,
        uint256 time
    );
    
    event taxation (
       uint256 itemId,
       uint256 tokenId,
       address from,
       address to,
       uint256 price,
       uint256 tax,
       uint256 total
    );

    constructor(DSCEngine _coin) {
        coin = _coin;
        current_owner = payable(msg.sender);
    }

    /// @notice function to create market item
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint price) public payable nonReentrant{
        
        if (price <= 0) {
            revert Price_Must_Be_Above_Zero();
        }

        _itemIds.increment(); //add 1 to the total number of items ever created
        uint256 itemId = _itemIds.current();
        uint256 tax = price.mul(18).div(100);


        uint256 actualpayment = price - tax;

        idMarketItem[itemId] = MarketItem(
             itemId,
             payable (nftContract),
             tokenId,
             payable(msg.sender), //address of the seller putting the nft up for sale
             payable(address(0)), //no owner yet (set owner to empty address)
             price,
             tax,
             actualpayment,
             false
        );
        myItemsID[msg.sender].push(itemId);

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
            block.timestamp
        );

    }

    function createAuctionItem(
        address nftContract,
        uint256 tokenId,
        uint256 price) public payable nonReentrant{
         require(price > 0, "Price must be above zero");

         _auctionID.increment(); //add 1 to the total number of items ever created
         uint256 auctionID = _auctionID.current();

         idAuctionItem[auctionID] = AuctionItem(
             auctionID,
             payable (nftContract),
             tokenId,
             payable(msg.sender), //address of the seller putting the nft up for sale
             payable(msg.sender), //no owner yet (set owner to empty address)
             price,
             0,
             0,
             false,
             price
         );

            //transfer ownership of the nft to the contract itself
            IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

            //log this transaction
            emit MarketItemCreated(
             auctionID,
             nftContract,
             tokenId,
             msg.sender,
             address(0),
             price,
             false,
             price);

    }  
    
    function sellItem (uint256 itemID, uint256 sellingPrice) public {
         // Only owner can sell
        require(msg.sender == idMarketItem[itemID].owner, " Only owner can sell");

         _itemIds.increment(); //add 1 to the total number of items ever created
         uint256 itemId = _itemIds.current();

        uint256 tax = sellingPrice.mul(18e2);


        uint256 actualpayment = sellingPrice - tax;

        idMarketItem[itemId] = MarketItem(
             itemId,
             payable (idMarketItem[itemID].nftContract),
             idMarketItem[itemID].tokenId,
             payable(msg.sender), //address of the seller putting the nft up for sale
             payable(address(0)), //no owner yet (set owner to empty address)
             sellingPrice,
             tax,
             actualpayment,
             false
        );
            //transfer ownership of the nft to the contract itself
            IERC721(idMarketItem[itemId].nftContract).transferFrom(msg.sender, address(this), idMarketItem[itemId].tokenId);

            //log this transaction
            emit MarketItemCreated(
            itemID,
            idMarketItem[itemId].nftContract,
            idMarketItem[itemId].tokenId,
            msg.sender,
            address(0),
            sellingPrice,
            false,
            block.timestamp
             );

    }

    function approveBuyer (uint256 itemID) public view returns(bool) {
        // seller cannot make offer
        require(msg.sender != idMarketItem[itemID].seller, "Seller can not make buyer");

        // Get Item details of a specific offer to know if already sold or not
        require(!idMarketItem[itemID].sold, "Item already sold");

        return true;
    }

    function buyItem (uint256 itemID) public  nonReentrant {
        
        require(idMarketItem[itemID].owner != msg.sender, "Item owner cant buy the item");
        require(idMarketItem[itemID].sold == false, "Item already sold");
        
        // Extract necessary details
        uint256 tokenId = idMarketItem[itemID].tokenId;
        address nftContractAddress = idMarketItem[itemID].nftContract;
        uint256 tax = idMarketItem[itemID].tax;
        uint256 total = idMarketItem[itemID].total; 
        uint256 actualPayment = idMarketItem[itemID].price; 

        // Transfer payment from buyer to seller
        // coin.transfer(idMarketItem[itemID].seller, buyPrice);

        // Transfer NFT ownership from seller to buyer
        IERC721(nftContractAddress).transferFrom(address(this), msg.sender, tokenId);

        // Update item ownership and sold status
        idMarketItem[itemID].owner = payable(msg.sender);
        idMarketItem[itemID].sold = true;
        _itemsSold.increment();
        _totalTax = _totalTax.add(tax);  // Accumulate the tax


        emit itemSold(
            itemID,
            idMarketItem[itemID].seller,
            msg.sender,
            actualPayment,
            block.timestamp
        );

        emit taxation (
            itemID,
            tokenId,
            msg.sender,
            idMarketItem[itemID].seller,
            actualPayment,
            tax,
            total
        );

        allTaxes.push(taxes(
            itemID,
            tokenId,
            msg.sender,
            idMarketItem[itemID].seller,
            actualPayment,
            tax,
            total,
            block.timestamp
        ));

        mySales[msg.sender].push(sales(
            itemID,
            tokenId,
            idMarketItem[itemID].owner,
            total
        )); 

        buyersMadeToItem[itemID].push(Buyer(
            idMarketItem[itemID].nftContract,
            itemID,
            actualPayment,
            tax,
            total,
            idMarketItem[itemID].seller,
            idMarketItem[itemID].owner,
            block.timestamp
        ));     
    }
 
    function getAllSalesMade(uint256 itemId) external view returns (Buyer[] memory) {
        Buyer[] storage purchase = buyersMadeToItem[itemId];
        Buyer[] memory saleInfo = new Buyer[](purchase.length);

        for (uint256 i = 0; i < purchase.length; i++) {
            saleInfo[i] = Buyer({
                nftContract: purchase[i].nftContract,
                itemID: purchase[i].itemID,
                seller: purchase[i].seller,
                buyer: purchase[i].buyer,
                tax: purchase[i].tax,
                total: purchase[i].total,
                actualPayment: purchase[i].actualPayment,
                time: purchase[i].time
            });
        }
        return saleInfo;
    }

    // function setAtshAddress(COIN _coin) public onlyOwner {
    //     coin = _coin;
    // }
        
    function makeOffer(uint256 auctionID, uint256 offerPrice) public payable nonReentrant {
        require(offerPrice > idAuctionItem[auctionID].currentBiddingPrice, "Offer price must be greater than the current bidding price");
        // require(msg.value == offerPrice, "Please submit the offer price in order to complete making an offer");


         // seller cannot make offer
        require(msg.sender != idAuctionItem[auctionID].seller, "Seller can not make offer");

        // Get Item details of a specific offer to know if already sold or not
        require(!idAuctionItem[auctionID].sold, "Item already sold");


        address nftContractAddress = idAuctionItem[auctionID].nftContract;

         // Decline the previous offer
        Offer[] storage previousOffers = offersMadeToItem[auctionID];
        if (previousOffers.length > 0) {
            previousOffers[previousOffers.length - 1].offerAccepted = false;

            // Transfer payment from contract to previousOfferer
            coin.transferWei(previousOffers[previousOffers.length - 1].offerer, previousOffers[previousOffers.length - 1].offerPrice);

            // previousOffers[previousOffers.length - 1].offerer.transfer(previousOffers[previousOffers.length - 1].offerPrice);
        }

        // Update the current highest offer price
        idAuctionItem[auctionID].currentBiddingPrice = offerPrice;

        _offerID.increment();

        // Store the offer
        offersMadeToItem[auctionID].push(Offer({
            nftContract: nftContractAddress, // Use the correct nftContractAddress
            auctionID: auctionID,
            offerPrice: offerPrice,
            offerer: payable(msg.sender),
            offerAccepted: true,
            offerID: _offerID.current()
        }));
        
    }

    function getAllOffersMade(uint256 auctionID) external view returns (Offer[] memory) {
        Offer[] storage offers = offersMadeToItem[auctionID];
        Offer[] memory offersInfo = new Offer[](offers.length);

        for (uint256 i = 0; i < offers.length; i++) {
            offersInfo[i] = Offer({
                nftContract: offers[i].nftContract,
                auctionID: offers[i].auctionID,
                offerPrice: offers[i].offerPrice,
                offerer: offers[i].offerer,
                offerAccepted: offers[i].offerAccepted,
                offerID: offers[i].offerID
            });
        }

        return offersInfo;
    }

    function acceptOffer(uint256 auctionID, address nftContract) external {

        require(idAuctionItem[auctionID].seller == msg.sender, "only the item creator can accept offer");

        // Get the array of offers made to the item with itemId
        Offer[] storage offers = offersMadeToItem[auctionID];

        // Verify if there are any offers made to the item
        require(offers.length > 0, "No offers made to this item");

        // Get the index of the last offer in the array
        uint256 lastIndex = offers.length - 1;

        // Get the last offer in the array
        Offer storage offer = offers[lastIndex];

        // Check if the offer has already been accepted
        require(offer.offerAccepted, "No accepted offer");


        // Extract necessary details
        uint256 tokenId = idAuctionItem[auctionID].tokenId;
        uint256 offerPrice = offer.offerPrice;
        address payable offerer = offer.offerer;
        uint256 tax = offerPrice.mul(18).div(100);
        uint256 actualpayment = offerPrice - tax;

        // Transfer payment from contract to seller
        // idAuctionItem[auctionID].seller.transfer(actualpayment);
        // TRA.transfer(tax);

        // coin.transferWei(idAuctionItem[auctionID].seller, actualpayment);
        // coin.transferWei(TRA, tax);


        // Transfer NFT ownership from contract to buyer
        IERC721(nftContract).transferFrom(address(this), offerer, tokenId);

        // Update item ownership and sold status
        idAuctionItem[auctionID].owner = payable(offerer);
        idAuctionItem[auctionID].sold = true;
        _auctionsClosed.increment();

        emit taxation (
            auctionID,
            tokenId,
            msg.sender,
            idAuctionItem[auctionID].seller,
            offerPrice,
            tax,
            actualpayment

        );
        
        emit itemSold(
            auctionID,
            idAuctionItem[auctionID].seller,
            msg.sender,
            offerPrice,
            block.timestamp
        );
        
        mytaxes[msg.sender].push(taxes(
            auctionID,
            tokenId,
            msg.sender,
            idMarketItem[auctionID].seller,
            offerPrice,
            tax,
            actualpayment,
            block.timestamp
        ));
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

    function fetchAuctionsCreated() public view returns (AuctionItem[] memory){
        //get total number of items ever created
        uint totalAuctionCount = _auctionID.current();

        uint auctionCount = 0;
        uint currentIndex = 0;


        for(uint i = 0; i < totalAuctionCount; i++){
            //get only the items that this user has bought/is the owner
            if(idMarketItem[i+1].seller == msg.sender){
                auctionCount += 1; //total length
            }
        }

        AuctionItem[] memory auctions = new AuctionItem[](auctionCount);
        for(uint i = 0; i < totalAuctionCount; i++){
            if(idAuctionItem[i+1].seller == msg.sender){
                uint currentId = idAuctionItem[i+1].auctionID;
                AuctionItem storage currentItem = idAuctionItem[currentId];
                auctions[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return auctions;

    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
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
            if(idMarketItem[i+1].sold == false ){
                //yes, this item has never been sold
                uint currentId = idMarketItem[i + 1].itemId;
                MarketItem storage currentItem = idMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;

            }
        }
        return items; //return array of all unsold items
    }

    function fetchAuctionItemsUnsold() public view returns (AuctionItem[] memory){
        uint auctionCount = _auctionID.current(); //total number of items ever created
        //total number of items that are unsold = total items ever created - total items ever sold
        uint openAuctionCount = auctionCount - _auctionsClosed.current();
       uint currentIndex = 0;

        AuctionItem[] memory auction =  new AuctionItem[](openAuctionCount);

        //loop through all items ever created
        for(uint i = 0; i < auctionCount; i++){

            //get only unsold item
            //check if the item has not been sold
            //by checking if the owner field is empty
            if(idAuctionItem[i+1].sold == false ){
                //yes, this item has never been sold
                uint currentId = idAuctionItem[i + 1].auctionID;
                AuctionItem storage currentAuction = idAuctionItem[currentId];
                auction[currentIndex] = currentAuction;
                currentIndex += 1;

            }
        }
        return auction; //return array of all unsold items
    }
    
    /// @notice fetch list of NFTS owned/bought by this user
    function fetchMyNFTs() public view returns (uint256[] memory){
        //get total number of items ever created
        return myItemsID[msg.sender];
    }

    /// @notice fetch list of NFTS owned/bought by this user
    function fetchMarketItemById(uint256 itemId) public view returns (MarketItem memory){
        //get total number of items ever created
        return idMarketItem[itemId];
    }

    function getAllTaxes() public view returns (taxes[] memory) {
        return allTaxes;
    }
    

}