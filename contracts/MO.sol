
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.7.6; 
// pragma experimental SMTChecker;

/**
  THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL CONTRIBUTORS 
  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCL. NEGLIGENCE 
  OR OTHERWISE) ARISING IN ANY WAY DUE TO USE OF THIS SOFTWARE, BEING ADVISED OF THE POSSIBILITY OF SUCH DAMAGE...
 */

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Dependencies/AggregatorV3Interface.sol";
import "hardhat/console.sol"; // TODO comment out
interface ICollection is IERC721 {
    function latestTokenId() external view returns (uint256);
} // transfer F8N tokenId to 1 lucky clipped pledge per !MO
// pledge may transfer it back to QUID_ETH to receive prize

// "Get a deposit; then I divide it:"
// MO stands 4 2 things: More Options;
// Mold Offering...mold it as you see
// "there’s no life except by [debt], 
// no vision but by..the faith...that 
// I could bring pair of dice...thing$ 
// have gotten closer to the sun, and 
// I have done things in small doses"
contract MO is ERC20, ReentrancyGuard { 
    using SafeERC20 for ERC20; IERC20 public sdai; address public lock; // multi-purpose locker
    address constant public SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA; // Phoenix Labs...
    address constant public F8N = 0x3B3ee1931Dc30C1957379FAc9aba94D1C48a5405; // youtu.be/sitXeGjm4Mc
    address constant public QUID_ETH = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4; // ERC404 deployer
    
    uint constant public ONE = 1e18; uint constant public DIGITS = 18;
    uint constant public MAX_PER_DAY = 7_777_777 * ONE; // supply cap
    uint constant public DURATION = 46 days; // ends on the 47th day:
    uint constant public START_PRICE = 53 * ONE_CENT; // .54 actually
    uint constant public TARGET = 357000000 * ONE; // mint target...
    uint constant public ONE_CENT = ONE / 100; // in units of QD
    uint constant public C_NOTE = 100 * ONE; // a.k.a. Benjamin
    
    event Minted (address indexed reciever, uint cost_in_usd, uint amt); // by !MO
    // Events are emitted, so only when we emit profits for someone do we call...
    event ClippedLong (address indexed owner, address indexed clipper, uint fee); // if you know the fee
    event ClippedShort (address indexed owner, address indexed clipper, uint fee); // then you know amt
    event Voted (address indexed voter, uint vote); // only emit when increasing
    
    AggregatorV3Interface public chainlink; // Uni TWAP? TODO with:
    uint constant public MO_CUT =  22000000000000000; // 777,742 QD
    uint constant public MO_FEE =  54000000000000000; // 1.477M sDAI
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
    } // 45 days of (soy)Lent
    Offering[20] public _MO; // 20x45 days = 900
    uint internal _YEAR; // index into the above
    uint internal _PRICE; // TODO comment out after finish testing
    uint internal _POINTS; // used in withdraw; weights (medianiser)
    struct Pod { // Used in all Pools, and in individual Pledges
        uint credit; // SP credits LP with debt valued in ETH
        uint debit; // LP debits sDAI of SP for ^^^^^^^^^^^^^
        // credit used for fee voting; debit for fee charging
    } 
    struct Owe {
        uint points; // time-weighted contribution to solvency 
        Pod long; // debit = last timestamp of long APR payment
        Pod short; // debit = last timestamp of short APR payment
        bool deuce; // for ✌🏻xAPR for peace of mind, and flip debt
        bool prime; // also ^^^^^ liquidation-free; not ^^^^^^^^^ 
    }
    struct Pool { // Pools have a long Pod & short Pod, borrowers have their own LPool
        Pod long; // for LP (credit: ETH, debit: QD); for BP (credit: QDebt, debit: ETH)
        Pod short; // for LP (credit: QD, debit: ETH); for BP (credit: ETHdebt, debit: QD)
    } 
    /** Quote from a movie called...The Prestige
        The first part is called "The Pledge"... 
        The magician shows you something ordinary: 
        a certificate of deposit, or a CD. Inspect  
        to see if it's...indeed un-altered, normal. 
    */
    struct Pledge { 
        uint last; // timestamp of last state update
        Pool love; // debt and collat (long OR short)
        Owe owe; // all kinds of utility variables
        Pod dam; // debit is ETH, credit QD profit
    }   mapping (address => Pledge) Pledges;
    Pool internal love; // LP
    // a.k.a. Liability Pool
    Pod internal brood; // BP
    // youtu.be/tcMcNFialH4
    Pod internal blood; // SP

    constructor(address _lock_address) ERC20("QU!Dao", "QD") { 
        require(_msgSender() == QUID_ETH, "MO: wrong deployer");
        require(sdai.approve(lock, type(uint256).max - 1),
                                    "MO: approval failed"
        ); _MO[0].start = 1717171717; // May 31 '24 19:08:37 PM EET 
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
        uint[27] memory empty; sdai = IERC20(SDAI); lock = _lock_address;
        longMedian = Medianiser(MIN_APR, empty, 0, 0, 0);
        shortMedian = Medianiser(MIN_APR, empty, 0, 0, 0); 
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                      HELPER FUNCTIONS                      */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/

    function _min(uint _a, uint _b) internal pure returns (uint) {
        return (_a < _b) ? _a : _b;
    }

    // TODO comment out after finish testing
    function set_price(uint price) external { // set ETH price in USD
        _PRICE = price;
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

    function get_stats() public view returns (uint assets, uint liabilities) { // in $
        uint price = _get_price();
        assets = blood.credit + // SP
        love.short.debit + love.long.debit + // LP collat
        _ratio(price, brood.debit, ONE) + // ETH ownd by all pledges
        _ratio(price, blood.debit, ONE); // ETH owned by specific pledges
        
        liabilities = brood.credit + // QDebt from !MO 
        _ratio(price, love.long.credit, ONE) + // synthetic ETH collat
        _ratio(price, love.short.credit, ONE);  // synthetic ETH debt
    }

    /**
     * Returns the latest price obtained from the Chainlink ETH:USD aggregator 
     * reference contract...https://docs.chain.link/docs/get-the-latest-price
     */
    function _get_price() internal view returns (uint) {
        if (_PRICE != 0) { return _PRICE; } // TODO uncomment when done testing
        (, int priceAnswer,, uint timeStamp,) = chainlink.latestRoundData();
    
        require(timeStamp > 0 && timeStamp <= block.timestamp, "MO::getPrice: price timestamp from aggregator is 0, or in future");
        require(priceAnswer >= 0, "MO::getPrice: price answer from aggregator is negative");
        
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
     *  Find value of k in range(1, len(Weights)) such that 
     *  sum(Weights[0:k]) = sum(Weights[k:len(Weights)+1])
     *  = sum(Weights) / 2
     *  If there is no such value of k, there must be a value of k 
     *  in the same range range(1, len(Weights)) such that 
     *  sum(Weights[0:k]) > sum(Weights) / 2
     * 
     * TODO why range starts with 1?
    */
    function _medianise(uint new_stake, uint new_vote, uint old_stake, uint old_vote, bool short) internal { 
        uint delta = MIN_APR / 16;
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
                )) {
                    data.sum_w_k -= data.weights[data.k];
                    data.k -= 1;			
                }
            } else {
                while (data.sum_w_k < mid_stake) {
                    data.k += 1;
                    data.sum_w_k += data.weights[data.k];
                }
            }
            data.apr = feeTargets[data.k];
            if (data.sum_w_k == mid_stake) { 
                uint intermedian = data.apr + ((data.k + 1) * delta) + MIN_APR;
                data.apr = intermedian / 2;  
            }
        }  else { data.sum_w_k = 0; } 
        if (!short) { longMedian = data; } 
        else { shortMedian = data; } // fin
    }

    function _get_pledge(address addr, uint price, bool exists_require, address caller) internal returns (Pledge memory pledge) {
        pledge = Pledges[addr];
        require(!exists_require 
            || pledge.last != 0, 
        "MO: pledge must exist");
        bool clipped = false;
        uint old_points = 0;
        if (pledge.last != 0) {
            Pod memory SPod = pledge.dam; old_points = pledge.owe.points;
            // wait oh wait oh wait oh wait oh wait oh wait oh wait...oh
            uint fee = caller == addr ? 0 : MIN_APR / 100; // liquidator
            uint sp_value = balanceOf(_msgSender()) + SPod.credit +
                                      _ratio(price, SPod.debit, ONE); 
            if (pledge.love.long.debit > 0) {
                Pod memory LPod = pledge.love.long;
                if (pledge.owe.long.debit == 0) { // edge case
                    pledge.owe.long.debit = block.timestamp;
                    sp_value = 0;
                }
                (LPod, SPod, clipped) = _return_pledge(addr, SPod, LPod, 
                    price, block.timestamp - pledge.owe.long.debit, 
                    pledge.owe.deuce, false
                );
                if (clipped) { fee *= LPod.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money
                    if (pledge.owe.deuce) { // flip long (credit conversion)
                        // blood.credit += fee; TODO??
                        if (pledge.owe.prime) { // optimus prime is over time

                        } // only flip a portion into deuce, keep the rest,
                        // slowly shrinking (fold with a %)
                        if (fee > 0) { LPod.debit -= fee; } 
                        love.short.credit += LPod.credit;
                        love.short.debit += LPod.debit;
                        pledge.love.short.credit = LPod.credit;
                        pledge.love.short.debit = LPod.debit;
                        pledge.owe.short.debit = block.timestamp;
                    } 
                    else if (fee > 0) { // didn't call own liquidation
                        blood.credit -= fee; 
                        emit ClippedLong (addr, caller, fee);
                    }
                    pledge.love.long.credit = 0;
                    pledge.love.long.debit = 0;
                    pledge.owe.long.debit = 0; 
                } 
                else { 
                    
                    pledge.love.long.credit = LPod.credit;
                    pledge.love.long.debit = LPod.debit;
                    // only update timestamp if charged otherwise can
                    // keep resetting timestamp before an hour passes
                    // and never get charged APR at all (costs gas tho)
                    if (sp_value > balanceOf(_msgSender()) + SPod.credit +
                                             _ratio(price, SPod.debit, ONE)) {
                        pledge.owe.long.debit = block.timestamp; 
                    } 
                }   pledge.dam = SPod;
                if (fee > 0) {
                    Pledges[caller].dam.credit += fee;
                }
            } // pledges should never be short AND a long at the same time
            else if (pledge.love.short.debit > 0) { // that's why ELSE if
                Pod memory LPod = pledge.love.short;
                if (pledge.owe.short.debit == 0) { // edge case
                    pledge.owe.short.debit = block.timestamp;
                }
                (LPod, SPod, clipped) = _return_pledge(addr, SPod, LPod, 
                    price, block.timestamp - pledge.owe.short.debit, 
                    pledge.owe.deuce, true
                );
                if (clipped) { fee *= LPod.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money
                    if (pledge.owe.deuce) { // flip short (credit conversion)
                        if (fee > 0) { LPod.debit += fee; }
                        love.long.credit += LPod.credit;
                        love.long.debit += LPod.debit;
                        pledge.love.long.credit = LPod.credit;
                        pledge.love.long.debit = LPod.debit;
                        pledge.owe.long.debit = block.timestamp;   
                    } 
                    if (fee > 0) { 
                        blood.credit -= fee; 
                        emit ClippedShort(addr, caller, fee);
                    }
                    pledge.love.short.credit = 0;
                    pledge.love.short.debit = 0;
                    pledge.owe.short.debit = 0; 
                } else { 
                    pledge.love.short.credit = LPod.credit;
                    pledge.love.short.debit = LPod.debit;
                    if (sp_value > balanceOf(_msgSender()) + SPod.credit +
                                             _ratio(price, SPod.debit, ONE)) {
                        pledge.owe.short.debit = block.timestamp; 
                    } 
                    pledge.owe.short.debit = block.timestamp;
                }   pledge.dam = SPod;
                if (fee > 0) {
                    Pledges[caller].dam.credit += fee;
                }
            }
            if (balanceOf(addr) > 0) { // update points
                uint since = (block.timestamp - pledge.last) / 1 hours;
                uint points = (since *
                    (balanceOf(addr) + pledge.dam.credit) / ONE
                ); 
                pledge.owe.points += points;
                _POINTS += points; // FIXME overflow?
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

    function _return_pledge(address addr, Pod memory SPod, Pod memory LPod, uint price, uint time_delta, bool deuce, bool short) internal returns (Pod memory, Pod memory, bool clipped) {
        // "though eight is not enough...no,
        // it's like switch [lest you] bust: 
        // now your whole [pledge] is dust" ~ Basta Rhymes, et. al.
        if (time_delta >= 1 hours) { // there's 8760 hours per year 
            time_delta /= 1 hours;
            uint owe = deuce ? 2 : 1;
            uint apr = short ? shortMedian.apr : longMedian.apr; 
            owe *= (apr * LPod.debit * time_delta) / (8760 * ONE);
            // try to pay with SP deposit: QD if long or ETH if short 
            uint most = short ? _min(SPod.debit, owe) : _min(SPod.credit, owe);
            if (owe > 0 && most > 0) { owe -= most;
                if (short) { // from the SP deposit
                    brood.debit += most;
                    blood.debit -= most;
                    SPod.debit -= most; 
                    owe -= _ratio(price, most, ONE);
                } else { 
                    SPod.credit -= most;
                    blood.credit += most; // TODO double check if double spend
                    owe -= most;
                }
            } if (owe > 0) { // SP deposit in QD was insufficient to pay pledge's APR
                most = _min(balanceOf(addr), owe);
                _transfer(addr, address(this), most);
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
                }   
                if (owe > 0) { // pledge cannot pay APR (delinquent)

                    (LPod, SPod, clipped) = _fold(addr, LPod, SPod, false, short, price);
                } 
            } 
        }
        if (_blush(price, LPod.credit, LPod.debit, short) < ONE) {
            (LPod, SPod, clipped) = _fold(addr, LPod, SPod, deuce, short, price);
        } return (LPod, SPod, clipped);
    }
    
    // ‘Neath the halo of a street-lamp, I turned my collar
    // to the cold and damp...know when to hold 'em...know 
    // when to..."
    function _fold(address owner, Pod memory LPod, Pod memory SPod, bool deuce, bool short, uint price) internal returns (Pod memory, Pod memory, bool folded) {
        uint in_qd = _ratio(price, LPod.credit, ONE); 
        folded = true; 
        if (short) {  
            if (LPod.debit > in_qd) { // profitable    
                LPod.debit -= in_qd; // return the
                blood.credit += in_qd; // debited amount to SP
                // since we canceled all the credit then
                // surplus debit is the pledge's profit
                SPod.credit += LPod.debit; // 
                // FIXME increase brood.credit...???...as it were,
                // PROFIT CAME AT THE EXPENSE OF BLOOD (everyone):
                // brood.credit += pledge.love.short.debit;
            } else { // "Lightnin' strikes and the court lights get dim"
                if (!deuce) {
                    uint delta = (in_qd * MIN_CR) / ONE - LPod.debit;
                    uint sp_value = balanceOf(owner) + SPod.credit +
                    _ratio(price, SPod.debit, ONE); uint in_eth;
                    if (delta > sp_value) {
                        delta = in_qd - LPod.debit;
                    } 
                    // "It's like inch by inch and step by step...i'm closin'
                    // in on your position and reconstruction is my mission"
                    if (sp_value >= delta) { folded = false;
                        // decrement QD first because ETH is rising
                        uint most = _min(SPod.credit, delta);
                        if (most > 0) { // virtual balance first
                            in_eth = _ratio(ONE, most, price);
                            LPod.credit -= in_eth;
                            love.short.credit -= in_eth;
                            SPod.credit -= most;
                            delta -= most; // TODO blood?
                        }
                        if (delta > 0) { // use actual _balances
                            most = _min(balanceOf(owner), delta);
                            if (most > 0) {
                                _transfer(owner, address(this), most);
                                blood.credit += most; delta -= most;
                                in_eth = _ratio(ONE, most, price);
                                LPod.credit -= in_eth;
                                love.short.credit -= in_eth;
                            }
                        }
                        if (delta > 0) {
                            in_eth = _ratio(ONE, delta, price);
                            blood.debit -= in_eth; // remove ETH from SP
                            SPod.debit -= in_eth;

                            brood.debit += in_eth; // sell ETH to BP
                            LPod.credit -= in_eth;
                            love.short.credit -= in_eth;                            
                        } // "Don't get no better than this, you catch my drift?"
                    }
                } if (folded && !deuce ) { blood.credit += LPod.debit; }
            } if (folded) { 
                love.short.credit -= LPod.credit;
                love.short.debit -= LPod.debit;
            }
        } else { // leveraged long position
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
                if (!deuce) { // liquidatable
                    uint delta = (LPod.debit * MIN_CR) / ONE - in_qd;
                    uint sp_value = balanceOf(owner) + SPod.credit +
                    _ratio(price, SPod.debit, ONE); uint in_eth;
                    if (delta > sp_value) {
                        delta = LPod.debit - in_qd;
                    } 
                    if (sp_value >= delta) { folded = false;
                        // decrement ETH first because it's falling
                        in_eth = _ratio(ONE, delta, price);
                        uint most = _min(SPod.debit, in_eth);
                        if (most > 0) {
                            blood.debit -= most; // remove ETH from SP
                            SPod.debit -= most;
                        
                            brood.debit += most; // sell ETH to BP
                            LPod.credit += most;
                            love.short.credit += most;
                            delta -= _ratio(price, most, ONE);
                        } 
                        if (delta > 0) {
                            most = _min(SPod.credit, delta); 
                            SPod.credit -= most; 
                            LPod.debit -= most;
                            love.long.debit -= most;
                            delta -= most;
                            blood.credit += most;
                        }
                        if (delta > 0) { // use actual _balances
                            _transfer(owner, address(this), delta);
                            LPod.debit -= delta;
                            love.long.debit -= delta;
                            blood.credit += delta;
                        }
                    } 
                } if (folded && !deuce) { blood.credit += LPod.debit; }
            } if (folded) {
                love.short.credit -= LPod.credit;
                love.short.debit -= LPod.debit;
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

    function protect(bool prime) external { 
        uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        if (prime) {
            pledge.owe.deuce = true;
            pledge.owe.prime = true;
        } else {
            pledge.owe.deuce = !pledge.owe.deuce;
            pledge.owe.prime = false;
        }
        Pledges[_msgSender()] = pledge;
    }

    function fold(bool short) external { // take profits and close 
        uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        Pod memory SPod = pledge.dam;
        if (short) {
            (,SPod,) = _fold(_msgSender(), pledge.love.short, 
                       SPod, pledge.owe.deuce, true, price);
            pledge.dam = SPod;
            pledge.love.short.credit = 0;
            pledge.love.short.debit = 0;
            pledge.owe.short.debit = 0;
        } else {
            (,SPod,) = _fold(_msgSender(), pledge.love.long,
                       SPod, pledge.owe.deuce, false, price);
            pledge.dam = SPod;
            pledge.love.long.credit = 0;
            pledge.love.long.debit = 0;
            pledge.owe.long.debit = 0;
        }
        Pledges[_msgSender()] = pledge;
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

    // if _msgSender() is not the beneficiary...first do approve() in frontend to _transfer QD
    function deposit(address beneficiary, uint amount, bool sp, bool long) external payable {
        uint price = _get_price();
        Pledge memory pledge = _get_pledge(beneficiary, price, false, beneficiary);
        bool two_pledges = _msgSender() != beneficiary;
        uint most;
        if (!sp) {
            _transfer(_msgSender(), address(this), amount);
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
            // water diffuses to dilute the salt. The organism dries out
            // liquidated debt is still wet. If fold is profitable for the
            // borrower that's like a liquidation for the lender. If the 
            // borrower is liquidated, it's like being on their win side.
            if (amount > 0) {
                pledge.dam.credit += amount;

            }
        }
        else if (two_pledges) {
            _transfer(_msgSender(), beneficiary, amount);
        }
        else { // not two_pledges || love
            require(true, "MO::deposit: Can't transfer QD from and to the same balance");
        }   Pledges[beneficiary] = pledge;
    }

    // "You're a beast...that I was raising...you're
    // a [lease] that I was twistin' and it wears you 
    // like a gown...in my [loan sum] advocation..."
    function withdraw(uint amt, bool qd) external {
        uint price = _get_price();
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        uint most = 0; 
        uint cr = 0; 
        if (!qd) { // withdrawal only from SP...use borrow() or fold() for LP
            // the LP balance is a synthetic (virtual) representation of ETH
            // pledges only care about P&L, which can only be withdrawn in QD 
            most = _min(pledge.dam.debit, amt);
            pledge.dam.debit -= most;
            blood.debit -= most;
            // require(address(this).balance > most, "MO::withdraw: deficit ETH");
            payable(_msgSender()).transfer(most);
        } 
        else { // TODO incomplete
            // FIXME withdraw from temporary balances if current MO failed ??
            
            // BLOOD.CREDIT OVER TIME (TOTAL POINTS)
            // WILL GET ITS SHARE OF THE BP AT THE END            

            // An alternative, without requiring the use of 404, is the enforcemint of...
            // 1:1 redemption of QD for sDAI has a time window, DURATION before next !MO
            uint least = _min(balanceOf(_msgSender()), amt);

            require(_MO[_YEAR].start > block.timestamp,
                "MO::withdraw: takes 1 year for QD to mature, redemption has a time window"
            );
            /*
            
            assets = blood.credit + // SP
            love.short.debit + love.long.debit + // LP collat
            _ratio(price, brood.debit, ONE) + // ETH ownd by all pledges
            _ratio(price, blood.debit, ONE); // ETH owned by specific pledges
        
            liabilities = brood.credit + // QDebt from !MO 
            _ratio(price, love.long.credit, ONE) + // synthetic ETH collat
            _ratio(price, love.short.credit, ONE);  // synthetic ETH debt
            */
            // how to dissolvency (BP into SP)
            (uint assets, uint liabilities) = get_stats();
            
            // dilute the value of the eth
            if (liabilities > assets) {

            } else { // dilute the value of $

            }
            // frequency and wavelength, half of liquidations stay til the next MO?
            
            blood.credit -= least; _burn(_msgSender(), amt); // ONLY PLACE WE BURN ;)
            sdai.transferFrom(address(this), _msgSender(), amt);
        }
    }

    // "honey won’t you break some bread, just let it crack" ~ Rapture, by Robert been on Lev
    function mint(uint amount, address beneficiary) external nonReentrant returns (uint cost) {
        require (beneficiary != address(0), "MO::mint: can't mint to the zero address");
        require(block.timestamp >= _MO[_YEAR].start, "MO::mint: can't mint before start date"); 
        // TODO allow roll over QD value in sDAI from last !MO into new !MO
        if (block.timestamp >= _MO[_YEAR].start + DURATION + 365 days) {
            // TODO new !MO every 6 months (takes a year to mature)
            if (_MO[_YEAR].minted >= TARGET) {
                
                sdai.transferFrom(address(this), lock, 
                    _MO[_YEAR].locked * MO_FEE / ONE
                );
            }
            _YEAR += 1; // new year, "same level, the same rebel that never settled"
            require(_YEAR < 20, "MO::mint: already had our last !MO");
            _MO[_YEAR].start = block.timestamp + DURATION; // restart into new !MO
            // but first, we have our withdrawal (QD redemption) window // TODO 404

            // if(_MO[_YEAR].raised)

        } else { // minting QD has a time window (!MO duration)
            require(block.timestamp <= _MO[_YEAR].start + DURATION, "MO::mint: !MO is over"); 
            require(amount >= C_NOTE, "MO::mint: below minimum mint amount");
            uint in_days = ((block.timestamp - _MO[_YEAR].start) / 1 days) + 1; 
            cost = (in_days * ONE_CENT + START_PRICE) * (amount / ONE);
            
            uint supply_cap = in_days * MAX_PER_DAY; // in_days must be at least 1
            if (Pledges[beneficiary].last == 0) { // initialise pledge
                Pledges[beneficiary].last = block.timestamp;
                // TODO give infinite approval of the contract to spend pledge's QD
            }
            
            // FIXME cap breaks on second !MO   
            require(supply_cap >= blood.credit, "MO::mint: supply cap exceeded");
            
            // TODO 404 record tokenId (add to range for this !MO) 

            _MO[_YEAR].locked += cost; _MO[_YEAR].minted += amount;
            _mint(beneficiary, amount); blood.credit += cost; // SP

            // TODO helper function
            // for how much credit to mint
            // based on target (what was minted before) and what is surplus from fold

            brood.credit += amount; // the debt associated with QD
            // balances belongs to everyone, not to any individual;
            // amount gets decremented by APR payments made in QD 

            // TODO add amt to pledge.dam.credit ??
            
            sdai.transferFrom(_msgSender(), address(this), cost); // TODO approve in frontend
            emit Minted(beneficiary, cost, amount); // in this !MO...
        }
    }

    function borrow(uint amount, bool short) external payable { // amount is in QD 
        require(block.timestamp >= _MO[0].start + DURATION
             && _MO[0].minted >= (TARGET - C_NOTE), // ~350
            "MO::borrow: can't borrow 'til 1st !MO succeeds"
        );    
        uint debit; uint credit;
        uint price = _get_price();
        Pledge memory pledge = _get_pledge(
            _msgSender(), price, false, _msgSender()
        );
        // the only way you can love long and short at the same time is if... 
        // there is more life in your years than there are years in your life...
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
        uint max = pledge.owe.deuce ? 2 : 1; // used in require for max borrowable
         
        if (!short) { max *= longMedian.apr; eth += msg.value;
            // we are crediting the pledge's long with virtual credit 
            // in units of ETH (its sDAI value is owed back to the SP) 
            pledge.love.long.credit += eth; love.long.credit += eth;
            // deposit() of QD to this LP side reduces credit value
            // we debited (in sDAI) by drawing from SP and recording 
            // the total value debited and value of the ETH credit...
            // will determine the P&L of the position in the future...
            // incrementing a liability...    decrementing an asset...
            pledge.love.long.debit += amount; blood.credit -= amount;
            love.long.debit += amount; brood.debit += msg.value; // ETH
            // essentially debit is the collateral backing the credit...
            debit = pledge.love.long.debit; credit = pledge.love.long.credit;
        } else { max *= shortMedian.apr; // see above for explanation
            pledge.love.short.credit += eth; love.short.credit += eth;
            // deposit() of QD to this LP side reduces debied owed that
            // we debited (in sDAI) by drawing from SP and recording it
            pledge.love.short.debit += amount; blood.credit -= amount;
            
            eth = _min(msg.value, pledge.love.short.credit);
            pledge.love.short.credit -= eth; // there's no way
            love.short.credit -= eth; // to burn actual ETH so
            brood.debit += eth; // ETH belongs to all pledges...
            eth = msg.value - eth; pledge.dam.debit += eth;
            blood.debit += eth; love.short.debit += amount; 
            
            debit = pledge.love.short.debit; credit = pledge.love.short.credit;
        }
        require(_blush(price, credit, debit, short) >= MIN_CR &&
        (blood.credit / 5 > debit) && sp_value > (debit * max / ONE), 
        "MO::borrow: taking on more leverage than considered healthy"
        ); Pledges[_msgSender()] = pledge; // write to storage last 
    }
}
