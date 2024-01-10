// SPDX-License-Identifier: MIT
pragma solidity 0.8.8; 
// pragma experimental SMTChecker;

/**
  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
  USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

interface ICollection is IERC721 {
    function latestTokenId() external view returns (uint256);
}

contract QD is Ownable, ERC20, ReentrancyGuard {
    using SafeERC20 for ERC20;
    uint public sale_start;
    uint public _VERSION;
    
    struct Raise {
        Outcome res;
        uint target;
        uint minted;
        uint raised;
    }
    uint constant public START_PRICE = 44 * PRECISION / 100; 
    uint constant public MAX_QD_PER_DAY = 7_777_777 * PRECISION; 
    uint constant public DELTA = 101_010_000_000_000_00; // .101010 42 base 2
    uint constant public SLICE = 1_111_111 * PRECISION; // 11 🍕 per raise
    uint constant public SALE_LENGTH = 54 days;
    uint constant internal _USDT_DECIMALS = 6;
    uint constant public PRECISION = 1e18;

    address constant public QUID_ETH = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4;
    address constant public F8N = 0x13B09CBc96aA378A04D4AFfBdF2116cEab14056b;
    
    // twitter.com/Ukraine/status/1497594592438497282
    address constant public UA = 0x165CD37b4C644C2921454429E7F9358d18A45e14;
    address immutable public tether; // never changes

    mapping (uint => address) public redeemed;
    mapping (uint => Raise) private _raises;
    
    mapping (uint => mapping(address => uint)) private _spent;
    mapping (uint => mapping(address => uint)) private _qd;

    event Withdraw (address indexed reciever, uint amt_usd, uint qd_amt); // TODO
    event Mint (address indexed reciever, uint cost_in_usd, uint qd_amt);
    enum Outcome { Ongoing, Success, TryAgain }

    constructor(address _usdt, bool _big) ERC20("QU!D", "QD") {
        _VERSION = 1; // TODO not zero for a sepcific reason 
        _mint(QUID_ETH, SLICE * 3); // 2 paid for, 1: grants
        _raises[1].res = Outcome.Ongoing; // we'll see 🤞
        _raises[1].target = _big ? 427_777_777_000_000 :  42_777_777_000_000; 
        sale_start = 1707920054; // Feb 14 '24 14:14:14 GMT
        tether = _usdt;
    }

    function withdraw() external nonReentrant {
        if (_msgSender() == QUID_ETH) { // exception for normal execution
            
        }
        if (block.timestamp > sale_start + SALE_LENGTH) {
            if (_raises[_VERSION].res == Outcome.Ongoing) {
                if ( _raises[_VERSION].raised > _raises[_VERSION].target) {  
                    ERC20(tether).safeTransfer(owner(), _raises[_VERSION].raised); 
                    _raises[_VERSION].res = Outcome.Success; 
                } 
                else { 
                    _raises[_VERSION].res = Outcome.TryAgain;
                }
            }
        }
        uint total_refund; uint total_mint;
        for (uint i = 1; i <= _VERSION; i++) { // how many raises we will ever have 
            if (_raises[i].res == Outcome.Success) { // land the rebates
                uint amount = _qd[i][_msgSender()];
                if (amount > 0) {
                    total_mint += amount;
                    _raises[i].minted -= amount; // for sanity, revert if neg
                    delete(_qd[i][_msgSender()]);
                }
                uint spent = _spent[i][_msgSender()];
                if (spent > 0) {
                    delete(_spent[i][_msgSender()]);
                }
            } 
            else if (_raises[i].res == Outcome.TryAgain) {
                uint refund = _spent[i][_msgSender()];
                if (refund > 0) {
                    total_refund += refund;
                    _raises[i].raised -= refund; // another sanity check
                    delete(_spent[i][_msgSender()]);
                }
                uint amount = _qd[i][_msgSender()];
                if (amount > 0) {
                    delete(_qd[i][_msgSender()]);
                }
            }
        }
        // USDT doesn't return "bool" in functions approve(), transfer(), and transferFrom() which makes it incompatible with ERC20 interfaces... 
        // Solidity reverts if the expected non-empty returndata happens to be empty (low-level calls and safeTransfer libraries skip the check).
        if (total_refund > 0) {
            ERC20(tether).safeTransfer(_msgSender(), total_refund);
        }
        if (total_mint > 0) {
            _mint(_msgSender(), total_mint); 
            // TODO add 11% QD to 
        }
    }

    function mint(uint qd_amt, address beneficiary) external nonReentrant 
        returns (uint cost, uint paid, uint aid) {

        if (qd_amt == SLICE) {
            qd_amt = 0;

            if (_msgSender() == QUID_ETH) { // the Superintendent 
                if (_raises[_VERSION].res != Outcome.Ongoing) { 
                    _VERSION += 1; 
                    _raises[_VERSION].res = Outcome.Ongoing;
                    sale_start = block.timestamp;
                }
                if (_raises[_VERSION].res == Outcome.Success) {
                    // TODO buyback unnecessary
                    /**
                    cost = 466_666 * 10 ** _USDT_DECIMALS; // call pops on money phone
                    ERC20(tether).safeTransferFrom(_msgSender(), address(this), cost);
                    _spent[_VERSION][QUID_ETH] += cost;
                    _raises[_VERSION].raised += cost;
                    qd_amt = SLICE;
                    */
                }
            } 
            else if (beneficiary != QUID_ETH) {

                /**
                uint latest = ICollection(F8N).latestTokenId(); 
                for (uint i = 1; i <= latest; i++) {
                    if (beneficiary == ICollection(F8N).ownerOf(i)) {
                        if (redeemed[i] == address(0)) {
                            redeemed[i] = beneficiary;
                            qd_amt += SLICE;
                        }
                    }
                }
                */
            }
            // TODO ratchet to make sure there's not more than 11 per raise
            _mint(beneficiary, qd_amt); 
        } 
        else {
            require(block.timestamp >= sale_start, "QD: MINT_R2");
            require(beneficiary != address(0), "ERC20: mint to the zero address");
            
            // uint min = _big ? 1000 : 100;
            uint remainder = qd_amt % 1000 == 0;

            require(qd_amt >= 1_000_000_000_000_000_000_000, "QD: MINT_R1"); // TODO % 1k
            require(get_total_supply_cap(block.timestamp) >= qd_amt, "QD: MINT_R3"); // supply cap for minting

            cost = qd_amt_to_usdt_amt(qd_amt, block.timestamp);
            aid = cost * 11 / 100; // 🇺🇦,🇺🇦
            paid = cost - aid;

            ERC20(tether).safeTransferFrom(_msgSender(), address(this), cost);
            // Tether requires an allowance to be reset before setting a new one. 
            // Can't just change it from 10 to 5. You have to do 10 -> 0 -> 5 = 2 transactions. 
            // We handle this in the frontend https://github.com/QuidMint/ibo-app/blob/main/components/Mint/Mint.tsx#L241

            ERC20(tether).safeTransfer(UA, aid); // must happen after above
                
            _raises[_VERSION].minted += qd_amt;
            _raises[_VERSION].raised += paid;

            _qd[_VERSION][beneficiary] += qd_amt;
            _spent[_VERSION][_msgSender()] += paid;
        }
        if (qd_amt > 0) {
            emit Mint(beneficiary, cost, qd_amt);
            emit Transfer(address(0), beneficiary, qd_amt);
        }
    }

    function get_total_supply_cap(uint block_timestamp) public view returns (uint total_supply_cap) {
        uint in_days = ((block_timestamp - sale_start) / 1 days) + 1; // +1 covers off by one due to rounding
        uint max = _raises[_VERSION].target > 42_777_777_000_000 ? 7_777_777 : 777_777;
        total_supply_cap = in_days * max * PRECISION;
        if (block_timestamp <= sale_start + SALE_LENGTH) {
            return total_supply_cap - _raises[_VERSION].minted;
        }   return 0;
    }
    function qd_amt_to_usdt_amt(uint qd_amt, uint block_timestamp) public view returns (uint usdt_amount) {
        uint price = (qd_amt / PRECISION) * calculate_price(block_timestamp);
        usdt_amount = (price * 10 ** _USDT_DECIMALS) / PRECISION ;
    }
    function calculate_price( uint block_timestamp) public view returns (uint price) {
        uint in_days = ((block_timestamp - sale_start) / 1 days) + 1;
        price = in_days * DELTA + START_PRICE;
    }

    function balanceOf(address account, uint version) public view returns (uint256) {
        uint balance;
        for (uint i = 1; i <= _VERSION; i++) {
            if (_raises[i].res != Outcome.TryAgain) {
                balance += _qd[i][account];
            }
        }
        return balance + balanceOf(account);
    }
    function totalSupply(uint version) public view returns (uint256) {
        uint minted;
        for (uint i = 1; i <= _VERSION; i++) {
            if (_raises[i].res != Outcome.TryAgain) {
                minted += _raises[i].minted;
            }
        }
        return minted + totalSupply();
    }
}
