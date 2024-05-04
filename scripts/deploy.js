
const { ethers } = require("hardhat");

async function getContract(name, addr) {
  const CONTRACT = await ethers.getContractFactory(name);
  const contract = await CONTRACT.attach(addr);
  return contract;
}

async function main() {
  const noteAddress = '0x04E52476d318CdF739C38BD41A922787D441900c'; // cNOTE
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  
  const note = await getContract('ERC20', noteAddress);
  const name = await note.name();
  console.log(name);

  console.log('deploy MO');
  let MO = await ethers.getContractFactory("MO");
  const mo = await MO.deploy();
  console.log('MO deployed! ' + mo);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
