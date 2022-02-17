// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract QD is Ownable, ERC20 {
    using SafeERC20 for ERC20;

    // Constants
    uint constant internal _QD_DECIMALS   = 24                                 ;
    uint constant internal _USDT_DECIMALS = 6                                  ;
    uint constant public   AUCTION_LENGTH = 42 days                            ;

    // In cents
    uint constant public start_price      = 12                                 ;
    uint constant public final_price      = 94                                 ;

    // Set in constructor and never changed
    address immutable public usdt                                              ;
    uint    immutable public auction_start                                     ;

    event Mint       (address indexed sender, uint cost_in_usd, uint qd_amount);
    event Withdrawal (address indexed owner, uint amount)                      ;


    constructor(RC20 _usdt) ERC20("QuiD", "QD") {
        // Data validation
        require(_usdt.symbol() == "USDT", "QD: CONSTRUCTOR_R1");

        usdt = _usdt;

        // Auction starts on deployment
        auction_start = block.timestamp;

        // By default, owner is set to msg.sender
    }

    function mint(uint qd_amount) external returns (uint cost_in_usdt) {
        // Data validation
        require(qd_amount > 0, "QD: MINT_R1");
        require(block.timestamp < auction_start + AUCTION_LENGTH, "QD: MINT_R2");

        // Optimistic mint
        _mint(_msgSender(), qd_amount);

        // Calculate cost in USDT based on current price
        cost_in_usdt = qd_amount_to_usdt_amount(qd_amount, block.timestamp);

        emit Mint(_msgSender(), cost_in_usdt, qd_amount);

        // Will revert on failure (namely insufficient allowance)
        usdt.safeTransferFrom(_msgSender(), address(this), cost_in_usdt);
    }

    function withdraw(uint amount) external onlyOwner {
        usdt.safeTransfer(owner(), amount);
        emit Withdrawal(owner(), amount);
    }

    function decimals() public view override(ERC20) returns (uint8) {
        return uint8(_QD_DECIMALS);
    }

    function qd_amount_to_usdt_amount(
        uint qd_amount,
        uint block_timestamp
    ) public view returns (uint usdt_amount) {
        // Do data validation just in case
        require(block_timestamp < auction_start + AUCTION_LENGTH, "QD: QD_AMOUNT_TO_USDT_AMOUNT_R1")
        uint time_elapsed = block_timestamp - auction_start;

        // price = ((now - auction_start) // auction_length) * (final_price - start_price) + start_price
        uint price = (final_price - start_price) * time_elapsed / AUCTION_LENGTH + start_price;

        // cost = amount / qd_multiplier * usdt_multipler * price / 100
        usdt_amount = qd_amount * 10 ** _USDT_DECIMALS * price / 10 ** _QD_DECIMALS / 100;
    }
}