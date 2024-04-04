//SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.7.6;
pragma abicoder v2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

/**
 * @title UniLock...like a Ulock for...elect Rick's bicycle of the mind
 * @dev Lock is a contract that lock users' Uniswap LP stakes (V3 only)
 *
 * rationale: https://docs.uniswap.org/contracts/v3/guides/liquidity-mining/overview
 * Contract keeps track of the durations of each deposit. Rewards are paid individually
 * to each NFT (multiple deposits may be made of several V3 positions). The duration of
 * the deposit as well as the share of total liquidity deposited in the vault determines
 * how much the reward will be. It's paid from the WETH balance of this contract itself.
 *
 */

contract Lock is ReentrancyGuard {
    // minimum duration of being in the vault before 
    // withdraw can be called (triggering reward payment)
    uint public minLockDuration;
    
    uint public weeklyReward;
    uint public unlockTime;
    
    uint public immutable deployed; // timestamp when contract was deployed
    IERC20 public immutable weth;
    
    address[] public owners;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool)) public isConfirmed; // mapping from tx index => owner => bool
    
    Transaction[] public transactions;
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
    }
    mapping(uint => uint) public totalsUSDT; // week # -> liquidity
    uint public totalLiquidityUSDT; // in UniV3 liquidity units
    uint public maxTotalUSDT; // in the same units

    mapping(uint => uint) public totalsWETH; // week # -> liquidity
    uint public totalLiquidityWETH; // for the WETH<>QD pool
    uint public maxTotalWETH;
    
    // ERC20 addresses TODO change QD (BO) contract deployed address
    address constant QD = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4; 
    address constant USDT = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    // Uniswap's NonFungiblePositionManager (one for all new pools)
    address constant NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    mapping(address => mapping(uint => uint)) public depositTimestamps; // for liquidity providers
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    event SetWeeklyReward(uint reward);
    event SetMinLockDuration(uint duration);

    event SetMaxTotalUSDT(uint maxTotal);
    event SetMaxTotalWETH(uint maxTotal);

    event Deposit(uint tokenId, address owner);
    event DepositETH(address indexed sender, uint256 amount, uint256 balance);

    event Withdraw(uint amount, uint when);
    event Withdrawal(uint tokenId, address owner, uint rewardPaid);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    
    modifier onlyOwners() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
        _;
    }


    function _getPositionInfo(uint tokenId) internal view returns (address token0, address token1, uint128 liquidity) {
        (, , token0, token1, , , , liquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
    }

    function _rollOverWETH() internal returns (uint current_week) {
        current_week = (block.timestamp - deployed) / 1 weeks;
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsWETH[current_week] == 0 && totalLiquidityWETH > 0) {
            totalsWETH[current_week] = totalLiquidityWETH;
        }
    }

    function _rollOverUSDT() internal returns (uint current_week) {
        current_week = (block.timestamp - deployed) / 1 weeks;
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsUSDT[current_week] == 0 && totalLiquidityUSDT > 0) {
            totalsUSDT[current_week] = totalLiquidityUSDT;
        }
    }

    /**
     * @dev Update the weekly reward. Amount in WETH.
     * @param _newReward New weekly reward.
     */
    function setWeeklyReward(uint _newReward) external onlyOwners {
        weeklyReward = _newReward;
        emit SetWeeklyReward(_newReward);
    }

    /**
     * @dev Update the minimum lock duration for staked LP tokens.
     * @param _newMinLockDuration New minimum lock duration.(in weeks)
     */
    function setMinLockDuration(uint _newMinLockDuration) external onlyOwners {
        require(_newMinLockDuration % 1 weeks == 0, "Uni::deposit: Duration must be in units of weeks");
        minLockDuration = _newMinLockDuration;
        emit SetMinLockDuration(_newMinLockDuration);
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>USDT pair).
     * The purpose is to increase the amount gradually, so as to not dilute the APY
     * unnecessarily much in beginning.
     * @param _newMaxTotalUSDT New max total.
     */
    function setMaxTotalUSDT(uint _newMaxTotalUSDT) external onlyOwners {
        maxTotalUSDT = _newMaxTotalUSDT;
        emit SetMaxTotalUSDT(_newMaxTotalUSDT);
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>WETH pair).
     * The purpose is to increase the amount gradually, so as to not dilute the APY
     * unnecessarily much in beginning.
     * @param _newMaxTotalWETH New max total.
     */
    function setMaxTotalWETH(uint _newMaxTotalWETH) external onlyOwners {
        maxTotalWETH = _newMaxTotalWETH;
        emit SetMaxTotalWETH(_newMaxTotalWETH);
    }

    constructor(uint _unlockTime, address[] memory _owners) {
        require(_owners.length == 5, "owners required");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true; owners.push(owner);
        }
        require( // TODO remove
            block.timestamp < _unlockTime,
            "Unlock time should be in the future"
        );
        unlockTime = _unlockTime; // TODO unused
        deployed = block.timestamp;
        minLockDuration = 1 weeks;

        maxTotalWETH = type(uint256).max - 1;
        maxTotalUSDT = type(uint256).max - 1;

        // TODO in QD
        weeklyReward = 1_000_000_000_000; // 0.000001 WETH
        weth = IERC20(WETH);
        nonfungiblePositionManager = INonfungiblePositionManager(NFPM); // UniV3
    }

    receive() external payable {
        emit DepositETH(msg.sender, msg.value, address(this).balance);
    }

     /**
     * @dev 
     * @param _to hardcoded, address of QD transaction will be executed ON
     * @param _value amount to send
     * @param _eth bool for whether to send ether or QD (if bool is false )
     * @param _data to be sent to _to 
     */
    function submitTransaction(address _to, uint256 _value, bool _eth, bytes memory _data)
        public
        onlyOwners
    {
        uint256 txIndex = transactions.length;
        // constrain to 
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                numConfirmations: 0
            })
        );
        emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
    }


    function confirmTransaction(uint256 _txIndex)
        public
        onlyOwners
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        transaction.numConfirmations += 1;
        isConfirmed[_txIndex][msg.sender] = true;

        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint256 _txIndex)
        public
        onlyOwners
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(
            transaction.numConfirmations == 3,
            "cannot execute tx"
        );

        transaction.executed = true;

        (bool success,) =
            transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");

        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(uint256 _txIndex)
        public
        onlyOwners
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];

        require(isConfirmed[_txIndex][msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[_txIndex][msg.sender] = false;

        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txIndex)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 numConfirmations
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.data,
            transaction.executed,
            transaction.numConfirmations
        );
    }
    
    function withdraw() public onlyOwners {
        console.log("Unlock time is %o and block timestamp is %o", unlockTime, block.timestamp);
        require(block.timestamp >= unlockTime, "You can't withdraw yet");
        emit Withdraw(address(this).balance, block.timestamp);
        // payable(owner()).transfer(address(this).balance); TODO
    }

    /**
     * @dev Withdraw UniV3 LP deposit from vault (changing the owner back to original)
     */
    function withdrawToken(uint tokenId) external nonReentrant {
        uint timestamp = depositTimestamps[msg.sender][tokenId]; // verify a deposit exists
        require(timestamp > 0, "Lock::withdraw: no owner exists for this tokenId");
        require( // how long this deposit has been in the vault
            (block.timestamp - timestamp) > minLockDuration,
            "Lock::withdraw: minimum duration for the deposit has not elapsed yet"
        );
        (address token0, , uint128 liquidity) = _getPositionInfo(tokenId);
        uint week_iterator = (timestamp - deployed) / 1 weeks;

        // could've deposited right before end of the week, so need some granularity
        // otherwise an unfairly large portion of rewards may be obtained by staker
        uint so_far = (timestamp - deployed) / 1 hours;
        uint delta = so_far - (week_iterator * 168);

        uint reward = (delta * weeklyReward) / 168; // 1st reward maybe fraction of week's worth
        uint totalReward = 0;
        if (token0 == WETH) {
            uint current_week = _rollOverWETH();
            while (week_iterator < current_week) {
                uint totalThisWeek = totalsWETH[week_iterator];
                if (totalThisWeek > 0) {
                    // need to check lest div by 0
                    // staker's share of rewards for given week
                    totalReward += (reward * liquidity) / totalThisWeek;
                }
                week_iterator += 1;
                reward = weeklyReward; // this is redundant but required
                // represents a full week's reward
            }
            so_far = (block.timestamp - deployed) / 1 hours;
            delta = so_far - (current_week * 168);
            // the last reward will be a fraction of a whole week's worth
            reward = (delta * weeklyReward) / 168; // we're in the middle of a current week
            totalReward += (reward * liquidity) / totalLiquidityWETH;
            totalLiquidityWETH -= liquidity;
        } else if (token0 == USDT) {
            uint current_week = _rollOverUSDT();
            while (week_iterator < current_week) {
                uint totalThisWeek = totalsUSDT[week_iterator];
                if (totalThisWeek > 0) {
                    // need to check lest div by 0
                    // staker's share of rewards for given week
                    totalReward += (reward * liquidity) / totalThisWeek;
                }
                week_iterator += 1;
                reward = weeklyReward;
            }
            so_far = (block.timestamp - deployed) / 1 hours;
            delta = so_far - (current_week * 168);
            // the last reward will be a fraction of a whole week's worth
            reward = (delta * weeklyReward) / 168; // we're in the middle of a current week
            totalReward += (reward * liquidity) / totalLiquidityUSDT;
            totalLiquidityUSDT -= liquidity;
        }
        delete depositTimestamps[msg.sender][tokenId]; 
        // TODO change to QD
        require(weth.transfer(msg.sender, totalReward), "Lock::withdraw: transfer failed");
        // transfer ownership back to the original LP token owner
        nonfungiblePositionManager.transferFrom(address(this), msg.sender, tokenId);
        emit Withdrawal(tokenId, msg.sender, totalReward);
    }

    /**
     * @dev This is one way of treating deposits.
     * Instead of deposit function implementation,
     * user might manually transfer their NFT
     * and this would trigger onERC721Received.
     * Stakers underwrite captive insurance for
     * the relay (against outages in mevAuction)
     */
    function deposit(uint tokenId) external nonReentrant {
        (address token0, address token1, uint128 liquidity) = _getPositionInfo(tokenId);
        require(token1 == QD, "Uni::deposit: improper token id");
        // usually this means that the owner of the position already closed it
        require(liquidity > 0, "Uni::deposit: cannot deposit empty amount");

        if (token0 == WETH) {
            totalsWETH[_rollOverWETH()] += liquidity;
            totalLiquidityWETH += liquidity;
            require(totalLiquidityWETH <= maxTotalWETH, "Uni::deposit: totalLiquidity exceed max");
        } else if (token0 == USDT) {
            totalsUSDT[_rollOverUSDT()] += liquidity;
            totalLiquidityUSDT += liquidity;
            require(totalLiquidityUSDT <= maxTotalUSDT, "Uni::deposit: totalLiquidity exceed max");
        } else {
            require(false, "Uni::deposit: improper token id");
        }
        depositTimestamps[msg.sender][tokenId] = block.timestamp;
        // transfer ownership of LP share to this contract
        nonfungiblePositionManager.transferFrom(msg.sender, address(this), tokenId);
        emit Deposit(tokenId, msg.sender);
    }
}
