//SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.8;

import "./Moulinette.sol";
import "hardhat/console.sol"; // TODO comment out

import "./Dependencies/VRFConsumerBaseV2.sol";
import "./Dependencies/VRFCoordinatorV2Interface.sol";
import "./Dependencies/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface ICollection is IERC721 {
    function latestTokenId() external view returns (uint);
}
interface LinkTokenInterface is IERC20 {
    function decreaseApproval(address spender, uint addedValue) external returns (bool success);
    function increaseApproval(address spender, uint subtractedValue) external;
    function transferAndCall(address to, uint value, bytes calldata data) external returns (bool success);
}
interface INonfungiblePositionManager is IERC721 { // reward QD<>USDC or QD<>WETH liquidity deposits
    function positions(uint tokenId) external
    view returns (uint96 nonce,address operator,
        address token0, address token1, uint24 fee,
        int24 tickLower, int24 tickUpper, uint128 liquidity,
        uint feeGrowthInside0LastX128,
        uint feeGrowthInside1LastX128,
        uint128 tokensOwed0, uint128 tokensOwed1
    );
}

contract Marenate is 
    VRFConsumerBaseV2, 
    IERC721Receiver { 
    // for tracking time deltas...
    uint public last_lotto_trigger;
    uint public immutable deployed;
    
    /// @notice Inidicates if staking is paused.
    bool public stakingPaused;
    uint public minDuration;
    uint public minDeposit; 
    uint public reward;
    
    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINK; bytes32 keyHash;
    uint64 public subscriptionId;
    address public owed;
    address public driver; 
    uint32 callbackGasLimit;
    uint16 requestConfirmations;
    uint public requestId; 
    uint randomness; // 🎲
    Moulinette MO; // MO = Modus Operandi 
        
    mapping(uint => uint) public totalsUSDC; // week # -> liquidity
    uint public liquidityUSDC; // in UniV3 liquidity units
    uint public maxUSDC; // in the same units

    address[] public owners;
    mapping(address => bool) public isOwner;
    mapping(uint => uint) public totalsETH; // week # -> liquidity
    uint public liquidityETH; // for the ETH<>QD pool
    uint public maxTotalETH;
    
    uint constant public LAMBO = 16508; // youtu.be/sitXeGjm4Mc 
    uint constant public LOTTO = 608358 * 1e18;
    uint constant public MIN_APR = 120000000000000000; // copy-pasted from Moulinette
    
    uint constant public FIVE_CENTS = 5 * PENNY; 
    uint constant public QUID_MINT = 41 * PENNY; 
    uint constant public META_LEX = 54 * PENNY;
    // together these are the 0.99% from mint()
    uint constant public PENNY = WAD / 100;
    uint constant public WAD = 1e18; 
    
    address constant public ETH_PRICE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // CANTO 0x6D882e6d7A04691FCBc5c3697E970597C68ADF39
    // https://data.chain.link/feeds/ethereum/mainnet/xag-usd 
    address constant public PRICE = 0x379589227b15F1a12195D3f2d90bBc9F31f95235; 
    address constant public F8N_0 = 0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405; // can only test 
    address constant public F8N_1 = 0x0299cb33919ddA82c72864f7Ed7314a3205Fb8c4; // on mainnet :)
    address constant public QUID = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4;
    address constant public NFPM = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant public USDC = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;     

    // https://www.instagram.com/p/C7Pkn1MtbUc
    uint[31] internal feeTargets; struct Medianiser { 
        uint apr; // most recent weighted median fee 
        uint[31] weights; // sum weights for each fee
        uint total; // _POINTS > sum of ALL weights... 
        uint sum_w_k; // sum(weights[0..k]) sum of sums
        uint k; // approximate index of median (+/- 1)
    } Medianiser public longMedian; // between 8-21%
    Medianiser public shortMedian; // 2 distinct fees

    struct Transfer {
        address to;
        uint value;
        address token;
        bool executed;
        uint confirm;
    }   Transfer[] public transfers;
    mapping(uint => mapping(address => bool)) public confirmed;
  
    event SubmitTransfer(
        address indexed owner,
        uint indexed index,
        address indexed to,
        uint value
    );
    event ConfirmTransfer(address indexed owner, uint indexed index);
    event RevokeTransfer(address indexed owner, uint indexed index);
    event ExecuteTransfer(address indexed owner, uint indexed index);
    event Withdrawal(uint tokenId, address owner, uint rewardPaid);
    event DepositETH(address indexed sender, uint amount, uint balance);
    mapping(address => mapping(uint => uint)) public depositTimestamps; // LP
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    // Uniswap's NonFungiblePositionManager (one for all pools of UNI V3)...

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    modifier exists(uint _index) {
        require(_index < transfers.length, "does not exist");
        _;
    }

    modifier notExecuted(uint _index) {
        require(!transfers[_index].executed, "already executed");
        _;
    }

    modifier notConfirmed(uint _index) {
        require(!confirmed[_index][msg.sender], "already confirmed");
        _;
    }

    event SetMinDeposit(uint _minDeposit);
    event SetMinDuration(uint duration);

    event SetMaxUSDC(uint maxTotal);
    event SetMaxTotalETH(uint maxTotal);
    event SetReward(uint reward);
    
    event Deposit(uint tokenId, address owner);
    event RequestedRandomness(uint requestId);
    
    event NewMedian(uint oldMedian, uint newMedian, bool long);
    
    function getMedian(bool short) external view returns (uint) {
        if (short) { return shortMedian.apr; } 
        else { return longMedian.apr; }
    }

    /** 
     * Returns the latest price obtained from the Chainlink ETH:USD aggregator 
     * reference contract...https://docs.chain.link/docs/get-the-latest-price
     */
    function getPrice(bool eth) external view returns (uint price) {
        AggregatorV3Interface chainlink; 
        if (eth) {
            chainlink = AggregatorV3Interface(ETH_PRICE);
        } else {
            chainlink = AggregatorV3Interface(PRICE);
        }
        (, int priceAnswer,, uint timeStamp,) = chainlink.latestRoundData();
        require(timeStamp > 0 && timeStamp <= block.timestamp 
                && priceAnswer >= 0, "MO::price");
        uint8 answerDigits = chainlink.decimals();
        price = uint(priceAnswer);
        // currently the Aggregator returns an 8-digit precision, but we handle the case of future changes
        if (answerDigits > 18) { price /= 10 ** (answerDigits - 18); }
        else if (answerDigits < 18) { price *= 10 ** (18 - answerDigits); } 
    }

    receive() external payable { // receive from MO
        emit DepositETH(msg.sender, msg.value, address(this).balance);
    }  
    fallback() external payable {}
    

    function _min(uint _a, uint _b) internal pure returns (uint) {
        return (_a < _b) ? _a : _b;
    }
    function _getInfo(uint tokenId) internal view 
        returns (address token0, address token1, uint128 liquidity) {
        (, , token0, token1, , , , liquidity, , , , ) = nonfungiblePositionManager.positions(tokenId);
    } 
    function _roll() internal returns (uint current_week) { // rollOver week
        current_week = (block.timestamp - deployed) / 1 weeks;
        // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsETH[current_week] == 0 && liquidityETH > 0) {
            totalsETH[current_week] = liquidityETH;
        } // if the vault was emptied then we don't need to roll over past liquidity
        if (totalsUSDC[current_week] == 0 && liquidityUSDC > 0) {
            totalsUSDC[current_week] = liquidityUSDC;
        }
    }

    function setReward(uint _newReward) external onlyOwner {
        reward = _newReward;
        emit SetReward(_newReward);
    }

    function setMinDuration(uint _duration) external onlyOwner {
        require(_duration % 1 weeks == 0 && _duration / 1 weeks >= 1,
        "MA::setMinDuration: must be in weeks");
        minDuration = _duration;
        emit SetMinDuration(_duration);
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>ETH pair).
     * The purpose is to increase the amount gradually, so as to not dilute reward
     * unnecessarily much in beginning phase.
     */
    function setMaxUSDC(uint _newMaxUSDC) external onlyOwner {
        maxUSDC = _newMaxUSDC;
        emit SetMaxUSDC(_newMaxUSDC);
    }

    function toggleStaking() external onlyOwner {
        stakingPaused = !stakingPaused;
    }

    /**
     * @dev Update the maximum liquidity the vault may hold (for the QD<>ETH pair).
     * The purpose is to increase the amount gradually, so as to not dilute reward
     * unnecessarily much in beginning phase.
     * @param _newMaxTotalETH New max total.
     */
    function setMaxTotalETH(uint _newMaxTotalETH) external onlyOwner {
        maxTotalETH = _newMaxTotalETH;
        emit SetMaxTotalETH(_newMaxTotalETH);
    }

    function submitTransfer(address _to, uint _value, 
        address _token) public onlyOwner {
        require(_token == MO.SFRAX() || _token == MO.SDAI(), "MO::bad address");
        uint index = transfers.length;
        transfers.push(
            Transfer({to: _to,
                value: _value,
                token: _token,
                executed: false,
                confirm: 0
            })
        );  emit SubmitTransfer(msg.sender, index, 
                                _to, _value);
    }

    function confirmTransfer(uint _index) 
        public onlyOwner exists(_index)
        notExecuted(_index) notConfirmed(_index) {
        Transfer storage transfer = transfers[_index];
        transfer.confirm += 1;
        confirmed[_index][msg.sender] = true;
        emit ConfirmTransfer(msg.sender, _index);
    }

    function executeTransfer(uint _index)
        public onlyOwner exists(_index)
        notExecuted(_index) {
        Transfer storage transfer = transfers[_index];
        require(transfer.confirm >= 2, "cannot execute tx");
        require(IERC20(transfer.token).transfer(transfer.to, transfer.value), "transfer failed");
        transfer.executed = true; 
        emit ExecuteTransfer(msg.sender, _index);
    }
    
    // bytes32 s_keyHash: The gas lane key hash value,
    //which is the maximum gas price you are willing to
    // pay for a request in wei. It functions as an ID 
    // of the offchain VRF job that runs in onReceived.
    constructor(address[] memory _owners, 
                address _vrf, address _link, bytes32 _hash, 
                uint32 _limit, uint16 _confirm, address _mo) 
                VRFConsumerBaseV2(_vrf) { MO = Moulinette(_mo); 
            
        require(_owners.length == 4, "owners");
        for (uint i = 0; i < 4; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }   
        reward = 1_000_000_000_000; // 0.000001 
        minDuration = MO.LENT(); keyHash = _hash;
        maxTotalETH = type(uint).max - 1;
        maxUSDC = type(uint).max - 1;
        LINK = LinkTokenInterface(_link); 
        requestConfirmations = _confirm;
        callbackGasLimit = _limit; 
        deployed = block.timestamp; owed = msg.sender;
        COORDINATOR = VRFCoordinatorV2Interface(_vrf);    
        COORDINATOR.addConsumer(subscriptionId, address(this));
        subscriptionId = COORDINATOR.createSubscription(); // pubsub...
        nonfungiblePositionManager = INonfungiblePositionManager(NFPM);
        feeTargets = [MIN_APR, 125000000000000000,130000000000000000, 
          135000000000000000, 140000000000000000, 145000000000000000, 
          150000000000000000, 155000000000000000, 160000000000000000, 
          165000000000000000, 170000000000000000, 175000000000000000, 
          180000000000000000, 185000000000000000, 190000000000000000, 
          195000000000000000, 200000000000000000, 205000000000000000,
          210000000000000000, 215000000000000000, 220000000000000000, 
          225000000000000000, 230000000000000000, 235000000000000000, 
          240000000000000000, 245000000000000000, 250000000000000000, 
          255000000000000000, 260000000000000000, 265000000000000000, 
          270000000000000000]; uint[31] memory blank; // no more than credit card
        longMedian = Medianiser(MIN_APR, blank, 0, 0, 0);
        shortMedian = Medianiser(MIN_APR, blank, 0, 0, 0); 
    }

     /** To be responsive to DSR changes we have dynamic APR 
     *  using a points-weighted median algorithm for voting:
     *  not too dissimilar github.com/euler-xyz/median-oracle
     *  Find value of k in range(0, len(Weights)) such that 
     *  sum(Weights[0:k]) = sum(Weights[k:len(Weights)+1])
     *  = sum(Weights) / 2
     *  If there is no such value of k, there must be a value of k 
     *  in the same range range(0, len(Weights)) such that 
     *  sum(Weights[0:k]) > sum(Weights) / 2
     *  TODO update total points only here ? 
     */ 
    function medianise(uint new_stake, uint new_vote, 
        uint old_stake, uint old_vote, bool short) external { 
        require(msg.sender == address(MO), "unauthorized");
        uint delta = MIN_APR / 16; 
        Medianiser memory data = short ? shortMedian : longMedian;
        // when k = 0 it has to be 
        if (old_vote != 0 && old_stake != 0) { // clear old values
            uint old_index = (old_vote - MIN_APR) / delta;
            data.weights[old_index] -= old_stake;
            data.total -= old_stake;
            if (old_vote <= data.apr) {   
                data.sum_w_k -= old_stake;
            }
        } uint index = (new_vote 
            - MIN_APR) / delta;
        if (new_stake != 0) {
            data.total += new_stake;
            if (new_vote <= data.apr) {
                data.sum_w_k += new_stake;
            }		  
            data.weights[index] += new_stake;
        } uint mid_stake = data.total / 2;
        if (data.total != 0 && mid_stake != 0) {
            if (data.apr > new_vote) {
                while (data.k >= 1 && (
                     (data.sum_w_k - data.weights[data.k]) >= mid_stake
                )) { data.sum_w_k -= data.weights[data.k]; data.k -= 1; }
            } else {
                while (data.sum_w_k < mid_stake) { data.k += 1;
                       data.sum_w_k += data.weights[data.k];
                }
            } data.apr = feeTargets[data.k];
            if (data.sum_w_k == mid_stake) { 
                uint intermedian = data.apr + ((data.k + 1) * delta) + MIN_APR;
                data.apr = intermedian / 2;  
            }
        }  else { data.sum_w_k = 0; } 
        if (!short) { longMedian = data; 
            if (longMedian.apr != data.apr) {
                emit NewMedian(longMedian.apr, data.apr, true);
            }
        } 
        else { shortMedian = data; 
            if (shortMedian.apr != data.apr) {
                emit NewMedian(shortMedian.apr, data.apr, false);
            }
        }
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
        uint tokenId, bytes calldata data
    ) external override returns (bytes4) { bool refund = false;
        require(MO.SEMESTER() > last_lotto_trigger, "early"); 
        uint shirt = ICollection(F8N_1).latestTokenId(); 
        address parked = ICollection(F8N_0).ownerOf(LAMBO);
        address racked = ICollection(F8N_1).ownerOf(shirt);
        if (tokenId == LAMBO && parked == address(this)) {
            driver = from; payout(driver, LOTTO);
        }   else if (tokenId == shirt && racked == address(this)) {
                require(parked == address(this), "chronology");
                require(from == owed, "MA::wrong winner");
                last_lotto_trigger = MO.SEMESTER();
                ICollection(F8N_0).transferFrom(
                    address(this), driver, LAMBO);
                uint most = _min(MO.balanceOf(address(this)), LOTTO); 
                require(MO.transfer(owed, most), "MA::QD"); 
                requestId = COORDINATOR.requestRandomWords(
                    keyHash, subscriptionId,
                    requestConfirmations,
                    callbackGasLimit, 1
                );  emit RequestedRandomness(requestId);
        }   else { refund = true; }
        if (!refund) { return this.onERC721Received.selector; }
        else { return 0; }
    }

    function payout(address to, uint amount) internal {
        uint sfrax = IERC20(MO.SFRAX()).balanceOf(address(this));
        uint sdai = IERC20(MO.SDAI()).balanceOf(address(this));
        uint total = sfrax + sdai;
        uint actual = _min(total, amount);
        if (sfrax > sdai) {
            sfrax = _min(sfrax, actual); uint delta = actual - sfrax;
            require(IERC20(MO.SFRAX()).transfer(to, sfrax), "MA::sFRAX");
            require(IERC20(MO.SDAI()).transfer(to, delta), "MA::sDAI");
        } else {
            sdai = _min(sdai, actual); uint delta = actual - sdai;
            require(IERC20(MO.SDAI()).transfer(to, sdai), "MA::sDAI");
            require(IERC20(MO.SFRAX()).transfer(to, delta), "MA::sFRAX");
        }
    }

    function cede(address to) external onlyOwner { // cede authority
        address parked = ICollection(F8N_0).ownerOf(LAMBO);
        require(parked == address(this), "wait for it");
        require(isOwner[msg.sender], "caller not an owner");
        require(!isOwner[to], "owner not unique");
        require(to != address(0), "invalid owner");
        isOwner[msg.sender] = false;
        isOwner[to] = true;
        owners.push(to);    
    } 
    
    function fulfillRandomWords(uint _requestId, 
        uint[] memory randomWords) internal override { 
        randomness = randomWords[0]; uint when = MO.SEMESTER() - 1; 
        uint shirt = ICollection(F8N_1).latestTokenId(); 
        address racked = ICollection(F8N_1).ownerOf(shirt);
        require(randomness > 0 && _requestId > 0 // secret
        && _requestId == requestId && // are we who we are
        address(this) == racked, "MA::randomWords"); 
        address[] memory owned = MO.liquidated(when);
        uint indexOfWinner = randomness % owned.length;
        owed = owned[indexOfWinner]; // quip captured
        ICollection(F8N_1).transferFrom( // 
            address(this), owed, shirt
        ); // next winner pays deployer
    }
   
    function deposit(uint tokenId) external { require(!stakingPaused, "paused");
        (address token0, address token1, uint128 liquidity) = _getInfo(tokenId);
        require(token1 == address(MO), "MA::deposit: improper token id"); 
        // usually this means that the owner of the position already closed it
        require(liquidity > 0, "MA::deposit: cannot deposit empty amount");
        // TODO address not WETH
        if (token0 == WETH) { totalsETH[_roll()] += liquidity; liquidityETH += liquidity;
            require(liquidityETH <= maxTotalETH, "MA::deposit: totalLiquidity exceed max");
        } else if (token0 == USDC) { totalsUSDC[_roll()] += liquidity; liquidityUSDC += liquidity;
            require(liquidityUSDC <= maxUSDC, "MA::deposit: totalLiquidity exceed max");
        } else { require(false, "MA::deposit: improper token id"); }
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
        require(timestamp > 0, "MA::withdraw: no owner exists for this tokenId");
        require( // how long this deposit has been in the vault
            (block.timestamp - timestamp) > minDuration,
            "MA::withdraw: min duration hasn't elapsed yet"
        );  (address token0, , uint128 liquidity) = _getInfo(tokenId);
        // possible that 1st reward is fraction of week's worth
        uint week_iterator = (timestamp - deployed) / 1 weeks;
        // could've deposited right before end of the week, so need some granularity
        // otherwise an unfairly large portion of rewards may be obtained by staker
        uint so_far = (timestamp - deployed) / 1 hours;
        uint delta = so_far - (week_iterator * 168);
        uint earn = (delta * reward) / 168; 
        uint current_week = _roll();
        if (token0 == WETH) { // TODO not WETH
            while (week_iterator < current_week) {
                uint thisWeek = totalsETH[week_iterator];
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
            total += (earn * liquidity) / liquidityETH;
            liquidityETH -= liquidity;
        } else if (token0 == USDC) {
            while (week_iterator < current_week) {
                uint thisWeek = totalsUSDC[week_iterator];
                if (thisWeek > 0) { // need to check lest div by 0
                    // staker's share of rewards for given week...
                    total += (earn * liquidity) / thisWeek;
                }   week_iterator += 1; earn = reward;
            }
            so_far = (block.timestamp - deployed) / 1 hours;
            delta = so_far - (current_week * 168);
            // the last reward will be a fraction of a whole week's worth...
            earn = (delta * reward) / 168; // in the middle of current week
            total += (earn * liquidity) / liquidityUSDC;
            liquidityUSDC -= liquidity;
        }   delete depositTimestamps[msg.sender][tokenId]; 
        if (total > address(this).balance) {
            payable(msg.sender).transfer(address(this).balance);
        } else {
            payable(msg.sender).transfer(total);
        }
        nonfungiblePositionManager.transferFrom(address(this), msg.sender, tokenId);
        emit Withdrawal(tokenId, msg.sender, total);
    }
}
