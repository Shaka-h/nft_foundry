// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { DecentralizedStableCoin } from "./DecentralizedStableCoin.sol";

/*
 * @title DSCEngine
 * @author Patrick Collins
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */

contract DSCEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenNotAllowed(uint8 token);
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__TransactionMinted();
    error DSCEngine__FailedToApprove();


    ///////////////////
    // State Variables
    ///////////////////
    DecentralizedStableCoin private immutable i_dsc;
    uint256 private constant TO_WEI = 1e18;

    enum CollateralToken {
        TSH,
        ALP
    }

    enum TransactionStatus {
        PENDING,
        COMPLETED
    }


    struct transaction {
        string transactionId;
        TransactionStatus transactionStatus;
    }

    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(CollateralToken tokenType => uint256 amount)) private s_collateralDeposited;
    /// @dev Amount of DSC minted by user
    mapping(address user => uint256 amount) private s_DSCMinted;

    mapping ( address user => transaction[]) public s_transactions;

    mapping(address => mapping(string => TransactionStatus)) public transactionStatusById;


    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(address indexed user, CollateralToken indexed token, uint256 indexed amount, string transactionId);
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, CollateralToken token, uint256 amount); // if
    event tokenMinted(address indexed user, string transactionId, uint256 indexed amount);

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    } 

    modifier isAllowedToken(CollateralToken token) {
        if (uint8(token) >= uint8(CollateralToken.ALP)) {
            revert DSCEngine__TokenNotAllowed(uint8(token));
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor( address dscAddress) {
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////
    // External Functions
    ///////////////////
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToMint: The amount of DSC you want to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDsc(
        CollateralToken token,
        uint256 amountCollateral,
        uint256 amountDscToMint,
        string memory transactionId
    )
        external
    {
        depositCollateral(token, amountCollateral, transactionId);
        mintDsc(amountDscToMint, transactionId);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountDscToBurn: The amount of DSC you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */
    function redeemCollateralForDsc(
        CollateralToken tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    )
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
    {
        _burnDsc(amountDscToBurn, msg.sender, msg.sender);
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have DSC minted, you will not be able to redeem until you burn your DSC
     */
    function redeemCollateral(
        CollateralToken tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _redeemCollateral(tokenCollateralAddress, amountCollateral, msg.sender, msg.sender);
    }

    function approve(uint256 amount) public moreThanZero(amount) nonReentrant{
        uint256 amountInWei = amount * TO_WEI;
        i_dsc.approve(address(this), amountInWei);
    }

    /*
     * @notice careful! You'll burn your DSC here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * you DSC but keep your collateral in.
     */
    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
    }

    
    ///////////////////
    // Public Functions
    ///////////////////
    /*
     * @param amountDscToMint: The amount of DSC you want to mint
     * You can only mint DSC if you hav enough collateral
     */
    function mintDsc(uint256 amountDscToMint, string memory transactionId) public moreThanZero(amountDscToMint) nonReentrant {

        // Ensure user has such transaction and its status is not already minted

        if (transactionStatusById[msg.sender][transactionId] != TransactionStatus.PENDING) {
            revert DSCEngine__TransactionMinted();
        }

        s_DSCMinted[msg.sender] += amountDscToMint;
        uint256 amountInWei = amountDscToMint * TO_WEI;
        bool minted = i_dsc.mint(msg.sender, amountInWei);
        transactionStatusById[msg.sender][transactionId] = TransactionStatus.COMPLETED;

        if (minted != true) {
            revert DSCEngine__MintFailed();
        }

        emit tokenMinted(msg.sender, transactionId, amountDscToMint);
    }

    function transferWei(address to, uint256 amountDscToTransfer) public  moreThanZero(amountDscToTransfer) nonReentrant{
        // address owner = msg.sender;
        uint256 amount = amountDscToTransfer * TO_WEI;
        i_dsc.transfer(to, amount);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(
        CollateralToken token,
        uint256 amountCollateral,
        string memory transactionId
    )
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(token)
    {
        s_collateralDeposited[msg.sender][token] += amountCollateral;

        s_transactions[msg.sender].push(transaction({
            transactionId: transactionId,
            transactionStatus: TransactionStatus.PENDING
        }));

        emit CollateralDeposited(msg.sender, token, amountCollateral, transactionId);
    }


    function getTransactionStatus(string memory transactionId) view external returns (TransactionStatus) {
        return transactionStatusById[msg.sender][transactionId];
    }

    ///////////////////
    // Private Functions
    ///////////////////
    function _redeemCollateral(
        CollateralToken token,
        uint256 amountCollateral,
        address from,
        address to
    )
        private
    {
        s_collateralDeposited[from][token] -= amountCollateral;
        emit CollateralRedeemed(from, to, token, amountCollateral);

        // Alp as collateral will be added here
        // bool success = IERC20(token).transfer(to, amountCollateral);
        // if (!success) {
        //     revert DSCEngine__TransferFailed();
        // }
    }

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;

        // // bool approve = i_dsc.approve(address(this), amountDscToBurn);
        // if (!approve) {
        //     revert DSCEngine__FailedToApprove();
        // }
        uint256 amountInWei = amountDscToBurn * TO_WEI;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountInWei);
        // This conditional is hypothetically unreachablea
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountInWei);
    }

    function balanceOf(address account) public view returns (uint256) {
        uint256 from_WEI = i_dsc.balanceOf(account) / TO_WEI;
        return from_WEI;
    }

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted)
    {
        totalDscMinted = s_DSCMinted[user];
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDscMinted)
    {
        return _getAccountInformation(user);
    }


    function getCollateralBalanceOfUser(address user, CollateralToken token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }


    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

}
