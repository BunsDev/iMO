// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("@nomicfoundation/hardhat-toolbox");
const axios = require('axios')
const BN = require('bn.js')
// require('dotenv').config()

const SUBGRAPH_URL = 'https://api.thegraph.com/subgraphs/name/uniswap/uniswap-v3'

TOKEN_IDS_QUERY_USDC = `
{
    positions(where: {
        owner: "0xb13Def621fDFb5C79c71ec8f55dc5D6075e68229"
        pool: "0xe081eeab0adde30588ba8d5b3f6ae5284790f54a"
    }) {
        id
        owner
    }  
}
`
TOKEN_IDS_QUERY_WETH = `
{
    positions(where: {
        owner: "0x14b8e5b39070558c5aed55b5bd48be6e8bd888d6"
        pool: "0x5ecef3b72cb00dbd8396ebaec66e0f87e9596e97"
    }) {
        id
        owner
    }  
}
`
const MO = artifacts.require("./MO.sol")
const LOT = artifacts.require("./Lot.sol")
const ZERO_ADDRESS = '0x' + '0'.repeat(40)
const maxBytes32 = '0x' + 'f'.repeat(64)


const { ethers, providers, utils } = require('ethers')
const INFURA_URL = process.env.INFURA_URL
const PROVIDER = new ethers.providers.JsonRpcProvider(INFURA_URL)
// const PROVIDER = new ethers.providers.JsonRpcProvider("https://canto.slingshot.finance")
async function printCurrentBlock() {
  console.log(await PROVIDER.getBlockNumber())
}

const { abi : INonfungiblePositionManagerABI} = require('@uniswap/v3-periphery/artifacts/contracts/interfaces/INonfungiblePositionManager.sol/INonfungiblePositionManager.json')
const POSITION_MANAGER_ADDRESS = '0xC36442b4a4522E871399CD717aBDD847Ab11FE88'

const getBlockTimestamp = async (provider/*: providers.JsonRpcProvider*/) => {
    return (await provider.getBlock("latest")).timestamp
}

const setNextBlockTimestamp = async (provider/*: providers.JsonRpcProvider*/, timestamp) => {
    await provider.send("evm_setNextBlockTimestamp", [utils.hexValue(timestamp)])
}

async function main() {
  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = currentTimestampInSeconds + 60;

  const result_weth = await axios.post(SUBGRAPH_URL, { query: TOKEN_IDS_QUERY_WETH })
    const result_usdc = await axios.post(SUBGRAPH_URL, { query: TOKEN_IDS_QUERY_USDC })

    const positions_weth = result_weth.data.data.positions
    const positions_usdc = result_usdc.data.data.positions

    console.log('positions in weth', positions_weth)
    console.log('positions in usdc', positions_usdc)

    // const nonFugiblePositionManagerContract = new ethers.Contract(
    //     POSITION_MANAGER_ADDRESS,
    //     INonfungiblePositionManagerABI,
    //     PROVIDER
    // )

    // const weth = nonFugiblePositionManagerContract.positions(positions_weth[0].id)
    //     .then(res => {
    //         console.log((res.liquidity).toString()) 
    //     })

    // const usdc = nonFugiblePositionManagerContract.positions(positions_usdc[0].id)
    //     .then(res => {
    //         console.log((res.liquidity).toString())
    //     })

  const owner = 0x42cc020Ef5e9681364ABB5aba26F39626F1874A4

  // const mo = await MO.new();
  // const lot = await LOT.new();


  // const _mo = await hre.ethers.deployContract("Lot", [, [owner]], {
  //   value: lockedAmount,
  // });

  // const _lot = await hre.ethers.deployContract("Lot", [unlockTime, [owner]], {
  //   value: lockedAmount,
  // });

  // await _mo.waitForDeployment();
  // await _lot.waitForDeployment();

  console.log(
    `Lot with ${ethers.formatEther()} ETH and deployed to ${_lot.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
