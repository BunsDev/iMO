//SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.8;

import "./MO.sol";
import "hardhat/console.sol"; // TODO comment out
import "./Dependencies/VRFConsumerBaseV2.sol";
import "./Dependencies/VRFCoordinatorV2Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ICollection is IERC721 {
    function latestTokenId() external view returns (uint256);
}
interface LinkTokenInterface is IERC20 {
    function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);
    function increaseApproval(address spender, uint256 subtractedValue) external;
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool success);
}
interface INonfungiblePositionManager is IERC721 {
    function positions(uint256 tokenId) external
        view returns (uint96 nonce,address operator,
            address token0, address token1, uint24 fee,
            int24 tickLower, int24 tickUpper, uint128 liquidity,
            uint feeGrowthInside0LastX128,
            uint feeGrowthInside1LastX128,
            uint128 tokensOwed0, uint128 tokensOwed1
        );
}

contract Lot is Ownable, 
    VRFConsumerBaseV2, 
    IERC721Receiver { 
    // for tracking time deltas...
    uint public last_lotto_trigger;
    uint public immutable deployed;
    IERC20 public immutable weth; 
    IERC20 public immutable sdai; 
    uint public minLock; 
    uint public reward;
    // TODO receive from _get_owe

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINK; bytes32 keyHash;
    uint64 public subscriptionId;
    address public owed; 
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint public requestId; 
    uint randomness; // 🎲
    MO Gen; // heap...

    mapping(uint => uint) public totalsUSDT; // week # -> liquidity
    uint public liquidityUSDT; // in UniV3 liquidity units
    uint public maxTotalUSDT; // in the same units

    mapping(uint => uint) public totalsWETH; // week # -> liquidity
    uint public liquidityWETH; // for the WETH<>QD pool
    uint public maxTotalWETH;

    uint constant public SALARY = 608358 * 1e18;
    uint constant public LOTTO = 69383 * 1e18;

    address constant F8N_0 = 0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405;
    address constant F8N_1 = 0x0299cb33919ddA82c72864f7Ed7314a3205Fb8c4;
    address constant QUID = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4;
    address constant QD = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4; // TODO reset after deploy MO
    address constant USDT = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    event SetReward(uint reward);
    event SetMinLock(uint duration);
    event SetMaxTotalUSDT(uint maxTotal);
    event SetMaxTotalWETH(uint maxTotal);
    event Deposit(uint tokenId, address owner);
    event RequestedRandomness(uint256 requestId);
    
    event Withdrawal(uint tokenId, address owner, uint rewardPaid);
    event DepositETH(address indexed sender, uint256 amount, uint256 balance);
    mapping(address => mapping(uint => uint)) public depositTimestamps; // LP
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    // Uniswap's NonFungiblePositionManager (one for all pools of UNI V3)...

    receive() external payable {
        emit DepositETH(msg.sender, msg.value, address(this).balance);
    }  
    function _getInfo(uint tokenId) internal view 
        returns (address token0, address token1, uint128 liquidity) {
        (, , token0, token1, , , , liquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
    } 
    function _roll() internal returns (uint current_week) { // rollOver week
        current_week = (block.timestamp - deployed) / 1 weeks;
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsWETH[current_week] == 0 && liquidityWETH > 0) {
            totalsWETH[current_week] = liquidityWETH;
        }
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsUSDT[current_week] == 0 && liquidityUSDT > 0) {
            totalsUSDT[current_week] = liquidityUSDT;
        }
    }

    /**
     * @dev Update the weekly reward. Amount in WETH.
     * @param _newReward New weekly reward.
     */
    function setReward(uint _newReward) external onlyOwner {
        reward = _newReward;
        // TODO get weth from BP.debit
        emit SetReward(_newReward);
    }

    /**
     * @dev Update minimum lock duration for staked LP tokens
     * @param _newMinLock New minimum lock duration (in weeks)
     */
    function setMinLock(uint _newMinLock) external onlyOwner {
        require(_newMinLock % 1 weeks == 0, 
        "Uni::setMinLock: must be in weeks");
        minLock = _newMinLock;
        emit SetMinLock(_newMinLock);
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>USDT pair).
     * The purpose is to increase the amount gradually, so as to not dilute reward
     * unnecessarily much in beginning phase.
     * @param _newMaxTotalUSDT New max total.
     */
    function setMaxTotalUSDT(uint _newMaxTotalUSDT) external onlyOwner {
        maxTotalUSDT = _newMaxTotalUSDT;
        emit SetMaxTotalUSDT(_newMaxTotalUSDT);
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>WETH pair).
     * The purpose is to increase the amount gradually, so as to not dilute reward
     * unnecessarily much in beginning phase.
     * @param _newMaxTotalWETH New max total.
     */
    function setMaxTotalWETH(uint _newMaxTotalWETH) external onlyOwner {
        maxTotalWETH = _newMaxTotalWETH;
        emit SetMaxTotalWETH(_newMaxTotalWETH);
    }

    // TODO circular dependency MO needs Lot address, and 
    // Lot also needs MO address (QD)
    constructor(address _vrfCoordinator, address _link_token, 
        bytes32 _hash, uint32 _limit, uint16 _confirm) 
        VRFConsumerBaseV2(_vrfCoordinator) {
            owed = QUID; // first liquidation
            callbackGasLimit = _limit;
            requestConfirmations = _confirm;
            reward = 1_000_000_000_000; // 0.000001 WETH
            minLock = Gen.LENT(); keyHash = _hash;
            maxTotalWETH = type(uint256).max - 1;
            maxTotalUSDT = type(uint256).max - 1;
            LINK = LinkTokenInterface(_link_token); 
            weth = IERC20(WETH); sdai = IERC20(SDAI);
            deployed = block.timestamp; Gen = MO(QUID);
            COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);    
            COORDINATOR.addConsumer(subscriptionId, address(this));
            subscriptionId = COORDINATOR.createSubscription(); // pubsub...
            nonfungiblePositionManager = INonfungiblePositionManager(NFPM);
    }

    /** Whenever an {IERC721} `tokenId` token is transferred to this contract:
     * @dev Safe transfer `tokenId` token from `from` to `address(this)`, 
     * checking that contract recipient prevent tokens from being forever locked.
     *
     * - `tokenId` token must exist and be owned by `from`
     * - If the caller is not `from`, it must have been allowed 
     *   to move this token by either {approve} or {setApprovalForAll}.
     *
     * - {onERC721Received} is called after a safeTransferFrom...
     *   
     * - It must return its Solidity selector to confirm the token transfer.
     *   If any other value is returned or the interface is not implemented
     *   by the recipient, the transfer will be reverted.
     */
    // QuidMint...foundation.app/@quid
    function onERC721Received(address, 
        address from, // previous owner's
        uint256 tokenId, bytes calldata data
    ) external override returns (bytes4) { 
        require(Gen.YEAR() > last_lotto_trigger, "early"); 
        uint lambo = 16508; // youtu.be/sitXeGjm4Mc 
        uint shirt = ICollection(F8N_1).latestTokenId(); 
        address parked = ICollection(F8N_0).ownerOf(lambo);
        address racked = ICollection(F8N_1).ownerOf(shirt);
        if (tokenId == lambo && parked == address(this)) {
            sdai.transfer(from, SALARY);
            // TODO QD
            // since this only gets called twice a year
            // 1477741 - (608358 x 2) stays in contract
        }   else if (tokenId == shirt && racked == address(this)) {
                require(parked == address(this), "chronology");
                require(from == owed, "Lot::wrong winner");
                last_lotto_trigger = Gen.YEAR();
                ICollection(F8N_0).transferFrom(
                    address(this), QUID, lambo
                );  sdai.transfer(owed, LOTTO); 
                requestId = COORDINATOR.requestRandomWords(
                    keyHash, subscriptionId,
                    requestConfirmations,
                    callbackGasLimit, 1
            );  emit RequestedRandomness(requestId);
        }   return this.onERC721Received.selector;
    }

    // TODO after 16th MO empty Lot of any surpluses
    function fulfillRandomWords(uint _requestId, 
        uint[] memory randomWords) internal override { 
        uint when = Gen.YEAR() - 1; // retro-active...
        randomness = randomWords[0]; 
        uint shirt = ICollection(F8N_1).latestTokenId(); // 2
        address racked = ICollection(F8N_1).ownerOf(shirt);
        require(randomness > 0 && _requestId > 0 
        && _requestId == requestId &&
        address(this) == racked, "Lot::randomWords"); 
        address[] memory own = Gen.liquidated(when);
        uint indexOfWinner = randomness % own.length;
        owed = own[indexOfWinner];
        ICollection(F8N_1).transferFrom(
            address(this), owed, shirt
        ); // next winner pays deployer
    }
   
    function deposit(uint tokenId) external { 
        (address token0, address token1, uint128 liquidity) = _getInfo(tokenId);
        require(token1 == QD, "Uni::deposit: improper token id"); 
        // usually this means that the owner of the position already closed it
        require(liquidity > 0, "Uni::deposit: cannot deposit empty amount");
        if (token0 == WETH) { totalsWETH[ _roll()] += liquidity; liquidityWETH += liquidity;
            require(liquidityWETH <= maxTotalWETH, "Uni::deposit: totalLiquidity exceed max");
        } else if (token0 == USDT) { totalsUSDT[ _roll()] += liquidity; liquidityUSDT += liquidity;
            require(liquidityUSDT <= maxTotalUSDT, "Uni::deposit: totalLiquidity exceed max");
        } else { require(false, "Uni::deposit: improper token id"); }
        depositTimestamps[msg.sender][tokenId] = block.timestamp;
        // transfer ownership of LP share to this contract
        nonfungiblePositionManager.transferFrom(msg.sender, address(this), tokenId);
        emit Deposit(tokenId, msg.sender);
    }

    /**
     * @dev Withdraw UniV3 LP deposit from vault (changing the owner back to original)
     */
    function withdraw(uint tokenId) external returns (uint total) {
        uint timestamp = depositTimestamps[msg.sender][tokenId]; // verify a deposit exists
        require(timestamp > 0, "Lock::withdraw: no owner exists for this tokenId");
        require( // how long this deposit has been in the vault
            (block.timestamp - timestamp) > minLock,
            "Lock::withdraw: min duration hasn't elapsed yet"
        );  (address token0, , uint128 liquidity) = _getInfo(tokenId);
        // possible that 1st reward is fraction of week's worth
        uint week_iterator = (timestamp - deployed) / 1 weeks;
        // could've deposited right before end of the week, so need some granularity
        // otherwise an unfairly large portion of rewards may be obtained by staker
        uint so_far = (timestamp - deployed) / 1 hours;
        uint delta = so_far - (week_iterator * 168);
        uint earn = (delta * reward) / 168; 
        uint current_week = _roll();
        if (token0 == WETH) {
            while (week_iterator < current_week) {
                uint thisWeek = totalsWETH[week_iterator];
                if (thisWeek > 0) { // check lest div by 0
                    // staker's share of rewards for given week
                    total += (earn * liquidity) / thisWeek;
                } week_iterator += 1; earn = reward;
                // represents a full week's reward
            }
            so_far = (block.timestamp - deployed) / 1 hours;
            delta = so_far - (current_week * 168);
            // the last reward will be a fraction of a whole week's worth
            earn = (delta * reward) / 168; // we're in the middle of a current week
            total += (earn * liquidity) / liquidityWETH;
            liquidityWETH -= liquidity;
        } else if (token0 == USDT) {
            while (week_iterator < current_week) {
                uint thisWeek = totalsUSDT[week_iterator];
                if (thisWeek > 0) { // need to check lest div by 0
                    // staker's share of rewards for given week...
                    total += (earn * liquidity) / thisWeek;
                }   week_iterator += 1; earn = reward;
            }
            so_far = (block.timestamp - deployed) / 1 hours;
            delta = so_far - (current_week * 168);
            // the last reward will be a fraction of a whole week's worth...
            earn = (delta * reward) / 168; // in the middle of current week
            total += (earn * liquidity) / liquidityUSDT;
            liquidityUSDT -= liquidity;
        }   delete depositTimestamps[msg.sender][tokenId]; 
        require(weth.transfer(msg.sender, total), "Lock::withdraw: transfer failed");
        nonfungiblePositionManager.transferFrom(address(this), msg.sender, tokenId);
        emit Withdrawal(tokenId, msg.sender, total);
    }
}
