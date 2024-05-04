const { expect } = require("chai");

describe("Token contract", function () {
  it("Deployment should assign the total supply of tokens to the owner", async function () {
    
    const [owner, addr1, addr2] = await ethers.getSigners();
    const token = await ethers.deployContract("MO");
    await token.waitForDeployment();
    const result = await token.sale_start()
    expect(await token.sale_start()).to.equal(40);
    
  });
});