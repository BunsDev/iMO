// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '../QD.sol';

contract LockerMock is ILocker {
    function lockToken(address ethToken, uint256 amount, string memory accountId) external override(ILocker) {
        ERC20(ethToken).transferFrom(msg.sender, address(this), amount);
    }
} 