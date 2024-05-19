const {
    loadFixture, time
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const BN = require('bn.js'); const { expect } = require("chai");

describe("Token contract", function () {
    async function deployFixture() { // plain, and empty deployment
        const currentTime = (Date.now() / 1000).toFixed(0)

        const [owner, addr1, addr2, 
            addr3, addr4, addr5 ] = await ethers.getSigners()
            
        const sDAI = await ethers.deployContract("mock")
        await sDAI.waitForDeployment()

        const MO = await ethers.deployContract("Moulinette", [sDAI.target]);
        await MO.waitForDeployment()

        const price = '2900000000000000000000'
        await MO.connect(owner).set_price(price)
        // const contractPrice = await MO.get_price()
        // expect(contractPrice).to.equal(price)

        return { sDAI, MO, owner, 
            addr1, addr2, addr3,
            addr4, addr5, currentTime }
    }

    async function deployAndMintFixture() { 
        const {  sDAI, MO, owner, 
            addr1, addr2, addr3,
            addr4, addr5, currentTime  } = await loadFixture(deployFixture)
        
        const hundred = '100000000000000000000000' // 100k
                        
        await sDAI.connect(addr1).mint(hundred)
        await sDAI.connect(addr2).mint(hundred) 
        await sDAI.connect(addr3).mint(hundred)
        await sDAI.connect(addr4).mint(hundred)
        await sDAI.connect(addr5).mint(hundred)
                                        
        await sDAI.connect(addr1).approve(MO.target, hundred)
        await sDAI.connect(addr2).approve(MO.target, hundred)
        await sDAI.connect(addr3).approve(MO.target, hundred)
        await sDAI.connect(addr4).approve(MO.target, hundred)
        await sDAI.connect(addr5).approve(MO.target, hundred)

        return { sDAI, MO, owner, 
            addr1, addr2, addr3,
            addr4, addr5, currentTime };
    }

    async function deployAndMintMOFixture() { // mint enough for a successful MO
        const {  sDAI, MO, owner, 
            addr1, addr2, addr3,
            addr4, addr5, currentTime  } = await loadFixture(deployAndMintFixture);

        // wait for price to get to .99
        await time.increase(3974000) // 46 days * 24 hours * 60 minutes * 60 seconds
        const amt = '500000000000000000000'
        await MO.connect(addr3).mint(amt, addr2) // beneficiary different from sender
        await MO.connect(addr4).mint(amt, addr2) // beneficiary different from sender
        await MO.connect(addr5).mint(amt, addr2) // beneficiary different from sender

        await time.increase(400) 
        return { sDAI, MO, owner, 
            addr1, addr2, addr3,
            addr4, addr5, currentTime };
    }

    it("Test mint", async function () {
        const { sDAI, MO, owner, addr1, addr2, currentTime } = await loadFixture(deployFixture);
        
        const oldDate = await MO.sale_start()
        await sDAI.connect(addr1).mint('1000000000000000000000') // 1k
        var balanceBefore = await sDAI.balanceOf(addr1);         
        
        expect(balanceBefore).to.equal('1000000000000000000000')
                                        
        await sDAI.connect(addr1).approve(MO.target, '50000000000000000000')

        const amt = '92000000000000000000' // mint 92$ for roughly 50$
        await MO.connect(addr1).mint(amt, addr2) // beneficiary different from sender

        var balanceAfter = await sDAI.balanceOf(addr1)
        const balanceDelta = balanceBefore - balanceAfter      
                
        const QD = await MO.balanceOf(addr2)
        
        const delta = new BN(amt) - new BN(QD)
        const pct = delta / new BN(amt)
        expect(pct).to.equal(0.022) // 0.22 %

        const in_wind = await MO.wind()
        expect(in_wind[0]).to.equal(amt) // protocol debt corresponds to minted amount

        const in_carry = await MO.carry()
        expect(in_carry[0]).to.equal(balanceDelta)

         
        await time.increase(3974400) // 46 days * 24 hours * 60 minutes * 60 seconds
        balanceBefore = await sDAI.balanceOf(addr1)
        
        await MO.connect(addr1).mint(amt, addr2)
        balanceAfter = await sDAI.balanceOf(addr1)

        expect(balanceBefore).to.equal(balanceAfter) // no sDAI was spent
        const date = await MO.sale_start()
        expect(oldDate).to.equal(date)

        await time.increase(12441600) // 144 days * 24 hours * 60 minutes * 60 seconds
        
        await MO.connect(addr1).mint(amt, addr2)   
        const newQD = await MO.balanceOf(addr2)
        expect(QD).to.equal(newQD) // no change in balance

        const newDate = await MO.sale_start();
        expect(newDate - oldDate).to.be.at.least(20390400) // (46 + 144 + 46) * 24 * 60 * 60
        
        await MO.connect(addr1).mint(amt, addr2)   
        balanceAfter = await sDAI.balanceOf(addr1)
        expect(balanceAfter).to.be.above(balanceBefore) // refund (not enough QD minted)
    });

    it("Test put ETH (then withdraw)", async function () { 
        const { sDAI, MO, owner, addr1, addr2 } = await loadFixture(deployFixture)
        const balanceBefore = await ethers.provider.getBalance(addr1)
        const amt = '5000000000000000000'

        await MO.connect(addr1).put(addr1, amt, true, true, { value: amt })
        const balanceAfter = await ethers.provider.getBalance(addr1)
        const delta = balanceBefore - balanceAfter // gas cost 150055889475635

        var in_carry = await MO.carry()
        expect(in_carry[1]).to.equal(amt) // debit is the 2nd element

        await MO.connect(addr1).call(amt, false)

        in_carry = await MO.carry()
        expect(in_carry[1]).to.equal(0) 
    });   
    
    it("Test borrow, put (into work), then withdraw (from work)", async function () { 
        const { sDAI, MO, owner, addr1, addr2, addr3,
            addr4, addr5, currentTime } = await loadFixture(deployAndMintMOFixture)

        var ethBefore = await ethers.provider.getBalance(addr2)
        const amt = '5000000000000000000'

        
        var in_carry_before = await MO.carry()
        console.log('in_carry_before', in_carry_before)

        await MO.connect(addr2).owe(amt, false, { value: amt }) // go long
        
        

        var ethAfter = await ethers.provider.getBalance(addr2)
        var delta = ethBefore - ethAfter
        console.log('delta', delta)

        var in_carry_after = await MO.carry()
        console.log('in_carry_after', in_carry_after)

        var in_work = await MO.work()
        console.log('in_work', in_work)

        await MO.connect(addr1).put(addr2, amt, false, false)

        in_carry_after = await MO.carry()
        console.log('AFTER_in_carry_after', in_carry_after)

        in_work = await MO.work()
        console.log('AFTER_in_work', in_work)


        // expect(delta).to.equal(amt)
    });    


    // it("Test borrow, vote, see delta in fee (charge APR)", async function () { 
    //     const { sDAI, MO, owner, addr1, addr2, addr3,
    //         addr4, addr5, currentTime } = await loadFixture(deployAndMintMOFixture)
        
        
    // }); 
    

    // it("Test liquidate (no deux)", async function () { 
    //     const { sDAI, MO, owner, addr1, addr2, addr3,
    //         addr4, addr5, currentTime } = await loadFixture(deployAndMintMOFixture)
        
        
    // }); 
    
    // it("Test liquidate (with deux, but no clutch)", async function () { 
    //     const { sDAI, MO, owner, addr1, addr2, addr3,
    //         addr4, addr5, currentTime } = await loadFixture(deployAndMintMOFixture)
        
        
    // });    

    // it("Test liquidate (with deux, AND clutch)", async function () { 
    //     const { sDAI, MO, owner, addr1, addr2, addr3,
    //         addr4, addr5, currentTime } = await loadFixture(deployAndMintMOFixture)

        
    // });    

    // it("Test call (take profits i.e. redeem QD for sDAI)", async function () { 
    //     const { sDAI, MO, owner, addr1, addr2, addr3,
    //         addr4, addr5, currentTime } = await loadFixture(deployAndMintMOFixture)

        
    // });    

    // await expect(
        //     hardhatToken.transfer(addr1.address, 50)
        //   ).to.changeTokenBalances(hardhatToken, [owner, addr1], [-50, 50]);
    
        //   // Transfer 50 tokens from addr1 to addr2
        //   // We use .connect(signer) to send a transaction from another account
        //   await expect(
        //     hardhatToken.connect(addr1).transfer(addr2.address, 50)
        //   ).to.changeTokenBalances(hardhatToken, [addr1, addr2], [-50, 50]);
  
});