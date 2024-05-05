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
    
        const date = await MO.sale_start();

        expect(date).to.equal(0);

        // Transfer 50 tokens from owner to addr1
        // await expect(
        //     hardhatToken.transfer(addr1.address, 50)
        // ).to.changeTokenBalances(hardhatToken, [owner, addr1], [-50, 50]);
  
    });
   
});