const { expect } = require("chai");
//const { defaultAccounts } = require("ethereum-waffle");
const { ethers } = require("hardhat");
const nullAddress = "0x0000000000000000000000000000000000000000";
describe("MiniChefV2", function () {
  it("create new MiniChefV2 contract", async function () {
    const MiniChefV2 = await ethers.getContractFactory("MiniChefV2");
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    const MultiRewarderTime = await ethers.getContractFactory("MultiRewarderTime");
    const [owner, addr1] = await ethers.getSigners();
    const flake = await ERC20Mock.deploy("flake","flake","0x100000000000000000000000000000000");
    await flake.deployed();
    const lpToken = await ERC20Mock.deploy("flp","flp","0x100000000000000000000000000000000");
    await lpToken.deployed();
    const minichef = await MiniChefV2.deploy(owner.getAddress(),flake.address);
    await minichef.deployed();
    await minichef.setTokenPerSecond("1000000000");
    const rewarder = await MultiRewarderTime.deploy(minichef.address,0);
    await rewarder.deployed();
    await minichef.add("10000", lpToken.address, rewarder.address);
    await rewarder.add(flake.address,"10000000");
    await lpToken.approve(minichef.address,"1000000000");
    await minichef.deposit("0","1000000000",addr1.address);
    await rewarder.add(flake.address,"10000000");
    let lpGauge = await minichef.lpGauges(0);
    let gauge = await ethers.getContractAt("lpGauge",lpGauge);
    let balance0 = await gauge.balanceOf(owner.address);
    let balance1 = await gauge.balanceOf(addr1.address);
    console.log("balance",balance0.toNumber(),balance1.toNumber());
    await logUserInfo(minichef,owner,addr1);
    await gauge.connect(addr1).transfer(owner.address,"1000000000");
    await logUserInfo(minichef,owner,addr1);
    let tx = await gauge.transfer(addr1.address,"1000000000");
    console.log(tx);
    await logUserInfo(minichef,owner,addr1);
  });
  async function logUserInfo(minichef,owner,addr1){
    let userInfo = await minichef.userInfo(0,owner.address);
    let balance = await minichef.pendingToken(0,owner.address);
    console.log("owner userInfo",balance,userInfo);
    userInfo = await minichef.userInfo(0,addr1.address);
    balance = await minichef.pendingToken(0,addr1.address);
    console.log("addr1 userInfo",balance,userInfo);
  }
});