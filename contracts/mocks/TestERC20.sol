// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TestERC20 is ERC20 {
    constructor() ERC20("USDT", "USDT") {}
    function unprotectedMint(address _account, uint256 _amount) external {
        // No check on caller here
        _mint(_account, _amount);
    }
}