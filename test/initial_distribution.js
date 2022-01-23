const { expect } = require("chai");
const { ethers } = require("hardhat");

function getCreate2Address(
  factoryAddress,
  [tokenA, tokenB],
  bytecode
) {
  const [token0, token1] = tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA]
  const create2Inputs = [
    '0xff',
    factoryAddress,
    keccak256(solidityPack(['address', 'address'], [token0, token1])),
    keccak256(bytecode)
  ]
  const sanitizedInputs = `0x${create2Inputs.map(i => i.slice(2)).join('')}`
  return getAddress(`0x${keccak256(sanitizedInputs).slice(-40)}`)
}

describe("initial distro", function () {

  let token;
  let ve_underlying;
  let ve;
  let owner;
  let minter;

  it("deploy base", async function () {
    [owner] = await ethers.getSigners(1);
    token = await ethers.getContractFactory("Token");
    ve_underlying = await token.deploy('VE', 'VE', 18, owner.address);
    vecontract = await ethers.getContractFactory("contracts/ve.sol:ve");
    ve = await vecontract.deploy(ve_underlying.address);
    const BaseV1Factory = await ethers.getContractFactory("BaseV1Factory");
    factory = await BaseV1Factory.deploy();
    await factory.deployed();
    const BaseV1Voter = await ethers.getContractFactory("BaseV1Voter");
    const gauge_factory = await BaseV1Voter.deploy(ve.address, factory.address, gauges_factory.address);
    await gauge_factory.deployed();
    const VeDist = await ethers.getContractFactory("contracts/ve_dist.sol:ve_dist");
    const ve_dist = await VeDist.deploy();
    await ve_dist.deployed();

    const BaseV1Minter = await ethers.getContractFactory("BaseV1Minter");
    minter = await BaseV1Minter.deploy(gauge_factory.address, ve.address, ve_dist.address);
    await minter.deployed();
  });

  it("initialize veNFT", async function () {
    await minter.initialize([owner.address],[ethers.BigNumber.from("1000000000000000000000000")], ethers.BigNumber.from("20000000000000000000000000"))
    expect(await ve.ownerOf(1)).to.equal(owner.address);
    await network.provider.send("evm_mine")
    console.log(await ve_underlying.balanceOf(minter.address));
    console.log(await ve.balanceOfNFT(1));
  });

});
