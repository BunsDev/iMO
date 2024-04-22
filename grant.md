## UNISWAP-ARBITRUM GRANT PROGRAM (UAGP)


Proposer: QuidMint Foundation
Project Title: QU!D  
Contractor: Quid Labs

Request for Proposal (RFP): New Protocols   
for Liquidity  Management and Derivatives

Requested Funding: 66,000 ARB  
Payment Address: `quid.eth`
Foudation Address: PO Box 144, 3119 9 Forum Lane.

Quid Labs' public key ends with 4A4, so what we did
was build a simplified ERC404 (took the zero coupon
out of it, and turned it into an asset), which also
includes a UniV3 incentivisation provision (Lock).  

The funds for the grant will be used to  
pay for audits (contract testing costs),    
and minor development costs (frontend),  
as well as integrations (partnerships).    

- **Costs:** 66000 ARB, 2 months
    - **Maintenance:** 42000 USD
      - Audit: 30000 USD
      - Counsel retainer & annual fees
        - (Cayman & BVI): 12000 USD
  - **R&D Costs:** 24000 USD
    - **Full-Time Equivalent (FTE)**: 2-3
      - Designer / Reactooor
      - Economist / Solidity

### Team Members:

Before Euromaidan, Ukraine had one of the world's first central bank-tethered digital currencies, issued by a licensed company whose EIN was 36**42**51**42** (without the use of DLT). I interned there as a paralegal before learning C through http://42.fr

After that, I helped build the precursor to Liquity on EOS, then worked for Bancor. Later, I audited THOR and bZx at CertiK (took turns with Dom consulting on side-projects at Liquity, fuzzing and [DSproxy](https://patentscope.wipo.int/search/en/detail.jsf?docId=WO2020102401), respectively). 

### Project Overview:

Derivatives derive their value from an underlying asset.
The capital deepening token we’ve developed derives it value from sDAI, and of course, the same value underlying said asset…which is demand for borrowing and lending ETH. The first paragraph in our README describes how to classify our token.

### Use of funds, milestones, and goals (KPIs):

- Launch: June 27th
- User Adoption: 357M QD in    
 Q2
same minted within Q4.  
- Liquidity: 544M sDAI locked for 2024 (aggregate, CCIP in Milestone 2)
- Contract Interaction: Facilitate at least 1000 Plunges post-launch.
- Community Growth: Garner a community of 1000 followers on Twitter.
- Partnerships: Milestone 2 and onwards


### Milestones:

  ETH public keys are 42 characters, Arbitrum's chainId starts with 42, sDAI's public key ends with 42🐝, `quid.eth`'s starts with 42.

  This project seeks to extend the capabilities of decentralised finance by introducing simple financial instruments that solve a complex problem, while adhering to the principles of UAGP Code of Conduct (and the 42 Laws of Ma'at), prioritizing transparency, and user empowerment, bringing liquidity, benefitting the entire Arbitrum ecosystem as a result.


### Milestone 1 - audit and frontend:

To arrive at its current level simplicity, Quid Labs had to rebuild its protocol 3 times over the last 3 years.
The latest implementation is just over 1000 lines.
The majority of the work for this milestone is devoted to testing this implementatiom, while extending
frontend functionality.

We already have a contract dedicated to Uniswap, incentivising V3 liquidity deposits.

Also as part of the 1st milestone, we will extend the existing QU!D frontend to serve as a fully featured, standalone web application for the protocol (currently just allows minting,
and seeing some basic stats: e.g. P&L...who minted...time left to mint).

| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0a.** | License | GPLv3 Copyleft is the legal technique of granting certain freedoms over copies of copyrighted works with the requirement that the same rights be preserved in derivative works. |
| **0b.** | Compliance | We will provide both code comments and safety instructions (e.g. wash hands to  Hans Zimmer like John 4:8, check for allergies, or OFAC countries) for running the frontend instance as well as sanity checking the operability with some test transactions on mainnet (at the end of the milestone). |
| **0c.** | Docker | A [Dockerfile](https://github.com/QuidMint/ibo-app/blob/main/Dockerfile) is provided for deploying the functionality delivered in this milestone. |
| 0d. | Smart Contract Development and Audit | Socratic seminar format (involving dialogue, or even debate) with one (or many) experienced interlocutor(s), exploring overarching themes inherited by the design space with granular Q&A, and audit the smart contracts for the derivative protocol ensuring security and functionality. |
| 1. | Withdrawal buttons | ETH may be freely deposited and withdrawn, meanwhile used to boost pledges. QD redemption (for sDAI) has rules based on when the QD was minted.  |
| 2. | Vertical fader | What the original iPod circle did for music players we'll do for...not CCTP. All the way down by default, there should be one input slider for the magnitude of either long leverage, or short (and a toggle to switch between the two. Touching the toggle once automatically triggers 2xAPR, and this must be manually disabled).|
| 3a. | Cross-fader for balance | This slider will represent how much of the user’s total holdings are deposited in LP, and how much are in SP (by default the whole balance is left…in SP). |
| 3b. | Cross-faders for voting | Shorts and longs are treated as separate risk budgets, so there is one APR target for each (combining them could be a worthy experiment, definitely better UX, though not necessarily optimal from an analytical standpoint). Median APR (for long or short) is 8-21%...a scale factor for up to 3x surge pricing. |
| 4. | [Metrics](https://orus.info/) |  Provide a side by side comparison of key metrics: aggregated for all users, and from the perspective of the authenticated user (who’s currently logged in, e.g. individual risk-adjusted returns); see most recently liquidated (sorted by time or size); top borrowers in terms of P&L, volume, duration. It's uncommon to keep reliving a leveraged position for more than a month (8-16% annual is the same as .666% - 1.33% monthly...the minimum "one-time fee" of “0% interest” platforms is 0.5%). |

### Milestone 2 - quid pro quotes:

The delivery of this milestone is *not* contingent on the completion of milestone 1 first. Either one may be completed before the other, or both roughly at the same time.

| Number | Deliverable | Specification |
| -----: | ----------- | ------------- |
| **0a.** | License GPLv3 | Copyleft (same as previous milestone’s…of the public, by the public, for the public). |
| **0b.** | Documentation |  We provide both code comments and instructions for running the protocol as well as sanity checking the operability with some test transactions. |
| 1. | QU!Dao: critical thinking school | Part of our mission is training crypto participants to be better decision makers when it comes to leverage. We plan to do this by partnering with TalentLayer (Grace-based mentorship escrow/subscription).  |
| 2. | Fiat off-ramps + frontend deployment | Providing real-world utility for our token is only possible through trusted partners for bridging into the domain of bank accounts and cash. We plan to sub-contract operation and hosting of yo.quid.io (on-ramp for web), and integrate with Flashy for web off-ramp, as well as Rivendell, Monarch, and Trustee for mobile. |
| 3. | Event bus (Watcher) | Publish code that reads the blockchain for liquidation opportunities, so anyone can run it. Liquidations happen when options are in-the-money (modifying debt/collat ratio moves the strike price along moneyness spectrum). |
| 4. | Twitter spaces | Demonstrate the extent of readiness of the frontend by interacting with all protocol functions. |
| 5. | Protocol integrations | After deployment, the [ecosystem](https://twitter.com/Rainmaker1973/status/1732089932707942438) runs in a closed loop; oomph (momentum) is harnessed internally (temporarily). An absolute necessity for scaling (growing liquidity), building moat, and fault-tolerance: cross-pollinating value through interoperability with ZigZag exchange. |
| 6. | [OCDB](https://chromewebstore.google.com/detail/ocdb-open-collectible-dat/kchfgahfakmfagdikgdigacgjijfgaeh) for recent liquidations and UX personalisation | Advancing on the results from milestone 1 should include push notifications based on more data feeds (to better inform trading decisions). Over-bought / over-sold signaling can involve a handful of technical analysis indicators (e.g. RSI, MACD, SMA, BBands) as well as knowledge curation (pertaining to macro signals) tying back to the Dao. One lucky unlucky pledge (that was liquidated) will be chosen as a lottery winner. |
