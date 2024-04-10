
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.8.0; 
// pragma experimental SMTChecker;

/**
  THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CONTRIBUTORS 
  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCL. NEGLIGENCE 
  OR OTHERWISE) ARISING IN ANY WAY DUE TO USE OF THIS SOFTWARE, BEING ADVISED OF THE POSSIBILITY OF SUCH DAMAGE...
 */

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Dependencies/AggregatorV3Interface.sol";
// import "./Dependencies/ERC404.sol";
import "hardhat/console.sol"; // TODO comment out
interface ICollection is IERC721 {
    function latestTokenId() external view returns (uint256);
} // transfer F8N tokenId to 1 lucky clapped pledge per !MO
// pledge may transfer it back to QUID_ETH to receive prize

// "Get a deposit; then I divided" MO,
// stands for 2 things: More Options;
// Made Offering...mold it as you see
// "there’s no life except by [debt], 
// no vision but by..the faith...that 
// I could bring" pair of dice to BP...
contract MO is ERC20 { // KISS for 404 
    IERC20 public sdai; address public lock; // multi-purpose locker (OpEx)...
    address constant public SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address constant public F8N = 0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405; // youtu.be/sitXeGjm4Mc
    address constant public QUID_ETH = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4; // ERC404 deployer
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // BP liquidity mining
    // all deposits of msg.value get converted into WETH as well, enables Lock.sol's ^^^^^^^^^ ^^^^^^
    
    mapping(address => uint) public _immature; // QD balances
    uint constant public ONE = 1e18; uint constant public DIGITS = 18;
    uint constant public MAX_PER_DAY = 7_777_777 * ONE; // supply cap
    uint constant public DURATION = 46 days; // ends on the 47th day:
    uint constant public START_PRICE = 53 * CENT; // .54 actually...
    uint constant public TARGET = 357000000 * ONE; // !MO mint target
    uint constant public STACK = C_NOTE * 100;
    uint constant public CENT = ONE / 100; 
    uint constant public C_NOTE = 100 * ONE; 
    
    event Minted (address indexed reciever, uint cost_in_usd, uint amt); // by !MO
    // Events are emitted, so only when we emit profits for someone do we call...
    event clappedLong (address indexed owner, address indexed clipper, uint fee); // if you know the fee
    event clappedShort (address indexed owner, address indexed clipper, uint fee); // then you know amt
    event Voted (address indexed voter, uint vote); // only emit when increasing
    
    AggregatorV3Interface public chainlink; // Uni TWAP? TODO with:
    uint constant public MO_FEE =  54000000000000000; // 1.477M sDAI
    uint constant public MO_CUT =  22000000000000000; 
    uint constant public MIN_CR = 108080808080808080; 
    uint constant public MIN_APR =  8080808080808080;               
    uint[27] public feeTargets; struct Medianiser { 
        uint apr; // most recent weighted median fee 
        uint[27] weights; // sum weights for each fee
        uint total; // _POINTS > sum of ALL weights... 
        uint sum_w_k; // sum(weights[0..k]) sum of sums
        uint k; // approximate index of median (+/- 1)
    } Medianiser public longMedian; // between 8-21%
    Medianiser public shortMedian; // 2 distinct fees
    struct Offering { 
        uint start; // date 
        uint locked; // sDAI
        uint minted; // QD
        uint burned; // ^
    }
    Offering[16] public _MO;
    uint internal _YEAR; // actually half a year, every 6 months
    uint internal _PRICE; // TODO comment out when finish testing
    uint internal _POINTS; // used in withdraw; weights (medianiser)
    struct Pod { // Used in all Pools, and in individual Pledges
        uint credit; // SP credits LP with debt valued in ETH
        uint debit; // LP debits sDAI of SP for ^^^^^^ ^^ ^^^
        // credit used for fee voting; debit for fee charging
    } 
    struct Owe {
        uint points; // time-weighted contribution to solvency 
        Pod long; // debit = last timestamp of long APR payment
        Pod short; // debit = last timestamp of short APR payment
        bool dance; // pay...✌🏻xAPR for peace of mind, and flip debt
        bool grace; // ditto ^^^^^ pro-rated _fold, but no ^^^^ ^^^^ 
    }
    struct Pool { Pod long; Pod short; } // LP
    /* Quote from a movie called...The Prestige
        The first part is called "The Pledge"... 
        The magician shows you something ordinary: 
        a certificate of deposit, or a CD. Inspect  
        to see if it's...indeed un-altered, normal 
    */
    mapping (address => Pledge) Pledges; // to love;
    struct Pledge { // last love...owe...dam (blood)
        uint last; // timestamp of last state update
        Pool love; // debt and collat (long OR short)
        Owe owe; // all kinds of utility variables
        Pod dam; // debit is ETH, credit QD profit 
    }  
    Pool internal love; // LP
    // a.k.a. Liability Pool
    Pod internal brood; // BP
    // youtu.be/tcMcNFialH4
    Pod internal blood; // SP

    constructor(address _lock_address) ERC20("QU!Dao", "QD") { 
        require(_msgSender() == QUID_ETH, "MO: wrong deployer");
        require(sdai.approve(lock, type(uint256).max - 1),
                                    "MO: approval failed"
        ); _MO[0].start = 1717171717; lock = _lock_address; 
        feeTargets = [MIN_APR, 85000000000000000,  90000000000000000,
           95000000000000000, 100000000000000000, 105000000000000000,
          110000000000000000, 115000000000000000, 120000000000000000,
          125000000000000000, 130000000000000000, 135000000000000000,
          140000000000000000, 145000000000000000, 150000000000000000,
          155000000000000000, 160000000000000000, 165000000000000000,
          170000000000000000, 175000000000000000, 180000000000000000,
          185000000000000000, 190000000000000000, 195000000000000000,
          200000000000000000, 205000000000000000, 210000000000000000];
        // chainlink = AggregatorV3Interface(_priceAggregatorAddress);
        uint[27] memory blank; sdai = IERC20(SDAI); // Phoenix Labs...
        longMedian = Medianiser(MIN_APR, blank, 0, 0, 0);
        shortMedian = Medianiser(MIN_APR, blank, 0, 0, 0); 
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                     OWN HELPER FUNCTIONS                   */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/
    
    // TODO comment out after finish testing
    function set_price(uint price) external { // set ETH price in USD
        _PRICE = price;
    }
    
    function _min(uint _a, uint _b) internal pure returns (uint) {
        return (_a < _b) ? _a : _b;
    }

    /**
     * Override the ERC20 functions to account 
     * for QD balances that are still maturing  
     */
    function transfer(address recipient, uint256 amount) public override returns (bool) {
       _send(_msgSender(), recipient, amount); return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        _send(from, to, value); return true;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) + _immature[account];
    }

    function _ratio(uint _multiplier, uint _numerator, uint _denominator) internal pure returns (uint ratio) {
        if (_denominator > 0) {
            ratio = _multiplier * _numerator / _denominator;
        } else { // if the Pledge has a debt of 0, represents "infinite" CR.
            ratio = type(uint256).max - 1; 
        }
    }

    // calculates CR (value of collat / value of debt)...if you look a little pale, might catch a cold
    function _blush(uint _price, uint _collat, uint _debt, bool _short) internal pure returns (uint) {   
        if (_short) {
            uint debt_in_qd = _ratio(_price, _debt, ONE); 
            return _ratio(ONE, _collat, debt_in_qd); // collat is in QD
            // we multiply collat first to preserve precision 
        } else {
            return _ratio(_price, _collat, _debt); // debt is in QD
        } 
    }
    
    function _send(address from, address to, uint256 value) internal {
        require(from != address(0) && to == address(0), 
               "MO::transfer: passed in zero address");
        uint delta;
        if (value > balanceOf(from)) {
            delta = value - balanceOf(from);
            value -= delta;
            _immature[from] -= delta;
            if (to != address(this)) { 
                _immature[to] += delta;
            } else { _burn(from, delta);
                     _mint(address(this), delta);
            } // we never transfer QD back from
            // (this) to pledge, so safe to mix
        }   if (value > 0) { _transfer(from, to, value); }
    }

    /**
     * Returns the latest price obtained from the Chainlink ETH:USD aggregator 
     * reference contract...https://docs.chain.link/docs/get-the-latest-price
     */
    function _get_price() internal view returns (uint) {
        if (_PRICE != 0) { return _PRICE; } // TODO comment when done testing
        (, int priceAnswer,, uint timeStamp,) = chainlink.latestRoundData();
        require(timeStamp > 0 && timeStamp <= block.timestamp,
                "MO::price: timestamp is 0, or in future");
        require(priceAnswer >= 0, "MO::price: negative");
        uint8 answerDigits = chainlink.decimals();
        uint price = uint256(priceAnswer);
        
        // currently the Aggregator returns an 8-digit precision, but we handle the case of future changes
        if (answerDigits > DIGITS) { 
            price /= 10 ** (answerDigits - DIGITS);
        }
        else if (answerDigits < DIGITS) {
            price *= 10 ** (DIGITS - answerDigits);
        } 
        return price;
    }

    /** To be responsive to DSR changes we have dynamic APR 
     *  using a points-weighted median algorithm for voting:
     *  Find value of k in range(0, len(Weights)) such that 
     *  sum(Weights[0:k]) = sum(Weights[k:len(Weights)+1])
     *  = sum(Weights) / 2
     *  If there is no such value of k, there must be a value of k 
     *  in the same range range(0, len(Weights)) such that 
     *  sum(Weights[0:k]) > sum(Weights) / 2
     *  TODO update total points only here ?
     */
    function _medianise(uint new_stake, uint new_vote, uint old_stake, uint old_vote, bool short) internal { 
        uint delta = MIN_APR / 16; // update annual average in Offering TODO
        Medianiser memory data = short ? shortMedian : longMedian;
        if (old_vote != 0 && old_stake != 0) { // clear old values
            uint old_index = (old_vote - MIN_APR) / delta;
            data.weights[old_index] -= old_stake;
            data.total -= old_stake;
            if (old_vote <= data.apr) {   
                data.sum_w_k -= old_stake;
            }
        }
        uint index = (new_vote - MIN_APR) / delta;
        if (new_stake != 0) {
            data.weights[index] += new_stake;
            data.total += new_stake;
            if (new_vote <= data.apr) {
                data.sum_w_k += new_stake;
            }		  
        }
        uint mid_stake = data.total / 2;
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
        if (!short) { longMedian = data; } 
        else { shortMedian = data; } // fin
    }

    function _get_pledge(address addr, uint price, bool must_exist, address caller) 
        internal returns (Pledge memory pledge) { pledge = Pledges[addr]; require(
            !must_exist || pledge.last != 0, "MO: pledge must exist"); 
            bool clapped = false; uint old_points = 0;  uint grace = 0; 
        if (pledge.last != 0) {
            Pod memory SPod = pledge.dam; old_points = pledge.owe.points;
            // wait oh wait oh wait oh wait oh wait oh wait oh wait...oh
            uint fee = caller == addr ? 0 : MIN_APR / 100; // liquidator
            uint sp_value = balanceOf(_msgSender()) + SPod.credit +
                                      _ratio(price, SPod.debit, ONE); 
            if (pledge.love.long.debit > 0) { // owes blood to the SP
                Pod memory LPod = pledge.love.long;
                if (pledge.owe.long.debit == 0) { sp_value = 0;
                    pledge.owe.long.debit = block.timestamp;
                }   if (pledge.owe.dance) { grace = 1;
                    if (pledge.owe.grace) { // 15% per 6 months
                        grace = fee * pledge.owe.long.debit;
                    }
                }   (LPod, SPod, clapped) = _return_pledge(addr, SPod, LPod, 
                    price, block.timestamp - pledge.owe.long.debit, grace, 
                    false // long pledge
                );
                if (clapped) { fee *= LPod.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money
                    if (pledge.owe.dance) { // flip long (credit conversion)
                        // blood.credit += fee; TODO??
                        if (fee > 0) { LPod.debit -= fee; } 
                        love.short.credit += LPod.credit;
                        love.short.debit += LPod.debit;
                        pledge.love.short.credit = LPod.credit;
                        pledge.love.short.debit = LPod.debit;
                        pledge.owe.short.debit = block.timestamp;
                    }   else if (fee > 0) { blood.credit -= fee; 
                        emit clappedLong(addr, caller, fee);
                    }   pledge.love.long.credit = 0;
                        pledge.love.long.debit = 0;
                        pledge.owe.long.debit = 0; 
                } else { pledge.love.long.credit = LPod.credit;
                        pledge.love.long.debit = LPod.debit;
                        // only update timestamp if charged otherwise can
                        // keep resetting timestamp before an hour passes
                        // and never get charged APR at all (costs gas tho)
                        if (sp_value > balanceOf(_msgSender()) + SPod.credit +
                                                 _ratio(price, SPod.debit, ONE)) {
                                                 pledge.owe.long.debit = block.timestamp; } 
                }   pledge.dam = SPod; if (fee > 0) { Pledges[caller].dam.credit += fee; }
            } // pledges should never be short AND a long at the same time
            else if (pledge.love.short.debit > 0) { // that's why ELSE if
                Pod memory LPod = pledge.love.short;
                if (pledge.owe.short.debit == 0) { // edge case
                    pledge.owe.short.debit = block.timestamp;
                }   if (pledge.owe.dance) { grace = 1;
                    if (pledge.owe.grace) {  // 15% per 6 months
                        grace = grace = fee * pledge.owe.short.debit;
                    }
                }   (LPod, SPod, clapped) = _return_pledge(addr, SPod, LPod, 
                    price, block.timestamp - pledge.owe.short.debit, grace, 
                    true
                );
                if (clapped) { fee *= LPod.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money
                    if (pledge.owe.dance) { // flip short (credit conversion)
                        if (fee > 0) { LPod.debit += fee; }
                        love.long.credit += LPod.credit;
                        love.long.debit += LPod.debit;
                        pledge.love.long.credit = LPod.credit;
                        pledge.love.long.debit = LPod.debit;
                        pledge.owe.long.debit = block.timestamp;   
                    }   if (fee > 0) { blood.credit -= fee; 
                        emit clappedShort(addr, caller, fee);
                    }   pledge.love.short.credit = 0;
                        pledge.love.short.debit = 0;
                        pledge.owe.short.debit = 0; 
                } else { 
                    pledge.love.short.credit = LPod.credit;
                    pledge.love.short.debit = LPod.debit;
                    if (sp_value > balanceOf(_msgSender()) + SPod.credit +
                                             _ratio(price, SPod.debit, ONE)) {
                        pledge.owe.short.debit = block.timestamp; 
                    }   pledge.owe.short.debit = block.timestamp;
                }   pledge.dam = SPod;
                if (fee > 0) {
                    Pledges[caller].dam.credit += fee;
                }
            }
            if (balanceOf(addr) > 0) { // update points
                uint since = (block.timestamp - pledge.last) / 1 hours;
                uint points = (since *
                    (balanceOf(addr) + pledge.dam.credit) / ONE
                );  pledge.owe.points += points; _POINTS += points; 
                blood.credit; // is subtracted from 
                // rebalance fee targets (governance)
                if (pledge.owe.long.credit != 0) { 
                    _medianise(pledge.owe.points, 
                        pledge.owe.long.credit, old_points, 
                        pledge.owe.long.credit, false
                    );
                } if (pledge.owe.short.credit != 0) {
                    _medianise(pledge.owe.points, 
                        pledge.owe.short.credit, old_points, 
                        pledge.owe.short.credit, true
                    );
                }
            }
        } pledge.last = block.timestamp;
    }

    // ------------ OPTIONAL -----------------
    // voting can allow LTV to act as moneyness,
    // but while DSR is high this is unnecessary  
    // function _get_owe() internal {
        // using APR / into MIN = scale
        // if you over-collat by 8% x scale
        // then you get a discount from APR
        // that is exactly proportional...
    // } TODO ??
    // discount from scale

    // duece is a semaphor...0 is false, 1 if dance no grace, otherwise both dance and grace...
    // Delight is the meaning, Oneg (charged eighth element)...demeaning is “loved” in reverse.
    function _return_pledge(address addr, Pod memory SPod, Pod memory LPod, 
        uint price, uint time_delta, uint dance, bool short) internal 
        returns (Pod memory, Pod memory, bool clapped) {
        // "though eight is not enough...no,
        // it's like switch [lest you] bust: 
        // now your whole [pledge] is dust" ~ Basta Rhymes, et. al.
        if (time_delta >= 1 hours) { // there's 8760 hours per year 
            time_delta /= 1 hours; uint owe = (dance > 0) ? 2 : 1; 
            uint apr = short ? shortMedian.apr : longMedian.apr; 
            owe *= (apr * LPod.debit * time_delta) / (8760 * ONE);
            // try to pay with SP deposit: QD if long or ETH if short 
            uint most = short ? _min(SPod.debit, owe) : _min(SPod.credit, owe);
            if (owe > 0 && most > 0) { 
                if (short) { // from the SP deposit
                    brood.debit += most;
                    blood.debit -= most;
                    SPod.debit -= most; 
                    owe -= _ratio(price, most, ONE);
                } else { SPod.credit -= most;
                    blood.credit += most; // TODO double check if double spend
                    owe -= most;
                }
            } if (owe > 0) { // SP deposit in QD was insufficient to pay pledge's APR
                most = _min(balanceOf(addr), owe);
                _send(addr, address(this), most);
                owe -= most; blood.credit += most;
                if (short && owe > 0) { owe = _ratio(owe, price, ONE);
                    most = _min(SPod.credit, owe);
                    SPod.credit -= most;
                    blood.credit += most; // TODO double check if double spend
                    owe -= most;
                } else if (owe > 0) { 
                    owe = _ratio(ONE, owe, price); // convert owe to be units of ETH
                    most = _min(SPod.debit, owe);
                    brood.debit += most;
                    SPod.debit -= most;
                    blood.debit -= most;
                    owe -= most;
                }   if (owe > 0) { // pledge cannot pay APR (delinquent)
                    (LPod, SPod, clapped) = _fold(addr, 
                     LPod, SPod, dance, short, price);
                } 
            } 
        }   if (_blush(price, LPod.credit, LPod.debit, short) < ONE) {
                (LPod, SPod, clapped) = _fold(addr, LPod, SPod, 
                                        dance, short, price);
            } return (LPod, SPod, clapped);
    }
    
    // "Don't get no better than this, you catch my drift?
    // So close no matter how far, rage be in it like you 
    // couldn’t believe...or love like one could scarcely 
    // imagine...if one isn’t satisfied, indulge the latter
    // ‘neath the halo of a street-lamp...I fold my collar
    // to the cold and damp...know when to hold 'em...know 
    // when to..."
    function _fold(address owner, Pod memory LPod, Pod memory SPod, 
                   uint dance, bool short, uint price) internal 
                   returns (Pod memory, Pod memory, bool folded) {
        uint in_qd = _ratio(price, LPod.credit, ONE);
        if (short && in_qd > 0) {
            if (LPod.debit > in_qd) { // profitable
                LPod.debit -= in_qd; // return debited
                blood.credit += in_qd; // amount to SP
                // since we canceled all the credit then
                // surplus debit is the pledge's profit
                SPod.credit += LPod.debit; // 
                // FIXME increase brood.credit...???...as it were,
                // PROFIT CAME AT THE EXPENSE OF BLOOD (everyone):
                // brood.credit += pledge.love.short.debit;
            } else { // "Lightnin' strikes and the court lights get dim"
                if (dance == 0) {
                    uint delta = (in_qd * MIN_CR) / ONE - LPod.debit;
                    uint sp_value = balanceOf(owner) + SPod.credit +
                    _ratio(price, SPod.debit, ONE); uint in_eth;
                    if (delta > sp_value) { delta = in_qd - LPod.debit; } 
                    // "It's like inch by inch and step by step...i'm closin'
                    // in on your position and reconstruction is my mission"
                    if (sp_value >= delta) { folded = false;
                        // decrement QD first because ETH is rising
                        uint most = _min(SPod.credit, delta);
                        if (most > 0) { in_eth = _ratio(ONE, most, price);
                            LPod.credit -= in_eth; SPod.credit -= most;
                            love.short.credit -= in_eth; delta -= most; 
                        } if (delta > 0) { // use _balances
                            most = _min(balanceOf(owner), delta);
                            if (most > 0) {
                                _send(owner, address(this), most);
                                blood.credit += most; delta -= most;
                                in_eth = _ratio(ONE, most, price);
                                LPod.credit -= in_eth;
                                love.short.credit -= in_eth;
                            }
                        } if (delta > 0) { in_eth = _ratio(ONE, delta, price);
                            blood.debit -= in_eth; SPod.debit -= in_eth;
                            brood.debit += in_eth; LPod.credit -= in_eth;
                            love.short.credit -= in_eth;                            
                        } 
                    } 
                } if (folded && dance == 0) { blood.credit += LPod.debit; } // TODO cover grace
            } if (folded) { 
                if (dance > 1) { in_qd = _min(dance, LPod.debit);
                    love.short.debit -= in_qd; blood.credit += in_qd;
                    love.short.credit -= _min(LPod.credit,
                        _ratio(ONE, in_qd, price)
                    );
                } else { love.short.credit -= LPod.credit;
                         love.short.debit -= LPod.debit;
                }   
            }
        } else if (in_qd > 0) { // leveraged long 
            if (in_qd > LPod.debit) { // profitable  
                in_qd -= LPod.debit; // remainder = profit
                SPod.credit += in_qd;
                // return the debited amount to the SP
                blood.credit += LPod.debit; // FIXME 
                // brood.credit += in_qd; 
                // SOMETIMES WE NEED TO ADD DEBT
                // if this was not credit from actual ETH deposited
                // but virtual credit based on sDAI
            } else { 
                if (dance == 0) { // liquidatable
                    uint delta = (LPod.debit * MIN_CR) / ONE - in_qd;
                    uint sp_value = balanceOf(owner) + SPod.credit +
                    _ratio(price, SPod.debit, ONE); uint in_eth;
                    if (delta > sp_value) { delta = LPod.debit - in_qd; } 
                    if (sp_value >= delta) { folded = false;
                        // decrement ETH first because it's falling
                        in_eth = _ratio(ONE, delta, price);
                        uint most = _min(SPod.debit, in_eth);
                        if (most > 0) { blood.debit -= most; // remove ETH from SP
                            SPod.debit -= most; brood.debit += most; // sell ETH to BP
                            LPod.credit += most; love.short.credit += most;
                            delta -= _ratio(price, most, ONE);
                        } if (delta > 0) { blood.credit += most;
                            most = _min(SPod.credit, delta); 
                            SPod.credit -= most; LPod.debit -= most;
                            love.long.debit -= most; delta -= most;   
                        } if (delta > 0) { blood.credit += delta;
                            _send(owner, address(this), delta);
                            LPod.debit -= delta; love.long.debit -= delta;   
                        }
                    } 
                } if (folded && dance == 0) { blood.credit += LPod.debit; }
            } if (folded) {
                if (dance > 1) { in_qd = _min(dance, LPod.debit);
                    love.long.debit -= in_qd; blood.credit += in_qd;
                    love.long.credit -= _min(LPod.credit,
                        _ratio(ONE, in_qd, price)
                    );
                } else { love.long.credit -= LPod.credit;
                         love.long.debit -= LPod.debit;
                } 
            }
        } return (LPod, SPod, folded);
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                      BASIC OPERATIONS                      */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    // "lookin' too hot...simmer down...or soon you'll get:"
    function drop(address[] memory pledges) external {
        uint price = _get_price(); 
        for (uint i = 0; i < pledges.length; i++ ) {
            _get_pledge(pledges[i], price, true, _msgSender());
        } 
    }

    function protect(bool grace) external { uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        if (grace) { pledge.owe.dance = true; pledge.owe.grace = true; } else {
            pledge.owe.dance = !pledge.owe.dance;
            pledge.owe.grace = false;
        }   Pledges[_msgSender()] = pledge;
    }

    function fold(bool short) external { uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        Pod memory SPod = pledge.dam;
        uint dance = pledge.owe.dance ? 1 : 0;
        if (short) { (,SPod,) = _fold(_msgSender(), pledge.love.short, 
                                      SPod, dance, true, price);
            pledge.dam = SPod;
            pledge.love.short.credit = 0;
            pledge.love.short.debit = 0;
            pledge.owe.short.debit = 0;
        } else { (,SPod,) = _fold(_msgSender(), pledge.love.long,
                                  SPod, dance, false, price);
            pledge.dam = SPod;
            pledge.love.long.credit = 0;
            pledge.love.long.debit = 0;
            pledge.owe.long.debit = 0;
        }   Pledges[_msgSender()] = pledge;
    }

    function vote(uint apr, bool short) external {
        uint delta = MIN_APR / 16; // 0.5%
        require(apr >= MIN_APR && apr <= (MIN_APR * 3 - delta * 6)
                && apr % delta == 0, "MO::vote: unacceptable APR");
        uint old_vote; // a vote of confidence gives...credit
        uint price = _get_price();
        Pledge memory pledge = _get_pledge(
            _msgSender(), price, true, _msgSender()
        );
        if (short) {
            old_vote = pledge.owe.short.credit;
            pledge.owe.short.credit = apr;
        } else {
            old_vote = pledge.owe.long.credit;
            pledge.owe.long.credit = apr;
        }
        _medianise(pledge.owe.points, apr, pledge.owe.points, old_vote, short);
        Pledges[_msgSender()] = pledge;
    }

    // if _msgSender() is not the beneficiary...first do approve() in frontend to transfer QD
    function deposit(address beneficiary, uint amount, bool sp, bool long) external payable {
        uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(beneficiary, price, false, beneficiary);
        bool two_pledges = _msgSender() != beneficiary; 
        if (!sp) { uint most;
            _send(_msgSender(), address(this), amount);
            if (long) {
                most = _min(amount, pledge.love.long.debit);
                pledge.love.long.debit -= most;
                love.long.debit -= most;
                amount -= most;
            } else { // we can't decrease the short debit because
                // that would simply decrease profits in fold()
                uint eth = _ratio(ONE, amount, price);
                most = _min(eth, pledge.love.short.credit);
                pledge.love.short.credit -= eth;
                love.short.credit -= eth;
                most = _ratio(price, most, ONE);
                amount -= most;
            }
            // TODO helper function gets rate
            blood.credit += most; // interchanging QD/sDAI consider ratio
            // if the outside environment is saltier than the organism... 
            // eliminating water helps prevent harmful organisms brooding.
            // water diffuses to dilute the salt. The organism dries out.
            // Liquidated debt is still wet. If fold is profitable for the
            // borrower, that's like a liquidation for the lender. If the 
            // borrower is liquidated, it's like being on their win side.
            if (amount > 0) { pledge.dam.credit += amount; }
        }
        else if (two_pledges) { _send(_msgSender(), beneficiary, amount); }
        else { // not two_pledges && not SP
            require(true, "MO::deposit: Can't transfer QD from and to the same balance");
        }   Pledges[beneficiary] = pledge;
    }

    // "You're a beast...that I was raising...you're
    // a [lease] that I was twistin' and it wears you 
    // like a gown...in my [loan sum] advocation..."
    function withdraw(uint amt, bool qd) external {
        uint most; uint cr; uint price = _get_price();
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        if (!qd) { // withdrawal only from SP...use borrow() or fold() for LP
            // the LP balance is a synthetic (virtual) representation of ETH
            // pledges only care about P&L, which can only be withdrawn in QD 
            most = _min(pledge.dam.debit, amt);
            pledge.dam.debit -= most;
            blood.debit -= most;
            // require(address(this).balance > most, "MO::withdraw: deficit ETH");
            payable(_msgSender()).transfer(most);
        } 
        else { 
            require(amt >= 1, "MO::withdraw: must be over 1000");
            
            
            // FIXME withdraw from temporary balances if current MO failed ??
            
            // BLOOD.CREDIT OVER TIME (TOTAL POINTS)
            // WILL GET ITS SHARE OF THE BP AT THE END            

            
            uint least = _min(balanceOf(_msgSender()), amt);

            // TODO calculate half for the whole year if the timestamp is 
            // over the first start date + 6 months
            require(_MO[_YEAR].start > block.timestamp,
                "MO::withdraw: takes 1 year for QD to mature, redemption has a time window"
            );
            
            
            uint assets = blood.credit + // SP
            love.short.debit + love.long.debit + // LP collat
            _ratio(price, brood.debit, ONE) + // ETH ownd by all pledges
            _ratio(price, blood.debit, ONE); // ETH owned by specific pledges
        
            uint liabilities = brood.credit + // QDebt from !MO 
            _ratio(price, love.long.credit, ONE) + // synthetic ETH collat
            _ratio(price, love.short.credit, ONE);  // synthetic ETH debt
            
            // TODO to dissolvency (BP into SP)
            
            // dilute the value of the eth
            if (liabilities > assets) {

            } else { // dilute the value of $

            }
            // frequency and wavelength, half of liquidations stay til the next MO?
            
            blood.credit -= least; _burn(_msgSender(), amt); 
            sdai.transferFrom(address(this), _msgSender(), amt);
        }
    }

    // "honey won’t you break some bread, just let it crack" ~ Rapture, by Robert 
    function mint(uint amount, address beneficiary) external returns (uint cost) {
        require(beneficiary != address(0), "MO::mint: can't mint to the zero address");
        require(block.timestamp >= _MO[_YEAR].start, "MO::mint: can't mint before start date"); 
        // TODO allow roll over QD value in sDAI from last !MO into new !MO...
        // determine what the excess debt was from the last MO 
        if (block.timestamp >= _MO[_YEAR].start + DURATION + 188 days) {
            if (_MO[_YEAR].minted >= TARGET) {
                sdai.transferFrom(address(this), lock, 
                    _MO[_YEAR].locked * MO_FEE / ONE
                );
            }
            _YEAR += 1; // "same level, the same rebel that never settled"
            require(_YEAR < 16, "MO::mint: already had our final !MO");
            _MO[_YEAR].start = block.timestamp + DURATION; // restart into new !MO
            // but first, we have our withdrawal (QD redemption) window // TODO 404

        } else { // minting QD has a time window (!MO duration)
            require(amount >= C_NOTE, "MO::mint: below minimum mint amount");
            uint in_days = ((block.timestamp - _MO[_YEAR].start) / 1 days) + 1; 
            require(in_days < 47, "MO::mint: current !MO is over"); 
            cost = (in_days * CENT + START_PRICE) * (amount / ONE);
            uint old_MO;
            for (uint year = 0; year < _YEAR; year++) {
                old_MO = _MO[_YEAR].minted - _MO[_YEAR].burned;
            }   uint supply_cap = in_days * MAX_PER_DAY + old_MO; // TODO total supply
            if (Pledges[beneficiary].last == 0) { // init. pledge
                Pledges[beneficiary].last = block.timestamp;
                _approve(beneficiary, address(this), type(uint256).max - 1);
            }
            _MO[_YEAR].locked += cost; _MO[_YEAR].minted += amount;
            uint cut = MO_CUT * amount / ONE; // 0.22% 777,742 QD 
            _immature[beneficiary] += amount - cut;
            _mint(lock, cut); blood.credit += cost; // SP sDAI
            brood.credit += amount; // the debt associated with QD
            // balances belongs to everyone, not to any individual;
            // amount gets decremented by APR payments made in QD 
            require(supply_cap >= brood.credit, 
            "MO::mint: supply cap exceeded");

            // TODO helper function
            // for how much credit to mint
            // based on target (what was minted before) and what is surplus from fold

            // TODO add amt to pledge.dam.credit ??
            
            sdai.transferFrom(_msgSender(), address(this), cost); // TODO approve in frontend
            emit Minted(beneficiary, cost, amount); // in this !MO...
        }
    }

    function borrow(uint amount, bool short) external payable { // amount is in QD 
        require(block.timestamp >= _MO[0].start + DURATION &&
                _MO[0].minted >= TARGET, "MO::borrow: early");    
        uint price = _get_price(); uint debit; uint credit; 
        Pledge memory pledge = _get_pledge( //  
            _msgSender(), price, false, _msgSender()
        );
        // the only way you can love long and short at the same time is if... 
        // there is more life in your years than there are years in your life.
        // religion exists because the only way to live a good life is to agree
        // to think a certain way about what is a good death is...or good debt.
        if (short) { 
            require(pledge.love.long.debit == 0 
            && pledge.owe.long.debit == 0, // timestmap
            "MO::borrow: pledge is already long");
        } else { 
            require(pledge.love.short.debit == 0 
            && pledge.owe.short.debit == 0, // timestamp
            "MO::borrow: pledge is already short");
        }
        uint sp_value = balanceOf(_msgSender()) + pledge.dam.credit +
        _ratio(price, pledge.dam.debit, ONE); 
        uint eth = _ratio(ONE, amount, price); // amount of ETH being credited...
        uint max = pledge.owe.dance ? 2 : 1; // used in require for max borrowable
         
        if (!short) { max *= longMedian.apr; eth += msg.value; // BP
            // we are crediting the pledge's long with virtual credit 
            // in units of ETH (its sDAI value is owed back to the SP) 
            pledge.love.long.credit += eth; love.long.credit += eth;
            // deposit() of QD to this LP side reduces credit value
            // we debited (in sDAI) by drawing from SP and recording 
            // the total value debited, and value of the ETH credit
            // will determine the P&L of the position in the future
            pledge.love.long.debit += amount; blood.credit -= amount;
            // incrementing a liability...LP...decrementing an asset^
            love.long.debit += amount; brood.debit += msg.value; 
            // essentially debit is the collat backing the credit
            debit = pledge.love.long.debit; credit = pledge.love.long.credit;
        } else { max *= shortMedian.apr; // see above for explanation
            pledge.love.short.credit += eth; love.short.credit += eth;
            // deposit() of QD to this LP side reduces debits owed that
            // we debited (in sDAI) by drawing from SP and recording it
            pledge.love.short.debit += amount; blood.credit -= amount;
    
            eth = _min(msg.value, pledge.love.short.credit);
            pledge.love.short.credit -= eth; // there's no way
            love.short.credit -= eth; // to burn actual ETH so
            brood.debit += eth; // ETH belongs to all pledges
            eth = msg.value - eth; pledge.dam.debit += eth;
            blood.debit += eth; love.short.debit += amount; 
            
            debit = pledge.love.short.debit; credit = pledge.love.short.credit;
        }
        // TODO limit total blood in love
        require(_blush(price, credit, debit, short) >= MIN_CR &&
        (blood.credit / 5 > debit) && sp_value > (debit * max / ONE), 
        "MO::borrow: taking on more leverage than considered healthy"
        ); Pledges[_msgSender()] = pledge; // write to storage last 
    }
}
