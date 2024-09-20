// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CoreLoanPlatform is Ownable {
    using SafeERC20 for IERC20;  // Add this line to use SafeERC20 for IERC20 tokens

    IERC20 public USD;
    IERC20 public BTC;

    uint256 public totalBorrowed;

    uint256 public constant COLLATERAL_RATIO = 150; // 150% collateral ratio
    uint256 public constant BORROWABLE_RATIO = 66;  // 66% borrowable against collateral

    struct Loan {
        uint256 amount;
        uint256 collateral;
        uint256 timestamp;
        bool active;
    }

    mapping(address => uint256) public userCollateral;
    mapping(address => Loan) public loans;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event LoanTaken(address indexed user, uint256 amount, uint256 collateral);
    
    // Constructor to initialize USD and BTC token addresses
    constructor(address _USD, address _BTC) Ownable(msg.sender) {
        require(_USD != address(0) && _BTC != address(0), "Invalid token addresses");
        USD = IERC20(_USD);
        BTC = IERC20(_BTC);
    }

    // Function to deposit collateral
    function depositCollateral(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        USD.safeTransferFrom(msg.sender, address(this), amount);  // Safe transfer with SafeERC20
        userCollateral[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    // Function to withdraw collateral
    function withdrawCollateral(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(userCollateral[msg.sender] >= amount, "Insufficient collateral");

        // Check for active loan and required collateral
        uint256 borrowedAmount = loans[msg.sender].active ? loans[msg.sender].amount : 0;
        uint256 requiredCollateral = (borrowedAmount * COLLATERAL_RATIO) / 100;

        require(userCollateral[msg.sender] - amount >= requiredCollateral, "Withdrawal would undercollateralize loan");

        // Update user collateral and transfer
        userCollateral[msg.sender] -= amount;
        USD.safeTransfer(msg.sender, amount);  // Safe transfer with SafeERC20
        emit CollateralWithdrawn(msg.sender, amount);
    }

    // Function to borrow BTC
    function borrowBTC(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(!loans[msg.sender].active, "Existing loan must be repaid first");

        // Calculate required collateral for this loan
        uint256 requiredCollateral = (amount * COLLATERAL_RATIO) / 100;
        require(userCollateral[msg.sender] >= requiredCollateral, "Insufficient collateral");

        // Check the maximum amount the user can borrow
        uint256 maxBorrowable = (userCollateral[msg.sender] * BORROWABLE_RATIO) / 100;
        require(amount <= maxBorrowable, "Borrow amount exceeds limit");

        // Ensure the contract has enough BTC to lend
        require(BTC.balanceOf(address(this)) >= amount, "Insufficient BTC in contract");

        // Create the loan
        loans[msg.sender] = Loan(amount, requiredCollateral, block.timestamp, true);

        // Transfer BTC to the borrower and update total borrowed
        BTC.safeTransfer(msg.sender, amount);  // Safe transfer with SafeERC20
        totalBorrowed += amount;

        emit LoanTaken(msg.sender, amount, requiredCollateral);
    }

    // Function to view how much a user can borrow based on their collateral
    function getBorrowableAmount(address user) external view returns (uint256) {
        return (userCollateral[user] * BORROWABLE_RATIO) / 100;
    }

    // Function to view user's collateral
    function getUserCollateral(address user) external view returns (uint256) {
        return userCollateral[user];
    }
}
