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

interface IMigratorChef {
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    function migrate(IERC20 token) external returns (IERC20);
}
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
    address public driver; 
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint public requestId; 
    uint randomness; // 🎲
    MO Gen; // heap...

    mapping(uint => uint) public totalsQD; // week # -> liquidity
    uint public liquidityUSDT; // in UniV3 liquidity units
    uint public maxQD; // in the same units

    mapping(uint => uint) public totalsFOLD; // week # -> liquidity
    uint public liquidityWETH; // for the FOLD<>QD pool
    uint public maxTotalFOLD;
    uint constant public LAMBO = 16508; // youtu.be/sitXeGjm4Mc 
    uint constant public SALARY = 608358 * 1e18;
    uint constant public LOTTO = 73888 * 1e18;

    address constant F8N_0 = 0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405; // can only test 
    address constant F8N_1 = 0x0299cb33919ddA82c72864f7Ed7314a3205Fb8c4; // on mainnet :)
    address constant QUID = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4; // TODO get from Gen
    address constant NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; // TODO rinkeby
    address constant FOLD = 0xd084944d3c05CD115C09d072B9F44bA3E0E45921; // mainnet
    address constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA; // // TODO get from Gen

    event SetReward(uint reward);
    event SetMinLock(uint duration);
    event SetMaxQD(uint maxTotal);
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
        if (totalsFOLD[current_week] == 0 && liquidityWETH > 0) {
            totalsFOLD[current_week] = liquidityWETH;
        }
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsQD[current_week] == 0 && liquidityUSDT > 0) {
            totalsQD[current_week] = liquidityUSDT;
        }
    }

    /**
     * @dev Update the weekly reward. Amount in FOLD.
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
     * @dev Update the maximum liquidity the vault may hold (for the QD<>QD pair).
     * The purpose is to increase the amount gradually, so as to not dilute reward
     * unnecessarily much in beginning phase.
     * @param _newmaxQD New max total.
     */
    function setMaxQD(uint _newmaxQD) external onlyOwner {
        maxQD = _newmaxQD;
        emit SetMaxQD(_newmaxQD);
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>FOLD pair).
     * The purpose is to increase the amount gradually, so as to not dilute reward
     * unnecessarily much in beginning phase.
     * @param _newMaxTotalWETH New max total.
     */
    function setMaxTotalWETH(uint _newMaxTotalWETH) external onlyOwner {
        maxTotalFOLD = _newMaxTotalWETH;
        emit SetMaxTotalWETH(_newMaxTotalWETH);
    }
    // bytes32 s_keyHash: The gas lane key hash value,
    //which is the maximum gas price you are willing to
    // pay for a request in wei. It functions as an ID 
    // of the offchain VRF job that runs in onReceived.
    constructor(address _vrf, address _link, bytes32 _hash, 
                uint32 _limit, uint16 _confirm, address JO) 
                VRFConsumerBaseV2(_vrf) { owed = QUID; // TODO 0xdasha...
                callbackGasLimit = _limit; requestConfirmations = _confirm;
        reward = 1_000_000_000_000; // 0.000001 
        minLock = Gen.LENT(); keyHash = _hash;
        maxTotalFOLD = type(uint256).max - 1;
        maxQD = type(uint256).max - 1;
        LINK = LinkTokenInterface(_link); 
        weth = IERC20(FOLD); sdai = IERC20(SDAI);
        deployed = block.timestamp; Gen = MO(JO); // JO
        COORDINATOR = VRFCoordinatorV2Interface(_vrf);  // JO   
        COORDINATOR.addConsumer(subscriptionId, address(this));
        subscriptionId = COORDINATOR.createSubscription(); // pubsub...
        nonfungiblePositionManager = INonfungiblePositionManager(NFPM);
    }

    /** Whenever an {IERC721} `tokenId` token is transferred to this contract:
     * @dev Safe transfer `tokenId` token from `from` to `address(this)`, 
     * checking that contract recipient prevent tokens from being forever locked.
     * - `tokenId` token must exist and be owned by `from`
     * - If the caller is not `from`, it must have been allowed 
     *   to move this token by either {approve} or {setApprovalForAll}.
     * - {onERC721Received} is called after a safeTransferFrom...
     * - It must return its Solidity selector to confirm the token transfer.
     *   If any other value is returned or the interface is not implemented
     *   by the recipient, the transfer will be reverted.
     */
    // QuidMint...foundation.app/@quid
    function onERC721Received(address, 
        address from, // previous owner's
        uint256 tokenId, bytes calldata data
    ) external override returns (bytes4) { bool refund = false;
        require(Gen.SEMESTER() > last_lotto_trigger, "early"); 
        uint shirt = ICollection(F8N_1).latestTokenId(); 
        address parked = ICollection(F8N_0).ownerOf(LAMBO);
        address racked = ICollection(F8N_1).ownerOf(shirt);
        if (tokenId == LAMBO && parked == address(this)) {
            require(Gen.transfer(from, SALARY), "Lot::QD");
            require(sdai.transfer(from, SALARY), "Lot::sDAI");
            // since this only gets called twice a year
            // 1477741 - (608358 x 2) stays in contract
            
            // TODO staked into Uni pools so that there isn't
            // ever zero liquidity in them (causes 4626 bug)
            driver = from;
        }   else if (tokenId == shirt && racked == address(this)) {
                require(parked == address(this), "chronology");
                require(from == owed, "Lot::wrong winner");
                last_lotto_trigger = Gen.SEMESTER();
                ICollection(F8N_0).transferFrom(
                    address(this), driver, LAMBO
                );  
                require(sdai.transfer(owed, LOTTO), "sDAI"); 
                requestId = COORDINATOR.requestRandomWords(
                    keyHash, subscriptionId,
                    requestConfirmations,
                    callbackGasLimit, 1
                );  emit RequestedRandomness(requestId);
        }   else { refund = true; }
        if (!refund) { return this.onERC721Received.selector; }
        else { return 0; }
    }

    function cede(address to) external { // cede authority
        address parked = ICollection(F8N_0).ownerOf(LAMBO);
        require(parked == address(this) //
        && _msgSender() == driver, "chronology");
        require(sdai.transfer(driver, //
        sdai.balanceOf(address(this))), "Lot::swap sDAI");
        require(Gen.transfer(driver, //
        Gen.balanceOf(address(this))), "Lot::swap QD"); 
        driver = to; // "unless a kernel of wheat falls
        // to the ground and dies, it remains a single
        // seed. But if it dies, it produces many seeds.
    }
    
    function fulfillRandomWords(uint _requestId, 
        uint[] memory randomWords) internal override { 
        uint when = Gen.SEMESTER() - 1; // retro-active...
        randomness = randomWords[0]; // retrobonus catcher...
        uint shirt = ICollection(F8N_1).latestTokenId(); // 2
        address racked = ICollection(F8N_1).ownerOf(shirt);
        require(randomness > 0 && _requestId > 0 // secret
        && _requestId == requestId && // are we who we are
        address(this) == racked, "Lot::randomWords"); 
        address[] memory owned = Gen.liquidated(when);
        uint indexOfWinner = randomness % owned.length;
        owed = owned[indexOfWinner]; // ;)
        ICollection(F8N_1).transferFrom(
            address(this), owed, shirt
        ); // next winner pays deployer
    }
   
    function deposit(uint tokenId) external { 
        (address token0, address token1, uint128 liquidity) = _getInfo(tokenId);
        require(token1 == address(Gen), "Uni::deposit: improper token id"); 
        // usually this means that the owner of the position already closed it
        require(liquidity > 0, "Uni::deposit: cannot deposit empty amount");
        if (token0 == FOLD) { totalsFOLD[ _roll()] += liquidity; liquidityWETH += liquidity;
            require(liquidityWETH <= maxTotalFOLD, "Uni::deposit: totalLiquidity exceed max");
        } else if (token0 == address(Gen)) { totalsQD[ _roll()] += liquidity; liquidityUSDT += liquidity;
            require(liquidityUSDT <= maxQD, "Uni::deposit: totalLiquidity exceed max");
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
        if (token0 == FOLD) {
            while (week_iterator < current_week) {
                uint thisWeek = totalsFOLD[week_iterator];
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
        } else if (token0 == address(Gen)) {
            while (week_iterator < current_week) {
                uint thisWeek = totalsQD[week_iterator];
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
