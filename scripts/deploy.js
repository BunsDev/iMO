
const { ethers } = require("hardhat");

async function getContract(name, addr) {
  const CONTRACT = await ethers.getContractFactory(name);
  const contract = await CONTRACT.attach(addr);
  return contract;
}

async function main() { // rinkeby:
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  console.log('deploy mock');
  let Mock = await ethers.getContractFactory("mock");
  const mock = await Mock.deploy();
  const token = await mock.getAddress()
  console.log('token deployed at', token)

  console.log('deploy MO');
  let MO = await ethers.getContractFactory("Moulinette");
  // const mo = await MO.deploy(mock.getAddress());
  const mo = await MO.deploy(token)
  
  console.log(await mo.getAddress())
 
  // console.log('deploy Marenate');
  // let Marenate = await ethers.getContractFactory("Marenate");
  
  // const maren = await Marenate.deploy('0x6168499c0cffcacd319c818142124b7a15e857ab',
  // '0x01BE23585060835E02B77ef475b0Cc51aA1e0709', 
  // '0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311',
  // 100000, 3, mo.getAddress())
  
  // console.log('Marenate deployed! ' + await maren.getAddress());
}  
  
  
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
