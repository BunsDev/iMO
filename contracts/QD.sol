// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

contract QD is ERC20Pausable {

    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    uint constant internal _QD_DECIMALS   = 24;
    uint constant internal _USDT_DECIMALS = 6;
    uint constant public AUCTION_LENGTH   = 42 days;
    uint constant public start_price      = 12;
    uint constant public final_price      = 94;

    address immutable public usdt;
    uint    immutable public deployment_date;

    // In cents

    constructor(
        address _usdt,
        address _founder
    ) ERC20("QuiD", "QD") {
        // TODO: Change
        usdt = _usdt;

        // Store deployment date
        deployment_date = block.timestamp;

        // Mint 100k Quid for founder
        _mint(_founder, 100_000 * 10 ** _QD_DECIMALS);

        // Pause contract
        _pause();
    }

    function mint(uint amount) external {
        require(amount > 0, "QD: MINT_R1");

        // price = ((now - deployment_date) // auction_length) * (final_price - start_price) + start_price
        
        uint time_elapsed = block.timestamp - deployment_date;

        uint price = (final_price - start_price) * (time_elapsed) / AUCTION_LENGTH + start_price;

        uint cost_in_usdt = amount * 10 ** _USDT_DECIMALS / 10 ** _QD_DECIMALS * price / 100;

        _mint(_msgSender(), amount);

        ERC20(usdt).safeTransferFrom(_msgSender(), address(this), cost_in_usdt);
    }

    function unpauseAfter42Days() external {
        require(block.timestamp >= deployment_date + AUCTION_LENGTH, "QD: UNPAUSE_AFTER_42_DAYS_R1");

        _unpause();
    }

    function decimals() public view override(ERC20) returns (uint8) {
        return uint8(_QD_DECIMALS);
    }
}