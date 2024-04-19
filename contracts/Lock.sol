//SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.8;

import "hardhat/console.sol";
import "./Dependencies/VRFConsumerBaseV2.sol";
import "./Dependencies/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

interface INonfungiblePositionManager is IERC721 {
    function positions(uint256 tokenId) external
        view returns (uint96 nonce,address operator,
            address token0, address token1, uint24 fee,
            int24 tickLower, int24 tickUpper, uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0, uint128 tokensOwed1
        );
}

interface ICollection is IERC721 {
    function latestTokenId() external view returns (uint256);
} // transfer F8N tokenId to 1 lucky clapped pledge per !MO
// pledge may transfer it back to QUID_ETH to receive prize

interface LinkTokenInterface is IERC20 {
  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);
  function increaseApproval(address spender, uint256 subtractedValue) external;
  function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
}

/**
 * @title Lock
 * @dev lock users' Uniswap LP stakes (V3 only)
 *
 * rationale: https://docs.uniswap.org/contracts/v3/guides/liquidity-mining/overview
 * Contract keeps track of the durations of each deposit. Rewards are paid individually
 * to each NFT (multiple deposits may be made of several V3 positions). The duration of
 * the deposit as well as the share of total liquidity deposited in the vault determines
 * how much the reward will be. It's paid from the WETH balance of this contract itself.
 *
 */

contract Lock is IERC721Receiver /*, VRFConsumerBaseV2, VRFCoordinatorV2Interface*/ { 

    // minimum duration of being in the vault before 
    // withdraw can be called (triggering reward payment)
    
    // for tracking time delta against 
    uint public immutable deployed; // timestamp when contract was deployed
    IERC20 public immutable weth; 
    IERC20 public immutable sdai; 
    uint public minLockDuration; 
    uint public weeklyReward;
    // TODO receive from _get_owe

    // VRFCoordinatorV2Interface COORDINATOR;
    bytes32 keyHash; address[] public owners;
    mapping(address => bool) public isOwner;
    mapping(uint256 => mapping(address => bool))
    public isConfirmed; LinkTokenInterface LINK;
    // mapping from tx index => owner => bool
    
    // no "drivin' a broke Vigor,
    // I'm with MO' [suppers]" 
    // ~ XX, crystallised remix
    MO[] public suppers;
    struct MO { 
        address winner;
        bool executed;
        uint confirm;
    }
    mapping(uint => uint) public totalsUSDT; // week # -> liquidity
    uint public totalLiquidityUSDT; // in UniV3 liquidity units
    uint public maxTotalUSDT; // in the same units

    mapping(uint => uint) public totalsWETH; // week # -> liquidity
    uint public totalLiquidityWETH; // for the WETH<>QD pool
    uint public maxTotalWETH;
    
    address constant F8N_0 = 0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405;
    address constant F8N_1 = 0x0299cb33919ddA82c72864f7Ed7314a3205Fb8c4;
    address constant QD = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4; // TODO reset after deploy
    address constant USDT = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    
    // Uniswap's NonFungiblePositionManager (one for all new pools)
    
    mapping(address => mapping(uint => uint)) public depositTimestamps; // for liquidity providers
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    event SetMinLockDuration(uint duration);
    event SetWeeklyReward(uint reward);

    event SetMaxTotalUSDT(uint maxTotal);
    event SetMaxTotalWETH(uint maxTotal);

    event Deposit(uint tokenId, address owner);
    event DepositETH(address indexed sender, uint256 amount, uint256 balance);

    event Withdraw(uint amount, uint when);
    event Withdrawal(uint tokenId, address owner, uint rewardPaid);
    event Propose(address indexed sender, uint txIndex, address _winner);

    event Confirm(address indexed owner, uint256 indexed txIndex);
    event Revoke(address indexed owner, uint256 indexed txIndex);
    event Execute(address indexed owner, uint256 indexed txIndex);
    
    modifier onlyOwners() { 
        require(isOwner[msg.sender], "not owner");
        _; 
    }
    modifier exists(uint256 _txIndex) { 
        require(_txIndex < suppers.length, "tx does not exist");
        _;
    }
    modifier notExecuted(uint256 _txIndex) { 
        require(!suppers[_txIndex].executed, "tx already executed"); 
        _;
    }
    modifier notConfirmed(uint256 _txIndex) { 
        require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed");
         _; 
    }
    function _getPositionInfo(uint tokenId) internal view returns (address token0, address token1, uint128 liquidity) {
        (, , token0, token1, , , , liquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
    }
    function getOwners() public view returns (address[] memory) { return owners; }
    function getCount() public view returns (uint256) { return suppers.length; }
    function _rollOver() internal returns (uint current_week) {
        current_week = (block.timestamp - deployed) / 1 weeks;
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsWETH[current_week] == 0 && totalLiquidityWETH > 0) {
            totalsWETH[current_week] = totalLiquidityWETH;
        }
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
        // TODO get weth from BP.debit
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

    constructor(address[] memory _owners) {
        require(_owners.length == 6, "owners required");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true; owners.push(owner);
        } weth = IERC20(WETH); sdai = IERC20(SDAI);
        deployed = block.timestamp;
        minLockDuration = 19 weeks; // out of 77 monbths total

        maxTotalWETH = type(uint256).max - 1;
        maxTotalUSDT = type(uint256).max - 1;

        // TODO in QD
        weeklyReward = 1_000_000_000_000; // 0.000001 WETH
        nonfungiblePositionManager = INonfungiblePositionManager(NFPM); // UniV3
    }

    receive() external payable {
        emit DepositETH(msg.sender, msg.value, address(this).balance);
    }

     /** contextual ref. youtube.com/clip/UgkxembxhMdjNasxjXBvGmIs1ceYD9kBGdkm
     * @dev This simplified multiSig only does transfer suppers (no calldata)...
     * @param _winner winner: check-in for supper, over 600k for all bday guests
     * when people propose a toast, they sip champagne...the equity tranche in
     * MO capital structure is represented by a Revuelto NFT, as the brake Pads
     * are what also power the batter my heart in 3, wind carry work, 3 types 
     * of QD, _get_owe is used in 3 places, not like senior/mezzanine/junior. 
     */
    function propose(address _winner) public onlyOwners { 
        // require(_to == QD || _to == sDAI || _to == WETH, "")

        // TODO transfer the warthog NFT or the shirt NFT
        // through off-chain randomness for lottery winner
 
        uint256 txIndex = suppers.length;
        suppers.push(
            MO({ winner: _winner,
                executed: false,
                confirm: 0 })
        );  emit Propose(msg.sender, txIndex, _winner);
    }


    function confirm(uint256 _txIndex)
        public
        onlyOwners
        exists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {   MO storage winner = suppers[_txIndex];
        winner.confirm += 1;
        isConfirmed[_txIndex][msg.sender] = true;
        emit Confirm(msg.sender, _txIndex);
    }

    function execute(uint256 _txIndex) public onlyOwners
        exists(_txIndex) notExecuted(_txIndex) {  
         MO storage winner = suppers[_txIndex];
        require(winner.confirm == 4,
            "cannot execute tx"
        );  winner.executed = true;
        emit Execute(msg.sender, _txIndex);
        // (bool success,) =
        //     transaction.to.call{value: transaction.value}(transaction.data);
        // require(success, "tx failed");
        // OPTIONAL expand scope of msig
    }

    function revoke(uint256 _txIndex) public onlyOwners
        exists(_txIndex) notExecuted(_txIndex) {  
        MO storage winner = suppers[_txIndex]; winner.confirm -= 1; 
        if (isConfirmed[_txIndex][msg.sender] && winner.confirm < 4) {
            isConfirmed[_txIndex][msg.sender] = false;
        }   emit Revoke(msg.sender, _txIndex);
    }
    function get(uint256 _txIndex) public view returns (address to,
    bool executed, uint confirm) { MO storage winner = suppers[_txIndex];
        return ( winner.winner, // check-in dinner...supper
            winner.executed, winner.confirm );
    }

    // QuidMint...foundation.app/@quid
    function onERC721Received( address, 
        address from, // previous owner's
        uint256 tokenId, bytes calldata data
    ) external override returns (bytes4) { 
        uint lambo = 16508; // youtu.be/sitXeGjm4Mc  
        if (tokenId == lambo && address(this) 
            == ICollection(F8N_0).ownerOf(lambo)) {
                sdai.transfer(from, 608358 * 1e18);
        } 
        if (address(this) == ICollection(F8N_1).ownerOf(2)) {
            sdai.transfer(from, 69383 * 1e18); // for shirt
        } // verfify that from was the winner of the lottery
        // and time delta
    }
   
    function deposit(uint tokenId) external { // all you need is...all UNI is...rolLOVEr
        (address token0, address token1, uint128 liquidity) = _getPositionInfo(tokenId);
        require(token1 == QD, "Uni::deposit: improper token id"); // love is all you need
        // usually this means that the owner of the position already closed it
        require(liquidity > 0, "Uni::deposit: cannot deposit empty amount");
        if (token0 == WETH) { totalsWETH[_rollOver()] += liquidity; totalLiquidityWETH += liquidity;
            require(totalLiquidityWETH <= maxTotalWETH, "Uni::deposit: totalLiquidity exceed max");
        } else if (token0 == USDT) { totalsUSDT[_rollOver()] += liquidity; totalLiquidityUSDT += liquidity;
            require(totalLiquidityUSDT <= maxTotalUSDT, "Uni::deposit: totalLiquidity exceed max");
        } else { require(false, "Uni::deposit: improper token id"); }
        depositTimestamps[msg.sender][tokenId] = block.timestamp;
        // transfer ownership of LP share to this contract
        nonfungiblePositionManager.transferFrom(msg.sender, address(this), tokenId);
        emit Deposit(tokenId, msg.sender);
    }

    /**
     * @dev Withdraw UniV3 LP deposit from vault (changing the owner back to original)
     */
    function withdrawToken(uint tokenId) external {
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
            uint current_week = _rollOver();
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
            uint current_week = _rollOver();
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
}
