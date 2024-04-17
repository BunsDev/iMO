
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.8.0; 
// pragma experimental SMTChecker;
import "hardhat/console.sol"; // TODO comment out
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Dependencies/AggregatorV3Interface.sol";
contract MO is ERC20 { 
    IERC20 public sdai; address public lock; // multi-purpose locker (OpEx)...
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant public SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address constant public QUID = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4;
    mapping(address => Pod) public _maturing; // QD from last 2 !MO...
    uint constant public ONE = 1e18; uint constant public DIGITS = 18;
    uint constant public MAX_PER_DAY = 7_777_777 * ONE; // supply cap
    uint constant public TARGET = 35700 * STACK; // !MO mint target
    uint constant public START_PRICE = 53 * CENT; // .54 actually
    uint constant public LENT = 46 days; // ends on the 47th day
    uint constant public STACK = C_NOTE * 100; // 10_000 in QD.
    uint constant public C_NOTE = 100 * ONE; 
    uint constant public RACK = STACK / 10;
    uint constant public CENT = ONE / 100; 
    
    event Minted (address indexed reciever, uint cost_in_usd, uint amt); // by !MO
    // Events are emitted, so only when we emit profits for someone do we call...
    event clappedLong (address indexed owner, address indexed clipper, uint fee); 
    event clappedShort (address indexed owner, address indexed clipper, uint fee);
    event Voted (address indexed voter, uint vote); // only emit when increasing
    
    AggregatorV3Interface public chainlink;
    uint constant public MO_FEE = 54 * CENT; 
    uint constant public MO_CUT = 22 * CENT; 
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
    Offering[16] public _MO; // been working on this 
    struct Offering { // since like 2016, no kidding
        uint start; // date 
        uint locked; // sDAI
        uint minted; // QD
        uint burned; // ^
    }
    uint internal _YEAR; // actually half a year, every 6 months
    uint internal _PRICE; // TODO comment out when finish testing
    uint internal _POINTS; // used in collect; weights (medianiser)
    struct Pod { // Used in all Pools, and in individual Pledges
        uint credit; // carry credits work with debt in ETH units
        uint debit; // work debits sDAI from carry as collateral 
        // credit used for fee voting; debit for fee charging...
    } 
    struct Owe { uint points; // time-weighted, matured _balances  
        Pod long; // debit = last timestamp of long APR payment...
        Pod short; // debit = last timestamp of short APR payment...
        bool dance; // pay...✌🏻xAPR for peace of mine, and flip debt
        bool grace; // ditto ^^^^^ pro-rated _fold, but no ^^^^ ^^^^ 
    }
    struct Pool { Pod long; Pod short; } // work
    /* Quote from a movie called...The Prestige
        The first part is called "The Pledge"... 
        The imagineer shows you something ordinary: 
        a certificate of deposit, or a CD. Inspect  
        to see if it's...indeed un-altered, normal 
    */
    struct Pledge {
        uint last; // timestamp of last state update
        Pool work; // debt and collat (long OR short)
        Pod carry; // debit is ETH, credit QD profit 
        Owe dues; // all kinds of utility variables:
    }   mapping (address => Pledge) Pledges; // work
    Pod internal wind; // debit chills; hot credit  
    Pool internal work; // (a.k.a. Liability Pool)
    Pod internal carry; // as in...cost of carry
    // always answers a question with a question
    // can we borrow? can we collect? depends
    constructor(address _lock_address) ERC20("QU!Dao", "QD") { 
        require(_msgSender() == QUID, "MO: wrong deployer");
        require(sdai.approve(lock, 1477741 * ONE * 16), "NO"); // 1719444444
        _MO[0].start = 1717171717; lock = _lock_address; // multi-sig
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
    /*                       HELPER FUNCTIONS                     */
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
        uint price = _get_price();
        Pledge memory pledge = _get_update( 
            _msgSender(), price, false, _msgSender()
        ); _send(_msgSender(), recipient, amount); return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint price = _get_price();
        _spendAllowance(from, _msgSender(), value);
        Pledge memory pledge = _get_update( 
            _msgSender(), price, false, _msgSender()
        );  _send(from, to, value); return true;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) + _maturing[account].debit +  _maturing[account].credit;
        // matured QD ^^^^^^^ in the process of maturing as ^^^^^^ and just starting to mature...
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
            uint debt_in_QD = _ratio(_price, _debt, ONE); 
            return _ratio(ONE, _collat, debt_in_QD); // collat is in QD
            // we multiply collat first to preserve precision 
        } else {
            return _ratio(_price, _collat, _debt); // debt is in QD
        } 
    }
    
    function _send(address from, address to, uint256 value) internal {
        require(from != address(0) && to == address(0), 
               "MO::transfer: passed in zero address");
        uint delta; // character
        if (value > balanceOf(from)) { 
            delta = value - balanceOf(from);
            value -= delta; // having a property 
            _maturing[from].credit -= delta; // is not 
            if (to != address(this)) { // same 
                _maturing[to].credit += delta; // as 
            } else { _burn(from, delta); // value
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
    function _medianise(uint new_stake, uint new_vote, 
        uint old_stake, uint old_vote, bool short) internal { 
        uint delta = MIN_APR / 16; // update annual average in Offering TODO
        Medianiser memory data = short ? shortMedian : longMedian;
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
        if (!short) { longMedian = data; } 
        else { shortMedian = data; } // fin
    }

     // ------------ OPTIONAL -----------------
    // voting can allow LTV to act as moneyness,
    // but while DSR is high this is unnecessary  
    function _get_owe() internal { // used in 3 places
        // using APR / into MIN = scale
        // if you over-collat by 8% x scale
        // then you get a discount from APR
        // that is exactly proportional...

        // means we do have to add it in _fold

        // every time we can update _get_owe
        // is when Lockers reset the clock...
        // transferring two NFTs onReceived
        // use medians to guage implied vol
        uint excess = _YEAR * TARGET; // excess wind.credit
        if (wind.credit > excess) {

        } else {

        }
    }   // "So listen This is how I shed my tears (crying down coins)
    // A [_get_owe work] is the law that we live by"

    function _get_update(address addr, uint price, bool must_exist, address caller) 
        internal returns (Pledge memory pledge) { pledge = Pledges[addr]; require(
            !must_exist || pledge.last != 0, "MO: pledge must exist"); 
        bool clapped = false; uint old_points; uint grace; uint time;
        if ((_YEAR % 2 == 1) && (_maturing[addr].credit > 0)) {
            require(block.timestamp >= _MO[0].start + LENT &&
                _MO[0].minted >= TARGET, "MO::borrow: early"); 
            if (_maturing[addr].debit == 0) {
                _maturing[addr].debit = _maturing[addr].credit;
                _maturing[addr].credit = 0;
            }
            // TODO track total so that in mint or withdraw we know
        } else if (_maturing[addr].debit > 0) { // !MO # 2 4 6 8...
            // debit for 2 is credit from 0...then for 2 from 4...
            _mint(addr, _maturing[addr].debit); 
            _maturing[addr].debit = 0;
        } // else if ()
        if (pledge.last != 0) { Pod memory _carry = pledge.carry; 
            old_points = pledge.dues.points; _POINTS -= old_points;
            time = pledge.dues.long.debit > block.timestamp ? 0 : 
                        block.timestamp - pledge.dues.long.debit; 
            // wait oh wait oh wait oh wait oh wait oh wait oh wait...oh
            uint fee = caller == addr ? 0 : MIN_APR / 100; // liquidator
            uint in_carry = balanceOf(_msgSender()) + _carry.credit +
                                      _ratio(price, _carry.debit, ONE); 
            if (pledge.work.long.debit > 0) { // owes carried interest
                Pod memory _work = pledge.work.long;
                if (pledge.dues.long.debit == 0) { in_carry = 0; // TODO?
                    pledge.dues.long.debit = block.timestamp;
                }   if (pledge.dues.dance) { grace = 1; 
                    if (pledge.dues.grace) { // 15% per 6 months
                        grace = fee * pledge.dues.long.debit;
                    } 
                }   (_work, _carry, clapped) = _fetch_pledge(addr, 
                            _carry, _work, price, time, grace, false
                ); 
                if (clapped) { fee *= _work.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money
                    if (grace == 1) { // flip long (credit conversion)
                        // carry.credit += fee; TODO??
                        if (fee > 0) { _work.debit -= fee; } 
                        work.short.debit += _work.debit;
                        work.short.credit += _work.credit;
                        pledge.work.short.debit = _work.debit;
                        pledge.work.short.credit = _work.credit;
                        pledge.dues.short.debit = block.timestamp + 96 hours; // TODO too much?
                    }   else if (fee > 0) { carry.credit -= fee; 
                        emit clappedLong(addr, caller, fee);
                    }   pledge.work.long.credit = 0;
                        pledge.work.long.debit = 0;
                        pledge.dues.long.debit = 0; 
                } else { pledge.work.long.debit = _work.debit; 
                        pledge.work.long.credit = _work.credit;
                        // only update timestamp if charged otherwise can
                        // keep resetting timestamp before 10 minutes pass
                        // and never get charged APR at all (costs gas tho)
                        if (in_carry > balanceOf(_msgSender()) + _carry.credit +
                                                 _ratio(price, _carry.debit, ONE)) {
                                                 pledge.dues.long.debit = block.timestamp; } 
                }   pledge.carry = _carry; if (fee > 0) { Pledges[caller].carry.credit += fee; }
            } // pledges should never be short AND a long at the same time
            else if (pledge.work.short.debit > 0) { // that's why ELSE if
                Pod memory _work = pledge.work.short;
                time = pledge.dues.short.debit > block.timestamp ? 0 : 
                        block.timestamp - pledge.dues.short.debit; 
                if (pledge.dues.short.debit == 0) { // edge case
                    pledge.dues.short.debit = block.timestamp;
                }   if (pledge.dues.dance) { grace = 1;
                    if (pledge.dues.grace) {  // 15% per 6 months
                        grace = fee * pledge.dues.short.debit;
                    }
                }   (_work, _carry, clapped) = _fetch_pledge(addr, 
                            _carry, _work, price, time, grace, true
                );
                if (clapped) { fee *= _work.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money...
                    if (grace == 1) { // flip short (credit conversion)
                        if (fee > 0) { _work.debit += fee; }
                        work.long.credit += _work.credit;
                        work.long.debit += _work.debit;
                        pledge.work.long.credit = _work.credit;
                        pledge.work.long.debit = _work.debit;
                        pledge.dues.long.debit = block.timestamp + 96 hours; // TODO too much?
                    }   if (fee > 0) { carry.credit -= fee; 
                        emit clappedShort(addr, caller, fee);
                    }   pledge.work.short.credit = 0;
                        pledge.work.short.debit = 0;
                        pledge.dues.short.debit = 0; 
                } else { 
                    pledge.work.short.credit = _work.credit;
                    pledge.work.short.debit = _work.debit;
                    if (in_carry > balanceOf(_msgSender()) + _carry.credit +
                                             _ratio(price, _carry.debit, ONE)) {
                        pledge.dues.short.debit = block.timestamp; 
                    }   pledge.dues.short.debit = block.timestamp;
                }   pledge.carry = _carry;
                if (fee > 0) {
                    Pledges[caller].carry.credit += fee;
                }
            }
            if (balanceOf(addr) > 0) { 
                // TODO simplify based on !MO
                pledge.dues.points += ( // 
                    ((block.timestamp - pledge.last) / 1 hours) 
                    * (balanceOf(addr) + pledge.carry.credit) / ONE
                ); 

                // carry.credit; // is subtracted from 
                // rebalance fee targets (governance)
                if (pledge.dues.long.credit != 0) { 
                    _medianise(pledge.dues.points, 
                        pledge.dues.long.credit, old_points, 
                        pledge.dues.long.credit, false
                    );
                } if (pledge.dues.short.credit != 0) {
                    _medianise(pledge.dues.points, 
                        pledge.dues.short.credit, old_points, 
                        pledge.dues.short.credit, true
                    );
                }   _POINTS += pledge.dues.points;
            }
        }   pledge.last = block.timestamp; // TODO check
    }

    // breath control (wind work) is imperative to do the survival "dance"
    // dance is a semaphor...0 is false, 1 is just dance, grace > 1 ^^^^^ true
    function _fetch_pledge(address addr, Pod memory _carry, Pod memory _work, 
        uint price, uint delta, uint dance, bool short) internal 
        returns (Pod memory, Pod memory, bool clapped) {
        // "though eight is not enough...no,
        // it's like switch [lest you] bust: 
        // now your whole [pledge] is dust" ~ Basta Rhymes, et. al.
        if (delta >= 10 minutes) { // 52704 x 10 mins per year
            uint apr = short ? shortMedian.apr : longMedian.apr; 
            delta /= 10 minutes; uint owe = (dance > 0) ? 2 : 1; 
            owe *= (apr * _work.debit * delta) / (52704 * ONE);
            delta = _blush(price, _work.credit, _work.debit, short);
            if (delta < ONE) {
                (_work, _carry, clapped) = _fold(addr, _work, _carry, 
                                              dance, short, price);
            }  else { 
            // if (delta > MIN_CR) { // TODO APR discount based on CR/MIN_CR
                // }
                
                uint most = short ? _min(_carry.debit, owe) : _min(_carry.credit, owe);
                if (owe > 0 && most > 0) { 
                    if (short) { 
                        wind.debit += most;
                        carry.debit -= most;
                        _carry.debit -= most; 
                        owe -= _ratio(price, most, ONE);
                    } else { _carry.credit -= most;
                        carry.credit += most; // TODO double check if double spend
                        owe -= most;
                    }
                    // TODO the user's own _maturing balance?
                } if (owe > 0) { 
                    most = _min(balanceOf(addr), owe);
                    _send(addr, address(this), most);
                    owe -= most; carry.credit += most;
                    if (short && owe > 0) { owe = _ratio(owe, price, ONE);
                        most = _min(_carry.credit, owe); _carry.credit -= most;
                        // TODO double check if double spend
                        carry.credit += most; owe -= most;
                    } else if (owe > 0) { owe = _ratio(ONE, owe, price); 
                        most = _min(_carry.debit, owe); wind.debit += most;
                        _carry.debit -= most; carry.debit -= most; owe -= most;
                    }   if (owe > 0) { // pledge cannot pay APR (delinquent)
                        (_work, _carry, clapped) = _fold(addr, 
                            _work, _carry, 0, short, price);
                    } 
                }   
            } 
        }   return (_work, _carry, clapped);
    }
    
    // "Don't get no better than this, you catch my drift?
    // So close no matter how far, rage be in it like you 
    // couldn’t believe...or work like one could scarcely 
    // imagine...if one isn’t satisfied, indulge the latter
    // ‘neath the halo of a street-lamp...I fold my collar
    // to the cold and damp...know when to hold 'em...know 
    // when to..."
    function _fold(address owner, Pod memory _work, Pod memory _carry, 
                   uint dance, bool short, uint price) internal 
                   returns (Pod memory, Pod memory, bool folded) {
        uint in_QD = _ratio(price, _work.credit, ONE); // folded = true;
        if (short && in_QD > 0) { // only if pledge owe any debt at all...
            if (_work.debit > in_QD) { // profitable (probably voluntary)
                folded = true;
                _work.debit -= in_QD; // return debited
                carry.credit += in_QD; // amount to carry
                
                // since we canceled all the credit then
                // surplus debit is the pledge's profit
             
                
                // FIXME increase wind.credit...???...as it were,
                // PROFIT CAME AT THE EXPENSE OF carry (everyone):
                
                // throw caution to the wind 
                // wind.credit += pledge.work.short.debit;

                // for creating QD we add QDebt, but this shouldn't
                // make the system more insolvent, no net change to 
                // LTV overall (TVL CR)
            } 
            // in_QD is worth more than _work.debit, price went up...
            else { // "Lightnin' strikes and the court lights get dim"
                if (dance == 0) { // no grace, and no way to flip debt
                    uint delta = (in_QD * MIN_CR) / ONE - _work.debit;
                    uint sp_value = balanceOf(owner) + _carry.credit +
                    _ratio(price, _carry.debit, ONE); uint in_eth;
                    if (delta > sp_value) { delta = in_QD - _work.debit; } 
                    // "It's like inch by inch and step by step...i'm closin'
                    // in on your position and reconstruction is my mission"
                    if (sp_value >= delta) { folded = false;
                        // decrement QD first because ETH is rising
                        uint most = _min(_carry.credit, delta);
                        if (most > 0) { in_eth = _ratio(ONE, most, price);
                            _work.credit -= in_eth; _carry.credit -= most;
                            work.short.credit -= in_eth; delta -= most; 
                        } if (delta > 0) { // use _balances
                            most = _min(balanceOf(owner), delta);
                            if (most > 0) { delta -= most;
                                _send(owner, address(this), most);
                                carry.credit += most; 
                                in_eth = _ratio(ONE, most, price);
                                _work.credit -= in_eth; 
                                
                                work.short.credit -= in_eth;
                            }
                        } if (delta > 0) { in_eth = _ratio(ONE, delta, price);
                            carry.debit -= in_eth; _carry.debit -= in_eth;
                            wind.debit += in_eth; _work.credit -= in_eth;
                            work.short.credit -= in_eth;                            
                        } 
                    } 
                } if (folded && dance == 0) { 
                    carry.credit += _work.debit; 
                } // TODO cover grace
            } if (folded) { 
                if (dance > 1) { in_QD = _min(dance, _work.debit);
                    work.short.debit -= in_QD; carry.credit += in_QD;
                    work.short.credit -= _min(_work.credit,
                        _ratio(ONE, in_QD, price)
                    ); folded = false;
                } else { work.short.credit -= _work.credit;
                         work.short.debit -= _work.debit;  
                }  // either dance state was 0 or zero...
                // TODO account if voluntary fold
                // _carry.credit += _work.debit
            }
        } else if (in_QD > 0) { // leveraged long 
            if (in_QD > _work.debit) { // profitable  
                in_QD -= _work.debit; // remainder = profit
                _carry.credit += in_QD;
                // return the debited amount to carry
                carry.credit += _work.debit; // FIXME 
                // wind.credit += in_QD; 
                // SOMETIMES WE NEED TO ADD DEBT
                // if this was not credit from actual ETH deposited
                // but virtual credit based on sDAI
            } else { 
                if (dance == 0) { // liquidatable
                    uint delta = (_work.debit * MIN_CR) / ONE - in_QD;
                    uint sp_value = balanceOf(owner) + _carry.credit +
                    _ratio(price, _carry.debit, ONE); uint in_eth;
                    if (delta > sp_value) { delta = _work.debit - in_QD; } 
                    if (sp_value >= delta) { folded = false;
                        // decrement ETH first because it's falling
                        in_eth = _ratio(ONE, delta, price);
                        uint most = _min(_carry.debit, in_eth);
                        if (most > 0) { carry.debit -= most; // remove ETH from carry
                            _carry.debit -= most; wind.debit += most; // sell the ETH 
                            _work.credit += most; work.short.credit += most;
                            delta -= _ratio(price, most, ONE);
                        } if (delta > 0) { carry.credit += most;
                            most = _min(_carry.credit, delta); 
                            _carry.credit -= most; _work.debit -= most;
                            work.long.debit -= most; delta -= most;   
                        } if (delta > 0) { carry.credit += delta;
                            _send(owner, address(this), delta);
                            _work.debit -= delta; work.long.debit -= delta;   
                        }
                    } 
                } if (folded && dance == 0) { carry.credit += _work.debit; }
            } if (folded) {
                if (dance > 1) { in_QD = _min(dance, _work.debit);
                    work.long.debit -= in_QD; carry.credit += in_QD;
                    work.long.credit -= _min(_work.credit,
                                        _ratio(ONE, in_QD, price));
                                        folded = false;
                } else { work.long.credit -= _work.credit;
                         work.long.debit -= _work.debit;
                } 
            }
        } return (_work, _carry, folded);
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/
    // dance...mint...vote...borrow...collect...fold...deposit...
    
    // "lookin' too hot...simmer down...or soon you'll get:" 
    function drop(address[] memory pledges) external {
        uint price = _get_price(); 
        for (uint i = 0; i < pledges.length; i++ ) {
            _get_update(pledges[i], price, true, _msgSender());
        } 
    }

    function dance(bool grace) external { uint price = _get_price(); 
        Pledge memory pledge = _get_update(_msgSender(), price, true, _msgSender());
        if (grace) { pledge.dues.dance = true; pledge.dues.grace = true; } else {
            pledge.dues.dance = !pledge.dues.dance;
            pledge.dues.grace = false;
        }   Pledges[_msgSender()] = pledge;
    }

    // this is a voluntary fold call, internal call can be a requisition (involuntary)
    function fold(bool short) external { uint price = _get_price(); 
        Pledge memory pledge = _get_update(_msgSender(), price, true, _msgSender());
        Pod memory _carry = pledge.carry;
        uint dance = pledge.dues.dance ? 1 : 0;
        if (short) { (,_carry,) = _fold(_msgSender(), pledge.work.short, 
                                      _carry, dance, true, price);
            pledge.work.short.credit = 0;
            pledge.work.short.debit = 0;
            pledge.dues.short.debit = 0;
        } else { (,_carry,) = _fold(_msgSender(), pledge.work.long,
                                  _carry, dance, false, price);
            pledge.work.long.credit = 0;
            pledge.work.long.debit = 0;
            pledge.dues.long.debit = 0;
        }   pledge.carry = _carry;
        Pledges[_msgSender()] = pledge; 
    }

    function vote(uint apr, bool short) external {
        uint delta = MIN_APR / 16; // 0.5%
        require(apr >= MIN_APR && apr <= (MIN_APR * 3 - delta * 6)
                && apr % delta == 0, "MO::vote: unacceptable APR");
        uint old_vote; // a vote of confidence gives...credit
        uint price = _get_price();
        Pledge memory pledge = _get_update(
            _msgSender(), price, true, _msgSender()
        );
        if (short) {
            old_vote = pledge.dues.short.credit;
            pledge.dues.short.credit = apr;
        } else {
            old_vote = pledge.dues.long.credit;
            pledge.dues.long.credit = apr;
        }
        _medianise(pledge.dues.points, apr, pledge.dues.points, old_vote, short);
        Pledges[_msgSender()] = pledge;
    }

    // if _msgSender() is not the beneficiary...first do approve() in frontend to transfer QD
    function deposit(address beneficiary, uint amount, bool _carry, bool long) external payable {
        uint price = _get_price(); 
        Pledge memory pledge = _get_update(beneficiary, price, false, beneficiary);
        bool two_pledges = _msgSender() != beneficiary; 
        if (!_carry) { uint most;
            _send(_msgSender(), address(this), amount);
            if (long) {
                most = _min(amount, pledge.work.long.debit);
                pledge.work.long.debit -= most;
                work.long.debit -= most;
                amount -= most;
            } else { // we can't decrease the short debit because
                // that would simply decrease profits in fold()
                uint eth = _ratio(ONE, amount, price);
                most = _min(eth, pledge.work.short.credit);
                pledge.work.short.credit -= eth;
                work.short.credit -= eth;
                most = _ratio(price, most, ONE);
                amount -= most;
            }
            // TODO helper function gets rate
            carry.credit += most; // interchanging QD/sDAI consider ratio
            if (amount > 0) { pledge.carry.credit += amount; }
        }
        else if (two_pledges) { _send(_msgSender(), beneficiary, amount); } // TODO sender.carry -= ; receiver.carry
        else { // not two_pledges && not _carry
            require(true, "MO::deposit: Can't transfer QD from and to the same balance");
        }   Pledges[beneficiary] = pledge;
    } // downpayment

    function collect(uint amt, bool qd) external {
        uint most; uint cr; uint price = _get_price();
        Pledge memory pledge = _get_update(_msgSender(), price, true, _msgSender());
        if (!qd) { // collect only from carry...use borrow() or fold() for work 
            // the work balance is a synthetic (virtual) representation of ETH
            // pledges only care about P&L, which can only be collected in QD 
            most = _min(pledge.carry.debit, amt);
            pledge.carry.debit -= most;
            carry.debit -= most;
            // require(address(this).balance > most, "MO::collect: deficit ETH");
            payable(_msgSender()).transfer(most); // TODO use WETH to deposit % in Lock?
        } 
        else { 
            // this automatically ensures that _YEAR > 1
            require(super.balanceOf(_msgSender()) >= amt, 
                    "MO::collect: insufficient QD balance");
            require(amt >= RACK, "MO::collect: must be over 1000");
            
            // FIXME collect from temporary balances if current MO failed ??          

            // carry.CREDIT OVER TIME (TOTAL POINTS)
            // WILL GET ITS SHARE OF THE WP AT THE END  ??
            // 1/16 * _get_owe_scale 
            // haul of costs (carry - wind).credit
            // displaced mint from logger's rhythmic rate of MOtion...
            // the more thermal mass (hot) the longer can retain chill
            // the amount of liquidity in something depends on volume.
            // surface to volume ratio determines how long 
        
              
            uint assets = carry.credit + // idle work
            work.short.debit + work.long.debit + // work is carry loaned out 
            _ratio(price, wind.debit, ONE) + // ETH owned by pledges pro rata
            _ratio(price, carry.debit, ONE); // ETH owned by specific pledges

            // TODO collapse work positions back into carry 

            // 1/16th or 1/8th 
            uint liabilities = wind.credit + // QDebt from !MO 
            _ratio(price, work.long.credit, ONE) + // synthetic ETH collat
            _ratio(price, work.short.credit, ONE);  // synthetic ETH debt
            

            if (liabilities > assets) { // speeding throttle


            } else { // dilute the value of $, slow down 

            }  
            
            
            carry.credit -= least; _burn(_msgSender(), amt); 
            sdai.transferFrom(address(this), _msgSender(), amt);
        }
    }

    // TODO bool qd, this will attempt to draw _max from _balances before sDAI (rest)
    function mint(uint amount, address beneficiary) external returns (uint cost) {
        require(beneficiary != address(0), "MO::mint: can't mint to the zero address");
        require(block.timestamp >= _MO[_YEAR].start, 
        "MO::mint: can't mint before start date"); 
        // TODO allow roll over QD value in sDAI from last !MO into new !MO...
        if (block.timestamp >= _MO[_YEAR].start + LENT + 144 days) { // 6 months
            if (_MO[_YEAR].minted >= TARGET) { // _MO[_YEAR].locked * MO_FEE / ONE
                sdai.transferFrom(address(this), lock, 1477741 * ONE); // ^  
                _MO[_YEAR].locked = 272222222 * ONE; // minus 0.54% of sDAI
            }   _YEAR += 1; // "same level, the same
            //  rebel that never settled" in _get_owe()
            require(_YEAR <= 16, "MO::mint: already had our final !MO");
            _MO[_YEAR].start = block.timestamp + LENT; // in the next !MO
        } else if (_YEAR < 16) { // forte vento, LENT gives time to _get_update
            require(amount >= RACK, "MO::mint: below minimum mint amount"); 
            uint in_days = ((block.timestamp - _MO[_YEAR].start) / 1 days) + 1; 
            require(in_days < 46, "MO::mint: current !MO is over"); 
            cost = (in_days * CENT + START_PRICE) * (amount / ONE);
            uint supply_cap = in_days * MAX_PER_DAY + totalSupply();
            if (Pledges[beneficiary].last == 0) { // init. pledge
                Pledges[beneficiary].last = block.timestamp;
                _approve(beneficiary, address(this),
                          type(uint256).max - 1);
            }
            _MO[_YEAR].locked += cost; _MO[_YEAR].minted += amount;
            wind.credit += amount; // the debts associated with QD
            // balances belong to everyone, not to any individual;
            // amount decremented by APR payments in QD (or collect)
            uint cut = MO_CUT * amount / ONE; // 0.22% 777,742 QD
            _maturing[beneficiary].credit += amount - cut; // QD
            _mint(lock, cut); carry.credit += cost; 
            emit Minted(beneficiary, cost, amount); 
            require(supply_cap >= wind.credit,
            "MO::mint: supply cap exceeded"); 

            // TODO helper function
            // for how much credit to mint
            // based on target (what was minted before) and what is surplus from fold
            // different input to _get_owe()
            
            // wind.credit 
            // TODO add amt to pledge.carry.credit ??
            
            sdai.transferFrom(_msgSender(), address(this), cost); // TODO approve in frontend
            
        }
    }

    function borrow(uint amount, bool short) external payable { // amount is in QD 
        require(block.timestamp >= _MO[0].start + LENT &&
                _MO[0].minted >= TARGET, "MO::borrow: early");    
        uint price = _get_price(); uint debit; uint credit; 
        Pledge memory pledge = _get_update( //  
            _msgSender(), price, false, _msgSender()
        );  if (short) { 
                require(pledge.work.long.debit == 0 
                && pledge.dues.long.debit == 0, // timestmap
                "MO::borrow: pledge is already long");
        } else { require(pledge.work.short.debit == 0 
            && pledge.dues.short.debit == 0, // timestamp
            "MO::borrow: pledge is already short");
        }
        uint sp_value = balanceOf(_msgSender()) + pledge.carry.credit + _ratio(
             price, pledge.carry.debit, ONE); uint old = carry.credit * 85 / 100;
        uint eth = _ratio(ONE, amount, price); // amount of ETH being credited...
        uint max = pledge.dues.dance ? 2 : 1; // used in require(max borrowable)
        if (!short) { max *= longMedian.apr; eth += msg.value; // wind
            // we are crediting the pledge's long with virtual credit 
            // in units of ETH (its sDAI value is owed back to carry) 
            pledge.work.long.credit += eth; work.long.credit += eth;
            // deposit() of QD to short work will reduce credit value
            // we debited (in sDAI) by drawing from carry, recording 
            // the total value debited (and value of the ETH credit)
            // will determine the P&L of the position in the future
            pledge.work.long.debit += amount; carry.credit -= amount;
            // increments a liability (work); decrements an asset^
            work.long.debit += amount; wind.debit += msg.value; 
            // essentially debit is the collat backing the credit
            debit = pledge.work.long.debit; credit = pledge.work.long.credit;
        } else { max *= shortMedian.apr; // see above for explanation
            pledge.work.short.credit += eth; work.short.credit += eth;
            // deposit() of QD to work.sort will reduce debit owed that
            // we debited (in sDAI) by drawing from carry (and recording)
            pledge.work.short.debit += amount; carry.credit -= amount;
            eth = _min(msg.value, pledge.work.short.credit);
            pledge.work.short.credit -= eth; // there's no way
            work.short.credit -= eth; // to burn actual ETH so
            wind.debit += eth; // ETH belongs to all pledges
            eth = msg.value - eth; pledge.carry.debit += eth;
            carry.debit += eth; work.short.debit += amount; 
            
            debit = pledge.work.short.debit; credit = pledge.work.short.credit;
        }   require(old > work.short.credit + work.long.credit, "MO::borrow");
        require(_blush(price, credit, debit, short) >= MIN_CR && // too much...
        (carry.credit / 5 > debit) && sp_value > (debit * max * MIN_APR / ONE), 
            "MO::borrow: taking on more leverage than considered healthy"
        ); Pledges[_msgSender()] = pledge; // write to storage last 
    }
}
