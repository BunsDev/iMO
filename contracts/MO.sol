
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
    mapping(address => Pod) public _immature; // QD from last 2 !MO...
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
    
    AggregatorV3Interface public chainlink; // TWAP?
    uint constant public MO_FEE =  54000000000000000; 
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
    Offering[16] public _MO; // been working on this 
    struct Offering { // since like 2016, no kidding
        uint start; // date 
        uint locked; // sDAI
        uint minted; // QD
        uint burned; // ^
    }
    uint internal _YEAR; // actually half a year, every 6 months
    uint internal _PRICE; // TODO comment out when finish testing
    uint internal _POINTS; // used in withdraw; weights (medianiser)
    struct Pod { // Used in all Pools, and in individual Pledges
        uint credit; // SP credits LP with debt valued in ETH
        uint debit; // LP debits sDAI of SP for ^^^^^^ ^^ ^^^
        // credit used for fee voting; debit for fee charging
    } 
    struct Owe { uint points; // time-weighted, matured _balances  
        Pod long; // debit = last timestamp of long APR payment...
        Pod short; // debit = last timestamp of short APR payment...
        bool dance; // pay...✌🏻xAPR for peace of mine, and flip debt
        bool grace; // ditto ^^^^^ pro-rated _fold, but no ^^^^ ^^^^ 
    }
    struct Pool { Pod long; Pod short; } // LP
    /* Quote from a movie called...The Prestige
        The first part is called "The Pledge"... 
        The imagineer shows you something ordinary: 
        a certificate of deposit, or a CD. Inspect  
        to see if it's...indeed un-altered, normal 
    */
    mapping (address => Pledge) Pledges; // to work;
    struct Pledge {
        uint last; // timestamp of last state update
        Pool work; // debt and collat (long OR short)
        Pod carry; // debit is ETH, credit QD profit 
        Owe dues; // all kinds of utility variables
    }   
    Pod internal wind; // debit (cold); credit (heat) 
    Pod internal carry; // as in cost of carry
    Pool internal work; // LP (Liability Pool)
    constructor(address _lock_address) ERC20("QU!Dao", "QD") { 
        require(_msgSender() == QUID, "MO: wrong deployer");
        require(sdai.approve(lock, 1477741 * ONE * 16), "NO");
         _MO[0].start = 1717171717; lock = _lock_address; 
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
        uint price = _get_price();
        Pledge memory pledge = _get_pledge( 
            _msgSender(), price, false, _msgSender()
        ); _send(_msgSender(), recipient, amount); return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint price = _get_price();
        _spendAllowance(from, _msgSender(), value);
        Pledge memory pledge = _get_pledge( 
            _msgSender(), price, false, _msgSender()
        );  _send(from, to, value); return true;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) + _immature[account].debit +  _immature[account].credit;
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
        uint delta; // character
        if (value > balanceOf(from)) { 
            delta = value - balanceOf(from);
            value -= delta; // having a property 
            _immature[from].credit -= delta; // is not 
            if (to != address(this)) { // same 
                _immature[to].credit += delta; // as 
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

    function _get_pledge(address addr, uint price, bool must_exist, address caller) 
        internal returns (Pledge memory pledge) { pledge = Pledges[addr]; require(
            !must_exist || pledge.last != 0, "MO: pledge must exist"); 
            bool clapped = false; uint old_points; uint grace; uint time;
        
        if ((_YEAR % 2 == 1) && (_immature[addr].credit > 0)) {
            require(block.timestamp >= _MO[0].start + LENT &&
                _MO[0].minted >= TARGET, "MO::borrow: early"); 
            if (_immature[addr].debit == 0) {
                _immature[addr].debit = _immature[addr].credit;
                _immature[addr].credit = 0;
            }
            
        } else if (_immature[addr].debit > 0) { // !MO # 2 4 6 8...
            // debit for 2 is credit from 0...then for 2 from 4...
            _mint(addr, _immature[addr].debit); 
            _immature[addr].debit = 0;
        } // else if ()
        if (pledge.last != 0) { Pod memory SPod = pledge.carry; 
            old_points = pledge.dues.points; _POINTS -= old_points;
            time = pledge.dues.long.debit > block.timestamp ? 0 : 
                        block.timestamp - pledge.dues.long.debit; 
            // wait oh wait oh wait oh wait oh wait oh wait oh wait...oh
            uint fee = caller == addr ? 0 : MIN_APR / 100; // liquidator
            uint sp_value = balanceOf(_msgSender()) + SPod.credit +
                                      _ratio(price, SPod.debit, ONE); 
            if (pledge.work.long.debit > 0) { // owes carry to the SP
                Pod memory LPod = pledge.work.long;
                if (pledge.dues.long.debit == 0) { sp_value = 0; // for line 311
                    pledge.dues.long.debit = block.timestamp;
                }   if (pledge.dues.dance) { grace = 1; 
                    if (pledge.dues.grace) { // 15% per 6 months
                        grace = fee * pledge.dues.long.debit;
                    } 
                }   (LPod, SPod, clapped) = _fetch_pledge(addr, 
                           SPod, LPod, price, time, grace, false
                ); 
                if (clapped) { fee *= LPod.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money
                    if (pledge.dues.dance) { // flip long (credit conversion)
                        // carry.credit += fee; TODO??
                        if (fee > 0) { LPod.debit -= fee; } 
                        work.short.debit += LPod.debit;
                        work.short.credit += LPod.credit;
                        pledge.work.short.debit = LPod.debit;
                        pledge.work.short.credit = LPod.credit;
                        pledge.dues.short.debit = block.timestamp + 1 days;
                    }   else if (fee > 0) { carry.credit -= fee; 
                        emit clappedLong(addr, caller, fee);
                    }   pledge.work.long.credit = 0;
                        pledge.work.long.debit = 0;
                        pledge.dues.long.debit = 0; 
                } else { pledge.work.long.debit = LPod.debit; 
                        pledge.work.long.credit = LPod.credit;
                        // only update timestamp if charged otherwise can
                        // keep resetting timestamp before 10 minutes pass
                        // and never get charged APR at all (costs gas tho)
                        if (sp_value > balanceOf(_msgSender()) + SPod.credit +
                                                 _ratio(price, SPod.debit, ONE)) {
                                                 pledge.dues.long.debit = block.timestamp; } 
                }   pledge.carry = SPod; if (fee > 0) { Pledges[caller].carry.credit += fee; }
            } // pledges should never be short AND a long at the same time
            else if (pledge.work.short.debit > 0) { // that's why ELSE if
                Pod memory LPod = pledge.work.short;
                time = pledge.dues.short.debit > block.timestamp ? 0 : 
                        block.timestamp - pledge.dues.short.debit; 
                if (pledge.dues.short.debit == 0) { // edge case
                    pledge.dues.short.debit = block.timestamp;
                }   if (pledge.dues.dance) { grace = 1;
                    if (pledge.dues.grace) {  // 15% per 6 months
                        grace = fee * pledge.dues.short.debit;
                    }
                }   (LPod, SPod, clapped) = _fetch_pledge(addr, 
                           SPod, LPod, price, time, grace, true
                );
                if (clapped) { fee *= LPod.debit / ONE;
                    // as per Alfred Mitchell-Innes' Credit Theory of Money...
                    if (pledge.dues.dance) { // flip short (credit conversion)
                        if (fee > 0) { LPod.debit += fee; }
                        work.long.credit += LPod.credit;
                        work.long.debit += LPod.debit;
                        pledge.work.long.credit = LPod.credit;
                        pledge.work.long.debit = LPod.debit;
                        pledge.dues.long.debit = block.timestamp + 1 hours;   
                    }   if (fee > 0) { carry.credit -= fee; 
                        emit clappedShort(addr, caller, fee);
                    }   pledge.work.short.credit = 0;
                        pledge.work.short.debit = 0;
                        pledge.dues.short.debit = 0; 
                } else { 
                    pledge.work.short.credit = LPod.credit;
                    pledge.work.short.debit = LPod.debit;
                    if (sp_value > balanceOf(_msgSender()) + SPod.credit +
                                             _ratio(price, SPod.debit, ONE)) {
                        pledge.dues.short.debit = block.timestamp; 
                    }   pledge.dues.short.debit = block.timestamp;
                }   pledge.carry = SPod;
                if (fee > 0) {
                    Pledges[caller].carry.credit += fee;
                }
            }
            if (balanceOf(addr) > 0) { 
                pledge.dues.points += (
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

    // ------------ OPTIONAL -----------------
    // voting can allow LTV to act as moneyness,
    // but while DSR is high this is unnecessary  
    // function _get_owe() internal {
        // using APR / into MIN = scale
        // if you over-collat by 8% x scale
        // then you get a discount from APR
        // that is exactly proportional...

    // dance is a semaphor...0 is false, 1 is just dance, or grace us too
    function _fetch_pledge(address addr, Pod memory SPod, Pod memory LPod, 
        uint price, uint delta, uint dance, bool short) internal 
        returns (Pod memory, Pod memory, bool clapped) {
        // "though eight is not enough...no,
        // it's like switch [lest you] bust: 
        // now your whole [pledge] is dust" ~ Basta Rhymes, et. al.
        if (delta >= 10 minutes) { // 52704 x 10 mins per year
            uint apr = short ? shortMedian.apr : longMedian.apr; 
            delta /= 10 minutes; uint owe = (dance > 0) ? 2 : 1; 
            owe *= (apr * LPod.debit * delta) / (52704 * ONE);
            delta = _blush(price, LPod.credit, LPod.debit, short);
            if (delta < ONE) {
                (LPod, SPod, clapped) = _fold(addr, LPod, SPod, 
                                        dance, short, price);
            }  else { 
            // if (delta > MIN_CR) { // TODO APR discount based on CR/MIN_CR
                // }
                // try to pay with SP deposit: QD if long or ETH if short 
                uint most = short ? _min(SPod.debit, owe) : _min(SPod.credit, owe);
                if (owe > 0 && most > 0) { 
                    if (short) { // from the SP deposit
                        wind.debit += most;
                        carry.debit -= most;
                        SPod.debit -= most; 
                        owe -= _ratio(price, most, ONE);
                    } else { SPod.credit -= most;
                        carry.credit += most; // TODO double check if double spend
                        owe -= most;
                    }
                    // TODO the user's own _immature balance
                } if (owe > 0) { // SP deposit in QD was insufficient to pay pledge's APR
                    most = _min(balanceOf(addr), owe);
                    _send(addr, address(this), most);
                    owe -= most; carry.credit += most;
                    if (short && owe > 0) { owe = _ratio(owe, price, ONE);
                        most = _min(SPod.credit, owe); SPod.credit -= most;
                        // TODO double check if double spend
                        carry.credit += most; owe -= most;
                    } else if (owe > 0) { owe = _ratio(ONE, owe, price); 
                        most = _min(SPod.debit, owe); wind.debit += most;
                        SPod.debit -= most; carry.debit -= most; owe -= most;
                    }   if (owe > 0) { // pledge cannot pay APR (delinquent)
                        (LPod, SPod, clapped) = _fold(addr, 
                            LPod, SPod, 0, short, price);
                    } 
                }   
            } 
        }   return (LPod, SPod, clapped);
    }
    
    // "Don't get no better than this, you catch my drift?
    // So close no matter how far, rage be in it like you 
    // couldn’t believe...or work like one could scarcely 
    // imagine...if one isn’t satisfied, indulge the latter
    // ‘neath the halo of a street-lamp...I fold my collar
    // to the cold and carryp...know when to hold 'em...know 
    // when to..."
    function _fold(address owner, Pod memory LPod, Pod memory SPod, 
                   uint dance, bool short, uint price) internal 
                   returns (Pod memory, Pod memory, bool folded) {
        uint in_qd = _ratio(price, LPod.credit, ONE); folded = true;
        if (short && in_qd > 0) {
            if (LPod.debit > in_qd) { // profitable
                LPod.debit -= in_qd; // return debited
                carry.credit += in_qd; // amount to SP
                // since we canceled all the credit then
                // surplus debit is the pledge's profit
                SPod.credit += LPod.debit; // 
                // FIXME increase wind.credit...???...as it were,
                // PROFIT CAME AT THE EXPENSE OF carry (everyone):
                // wind.credit += pledge.work.short.debit;
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
                            work.short.credit -= in_eth; delta -= most; 
                        } if (delta > 0) { // use _balances
                            most = _min(balanceOf(owner), delta);
                            if (most > 0) { delta -= most;
                                _send(owner, address(this), most);
                                carry.credit += most; 
                                in_eth = _ratio(ONE, most, price);
                                LPod.credit -= in_eth; 
                                work.short.credit -= in_eth;
                            }
                        } if (delta > 0) { in_eth = _ratio(ONE, delta, price);
                            carry.debit -= in_eth; SPod.debit -= in_eth;
                            wind.debit += in_eth; LPod.credit -= in_eth;
                            work.short.credit -= in_eth;                            
                        } 
                    } 
                } if (folded && dance == 0) { carry.credit += LPod.debit; } // TODO cover grace
            } if (folded) { 
                if (dance > 1) { in_qd = _min(dance, LPod.debit);
                    work.short.debit -= in_qd; carry.credit += in_qd;
                    work.short.credit -= _min(LPod.credit,
                        _ratio(ONE, in_qd, price)
                    ); folded = false;
                } else { work.short.credit -= LPod.credit;
                         work.short.debit -= LPod.debit;  
                }  // either dance state was 0 or zero...
            }
        } else if (in_qd > 0) { // leveraged long 
            if (in_qd > LPod.debit) { // profitable  
                in_qd -= LPod.debit; // remainder = profit
                SPod.credit += in_qd;
                // return the debited amount to the SP
                carry.credit += LPod.debit; // FIXME 
                // wind.credit += in_qd; 
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
                        if (most > 0) { carry.debit -= most; // remove ETH from SP
                            SPod.debit -= most; wind.debit += most; // sell ETH to WP
                            LPod.credit += most; work.short.credit += most;
                            delta -= _ratio(price, most, ONE);
                        } if (delta > 0) { carry.credit += most;
                            most = _min(SPod.credit, delta); 
                            SPod.credit -= most; LPod.debit -= most;
                            work.long.debit -= most; delta -= most;   
                        } if (delta > 0) { carry.credit += delta;
                            _send(owner, address(this), delta);
                            LPod.debit -= delta; work.long.debit -= delta;   
                        }
                    } 
                } if (folded && dance == 0) { carry.credit += LPod.debit; }
            } if (folded) {
                if (dance > 1) { in_qd = _min(dance, LPod.debit);
                    work.long.debit -= in_qd; carry.credit += in_qd;
                    work.long.credit -= _min(LPod.credit,
                                        _ratio(ONE, in_qd, price));
                                        folded = false;
                } else { work.long.credit -= LPod.credit;
                         work.long.debit -= LPod.debit;
                } 
            }
        } return (LPod, SPod, folded);
    }
    // 

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                      BASIC OPERATIONS                      */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/
    // freeze...mint...vote...borrow...withdraw...fold...deposit...
    // "lookin' too hot...simmer down...or soon you'll get:" 
    function drop(address[] memory pledges) external {
        uint price = _get_price(); 
        for (uint i = 0; i < pledges.length; i++ ) {
            _get_pledge(pledges[i], price, true, _msgSender());
        } 
    }

    function freeze(bool grace) external { uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        if (grace) { pledge.dues.dance = true; pledge.dues.grace = true; } else {
            pledge.dues.dance = !pledge.dues.dance;
            pledge.dues.grace = false;
        }   Pledges[_msgSender()] = pledge;
    }

    function fold(bool short) external { uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        Pod memory SPod = pledge.carry;
        uint dance = pledge.dues.dance ? 1 : 0;
        if (short) { (,SPod,) = _fold(_msgSender(), pledge.work.short, 
                                      SPod, dance, true, price);
            pledge.work.short.credit = 0;
            pledge.work.short.debit = 0;
            pledge.dues.short.debit = 0;
        } else { (,SPod,) = _fold(_msgSender(), pledge.work.long,
                                  SPod, dance, false, price);
            pledge.work.long.credit = 0;
            pledge.work.long.debit = 0;
            pledge.dues.long.debit = 0;
        }   pledge.carry = SPod;
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
    function deposit(address beneficiary, uint amount, bool sp, bool long) external payable {
        uint price = _get_price(); 
        Pledge memory pledge = _get_pledge(beneficiary, price, false, beneficiary);
        bool two_pledges = _msgSender() != beneficiary; 
        if (!sp) { uint most;
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
            // if the outside environment is saltier than the organism... 
            // eliminating water helps prevent harmful organisms winding.
            // water diffuses to dilute the salt. The organism dries out.
            // Liquidated debt is still wet. If fold is profitable for the
            // borrower, that's like a liquidation for the lender. If the 
            // borrower is liquidated, it's like being on their win side.
            if (amount > 0) { pledge.carry.credit += amount; }
        }
        else if (two_pledges) { _send(_msgSender(), beneficiary, amount); }
        else { // not two_pledges && not SP
            require(true, "MO::deposit: Can't transfer QD from and to the same balance");
        }   Pledges[beneficiary] = pledge;
    }

    function withdraw(uint amt, bool qd) external {
        uint most; uint cr; uint price = _get_price();
        Pledge memory pledge = _get_pledge(_msgSender(), price, true, _msgSender());
        if (!qd) { // withdrawal only from SP...use borrow() or fold() for LP
            // the LP balance is a synthetic (virtual) representation of ETH
            // pledges only care about P&L, which can only be withdrawn in QD 
            most = _min(pledge.carry.debit, amt);
            pledge.carry.debit -= most;
            carry.debit -= most;
            // require(address(this).balance > most, "MO::withdraw: deficit ETH");
            payable(_msgSender()).transfer(most);
        } 
        else { 
            require(super.balanceOf(_msgSender()) >= amt, 
                    "MO::withdraw: insufficient QD balance");
            require(amt >= RACK, "MO::withdraw: must be over 1000");
            
            
            // FIXME withdraw from temporary balances if current MO failed ??
            
            // carry.CREDIT OVER TIME (TOTAL POINTS)
            // WILL GET ITS SHARE OF THE WP AT THE END 

                       

            
            uint least = _min(balanceOf(_msgSender()), amt);

            // TODO calculate half for the whole year 
            // if timestamp is over the first start
            // date + 6 months, 1/16 of excess 
            require(_MO[_YEAR].start > block.timestamp,
                "MO::withdraw: takes 1 year for QD to mature, redemption has a time window"
            );
            
            
            uint assets = carry.credit + // idle work
            work.short.debit + work.long.debit + // work is carry loaned out 
            _ratio(price, wind.debit, ONE) + // ETH owned by pledges pro rata
            _ratio(price, carry.debit, ONE); // ETH owned by specific pledges



            // 1/16th or 1/8th 
            uint liabilities = wind.credit + // QDebt from !MO 
            _ratio(price, work.long.credit, ONE) + // synthetic ETH collat
            _ratio(price, work.short.credit, ONE);  // synthetic ETH debt
            
            // TODO to dissolvency (WP into SP)
            
            // dilute the value of the eth
            if (liabilities > assets) {

            } else { // dilute the value of $

            }
            // frequency and wavelength, half of liquidations stay til the next MO?
            
            carry.credit -= least; _burn(_msgSender(), amt); 
            sdai.transferFrom(address(this), _msgSender(), amt);
        }
    }

    // "honey won’t you break some bread, just let it crack" ~ Rapture, by Robert 
    function mint(uint amount, address beneficiary) external returns (uint cost) {
        require(beneficiary != address(0), "MO::mint: can't mint to the zero address");
        require(block.timestamp >= _MO[_YEAR].start, 
        "MO::mint: can't mint before start date"); 
        // TODO allow roll over QD value in sDAI from last !MO into new !MO...
        if (block.timestamp >= _MO[_YEAR].start + LENT + 144 weeks) { // 6 months
            if (_MO[_YEAR].minted >= TARGET) { // _MO[_YEAR].locked * MO_FEE / ONE
                sdai.transferFrom(address(this), lock, 1477741 * ONE); // ^  
                _MO[_YEAR].locked = 272222222 * ONE; // minus 0.54% of sDAI
            }   _YEAR += 1; // "same level, the same
            //  rebel that never settled" in _get_owe()
            require(_YEAR <= 16, "MO::mint: already had our final !MO");
            _MO[_YEAR].start = block.timestamp + LENT; // in the next !MO
        } else if (_YEAR < 16) { // forte vento, LENT gives time to update
            require(amount >= RACK, "MO::mint: below minimum mint amount"); 
            uint in_days = ((block.timestamp - _MO[_YEAR].start) / 1 days) + 1; 
            require(in_days < 47, "MO::mint: current !MO is over"); 
            cost = (in_days * CENT + START_PRICE) * (amount / ONE);
            uint supply_cap = in_days * MAX_PER_DAY + totalSupply();
            if (Pledges[beneficiary].last == 0) { // init. pledge
                Pledges[beneficiary].last = block.timestamp;
                _approve(beneficiary, address(this),
                          type(uint256).max - 1);
            }
            _MO[_YEAR].locked += cost; _MO[_YEAR].minted += amount;
            wind.credit += amount; // the debt associated with QD
            // balances belongs to everyone, not to any individual;
            // amount gets decremented by APR payments made in QD
            uint cut = MO_CUT * amount / ONE; // 0.22% 777,742 QD
            _immature[beneficiary].credit += amount - cut; // QD
            _mint(lock, cut); carry.credit += cost; // SP sDAI
            emit Minted(beneficiary, cost, amount); // in this
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
        Pledge memory pledge = _get_pledge( //  
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
        if (!short) { max *= longMedian.apr; eth += msg.value; // WP
            // we are crediting the pledge's long with virtual credit 
            // in units of ETH (its sDAI value is owed back to the SP) 
            pledge.work.long.credit += eth; work.long.credit += eth;
            // deposit() of QD to this LP side reduces credit value
            // we debited (in sDAI) by drawing from SP and recording 
            // the total value debited, and value of the ETH credit
            // will determine the P&L of the position in the future
            pledge.work.long.debit += amount; carry.credit -= amount;
            // incrementing a liability...LP...decrementing an asset^
            work.long.debit += amount; wind.debit += msg.value; 
            // essentially debit is the collat backing the credit
            debit = pledge.work.long.debit; credit = pledge.work.long.credit;
        } else { max *= shortMedian.apr; // see above for explanation
            pledge.work.short.credit += eth; work.short.credit += eth;
            // deposit() of QD to this LP side reduces debits owed that
            // we debited (in sDAI) by drawing from SP and recording it
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
