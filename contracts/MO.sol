
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.8.8; 
// pragma experimental SMTChecker;
import "hardhat/console.sol"; // TODO comment out
import "./Dependencies/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MO is ERC20 { 
    AggregatorV3Interface public chainlink;
    IERC20 public sdai; address public lot; // multi-purpose (lock/lotto/OpEx)
    address constant public mevETH = 0x24Ae2dA0f361AA4BE46b48EB19C91e02c5e4f27E; 
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant public SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    address constant public QUID = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4;
    mapping(address => Pod) public _maturing; // QD from last 2 !MO...
    uint constant public ONE = 1e18; uint constant public DIGITS = 18;
    uint constant public MAX_PER_DAY = 7_777_777 * ONE; // supply cap
    uint constant public TARGET = 35700 * STACK; // !MO mint target
    uint constant public START_PRICE = 53 * CENT; // .54 actually
    uint constant public LENT = 46 days; // ends on the 47th day
    uint constant public STACK = C_NOTE * 100;
    uint constant public C_NOTE = 100 * ONE; 
    uint constant public RACK = STACK / 10;
    uint constant public CENT = ONE / 100;
    // investment banks underwriting IPOs 
    // take 2-7%...compare this to 0.76%
    uint constant public MO_FEE = 54 * CENT; 
    uint constant public MO_CUT = 22 * CENT; 
    uint constant public MIN_CR = 108080808080808080; 
    // wait oh wait oh wait oh wait oh wait oh wait...
    uint constant public MIN_APR =  8080808080808080;
    uint[27] public feeTargets; struct Medianiser { 
        uint apr; // most recent weighted median fee 
        uint[27] weights; // sum weights for each fee
        uint total; // _POINTS > sum of ALL weights... 
        uint sum_w_k; // sum(weights[0..k]) sum of sums
        uint k; // approximate index of median (+/- 1)
    } Medianiser public longMedian; // between 8-21%
    Medianiser public shortMedian; // 2 distinct fees
    Offering[16] public _MO; // one !MO per 6 months
    struct Offering { // 8 years x 544,444,444 sDAI
        uint start; // date 
        uint locked; // sDAI
        uint minted; // QD
        uint burned; // ^
        address[] own;
    }  uint public SEMESTER; // actually half a year, every 6 months
    uint internal _PRICE; // TODO comment out when finish testing
    uint internal _POINTS; // used in call() weights (medianiser)
    struct Pod { // used in Pools (incl. individual Plunges')
        uint credit; // in wind...this is hamsin (heat wave)
        uint debit; // in wind this is mevETH shares (chilly)
    }  // credit used for fee voting; debit for fee charging
    struct Owe { uint points; // time-weighted _balances of QD 
        Pod long; // debit = last timestamp of long APR payment;
        Pod short; // debit = last timestamp of short APR payment
        bool deux; // pay...✌🏻xAPR for peace of mind, and flip debt
        bool grace; // ditto ^^^^^ pro-rated _call but no ^^^^ ^^^^ 
    } // deux almighty and grace...married options are hard work...  
    struct Pool { Pod long; Pod short; } // work
    /*  The first part is called "The Pledge"... 
        An imagineer shows you something ordinary: 
        to see if it's...indeed un-altered, normal 
    */ Pod internal carry; // cost of carry as we:
    struct Plunge { // pledge to plunge into work...
        uint last; // timestamp of last state update
        Pool work; // debt and collat (long OR short)
        Owe dues; // all kinds of utility variables
        uint eth; // Marvel's (pet) Rock of Eternity
    }   mapping (address => Plunge) Plunges;
    Pod internal wind; Pool internal work; // internally 1 sDAI = 1 QD
    constructor(address _lot, address _price) ERC20("QU!Dao", "QD") { 
        _MO[0].start = 1719444444; lot = _lot; 
        feeTargets = [MIN_APR, 85000000000000000,  90000000000000000,
           95000000000000000, 100000000000000000, 105000000000000000,
          110000000000000000, 115000000000000000, 120000000000000000,
          125000000000000000, 130000000000000000, 135000000000000000,
          140000000000000000, 145000000000000000, 150000000000000000,
          155000000000000000, 160000000000000000, 165000000000000000,
          170000000000000000, 175000000000000000, 180000000000000000,
          185000000000000000, 190000000000000000, 195000000000000000,
          200000000000000000, 205000000000000000, 210000000000000000];
        // CANTO 0x6D882e6d7A04691FCBc5c3697E970597C68ADF39 redstone
        chainlink = AggregatorV3Interface(_price);
        uint[27] memory blank; sdai = IERC20(SDAI);
        longMedian = Medianiser(MIN_APR, blank, 0, 0, 0);
        shortMedian = Medianiser(MIN_APR, blank, 0, 0, 0); 
    }

    event Minted (address indexed reciever, uint amt);
    // Events are emitted, so only when we emit profits
    event Long (address indexed owner, uint amt); 
    event Short (address indexed owner, uint amt);
    event Voted (address indexed voter, uint vote); // only emit when increasing

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
        Plunge memory plunge = _fetch(_msgSender(), 
                 _get_price(), false, _msgSender()
        );  _send(_msgSender(), recipient, amount, true); 
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _spendAllowance(from, _msgSender(), value);
        Plunge memory plunge = _fetch(_msgSender(),  
                 _get_price(), false, _msgSender()
        );  _send(from, to, value, true); 
        return true;
    }

    // in _call, the ground you stand on balances you...what balances the ground?
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) + _maturing[account].debit +  _maturing[account].credit;
        // mature QD ^^^^^^^^^ in the process of maturing as ^^^^^ or starting to mature ^^^^^^
    }

    function liquidated(uint when) public view returns (address[] memory) {
        return _MO[when].own;
    }

    function _ratio(uint _multiplier, uint _numerator, uint _denominator) internal pure returns (uint ratio) {
        if (_denominator > 0) {
            ratio = _multiplier * _numerator / _denominator;
        } else { // if  Plunge has a debt of 0: "infinite" CR
            ratio = type(uint256).max - 1; 
        }
    }

    // calculates CR (value of collat / value of debt)...if you look a little pale, might credshort a cold
    function _blush(uint _price, uint _collat, uint _debt, bool _short) internal pure returns (uint) {   
        if (_short) {
            uint debt_in_QD = _ratio(_price, _debt, ONE); 
            return _ratio(ONE, _collat, debt_in_QD); // collat is in QD
            // we multiply collat first to preserve precision 
        } else {
            return _ratio(_price, _collat, _debt); // debt is in QD
        } 
    }
    
    // _send _it !
    function _it(address from, address to, uint256 value) internal returns (uint) {
        uint delta = _min(_maturing[from].credit, value);
        _maturing[from].credit -= delta; value -= delta;
        if (to != address(this)) { _maturing[to].credit += delta; }
        if (value > 0) {
            delta = _min(_maturing[from].debit, value);
            _maturing[from].debit -= delta; value -= delta;
            if (to != address(this)) { _maturing[to].debit += delta; }
            // else we don't care because address(this) is PCV (static) 
        }   return value; 
    }

    // bool matured indicates priority to use in control flow (to charge) 
    function _send(address from, address to, uint256 value, bool matured) 
        internal { require(from != address(0) && to == address(0), 
                           "MO::send: passed in zero address");
        uint delta;
        if (!matured) {
            delta = _it(from, to, value);
            if (delta > 0) { _transfer(from, to, delta); }
        } else { // fire doesn't erase blood, QD is never burned
            delta = _min(super.balanceOf(from), value);
            _transfer(from, to, delta); value -= delta;
            if (value > 0) {
                require(_it(from, to, value) == 0, 
                "MO::send: insufficient funds");
            } // address(this) will never _send QD
        }   
    }

    /** 
     * Returns the latest price obtained from the Chainlink ETH:USD aggregator 
     * reference contract...https://docs.chain.link/docs/get-the-latest-price
     */

    function _get_price() internal view returns (uint price) {
        if (_PRICE != 0) { return _PRICE; } // TODO comment when done testing
        (, int priceAnswer,, uint timeStamp,) = chainlink.latestRoundData();
        require(timeStamp > 0 && timeStamp <= block.timestamp,
                "MO::price: timestamp is 0, or in future");
        require(priceAnswer >= 0, "MO::price: negative");
        uint8 answerDigits = chainlink.decimals();
        price = uint256(priceAnswer);
        // currently the Aggregator returns an 8-digit precision, but we handle the case of future changes
        if (answerDigits > DIGITS) { price /= 10 ** (answerDigits - DIGITS); }
        else if (answerDigits < DIGITS) { price *= 10 ** (DIGITS - answerDigits); } 
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
    function _medianise(uint new_stake, uint new_vote, 
        uint old_stake, uint old_vote, bool short) internal { 
        uint delta = MIN_APR / 16; // update annual average in Offering TODO
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
        if (!short) { longMedian = data; } 
        else { shortMedian = data; } // fin
    }
    
    // return Plunge after charging APR; if need be...liquidate (preventable)
    function _fetch(address addr, uint price, bool must_exist, address caller) 
        internal returns (Plunge memory plunge) { plunge = Plunges[addr]; 
        require(!must_exist || plunge.last != 0, "MO: plunge must exist");
        bool clocked = false; uint old_points; uint grace; uint time;
        // time window to roll over balances before the start of new MO
        if (block.timestamp < _MO[SEMESTER].start) {
            if (SEMESTER % 2 == 1) { // odd semester
                _maturing[addr].debit += _maturing[addr].credit;
                _maturing[addr].credit = 0;
            } else if (_maturing[addr].debit > 0) { // SEMESTER % 2 == 0 
                // credit from 0 is debit for 2...then for 2 from 4...
                _mint(addr, _maturing[addr].debit); // minting only here...
                _maturing[addr].debit = 0; // no minting in mint() function
                // because freshly minted QD in !MO is still _maturing...
            }
        } old_points = plunge.dues.points; _POINTS -= old_points; 
        // caller may earn a fee for paying gas to update a Plunge
        uint fee = caller == addr ? 0 : MIN_APR / 2000;  // 0.0041 %
        uint _eth = plunge.eth; // carry.debit
        if (plunge.work.short.debit > 0) { 
            Pod memory _work = plunge.work.short; 
            fee *= _work.debit / ONE;
            time = plunge.dues.short.debit > block.timestamp ? 
                0 : block.timestamp - plunge.dues.short.debit; 
            if (plunge.dues.deux) { grace = 1; // used in _call
                if (plunge.dues.grace) { // 144x per day is
                    // (24 hours * 60 minutes) / 10 minutes
                    grace = (MIN_APR / 1000) * _work.debit / ONE; // 1.15% per day
                    grace += fee; // 0,5% per day for caller
                } 
            }   (_work, _eth, clocked) = _charge(addr,
                 _eth, _work, price, time, grace, true); 
            if (clocked) { // grace == 1 flips the debt
                if (grace == 1) { plunge.dues.short.debit = 0;
                    plunge.work.short.credit = 0;
                    plunge.work.short.debit = 0;
                    plunge.work.long.credit = _work.credit;
                    plunge.work.long.debit = _work.debit;
                    plunge.dues.long.debit = block.timestamp + 1 days; 
                }   else if (grace > 1) { // slow drip option
                    plunge.dues.short.debit = block.timestamp; 
                }   else { plunge.dues.short.debit = 0; }
            } else { plunge.dues.short.debit = block.timestamp; }   
            plunge.work.short = _work; 
        }   
        else if (plunge.work.long.debit > 0) {
            Pod memory _work = plunge.work.long;
            fee *= _work.debit / ONE; // liquidator's fee for gas
            time = plunge.dues.long.debit > block.timestamp ? 
                0 : block.timestamp - plunge.dues.long.debit; 
            if (plunge.dues.deux) { grace = 1; // used in _call
                if (plunge.dues.grace) { // 144x per day is
                    // (24 hours * 60 minutes) / 10 minutes
                    grace = (MIN_APR / 1000) * _work.debit / ONE; // 1.15% per day
                    grace += fee; // 0,5% per day for caller
                } 
            }   (_work, _eth, clocked) = _charge(addr, 
                 _eth, _work, price, time, grace, false); 
            if (clocked) { // festina...lent...eh? make haste
                if (grace == 1) { plunge.dues.long.debit = 0;
                    plunge.work.long.credit = 0;
                    plunge.work.long.debit = 0;
                    plunge.work.short.credit = _work.credit;
                    plunge.work.short.debit = _work.debit;
                    plunge.dues.short.debit = block.timestamp + 1 days;
                    // a grace period is provided for calling put(),
                    // otherwise can get stuck in an infinite loop
                    // of throwing back & forth between directions
                }   else if (grace > 1) { // slow drip option
                    plunge.dues.long.debit = block.timestamp; 
                }   else { plunge.dues.long.debit = 0; }
            } else { plunge.dues.long.debit = block.timestamp; }  
            plunge.work.long = _work;
        } 
        if (fee > 0) { _maturing[caller].credit += fee; }

        if (balanceOf(addr) > 0) { // TODO default vote not counted
            // TODO simplify based on !MO
            plunge.dues.points += ( // 
                ((block.timestamp - plunge.last) / 1 hours) 
                * balanceOf(addr) / ONE
            ); 
            // carry.credit; // is subtracted from 
            // rebalance fee targets (governance)
            if (plunge.dues.long.credit != 0) { 
                _medianise(plunge.dues.points, 
                    plunge.dues.long.credit, old_points, 
                    plunge.dues.long.credit, false
                );
            } if (plunge.dues.short.credit != 0) {
                _medianise(plunge.dues.points, 
                    plunge.dues.short.credit, old_points, 
                    plunge.dues.short.credit, true
                );
            }   _POINTS += plunge.dues.points;
        }   
        plunge.last = block.timestamp; plunge.eth = _eth;
    }

    function _charge(address addr, uint _eth, Pod memory _work, 
        uint price, uint delta, uint grace, bool short) internal 
        returns (Pod memory, uint, bool clocked) {
        // "though eight is not enough...no,
        // it's like [grace lest you] bust: 
        // now your whole [plunge] is dust" ~ Hit 'em High
        if (delta >= 10 minutes) { // 52704 x 10 mins per year
            uint apr = short ? shortMedian.apr : longMedian.apr; 
            delta /= 10 minutes; uint owe = (grace > 0) ? 2 : 1; 
            owe *= (apr * _work.debit * delta) / (52704 * ONE);
            // need to reuse the delta variable (or stack too deep)
            delta = _blush(price, _work.credit, _work.debit, short);
            if (delta < ONE) { // liquidatable potentially
                (_work, _eth, clocked) = _call(addr, _work, _eth, 
                                               grace, short, price);
            }  else { // healthy CR, proceed to charge APR
                // if addr is shorting: indicates a desire
                // to give priority towards getting rid of
                // ETH first, before spending available QD
                grace = _ratio(price, _eth, ONE); // reuse var lest stack too deep
                uint most = short ? _min(grace, owe) : _min(balanceOf(addr), owe);
                if (owe > 0 && most > 0) { 
                    if (short) { owe -= most;
                        most = _ratio(ONE, most, price);
                        _eth -= most; carry.debit -= most;
                        wind.debit += most; 
                        bytes memory payload = abi.encodeWithSignature(
                        "deposit(uint256,address)", most, address(this));
                        (bool success,) = mevETH.call{value: most}(payload); 
                    } else { _send(addr, address(this), most, false);
                        wind.credit -= most; // equivalent of burning QD
                        // carry.credit += most would be a double spend
                        owe -= most;
                    }
                } if (owe > 0) { 
                    // do it backwards from original calculation
                    most = short ? _min(balanceOf(addr), owe) : _min(grace, owe);
                    // if the last if block was a long, grace was untouched
                    if (short && most > 0) { 
                        _send(addr, address(this), most, false);
                        wind.credit -= most; owe -= most;
                    }   
                    else if (!short && most > 0) { owe -= most;
                        most = _ratio(ONE, most, price);
                        _eth -= most; carry.debit -= most;
                        wind.debit += most; 
                        bytes memory payload = abi.encodeWithSignature(
                        "deposit(uint256,address)", most, address(this));
                        (bool success,) = mevETH.call{value: most}(payload); 
                    }   if (owe > 0) { // plunge cannot pay APR (delinquent)
                            (_work, _eth, clocked) = _call(addr, _work, _eth, 
                                                        0, short, price);
                            // zero passed in for grace ^
                            // because...even if the plunge
                            // elected to be treated gracefully
                            // there is an associated cost for it
                        } 
                }   
            } 
        }   return (_work, _eth, clocked);
    }  
    
    // "So close no matter how far, rage be in it like you 
    // couldn’t believe...or work like one could scarcely 
    // imagine...if one isn’t satisfied, indulge the latter
    // ‘neath the halo of a street-lamp...I fold my collar
    // to the cold and damp...know when to hold 'em...know 
    // when to..." 
    function _call(address owner, Pod memory _work, uint _eth, 
                   uint grace, bool short, uint price) internal 
                   returns (Pod memory, uint, bool folded) { 
        uint in_QD = _ratio(price, _work.credit, ONE); uint in_eth;
        require(in_QD > 0, "MO: nothing to _call in"); folded = true;
        if (short) { // plunge into pool (caught the wind on low) 
            if (_work.debit > in_QD) { // value of credit fell
                work.short.debit -= _work.debit; // return what
                carry.credit += _work.debit; // has been debited
                _work.debit -= in_QD; // remainder is profit...
                wind.credit += _work.debit; // associated debt 
                _maturing[owner].credit += _work.debit;
                // _maturing credit takes 1 year to get
                // into _balances (redeemable for sDAI)
                work.short.credit -= _work.credit;
                _work.debit = 0; _work.credit = 0;  
            } // in_QD is worth more than _work.debit, price went up... 
            else { // "lightnin' strikes and the court lights get dim"
                if (grace == 0) { // try to prevent folded from happening
                    uint delta = (in_QD * MIN_CR) / ONE - _work.debit;
                    uint salve = balanceOf(owner) + _ratio(price, _eth, ONE); 
                    if (delta > salve) { delta = in_QD - _work.debit; } 
                    // "It's like inch by inch and step by step...i'm closin'
                    // in on your position and [reconstruction] is my mission"
                    if (salve >= delta) { folded = false; // salvageable...
                        // decrement QD first because ETH is rising
                        in_eth = _ratio(ONE, delta, price);
                        uint most = _min(balanceOf(owner), delta);
                        if (most > 0) { delta -= most;
                            _send(owner, address(this), most, false);
                            // TODO double check re carry.credit or wind.credit
                        } if (delta > 0) { most = _ratio(ONE, delta, price);
                            _eth -= most; wind.debit += most; carry.debit -= most; 
                            bytes memory payload = abi.encodeWithSignature(
                            "deposit(uint256,address)", most, address(this));
                            (bool success,) = mevETH.call{value: most}(payload); 
                            require(success, "MO::mevETH");
                        } _work.credit -= in_eth;
                        work.short.credit -= in_eth;
                    } else { emit Short(owner, _work.debit);
                        carry.credit += _work.debit; 
                        if (_work.debit > 5 * STACK) { 
                            _MO[SEMESTER].own.push(owner); // for Lot.sol
                        }   work.short.debit -= _work.debit;
                            work.short.credit -= _work.credit;
                            _work.credit = 0; _work.debit = 0;
                    }
                }   else if (grace == 1) { // no return to carry
                        work.short.credit -= _work.credit;
                        work.long.credit += _work.credit;
                        work.short.debit -= _work.debit;
                        work.long.debit += _work.debit;
                } else { // partial return to carry
                    _work.debit -= grace; in_eth = _ratio(ONE, grace, price);
                    _work.credit -= in_eth; work.short.credit -= in_eth; 
                    work.short.debit -= grace; carry.credit += grace;
                } 
            }   
        } else { // plunge into leveraged long pool  
            if (in_QD > _work.debit) { // caught the wind (high)
                in_QD -= _work.debit; // profit is remainder
                _maturing[owner].credit += in_QD;
                carry.credit += _work.debit; 
                wind.credit += in_QD; 
                work.long.debit -= _work.debit;
                work.long.credit -= _work.credit;
                _work.debit = 0; _work.credit = 0;                 
            }   else {
                if (grace == 0) {
                    uint delta = (_work.debit * MIN_CR) / ONE - in_QD;
                    uint salve = balanceOf(owner) + _ratio(price, _eth, ONE); 
                    if (delta > salve) { delta = _work.debit - in_QD; } 
                    if (salve >= delta) { folded = false; // salvageable
                        // decrement ETH first because it's falling
                        in_eth = _ratio(ONE, delta, price); 
                        uint most = _min(_eth, in_eth);
                        if (most > 0) { carry.debit -= most; // remove ETH from carry
                            _eth -= most; wind.debit += most; // sell ETH, so 
                            // original ETH is not callable or puttable by the Plunge
                            in_QD = _ratio(price, most, ONE);
                            work.long.debit -= in_QD;
                            _work.debit -= in_QD; delta -= in_QD;
                            bytes memory payload = abi.encodeWithSignature(
                            "deposit(uint256,address)", most, address(this));
                            (bool success,) = mevETH.call{value: most}(payload); 
                            require(success, "MO::mevETH");
                        } if (delta > 0) { _send(owner, address(this), delta, false); 
                            in_eth = _ratio(ONE, delta, price); _work.credit += in_eth;
                            work.long.credit += in_eth;
                        }
                    } // "Don't get no better than this, you catch my drift?"
                    else { emit Long(owner, _work.debit);
                        carry.credit += _work.debit; 
                        if (_work.debit > 5 * STACK) { 
                            _MO[SEMESTER].own.push(owner); // for Lot.sol
                        }   work.long.debit -= _work.debit;
                            work.long.credit -= _work.credit;
                            _work.credit = 0; _work.debit = 0;
                    }
                } else if (grace == 1) { // no return to carry
                    work.long.credit -= _work.credit;
                    work.short.credit += _work.credit;
                    work.long.debit -= _work.debit;
                    work.short.debit += _work.debit;
                } else { // partial return to carry
                    _work.debit -= grace; in_eth = _ratio(ONE, grace, price);
                    _work.credit -= in_eth; work.long.credit -= in_eth; 
                    work.long.debit -= grace; carry.credit += grace;
                }  
            } 
        }   return (_work, _eth, folded);
    }

    /*«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-«-*/
    /*                     EXTERNAL FUNCTIONS                     */
    /*-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»-»*/
    // mint...flip...vote...put...borrow...fold...call...
    // "lookin' too hot...simmer down, or soon you'll get" 
    function clocked(address[] memory plunges) external { 
        uint price = _get_price(); 
        for (uint i = 0; i < plunges.length; i++ ) {
            _fetch(plunges[i], price, true, _msgSender());
        } 
    } 
    
    function flip(bool grace) external { uint price = _get_price();
        Plunge memory plunge = _fetch(_msgSender(), price, true, _msgSender());
        if (grace) { plunge.dues.deux = true; plunge.dues.grace = true; } else {
            plunge.dues.deux = !plunge.dues.deux; plunge.dues.grace = false;
        }   Plunges[_msgSender()] = plunge; // write to storage, we're done
    }

    function fold(bool short) external { 
        Pod memory _work; uint price = _get_price();
        Plunge memory plunge = _fetch(_msgSender(), price,
                                      true, _msgSender());
        if (short) { 
            (_work,,) = _call(_msgSender(), plunge.work.short, 
                              plunge.eth, 0, true, price); 
            plunge.dues.short.debit = 0;
            plunge.work.short = _work; 
        } else { 
            (_work,,) = _call(_msgSender(), plunge.work.long, 
                              plunge.eth, 0, false, price); 
            plunge.dues.long.debit = 0;
            plunge.work.long = _work; 
        }   Plunges[_msgSender()] = plunge; 
    }

    // truth is the highest vibration (not love)
    function vote(uint apr, bool short) external {
        uint delta = MIN_APR / 16; // half a percent 
        require(apr >= MIN_APR && apr <= 
            (MIN_APR * 3 - delta * 6) &&
            apr % delta == 0, "MO::vote");
        uint old_vote; // a vote of confidence gives...credit 
        uint price = _get_price(); Plunge memory plunge = _fetch(
            _msgSender(), price, true, _msgSender()
        );
        if (short) {
            old_vote = plunge.dues.short.credit;
            plunge.dues.short.credit = apr;
        } else {
            old_vote = plunge.dues.long.credit;
            plunge.dues.long.credit = apr;
        }
        _medianise(plunge.dues.points, apr, 
        plunge.dues.points, old_vote, short);
        Plunges[_msgSender()] = plunge;
    }

    function put(address beneficiary, uint amount, bool _eth, bool long)
        external payable { uint price = _get_price(); uint most;
        Plunge memory plunge = _fetch(beneficiary, price,
                                      false, _msgSender());
        if (!_eth) { _send(_msgSender(), address(this), amount, false);
            uint eth = _ratio(ONE, amount, price);
            if (long) { work.long.credit += eth;
                plunge.work.long.credit += eth;
                // TODO decrement carry.credit and wind.credit?
            } else { 
                most = _min(eth, plunge.work.short.credit);
                plunge.work.short.credit -= eth;
                work.short.credit -= eth;
            }  // do nothing with remainder (amount - most)
        }   else { 
            if (!long && plunge.work.short.credit == 0) {
                carry.debit += amount;
                plunge.eth += amount; // deposit (no mevETH)
                // must be withdrawable instantly (own funds)
            }   else { // sell ETH (throw caution to the wind)
                    if (plunge.work.short.credit > 0) { 
                        most = _min(amount, plunge.work.short.credit);
                        require(msg.value + plunge.eth >= most, "MO::put: short");
                        plunge.work.short.credit -= most; work.short.credit -= most;
                        uint delta;
                        if (most > msg.value) { 
                            delta = most - msg.value;
                            carry.debit -= delta;
                            plunge.eth -= delta; 
                        } 
                        else { delta = msg.value - most;
                            plunge.eth += delta;
                            carry.debit += delta; 
                        }
                    } else if (plunge.work.long.credit > 0) { 
                        most = _min(msg.value + plunge.eth, amount);
                        if (most > msg.value) { 
                            uint delta = most - msg.value;
                            carry.debit -= delta;
                            plunge.eth -= delta; 
                        }   plunge.work.long.credit += most;
                    }   bool success; bytes memory payload = abi.encodeWithSignature(
                            "deposit(uint256,address)", most, address(this)
                        );  (success,) = mevETH.call{value: most}(payload); 
                            require(success, "MO::put: mevETH");  
                }
        }   Plunges[beneficiary] = plunge;
    }

    // "collect calls to the tip sayin' how ya changed" 
    function call(uint amt, bool qd, bool eth) external { 
        uint most; uint cr; uint price = _get_price();
        Plunge memory plunge = _fetch(
            _msgSender(), price, true, _msgSender());
        if (!qd) { most = _min(plunge.eth, amt);
            plunge.eth -= most; carry.debit -= most;
            payable(_msgSender()).transfer(most); 
        } 
        else if (qd) { uint debt_minted; // total since start    
            most = _min(super.balanceOf(_msgSender()), amt);
            wind.credit -= most; _burn(_msgSender(), most); 
            for (uint i = 0; i < SEMESTER; i++) {
                debt_minted += _MO[SEMESTER].minted;
            }   uint surplus = wind.credit - debt_minted;
            uint share = plunge.dues.points * surplus / _POINTS;
            uint paying = most - (surplus - share); // dilution
            // so that plunges that have been around since
            // the beginning don't take the same proportion
            // as recently joined plegdes, which may other-
            // wise have the same stake-based equity in wind
            carry.credit -= paying;
            require(carry.credit >= work.long.debit +
                    work.short.debit, "MO::call");
            sdai.transfer(_msgSender(), paying);
        }
    } 

    // TODO bool qd, this will attempt to draw _max from _balances before sDAI...
    function mint(uint amount, address beneficiary) external returns (uint cost) {
        require(beneficiary != address(0) && beneficiary != address(this), "MO::mint");
        require(block.timestamp >= _MO[SEMESTER].start, "MO::mint: before start date"); 
        if (block.timestamp >= _MO[SEMESTER].start) {
            if (block.timestamp <= _MO[SEMESTER].start + LENT) {
                require(amount >= RACK, "MO::mint: 1 rack min"); 
                uint in_days = ((block.timestamp - _MO[SEMESTER].start) / 1 days) + 1; 
                require(in_days < 47, "MO::mint: current !MO is over"); 
                cost = (in_days * CENT + START_PRICE) * amount / ONE;
                Plunges[beneficiary].last = block.timestamp;
                uint supply_cap = in_days * MAX_PER_DAY; 
                _MO[SEMESTER].locked += cost; _MO[SEMESTER].minted += amount;
                wind.credit += amount; // the debts associated with QD
                // balances belong to everyone, not to any individual;
                // amount decremented by APR payments in QD (or call)
                uint cut = MO_CUT * amount / ONE; // .22% = 777742 QD
                _maturing[beneficiary].credit += amount - cut; // QD
                _mint(lot, cut); carry.credit += cost; 
                require(_MO[SEMESTER].minted <= supply_cap, 
                        "MO::mint: supply cap exceeded"); 
                        emit Minted(beneficiary, cut); 
                require(sdai.transferFrom( // TODO approve in frontend
                    _msgSender(), address(this), cost
                ), "MO::mint: sDAI transfer failed");
            } else if (block.timestamp >= _MO[SEMESTER].start + LENT + 144 days) { // 6 months
                uint ratio = _MO[SEMESTER].locked * 100 / _MO[SEMESTER].minted; // % backing
                require(ratio >= 76, "MO::mint: must respect minimum backing");
                _MO[SEMESTER].locked -= _MO[SEMESTER].locked * MO_FEE / ONE;
                uint fee = MO_FEE * amount / ONE; // .54% = 1477741 sDAI
                require(sdai.transferFrom(
                    address(this), lot, fee
                ), "MO::mint: sDAI transfer failed"); // OpEx
                if (SEMESTER < 15) { // "same level...the same 
                    SEMESTER += 1; // rebel that never settled"
                    _MO[SEMESTER].start = block.timestamp + LENT; 
                    // LENT gives time window for _fetch update 
                }
            }
        }
    }

    function borrow(uint amount, bool short) external payable { // amount is in QD 
        require(block.timestamp >= _MO[0].start + LENT &&
                _MO[0].minted >= TARGET, "MO::escrow: early"); // TODO instead of target check 77% backed
        uint price = _get_price(); uint debit; uint credit; 
        Plunge memory plunge = _fetch(_msgSender(), price, 
                                      false, _msgSender()); 
        if (short) { 
            require(plunge.work.long.debit == 0 
            && plunge.dues.long.debit == 0, // timestmap
            "MO::escrow: plunge is already long");
            plunge.dues.short.debit = block.timestamp;
        } else { require(plunge.work.short.debit == 0 
            && plunge.dues.short.debit == 0, // timestamp
            "MO::escrow: plunge is already short");
            plunge.dues.long.debit = block.timestamp;
        }
        uint _carry = balanceOf(_msgSender()) + _ratio(price,
        plunge.eth, ONE); uint eth = _ratio(ONE, amount, price);
        uint max = plunge.dues.deux ? 2 : 1; // used in require
        if (msg.value > 0) { wind.debit += msg.value; // sell ETH
            bytes memory payload = abi.encodeWithSignature(
            "deposit(uint256,address)", most, address(this));
            (bool success,) = mevETH.call{value: most}(payload); 
            require(success, "MO::borrow: mevETH");
        } 
        if (!short) { max *= longMedian.apr; eth += msg.value; // wind
            // we are crediting the position's long with virtual credit 
            // in units of ETH (its sDAI value is owed back to carry) 
            plunge.work.long.credit += eth; work.long.credit += eth;
            plunge.work.long.debit += amount; carry.credit -= amount;
            // increments a liability (work); decrements an asset^
            work.long.debit += amount; // debit is collat backing credit
            debit = plunge.work.long.debit; credit = plunge.work.long.credit;
        } else { max *= shortMedian.apr; eth -= msg.value; carry.credit -= amount;
            plunge.work.short.credit += eth; work.short.credit += eth; 
            plunge.work.short.debit += amount; work.short.debit += amount; 
            debit = plunge.work.short.debit; credit = plunge.work.short.credit;
        }   
        require(_blush(price, credit, debit, short) >= MIN_CR && 
            (carry.credit / 5 > debit) && _carry > (debit * max / ONE), 
            "MO::borrow: taking on more leverage than is healthy"
        ); Plunges[_msgSender()] = plunge; // write to storage last 
    }
}
