
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity =0.8.8; 
// pragma experimental SMTChecker;
import "hardhat/console.sol"; // TODO comment out
import "./Dependencies/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MO is ERC20 { 
    IERC20 public sdai; address public lotok; // multi-purpose contract (OpEx)
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
    event Long (address indexed owner, address indexed caller, uint fee); 
    event Short (address indexed owner, address indexed caller, uint fee);
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
    Offering[16] public _MO; // one !MO per 6 months
    struct Offering { // 8 years x 544,444,444 sDAI
        uint start; // date 
        uint locked; // sDAI
        uint minted; // QD
        uint burned; // ^
        address[] d; // liquidated
    }
    uint public YEAR; // actually half a year, every 6 months...
    uint internal _PRICE; // TODO comment out when finish testing
    uint internal _POINTS; // used in call() weights (medianiser)
    struct Pod { // used in Pools (incl. individual Plunges')
        uint credit; 
        uint debit; 
        // credit used for fee voting; debit for fee charging
    } 
    struct Owe { uint points; // time-weighted _balances  
        Pod long; // debit = last timestamp of long APR payment...
        Pod short; // debit = last timestamp of short APR payment...
        // IDK how Nik wrote mom.sol, but Pac wrote Dear Mama while 
        bool deuce; // pay...✌🏻xAPR for peace of mine, and flip debt
        bool grace; // ditto ^^^^^ pro-rated _call but no ^^^^ ^^^^ 
    } // deuce almighty and grace are characters 
    struct Pool { Pod long; Pod short; } // work
    /* Quote from a movie called...The Prestige
        The first part is called "The Plunge"... 
        The imagineer shows you something ordinary: 
        to see if it's...indeed un-altered, normal 
    */ 
    struct Plunge { // pledging to plunge into work
        uint last; // timestamp of last state update
        Pool work; // debt and collat (long OR short)
        Pod carry; // QD bonus CREDIT, DEBITable ETH
        Owe dues; // all kinds of utility variables
    }   mapping (address => Plunge) Plunges; 
    Pod internal wind; Pool internal work; 
    Pod internal carry; // cost of carry
    
    // youtu.be/gQyV1wbPJXA?si=MvuPEnmFXnaRcvIB read offering
    constructor(address _lotok, address _price) ERC20("QU!Dao", "QD") { 
        _MO[0].start = 1719444444; lotok = _lotok; // MOlotock
        require(_msgSender() == QUID, "MO: wrong deployer");
        feeTargets = [MIN_APR, 85000000000000000,  90000000000000000,
           95000000000000000, 100000000000000000, 105000000000000000,
          110000000000000000, 115000000000000000, 120000000000000000,
          125000000000000000, 130000000000000000, 135000000000000000,
          140000000000000000, 145000000000000000, 150000000000000000,
          155000000000000000, 160000000000000000, 165000000000000000,
          170000000000000000, 175000000000000000, 180000000000000000,
          185000000000000000, 190000000000000000, 195000000000000000,
          200000000000000000, 205000000000000000, 210000000000000000];
        chainlink = AggregatorV3Interface(_price);
        uint[27] memory blank; sdai = IERC20(SDAI);
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
        Plunge memory plunge = _get_update( 
            _msgSender(), price, false, _msgSender()
        ); _send(_msgSender(), recipient, amount); return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        uint price = _get_price();
        _spendAllowance(from, _msgSender(), value);
        Plunge memory plunge = _get_update( 
            _msgSender(), price, false, _msgSender()
        );  _send(from, to, value); return true;
    }

    // in _call, the ground you stand on balances you...what balances the ground?
    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) + _maturing[account].debit +  _maturing[account].credit;
        // matured QD ^^^^^^^ in the process of maturing as ^^^^ and just starting to mature
    }

    function liquidated(uint when) public view returns (address[] memory) {
        return _MO[when].d;
    }

    function _ratio(uint _multiplier, uint _numerator, uint _denominator) internal pure returns (uint ratio) {
        if (_denominator > 0) {
            ratio = _multiplier * _numerator / _denominator;
        } else { // if  Plunge has a debt of 0: "infinite" CR
            ratio = type(uint256).max - 1; 
        }
    }

    // calculates CR (value of collat / value of debt)...if you look a little pale, might creditch a cold
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
        uint delta;
        if (value > balanceOf(from)) { 
            delta = value - balanceOf(from);
            value -= delta; 
            _maturing[from].credit -= delta; 
            if (to != address(this)) { 
                _maturing[to].credit += delta; 
            } else { _burn(from, delta); 
                     _mint(address(this), delta);
            } // we never transfer QD back from
            // (this) to plunge, so safe to mix
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

    // ------------ OPTIONAL -----------------
    // voting can allow LTV to act as moneyness,
    // but while DSR is high this is unnecessary  

    // 
    
    function _get_owe(uint param) internal { // used in 3 places
        
        // using APR / into MIN = scale
        // if you over-collat by 8% x scale
        // then you get a discount from APR
        // that is exactly proportional...
        // means we do have to add it in _call

        uint excess = YEAR * TARGET; // excess wind.credit
        if (wind.credit > excess) {

        } else {

        }
    }   // "so listen this is how I shed my tears (crying down coins)
    // ...a [_get_owe work] is the law that we live by" ~ Legal Money

    function _get_update(address addr, uint price, bool must_exist, address caller) 
        internal returns (Plunge memory plunge) { plunge = Plunges[addr]; require(
            !must_exist || plunge.last != 0, "MO: plunge must exist"); 
        bool clocked = false; uint old_points; uint grace; uint time;
        if ((YEAR % 2 == 1) && (_maturing[addr].credit > 0)) {
            
            // TODO can't be a require must be an if 
             // FIXME call from temporary balances if current MO failed ??
            require(block.timestamp >= _MO[0].start + LENT &&
                _MO[0].minted >= TARGET, "MO::get: early"); 
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
        if (plunge.last != 0) { Pod memory _carry = plunge.carry; 
            old_points = plunge.dues.points; _POINTS -= old_points;
            time = plunge.dues.long.debit > block.timestamp ? 0 : 
                        block.timestamp - plunge.dues.long.debit; 
            // wait oh wait oh wait oh wait oh wait oh wait oh wait...oh
            uint fee = caller == addr ? 0 : MIN_APR / 100; // liquidator
            uint in_carry = balanceOf(_msgSender()) + _carry.credit +
                                      _ratio(price, _carry.debit, ONE); 
            if (plunge.work.long.debit > 0) { // owes carried interest
                Pod memory _work = plunge.work.long;
                if (plunge.dues.long.debit == 0) { in_carry = 0; // TODO?
                    plunge.dues.long.debit = block.timestamp;
                }   if (plunge.dues.deuce) { grace = 1; 
                    if (plunge.dues.grace) { // 15% per 6 months
                        grace = fee * plunge.dues.long.debit;
                    } 
                }   (_work, _carry, clocked) = _fetch_plunge(addr, 
                            _carry, _work, price, time, grace, false
                ); 
                if (clocked) { fee *= _work.debit / ONE;
                    if (grace == 0) { // TODO check size at least 50k
                        _MO[YEAR].d.push(addr);  
                    }
                    else if (grace == 1) {
                        // carry.credit += fee; TODO??
                        if (fee > 0) { _work.debit -= fee; } 
                        work.short.debit += _work.debit;
                        work.short.credit += _work.credit;
                        plunge.work.short.debit = _work.debit;
                        plunge.work.short.credit = _work.credit;
                        plunge.dues.short.debit = block.timestamp + 96 hours; // TODO too much?
                    }   else if (fee > 0) { carry.credit -= fee; 
                        emit Long(addr, caller, fee);
                    }   plunge.work.long.credit = 0;
                        plunge.work.long.debit = 0;
                        plunge.dues.long.debit = 0; 
                } else { plunge.work.long.debit = _work.debit; 
                        plunge.work.long.credit = _work.credit;
                        // only update timestamp if charged otherwise can
                        // keep resetting timestamp before 10 minutes pass
                        // and never get charged APR at all (costs gas tho)
                        if (in_carry > balanceOf(_msgSender()) + _carry.credit +
                                                 _ratio(price, _carry.debit, ONE)) {
                                                 plunge.dues.long.debit = block.timestamp; } 
                }   plunge.carry = _carry; if (fee > 0) { Plunges[caller].carry.credit += fee; }
            } // plunges should never be short AND a long at the same time
            else if (plunge.work.short.debit > 0) { // that's why ELSE if
                Pod memory _work = plunge.work.short;
                time = plunge.dues.short.debit > block.timestamp ? 
                    0 : block.timestamp - plunge.dues.short.debit; 
                if (plunge.dues.short.debit == 0) { // edge case
                    plunge.dues.short.debit = block.timestamp;
                }   if (plunge.dues.deuce) { grace = 1;
                    if (plunge.dues.grace) {  // 15% per 6 months
                        grace = fee * plunge.dues.short.debit;
                    }
                }   (_work, _carry, clocked) = _fetch_plunge(addr, 
                            _carry, _work, price, time, grace, true
                );
                if (clocked) { fee *= _work.debit / ONE;
                    if (grace == 0) { // TODO check size at least 50k
                        _MO[YEAR].d.push(addr);
                    }
                    else if (grace == 1) { 
                        if (fee > 0) { _work.debit += fee; }
                        work.long.credit += _work.credit;
                        work.long.debit += _work.debit;
                        plunge.work.long.credit = _work.credit;
                        plunge.work.long.debit = _work.debit;
                        plunge.dues.long.debit = block.timestamp + 96 hours; // TODO too much?
                    }   if (fee > 0) { carry.credit -= fee; 
                        emit Short(addr, caller, fee);
                    }   plunge.work.short.credit = 0;
                        plunge.work.short.debit = 0;
                        plunge.dues.short.debit = 0; 
                } else { 
                    plunge.work.short.credit = _work.credit;
                    plunge.work.short.debit = _work.debit;
                    if (in_carry > balanceOf(_msgSender()) + _carry.credit +
                                             _ratio(price, _carry.debit, ONE)) {
                        plunge.dues.short.debit = block.timestamp; 
                    }   plunge.dues.short.debit = block.timestamp;
                }   plunge.carry = _carry;
                if (fee > 0) {
                    Plunges[caller].carry.credit += fee;
                }
            }
            if (balanceOf(addr) > 0) { // TODO default vote not counted
                // TODO simplify based on !MO
                plunge.dues.points += ( // 
                    ((block.timestamp - plunge.last) / 1 hours) 
                    * (balanceOf(addr) + plunge.carry.credit) / ONE
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
        }   plunge.last = block.timestamp; // TODO check
    }

    // deuce is a semaphor: 0 = false, 1 = just deuce, if grace > 1 deuce true
    function _fetch_plunge(address addr, Pod memory _carry, Pod memory _work, 
        uint price, uint delta, uint deuce, bool short) internal 
        returns (Pod memory, Pod memory, bool clocked) {
        // "though eight is not enough...no,
        // it's like [deuce lest you] bust: 
        // now your whole [plunge] is dust" 
        if (delta >= 10 minutes) { // 52704 x 10 mins per year
            uint apr = short ? shortMedian.apr : longMedian.apr; 
            delta /= 10 minutes; uint owe = (deuce > 0) ? 2 : 1; 
            owe *= (apr * _work.debit * delta) / (52704 * ONE);
            delta = _blush(price, _work.credit, _work.debit, short);
            if (delta < ONE) {
                (_work, _carry, clocked) = _call(addr, _work, _carry, 
                                                 deuce, short, price);
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
                    }   if (owe > 0) { // plunge cannot pay APR (delinquent)
                        (_work, _carry, clocked) = _call(addr, 
                         _work, _carry, 0, short, price);
                    } 
                }   
            } 
        }   return (_work, _carry, clocked);
    }
    
    // "Don't get no better than this, you creditch my drift?
    // So close no matter how far, rage be in it like you 
    // couldn’t believe...or work like one could scarcely 
    // imagine...if one isn’t satisfied, indulge the latter
    // ‘neath the halo of a street-lamp...I fold my collar
    // to the cold and damp...know when to hold 'em...know 
    // when to..." 
    function _call(address owner, Pod memory _work, Pod memory _carry, 
                   uint deuce, bool short, uint price) internal 
                   returns (Pod memory, Pod memory, bool folded) {
        uint in_QD = _ratio(price, _work.credit, ONE); // folded = true;
        if (short && in_QD > 0) { // only if plunge owe any debt at all...
            if (_work.debit > in_QD) { // profitable (probably voluntary)
                folded = true;
                _work.debit -= in_QD; // return debited
                carry.credit += in_QD; // amount to carry
                
                // since we canceled all the credit then
                // surplus debit is the plunge's profit
             
                
                // FIXME increase wind.credit...???...as it were,
                // PROFIT CAME AT THE EXPENSE OF carry (everyone):
                
                // throw caution to the wind 
                // wind.credit += plunge.work.short.debit;

                // for creating QD we add QDebt, but this shouldn't
                // make the system more insolvent, no net change to 
                // LTV overall (TVL CR)

            } 
            // in_QD is worth more than _work.debit, price went up...
            else { // "Lightnin' strikes and the court lights get dim"
                if (deuce == 0) { // no grace, and no way to flip debt
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
                } if (folded && deuce == 0) { 
                    carry.credit += _work.debit; 
                } // TODO cover grace
            } if (folded) { 
                if (deuce > 1) { in_QD = _min(deuce, _work.debit);
                    work.short.debit -= in_QD; carry.credit += in_QD;
                    work.short.credit -= _min(_work.credit,
                        _ratio(ONE, in_QD, price)
                    ); folded = false;
                } else { work.short.credit -= _work.credit;
                         work.short.debit -= _work.debit;  
                }  // either deuce state was 0 or zero...
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
                // if this was not credit from actual ETH puted
                // but virtual credit based on sDAI
            } else { 
                if (deuce == 0) { // liquidatable
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
                } if (folded && deuce == 0) { carry.credit += _work.debit; }
            } if (folded) {
                if (deuce > 1) { in_QD = _min(deuce, _work.debit);
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
    // mint...clutch...vote...put...borrow...fold...call.
    // verse 42: mom.sol carries wind to work (quidditas) 
    // "lookin' too hot...simmer down, or soon you'll get" 
    function clocked(address[] memory plunges) external { 
        uint price = _get_price(); // TODO direction doesn't matter, but 
        // an amplitude of price change since the last 10 minutes has to
        // be more than 10%, require this or no point in looping through
        for (uint i = 0; i < plunges.length; i++ ) {
            _get_update(plunges[i], price, true, _msgSender());
        } 
    }

    function clutch(bool grace) external { uint price = _get_price(); 
        Plunge memory plunge = _get_update(_msgSender(), price, true, _msgSender());
        if (grace) { plunge.dues.deuce = true; plunge.dues.grace = true; } else {
            plunge.dues.deuce = !plunge.dues.deuce; plunge.dues.grace = false;
        }   Plunges[_msgSender()] = plunge;
    }

    // a voluntary fold call, internally callable for requisition (involuntary yoga)
    function fold(bool short) external { uint price = _get_price(); // Neo Jiu Jitsu
        Plunge memory plunge = _get_update(_msgSender(), price, true, _msgSender());
        Pod memory _carry = plunge.carry; uint deuce = plunge.dues.deuce ? 1 : 0;
        if (short) { (,_carry,) = _call(_msgSender(), plunge.work.short, 
                                        _carry, deuce, true, price);
            plunge.work.short.credit = 0;
            plunge.work.short.debit = 0;
            plunge.dues.short.debit = 0;
        } else { (,_carry,) = _call(_msgSender(), plunge.work.long,
                                    _carry, deuce, false, price); 
            plunge.work.long.credit = 0;
            plunge.work.long.debit = 0;
            plunge.dues.long.debit = 0;
        }   plunge.carry = _carry; // 🔫
        Plunges[_msgSender()] = plunge; 
    } // function even looks like an F

    // truth is the highest vibration (not love).  
    function vote(uint apr, bool short) external {
        uint delta = MIN_APR / 16; // half a percent
        require(apr >= MIN_APR && apr <= (MIN_APR * 3 - delta * 6)
                && apr % delta == 0, "MO::vote: unacceptable APR");
        uint old_vote; // a vote of confidence gives...credit (credit)
        uint price = _get_price();
        Plunge memory plunge = _get_update(
            _msgSender(), price, true, _msgSender()
        );
        if (short) {
            old_vote = plunge.dues.short.credit;
            plunge.dues.short.credit = apr;
        } else {
            old_vote = plunge.dues.long.credit;
            plunge.dues.long.credit = apr;
        }
        _medianise(plunge.dues.points, apr, plunge.dues.points, old_vote, short);
        Plunges[_msgSender()] = plunge;
    }

    // putting down a deposit changes the moneyness of the option (work.long or work.short)...
    // if _msgSender() is not the beneficiary...first do approve() in frontend to transfer QD
    function put(address beneficiary, uint amount, bool _carry, bool long) external payable {
        uint price = _get_price(); 
        Plunge memory plunge = _get_update(beneficiary, price, false, beneficiary);
        bool two_plunges = _msgSender() != beneficiary; 
        if (!_carry) { uint most;
            _send(_msgSender(), address(this), amount);
            if (long) {
                most = _min(amount, plunge.work.long.debit);
                plunge.work.long.debit -= most;
                work.long.debit -= most;
                amount -= most;
            } else { // we can't decrease the short debit because
                // that would simply decrease profits in fold()
                uint eth = _ratio(ONE, amount, price);
                most = _min(eth, plunge.work.short.credit);
                plunge.work.short.credit -= eth;
                work.short.credit -= eth;
                most = _ratio(price, most, ONE);
                amount -= most;
            }
            // TODO helper function gets rate
            carry.credit += most; // interchanging QD/sDAI consider ratio
            if (amount > 0) { plunge.carry.credit += amount; }
        }
        else if (two_plunges) { _send(_msgSender(), beneficiary, amount); } // TODO sender.carry -= ; receiver.carry
        else { // not two_plunges && not _carry
            require(true, "MO::put: Can't transfer QD from and to the same balance");
        }   Plunges[beneficiary] = plunge;
    } // downpayment 
    // keep track of what came from carry (own funds)
    // so when grace invoked, return what was put()

    // "collect calls to the tip sayin' how ya changed" 
    function call(uint amt, bool qd, bool eth) external { 
        uint most; uint cr; uint price = _get_price();
        Plunge memory plunge = _get_update(
            _msgSender(), price, true, _msgSender());
        if (!qd) { // call only from carry...use escrow() or fold() for work 
            // the work balance is a synthetic (virtual) representation of ETH
            // plunges only care about P&L, which can only be called in QD 
            most = _min(plunge.carry.debit, amt);
            plunge.carry.debit -= most;
            carry.debit -= most;
            // require(address(this).balance > most, "MO::call: deficit ETH");
            payable(_msgSender()).transfer(most); // TODO use WETH to put % in Lock?
        } 
        else if (qd) {         
            // but we must also be able to evict (involuntary fold from profitables)
            // consider that extra minting happens here 
            // in order to satisfy call (in that sense perfection rights are priotised)
            // this automatically ensures that YEAR > 1
            
            // try to burn carry.credit against existing

            require(super.balanceOf(_msgSender()) >= amt, 
                    "MO::call: insufficient QD balance");
            require(amt >= RACK, "MO::call: must be over 1000");
                   
            // POINTS (per plunge are products) sum in total
            // _get_owe(_POINTS);
            // so that plunges that have been around since
            // the beginning don't take the same proportion
            // as recently joined plegdes, which may other-
            // wise have the same stake-based equity in wind
            // so it's a product of the age and stake instead

            // carry.CREDIT OVER TIME (TOTAL POINTS)
            // WILL GET ITS SHARE OF THE WP AT THE END  ??
            // 1/16 * _get_owe_scale 
            // (carry - wind).credit
              
            uint assets = carry.credit + work.short.debit + work.long.debit + 
            _ratio(price, wind.debit, ONE) + _ratio(price, carry.debit, ONE); 

            // TODO collapse work positions back into carry 
            // can only call from what is inside carry

            // 1/16th or 1/8th 
            uint liabilities = wind.credit + // QDebt from !MO 
            _ratio(price, work.long.credit, ONE) + // synthetic ETH collat
            _ratio(price, work.short.credit, ONE);  // synthetic ETH debt
         
            if (liabilities > assets) {

            } else { 
                // carry.credit -= least; _burn(_msgSender(), amt); 
                // sdai.transferFrom(address(this), _msgSender(), amt);
            }      
        }
    }

    // TODO bool qd, this will attempt to draw _max from _balances before sDAI 
    function mint(uint amount, address beneficiary) external returns (uint cost) {
        require(beneficiary != address(0), "MO::mint: can't mint to the zero address");
        require(block.timestamp >= _MO[YEAR].start, 
        "MO::mint: can't mint before start date"); 
        // TODO allow roll over QD value in sDAI from last !MO into new !MO...

        // evict the wei used to store Offering data after 
        // the end of the offering? TODO

        if (block.timestamp >= _MO[YEAR].start + LENT + 144 days) { // 6 months
            if (_MO[YEAR].minted >= TARGET) { // _MO[YEAR].locked * MO_FEE / ONE
                sdai.transferFrom(address(this), lotok, 1477741 * ONE); // ^  
                _MO[YEAR].locked = 272222222 * ONE; // minus 0.54% of sDAI
            }   YEAR += 1; // "same level, the same
            //  rebel that never settled" in _get_owe()
            require(YEAR <= 16, "MO::mint: already had our final !MO");
            _MO[YEAR].start = block.timestamp + LENT; // in the next !MO
        } else if (YEAR < 16) { // forte vento, LENT gives time to _get_update
            require(amount >= RACK, "MO::mint: below minimum mint amount"); 
            uint in_days = ((block.timestamp - _MO[YEAR].start) / 1 days) + 1; 
            require(in_days < 46, "MO::mint: current !MO is over"); 
            cost = (in_days * CENT + START_PRICE) * (amount / ONE);
            uint supply_cap = in_days * MAX_PER_DAY + totalSupply();
            if (Plunges[beneficiary].last == 0) { // init. plunge
                Plunges[beneficiary].last = block.timestamp;
                _approve(beneficiary, address(this),
                          type(uint256).max - 1);
            }
            _MO[YEAR].locked += cost; _MO[YEAR].minted += amount;
            wind.credit += amount; // the debts associated with QD
            // balances belong to everyone, not to any individual;
            // amount decremented by APR payments in QD (or call)
            uint cut = MO_CUT * amount / ONE; // 0.22% 777,742 QD
            _maturing[beneficiary].credit += amount - cut; // QD
            _mint(lotok, cut); carry.credit += cost; 
            emit Minted(beneficiary, cost, amount); 
            require(supply_cap >= wind.credit,
            "MO::mint: supply cap exceeded"); 

            // TODO helper function
            // for how much credit to mint
            // based on target (what was minted before) and what is surplus from fold
            // different input to _get_owe(). fold only credits a carry to the plunge winsin
            
            // wind.credit 
            // TODO add amt to plunge.carry.credit ??
            
            sdai.transferFrom(_msgSender(), address(this), cost); // TODO approve in frontend
            
        }
    }

    function borrow(uint amount, bool short) external payable { // amount is in QD 
        require(block.timestamp >= _MO[0].start + LENT &&
                _MO[0].minted >= TARGET, "MO::escrow: early");    
        // if above fails must call call for sDAI refund ? 
        uint price = _get_price(); uint debit; uint credit; 
        Plunge memory plunge = _get_update(_msgSender(), 
                             price, false, _msgSender());  
        if (short) { 
            require(plunge.work.long.debit == 0 
            && plunge.dues.long.debit == 0, // timestmap
            "MO::escrow: plunge is already long");
        } else { require(plunge.work.short.debit == 0 
            && plunge.dues.short.debit == 0, // timestamp
            "MO::escrow: plunge is already short");
        }
        uint _carry = balanceOf(_msgSender()) + plunge.carry.credit + _ratio(
        price, plunge.carry.debit, ONE); uint old = carry.credit * 85 / 100;
        uint eth = _ratio(ONE, amount, price); // amount of ETH being credited:
        uint max = plunge.dues.deuce ? 2 : 1; // used in require(max escrowable)
        if (!short) { max *= longMedian.apr; eth += msg.value; // wind
            // we are crediting the plunge's long with virtual credit 
            // in units of ETH (its sDAI value is owed back to carry) 
            plunge.work.long.credit += eth; work.long.credit += eth;
            // put() of QD to short work will reduce credit value
            // we debited (in sDAI) by drawing from carry, recording 
            // the total value debited (and value of the ETH credit)
            // will determine the P&L of the position in the future
            plunge.work.long.debit += amount; carry.credit -= amount;
            // increments a liability (work); decrements an asset^
            work.long.debit += amount; wind.debit += msg.value; 
            // essentially debit is the collat backing the credit
            debit = plunge.work.long.debit; credit = plunge.work.long.credit;
        } else { max *= shortMedian.apr; // see above for explanation
            plunge.work.short.credit += eth; work.short.credit += eth;
            // put() of QD to work.sort will reduce debit owed that
            // we debited (in sDAI) by drawing from carry (and recording)
            plunge.work.short.debit += amount; carry.credit -= amount;
            eth = _min(msg.value, plunge.work.short.credit);
            plunge.work.short.credit -= eth; // there's no way
            work.short.credit -= eth; // to burn actual ETH so
            wind.debit += eth; // ETH belongs to all plunges
            eth = msg.value - eth; plunge.carry.debit += eth;
            carry.debit += eth; work.short.debit += amount; 
            
            debit = plunge.work.short.debit; credit = plunge.work.short.credit;
        }   require(old > work.short.credit + work.long.credit, "MO::escrow");
        require(_blush(price, credit, debit, short) >= MIN_CR && // too much...
        (carry.credit / 5 > debit) && _carry > (debit * max * MIN_APR / ONE), 
            "MO::escrow: taking on more leverage than considered healthy"
        ); Plunges[_msgSender()] = plunge; // write to storage last 
    }
}
