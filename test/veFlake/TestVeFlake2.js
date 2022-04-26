const { time, expectEvent} = require("@openzeppelin/test-helpers");

const SavingMinePool = artifacts.require('veFlake');

const RewardMeltToken = artifacts.require("MockToken");

const assert = require('chai').assert;
const Web3 = require('web3');
const BN = require("bignumber.js");
var utils = require('../boostFarm/utils.js');

web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/
// 现在一般都是1个小时结息一次，
// 计算器算一下,
//     _interestRate = (1.05)^(1/24)-1,decimals=27，_interestInterval = 3600
//
// 1.0020349912970346474243981869599-1 = 0.0020349912970346474243981869599，再*1e27就行了
let YEAR_INTEREST = new BN("0.6");
let DAY_INTEREST = YEAR_INTEREST.div(new BN(365));//日利息 5%0
//let DAY_INTEREST = new BN(0.005);
let INTEREST_RATE = new BN("1").plus(new BN(DAY_INTEREST));
let DIV24= new BN("1").div(24);//div one day 24 hours
INTEREST_RATE = Math.pow(INTEREST_RATE,DIV24) - 1;

console.log("INTEREST_RATE",INTEREST_RATE);
INTEREST_RATE = new BN(INTEREST_RATE).times(new BN("1000000000000000000000000000"));

console.log("INTEREST_RATE "+INTEREST_RATE.toString(10));
//return;

contract('Saving Pool Farm', function (accounts){
  let rewardOneDay = web3.utils.toWei('5000', 'ether');
  let blockSpeed = 5;
  let bocksPerDay = 3600*24/blockSpeed;
  let rewardPerBlock = new BN(rewardOneDay).div(new BN(bocksPerDay));
  console.log(rewardPerBlock.toString(10));

  let unstakeAmount = web3.utils.toWei('1', 'ether');
  let startBlock = 0;
  //let unstakeLockTime = 90*24*3600;
  let unstakeLockTime = 3600;

  let staker1 = accounts[2];
  let staker2 = accounts[3];

  let teamMember1 = accounts[4];
  let teamMember2 = accounts[5];
  let teammems = [teamMember1,teamMember2];
  let teammemsRatio = [20,80];

  let operator0 = accounts[7];
  let operator1 = accounts[8]

  let disSpeed1 = web3.utils.toWei('1', 'ether');

  let VAL_1M = web3.utils.toWei('1000000', 'ether');
  let VAL_10M = web3.utils.toWei('10000000', 'ether');
  let VAL_100M = web3.utils.toWei('100000000', 'ether');
  let VAL_1B = web3.utils.toWei('1000000000', 'ether');
  let VAL_10B = web3.utils.toWei('10000000000', 'ether');

  let minutes = 60;
  let hour    = 60*60;
  let day     = 24*hour;
  let totalPlan  = 0;
  let flake;
  let veFlake;

  before("init", async()=>{

      flake = await RewardMeltToken.new("falke token","flake",18);

      veFlake = await SavingMinePool.new(flake.address,accounts[0],"veFalke token","veFlake",18);
      console.log("pool address:", veFlake.address);


      await flake.mint(staker1,VAL_1B);
      await flake.mint(staker2,VAL_1B);

  })

  it("[0010] stake in,should pass", async()=>{
    let res = await flake.approve(veFlake.address,VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);

    let beforeVeFlakeBal = await veFlake.balanceOf(staker1);

    res = await veFlake.enter(VAL_1M,{from:staker1});
    assert.equal(res.receipt.status,true);

    let afterVeFlakeBal = await veFlake.balanceOf(staker1);
    let diff = web3.utils.fromWei(afterVeFlakeBal) - web3.utils.fromWei(beforeVeFlakeBal);

    assert.equal(diff,1000000,'balance init is not equal')
  })



  it("[0020] apply cancel mul times's apply,part expired,part not,should pass", async()=>{
        console.log("\n\n");

        res = await veFlake.leaveApply(unstakeAmount,{from:staker1});
        assert.equal(res.receipt.status,true);

        time.increase(3600);
        res = await veFlake.leaveApply(unstakeAmount,{from:staker1});
        assert.equal(res.receipt.status,true);

        // time.increase(3600);
        // res = await veFlake.leaveApply(unstakeAmount,{from:staker1});
        // assert.equal(res.receipt.status,true);
        //
        // time.increase(3600);
        // res = await veFlake.leaveApply(unstakeAmount,{from:staker1});
        // assert.equal(res.receipt.status,true);

        let allPending = await veFlake.getUserAllPendingAmount(staker1);
        console.log("all pending amount before cancel:",allPending.toString(10));

        assert.equal(allPending.toString(),new BN(unstakeAmount.toString(10)).times(new BN(2)));

        //time.increase(unstakeLockTime-2*day+ 3600);
        time.increase(unstakeLockTime + day);

        res = await veFlake.cancelLeave({from:staker1});
        assert.equal(res.receipt.status,true);

        allPending = await veFlake.getUserAllPendingAmount(staker1);
        console.log("all pending amount after cancel:",allPending.toString(10));

        assert.equal(allPending.toString(),0);


        releasePending = await veFlake.getUserReleasePendingAmount(staker1);
        assert.equal(releasePending.toString(),0);
    })


})