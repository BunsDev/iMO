// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract QD is Ownable, Pausable, ERC20 {

    using SafeERC20 for ERC20;

    uint constant internal _QD_DECIMALS   = 24;
    uint constant internal _USDT_DECIMALS = 6;
    uint constant public AUCTION_LENGTH   = 42 days;
    uint constant public start_price      = 12;
    uint constant public final_price      = 94;

    address immutable public usdt;
    uint    immutable public auction_start;

    // In cents

    constructor(
        address _usdt
    ) ERC20("QuiD", "QD") {
        // TODO: Change
        usdt = _usdt;

        // Auction starts on deployment
        auction_start = block.timestamp;

        // Pause token transfers
        _pause();

        // By default, owner is set to msg.sender
    }

    function mint(uint qd_amount) external {
        require(qd_amount > 0, "QD: MINT_R1");
        require(block.timestamp < auction_start + AUCTION_LENGTH, "QD: MINT_R2");

        _mint(_msgSender(), qd_amount);

        uint cost_in_usdt = qd_amount_to_usdt_amount(qd_amount, block.timestamp);

        ERC20(usdt).safeTransferFrom(_msgSender(), address(this), cost_in_usdt);
    }

    function withdraw(uint amount) external onlyOwner {
        ERC20(usdt).safeTransfer(owner(), amount);
    }

    function unpauseAfter42Days() external {
        require(block.timestamp >= auction_start + AUCTION_LENGTH, "QD: UNPAUSE_AFTER_42_DAYS_R1");

        _unpause();
    }

    function decimals() public view override(ERC20) returns (uint8) {
        return uint8(_QD_DECIMALS);
    }

    function transfer(address to, uint256 amount)
        public override(ERC20) whenNotPaused returns (bool)
    {
        return ERC20.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount)
        public override(ERC20) whenNotPaused returns (bool)
    {
        return ERC20.transferFrom(from, to, amount);
    }

    function qd_amount_to_usdt_amount(
        uint qd_amount,
        uint block_timestamp
    ) public view returns (uint usdt_amount) {
        uint time_elapsed = block_timestamp - auction_start;

        // price = ((now - auction_start) // auction_length) * (final_price - start_price) + start_price
        uint price = (final_price - start_price) * time_elapsed / AUCTION_LENGTH + start_price;

        // cost = amount / qd_multiplier * usdt_multipler * price / 100
        usdt_amount = qd_amount * 10 ** _USDT_DECIMALS * price / 10 ** _QD_DECIMALS / 100;
    }
}