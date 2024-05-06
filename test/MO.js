const {
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { expect } = require("chai");
  

describe("Token contract", function () {
    async function deployFixture() {
        const [owner, addr1, addr2] = await ethers.getSigners();
    
        const sDAI = await ethers.deployContract("mock");
        await sDAI.waitForDeployment();

        const MO = await ethers.deployContract("MO");
        await MO.waitForDeployment();
    
        
        return { sDAI, MO, owner, addr1, addr2 };
    }

    it("Should assign the total supply of tokens to the owner", async function () {
        const { sDAI, MO, owner, addr1, addr2 } = await loadFixture(deployFixture);
    
        const date = await MO.sale_start(); await sDAI.mint(addr1, 40000000000000);
        const balance = await sDAI.balanceOf(addr1); 

        await MO.set_price(40000000000000);
        const price = await MO.get_price();
        
        
        expect(price).to.equal(40000000000000);

        const QD = await MO.mint(who)

        await expect(
            hardhatToken.transfer(addr1.address, 50)
          ).to.changeTokenBalances(hardhatToken, [owner, addr1], [-50, 50]);
    
          // Transfer 50 tokens from addr1 to addr2
          // We use .connect(signer) to send a transaction from another account
          await expect(
            hardhatToken.connect(addr1).transfer(addr2.address, 50)
          ).to.changeTokenBalances(hardhatToken, [addr1, addr2], [-50, 50]);
  
    });
   
});