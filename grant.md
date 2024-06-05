## UNISWAP-ARBITRUM GRANT PROGRAM 

**Request for Proposal (RFP)**: New Protocols   
for Liquidity Management and *"Derivatives"*

**Proposer**: QuidMint Foundation  
on behalf of Quid Labs (R&D)...

**Requested funds**: 154 000 ARB   
**Payment address**: `quid.eth`  

Quid Labs' public key ends  
with 4A4, so we built [gilts](https://www.youtube.com/clip/UgkxUlE5S5Ogc0ipmxJ2eFR_KNourTd28q1i) as  
a sort of simplified ERC404:   

replaced 0 with A..."the secret  
to survivin'...is knowin' what to   
throw away, and knowin' what    
to keep..." on commodifying...  
bonds on bonds (re-staking)

- **Launch Costs:** 76 000 ARB
  - **Maintenance:** 42000 USD
    - Solidity [audit](https://www.protectorguild.co/) + general  
    counsel retainer: 30 000  
    [Cayman](https://arbiscan.io/tx/0x5e4b70fad2039257bfe742d42a0fe085525351b99f1f979c424ddf93a60c882a): 12k + late fees
  - **R&D Costs:** 34000 USD
    - **Full-Time Equivalent (FTE)**: 1 month
      - Senior React developer
      - Senior Solidity developer 
- **Incentivised launch:** 76 000 ARB
  - Up to 127 `Plunge`s ($600 min.)  
  - Guarantees quality of the audit...


### Project Overview:




Maker & Spark account for 57% of  ETH TVL (incl. LSTs) between all lending markets.    
There is an increasing demand for bringing sDAI to L2; QU!D focuses on Arbitrum...  
[Derivatives](https://twitter.com/lex_node/status/1740509787690086847) derive their value from an underlying asset. Our ~~certicificate of deposit~~...   
[capital deepening](https://www.wallstreetmojo.com/capital-deepening/) token (QD) derives its value from stable collateral used to `mint`;  
It takes 1 year for minted QD tokens to mature, after this they become redeemable.  





### Use of funds, milestones, and goals (KPIs):


- Arbitrum Launch: June 27th
- User Adoption (2024-'25): 357M in  
QD minted for Q2 (same within Q4)  
  
     
- Contract Interaction: facilitate at least  
  1000 `Plunge` positions, which use a   
  wholesale strategy instead of importing  
  liquidity the step-wise [way]((https://twitter.com/zellic_io/status/1688666477552193536)) we're used to 
- Partnerships: Milestone 2 and onwards  
  

### Milestone 1:

QU!D is a decentralized liquidity aggregation protocol built on top of multiple blockchain software stacks...   
(go-to-market version is in Solidity) 
To arrive at its current level simplicity, Quid Labs had to rebuild 3 times,  
latest implementation is just over 1000 lines. The majority of the work for this milestone will be devoted to  
 testing this implementation, while extending  `frontend` functionality to support all 8 contract functions in  
 `Moulinette.sol` which powers the in-house tokenomics, and `Marenate.sol` (integrates UNI and LINK).


| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0.** | License | GPLv3 Copyleft is the technique of granting freedoms over copies  with  the requirement that the same rights be preserved in *derivative* works. |
| 1. | `call` widget | ETH which was deposited into `carry` may be freely  withdrawn. QD redemption (for sDAI at minimum or, potentially, also GHO) has rules based on when QD was minted.  |
| 2. | Vertical fader | All the way down by default, there should be one input slider for the magnitude of either long leverage (or short), and a toggle to switch between the two directions (including a toggle for `flip`: disabling or re-enabling 2x multiplier for APR).|
| 3a. | Cross-fader for balance | This slider will represent how much of the user’s total QD is at risk (deposited in `work`), and the % in `carry` (by default 100% balance left in `carry`). |
| 3b. | Cross-faders for voting | Shorts and longs are treated as separate risk budgets, so there is one APR target for each (combining them could be a worthy experiment, definitely better UX, though not necessarily optimal from an analytical standpoint). [Median](https://github.com/QuidLabs/iMO/blob/main/contracts/Marenate.sol#L91) APR (for long or short) is 12-27% (surge pricing). |
| 4. | Basic Metrics |  Provide a side by side comparison of key metrics: aggregated for all users, and from the perspective of the authenticated user (who’s currently logged in); see most recently liquidated (sorted by time or size); top borrowers by P&L. |
| 5. | Simulation [Metrics](https://orus.info/) | Future projections for the possible outputs of the `call` function, with variable inputs being: the extent to which `work` is leveraged relative to `carry` over time; % of profitable `fold`s over the last SEMESTER (and their magnitude) relative to losses experienced by traders.  |

### Milestone 2:
  
As part of the 1st milestone , `yo.quid.io` will be the first external operator (QU!D Ltd in BVI) running `frontend` as a stand-a-loan web app for the protocol (currently allows minting,
and seeing basic stats).  


| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0.** | License GPLv3 | Copyleft (same as previous milestone’s…of the public, by the public, for the public). We provide both code comments and instructions for running the code. |
| 1. | NFT [marketplaces](http://polyone.io) + Fiat [off-ramps](https://www.flashy.cash/) + deployment | Enable payment with QD on various venues (e.g. for preferential pricing of NFTs). Providing real-world utility for QD  (beyond crypto trading) is further made possible through trusted partners for bridging into fiat. |
| 2. | Event Watcher (a.k.a. catcher in the ~~rye~~ [rights](https://en.wikipedia.org/wiki/Perfection_(law))) | Publish code that reads the blockchain for opportunities to liquidate (obtain perfection rights), so anyone can trigger `clocked`. Later, this code could be potentially integrated with ZigZag's off-chain order matcher for taking liquidated collateral out of QU!D protocol. |
| 3. | [Twitter spaces](https://t.ly/B7pin) | Demonstrate the extent of readiness of the frontend by interacting with all protocol functions (minting is the only thing that may be done for the first 46 days after deployment). |
| 4. | Multi-collat | Something like CCIP will enable re-using one QD balance across several deployed states of the core protocol on [multiple EVMs](https://twitter.com/Brechtpd/status/1688533026156744704) (each having their own domain-specific plugins, such as cNOTE on CANTO instead of sDAI). |
| 5. |  Profile Preferences | Advancing on frontend progress from milestone 1, users should have the ability to pull custom insights into their trading dashboard. This should include push notifications based on more data feeds (to better inform trading decisions). Over-bought / over-sold signaling involves a [handful of TA indicators](https://github.com/QuidLabs/bnbot/blob/main/Bot.py#L366). Other kinds of insights in addition to TA indicators will be explored.  |

