## UNISWAP-ARBITRUM GRANT PROGRAM (UAGP)

**Request for Proposal (RFP)**: New Protocols   
for Liquidity  Management and Derivatives


**Proposer**: QuidMint Foundation  
**Requested Funding**: 76 000 ARB  
**Payment Address**: `quid.eth`  


**Foundation Address**: PO Box 144, 3119 9 Forum Lane  
Quid Labs' public key ends with 4A4, so what we did...   
was build a simplified ERC404: took the zero (coupon)  

The funds for the grant will be used to  
pay for audits (contract testing costs),    
minor development costs (frontend),  
as well as integrations (partnerships).    


  - **Maintenance:** 42000 USD
    - Audit + counsel [retainer](https://twitter.com/lex_node/status/1760701615424630848): 30000 USD
    -   Cayman & BVI annual fees: 12000 USD
  - **R&D Costs:** 34000 USD
    - **Full-Time Equivalent (FTE)**: 2 x 2 months
      - Senior frontend developer
      - Senior backend developer 


### Project Overview:

[Derivatives](https://twitter.com/lex_node/status/1740509787690086847) derive their value from an underlying asset. Our certicificate of deposite (CD) is a [Capital Deepening](https://www.wallstreetmojo.com/capital-deepening/)  
token (QD) deriving value from sDAI, and demand for borrowing and lending ETH with maximal capital efficiency.  


ETH public keys are 42 characters; Arbitrum's chainId starts with 42; sDAI's public key ends with 42🐝, `quid.eth`  
starts with 42. Bridging liquidity (benefitting the entire Arbitrum ecosystem as a result), this project seeks to extend  

the capabilities of decentralised finance by introducing simple financial instruments (sDAI re-staking) that solve a   

complex problem (rich art of bi-directional leverage with maximum capital efficiency), while adhering to principles  
of UAGP Code of Conduct (and the 42 Laws of Ma'at), prioritizing transparency, user empowerment, and security.

### Team Members:

Before Euromaidan, Ukraine had one of the world's first central bank-tethered digital currencies, issued by a company  
whose EIN was 36**42**51**42** (without the use of DLT): interned there as a paralegal before learning C through http://42.fr ;   
after that, helped build the [predecessor](https://patentscope.wipo.int/search/en/detail.jsf?docId=WO2020102401) to Liquity on EOS, then worked for Bancor, also audited THOR and bZx (CertiK).

### Use of funds, milestones, and goals (KPIs):

- Mainnet Launch: June 1st...  
- Arbitrum Launch: June 27th
- User Adoption: 357M QD in    
 Q2
(same minted within Q4)  
- Liquidity: 544M sDAI locked for 2024
- Contract Interaction: Facilitate at least  
  1000 `Plunge` positions, which, instead  
  of importing liquidity step-wise as we're     
  used to with CDPs, employ a wholesale  
  incentivisastion program, that benefits 
- Partnerships: Milestone 2 and onwards


### Milestone 1:

To arrive at its current level simplicity, Quid Labs had to rebuild its protocol 3 times over the last 3 years; latest implementation:  
just over 800 lines. The majority of the work for this milestone is devoted to testing this implementation, while also extending  
`frontend` functionality. We already have a contract (Lot.sol) dedicated to Uniswap, incentivising V3 liquidity deposits with  

Tether to give QD a way to earn outside of being used in QU!D protocol. Potentially, all the sDAI that gets locked in PCV can  
also be deployed as single-sided liquidity in a pool with sDAI and ETH. We may extend our medianiser to vote between UNI  
and other liquidity pools (for % of sDAI to lock in AMMs against ETH), but this is seen as V2 feature (given enough interest).  


Also as part of the 1st milestone, `yo.quid.io` will be the first external operator (QU!D Ltd in BVI) running `frontend` as a fully featured, standalone web application for the protocol (currently just allows minting,
and seeing some basic stats: e.g. P&L...etc).  

| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0a.** | License | GPLv3 Copyleft is the  technique of granting certain freedoms over copies of copyrighted works with the requirement that the same rights be preserved in *derivative* works (hint)... |
| 1. | Withdrawal (`call`) buttons | ETH may be freely deposited and withdrawn, meanwhile used to boost pledges. QD redemption (for sDAI) has rules based on when the QD was minted.  |
| 2. | Vertical fader | All the way down by default, there should be one input slider for the magnitude of either long leverage, or short (and a toggle to switch between the two. Touching the toggle once automatically triggers 2xAPR, and this must be manually disabled).|
| 3a. | Cross-fader for balance | This slider will represent how much of the user’s total QD is deposited in `work`, and how much is in `carry` (by default the whole balance is left…in `carry`). |
| 3b. | Cross-faders for voting | Shorts and longs are treated as separate risk budgets, so there is one APR target for each (combining them could be a worthy experiment, definitely better UX, though not necessarily optimal from an analytical standpoint). Median APR (for long or short) is 8-21%...voting provides a scale factor for roughly up to 3x surge pricing. |
| 4. | Basic Metrics |  Provide a side by side comparison of key metrics: aggregated for all users, and from the perspective of the authenticated user (who’s currently logged in, e.g. individual risk-adjusted returns); see most recently liquidated (sorted by time or size); top borrowers in terms of P&L, volume, duration. |
| 5. | Simulation [Metrics](https://orus.info/) | Future projections for the output of the `call` function, with varying inputs of how is being leveraged in `work` at the time of calling the function, as well as what % of borrowers were profitable over the course of the previous year.  |


### Milestone 2:


| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0a.** | License GPLv3 | Copyleft (same as previous milestone’s…of the public, by the public, for the public). |
| **0b.** | Documentation |  We provide both code comments and instructions for running the protocol as well as sanity checking the operability with some test transactions. |
| 1. | NFT marketplaces + Fiat [off-ramps](https://www.flashy.cash/) + deployment | Exclusive NFT [marketplaces](http://polyone.io) will enable payment with QD (for preferential pricing of NFTs) as a well as other bonuses. Providing real-world utility for our token (beyond crypto trading) is further possible through trusted partners for bridging into the domain of bank accounts and cash. We plan to sub-contract operation and hosting of yo.quid.io (on-ramp for web). |
| 2. | Event bus (Watcher) | Publish code that reads the blockchain for liquidation opportunities, so anyone can run it. Later, this code could be potentially integrated with ZigZag exchange's off-chain order matcher so that the beneficiaries of `grace` can become arbitrary accounts, purchasing a liqudiated position's collateral for the value of its debt at the time of liquidation.  |
| 3. | Kickoff Twitter spaces | Demonstrate the extent of readiness of the frontend by interacting with all protocol functions (minting is the only thing that may be done for the first 46 days after deloyment). |
| 4. | Protocol integrations (multi-collateral) | CCIP will enable re-using the same QD tokens across deployments of the core protocol (MO) on separate EVMs (each having their own domain-specific plugins, such as cNOTE on CANTO as the replacement for sDAI, as well as different price feed source). |
| 5. |  UX personalisation | Advancing on the results from milestone 1 should include push notifications based on more data feeds (to better inform trading decisions). Over-bought / over-sold signaling can involve a handful of technical analysis indicators (e.g. RSI, MACD, SMA, BBands). |


