## UNISWAP-ARBITRUM GRANT PROGRAM (UAGP)

**Request for Proposal (RFP)**: New Protocols   
for Liquidity Management and *"Derivatives"*


**Proposer**: QuidMint Foundation  
**Requested divison**: 76 000 ARB  
**Payment Address**: `quid.eth`  
which collects 0.76% x 16 [MO](https://github.com/QuidLabs/iMO/blob/main/contracts/MO.sol#L45)  
pegs seed valuation at $16M  

 
Quid Labs' public key ends  
with 4A4, so we built [gilts](https://www.youtube.com/clip/UgkxUlE5S5Ogc0ipmxJ2eFR_KNourTd28q1i),   
a simplified ERC404: took  
out the zero, put A. "Secret  
to  survivin'...is knowin' what  
to throw 🏀 & knowin' what    
to keep" on [commodifying](https://twitter.com/QuidMint/status/1788041764282020033):

  - **Maintenance:** 42000 USD
    - Solidity [audit](https://www.youtube.com/watch?v=9uOvSdNQePs) + general  
    counsel [retainer](https://twitter.com/lex_node/status/1760701615424630848): 30k  
    [Cayman](https://arbiscan.io/tx/0x5e4b70fad2039257bfe742d42a0fe085525351b99f1f979c424ddf93a60c882a): 12k + late fees
  - **R&D Costs:** 34000 USD
    - **Full-Time Equivalent (FTE)**: 2 x 2 months
      - Senior frontend developer
      - Senior backend developer 


### Project Overview:

[Derivatives](https://twitter.com/lex_node/status/1740509787690086847) derive their value from an underlying asset. Our certicificate of deposite (CD) is  
a [Capital Deepening](https://www.wallstreetmojo.com/capital-deepening/) token (QD) deriving value from 


### Use of funds, milestones, and goals (KPIs):

- Mainnet Launch: June 1st...  
- Arbitrum Launch: June 27th
- User Adoption: 357M QD in    
 Q2
(same minted within Q4)  
  544M sDAI locked for 2024...  
as reach goal (minimum [54M](https://twitter.com/WethWood/status/1786389167292772697))
  
- Contract Interaction: Facilitate at least  
  1000 `Plunge` positions, which, instead  
  of importing liquidity step-wise as we're     
  used to with [CDPs](https://twitter.com/zellic_io/status/1688666477552193536), implement wholesale  
  incentivisastion program, that benefits 
- Partnerships: Milestone 2 and onwards




### Milestone 1:

To arrive at its current level simplicity, Quid Labs had to rebuild its protocol 3 times over the last 3 years;  
latest implementation is just over 800 lines. The majority of the work for this milestone will be devoted to  
 testing this implementation, while also extending  `frontend` functionality. We have Lot.sol dedicated to  
  Uniswap, incentivising V3 deposits with QD<>FOLD to give LPs MEV-protected fair launch assurances...  


| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0a.** | License | GPLv3 Copyleft is the technique of granting freedoms over copies  with  the requirement that the same rights be preserved in *derivative* works. |
| 1. | `call` button | ETH may be freely deposited and withdrawn, meanwhile used to boost pledges. QD redemption (for sDAI) has rules based on when the minted.  |
| 2. | Vertical fader | All the way down by default, there should be one input slider for the magnitude of either long leverage, or short (and a toggle to switch between the two. Touching the toggle automatically triggers 2xAPR.|
| 3a. | Cross-fader for balance | This slider will represent how much of the user’s total QD is deposited in `work`, and the % in `carry` (by default 100% balance left in `carry`). |
| 3b. | Cross-faders for voting | Shorts and longs are treated as separate risk budgets, so there is one APR target for each (combining them could be a worthy experiment, definitely better UX, though not necessarily optimal from an analytical standpoint). [Median](https://github.com/QuidLabs/iMO/blob/main/contracts/MO.sol#L35) APR (for long or short) is 8-21%...up to 3x [surge pricing](https://twitter.com/hexonaut/status/1746617244002517144). |
| 4. | Basic Metrics |  Provide a side by side comparison of key metrics: aggregated for all users, and from the perspective of the authenticated user (who’s currently logged in, e.g. individual risk-adjusted returns); see most recently liquidated (sorted by time or size); top `owe` by P&L. |
| 5. | Simulation [Metrics](https://orus.info/) | Future projections for the output of the `call` function, variable inputs being: the extent to which `work` is leveraged relative to `carry` at the time of function `_call`; % of  profitable `fold` over last SEMESTER.  |

### Milestone 2:
  
Potentially, all the sDAI that gets locked in PCV can be deployed as single-sided liquidity in a pool with  
 sDAI and ETH. We may extend our medianiser to vote (for % of sDAI to lock in other [AMMs](https://twitter.com/futurenomics/status/1766187064444309984)) or in UNI,  
but it's seen as V2 feature (given enough interest).  Also as part of the 1st milestone , `yo.quid.io`  
 will be the first external operator (QU!D Ltd in BVI) running `frontend` as a stand-a-loan web app  
for the protocol (currently just allows minting,
and seeing basic stats for current MO e.g. P&L...etc).  

| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0.** | License GPLv3 | Copyleft (same as previous milestone’s…of the public, by the public, for the public). We provide both code comments and instructions for running the code, and sanity checking runtimes. |
| 1. | NFT [marketplaces](http://polyone.io) + Fiat [off-ramps](https://www.flashy.cash/) + deployment | Enable payment with QD (for preferential pricing of NFTs such as ERC404 or REIT baskets) as a well as other bonuses. Providing real-world utility for our token (beyond crypto trading) is further possible through trusted partners for bridging into cash markets and fiat. |
| 2. | Event Watcher (a.k.a. Catcher in the ~~rye~~ [rights](https://en.wikipedia.org/wiki/Perfection_(law))) | Publish code that reads the blockchain for opportunities to obtain perfection rights, so anyone can run `clocked`. Later, this code could be potentially integrated with ZigZag off-chain order matcher for purchasing liqudiated collateral, valued by `clutch`ed (depleting 2% per day). |
| 3. | [Twitter spaces](https://t.ly/B7pin) | Demonstrate the extent of readiness of the frontend by interacting with all protocol functions (minting is the only thing that may be done for the first 46 days after deloyment of MO.sol). |
| 4. | Multi-collat | CCIP will enable re-using the same QD tokens across deployments of the core protocol (MO) on multiple EVMs (each having their own domain-specific plugins, such as cNOTE on CANTO). |
| 5. |  Profile Preferences | Advancing on frontend progress from milestone 1, users should have the ability to pull insights into their  should include push notifications based on more data feeds (to better inform trading decisions). Over-bought / over-sold signaling involves [handful of TA indicators](https://github.com/QuidLabs/bnbot/blob/main/Bot.py#L366). |

