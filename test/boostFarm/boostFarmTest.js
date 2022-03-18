const { time, expectEvent} = require("@openzeppelin/test-helpers");
const MinePool = artifacts.require('MiniChefV2');

const LpToken = artifacts.require('MockToken');
const FlakeToken = artifacts.require("MockToken");
const BoostToken = artifacts.require("MockToken");

const BoostSc = artifacts.require("hexagonBoost");

const assert = require('chai').assert;
const Web3 = require('web3');

const BN = require("bn.js");
var utils = require('./utils.js');
web3 = new Web3(new Web3.providers.HttpProvider("http://127.0.0.1:7545"));

/**************************************************
 test case only for the ganahce command
 ganache-cli --port=7545 --gasLimit=8000000 --accounts=10 --defaultBalanceEther=100000 --blockTime 1
 **************************************************/

contract('hexgon farm test', function (accounts){
    let rewardOneDay = web3.utils.toWei(""+3600*24, 'ether');
    let rewardPerSec = new BN(rewardOneDay).div(new BN(3600*24));
    console.log(rewardPerSec.toString(10));
////////////////////////////////////////////////////////////////////////
    let baseBoostTokenAmount=web3.utils.toWei(""+1000);//uint256 _baseBoostTokenAmount, 1000 ether
    let baseIncreaseRatio = new BN("30000000000000000000");//uint256 ,3%
    let boostTokenStepAmount = new BN("1000000000000000000000");     //uint256 _boostTokenStepAmount,1000 ether
    let ratioIncreaseStep = new BN("10000000000000000000");// uint256 _ratioIncreaseStep,1%
    let maxIncRatio = new BN("4500000000000000000000");//uint256 _maxIncRatio,4.5
    let lockTime =  new BN(""+3600*24);//uint256 _lockTime,
    let enableTokenBoost = true;    //bool    _enableTokenBoost,
    let boostToken;   //address _boostToken

////////////////////////////////////////////////////////////////////////
    let staker1 = accounts[2];
    let staker2 = accounts[3];
    let staker3 = accounts[6];

    let VAL_1M = web3.utils.toWei('1000000', 'ether');
    let VAL_10M = web3.utils.toWei('10000000', 'ether');
    let VAL_99M = web3.utils.toWei(  '99999999', 'ether');
    let VAL_100M = web3.utils.toWei('100000000', 'ether');
    let VAL_1B = web3.utils.toWei('1000000000', 'ether');
    let VAL_10B = web3.utils.toWei('10000000000', 'ether');

    let WITHTELIST_MINIMUM = VAL_100M ;

    let farminst;
    let lp;//stake token

    let booster;

    before("init contracts", async()=>{

        lp = await LpToken.new("lptoken","lp",18);
        await lp.mint(staker1,VAL_1B);
        await lp.mint(staker2,VAL_1B);
        await lp.mint(staker3,VAL_1B);

/////////////////////////////reward token///////////////////////////////////////////
        flake = await FlakeToken.new("flake token","flake",18);

        boostToken = await BoostToken.new("boost token","boost",18);
        await boostToken.mint(staker1,VAL_1B);
        await boostToken.mint(staker2,VAL_1B);
        await boostToken.mint(staker3,VAL_1B);

//set farm///////////////////////////////////////////////////////////
        farminst = await MinePool.new(accounts[0],flake.address);
        console.log("pool address:", farminst.address);

        res = await farminst.add(new BN(100),
            lp.address,
            "0x0000000000000000000000000000000000000000"
             //0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
            );
        assert.equal(res.receipt.status,true);

        res = await farminst.setFlakePerSecond(rewardPerSec);
        assert.equal(res.receipt.status,true);

        await flake.mint(farminst.address,VAL_1B);

//set boost//////////////////////////////////////////////////////////////////
        booster = await BoostSc.new(accounts[0],farminst.address);
//////////////////////////////////////////////////////////////////////////////
        res = await farminst.setBooster(booster.address);
        assert.equal(res.receipt.status,true);
/////////////////////////////////////////////////////////////////////////////
        res = await booster.setFixedTeamRatio(0,new BN(100));
        assert.equal(res.receipt.status,true);

        res = await booster.setFixedWhitelistPara(0,new BN(100),WITHTELIST_MINIMUM);
        assert.equal(res.receipt.status,true);

        res = await booster.setWhiteList(0,[accounts[8],accounts[9]]);
        assert.equal(res.receipt.status,true);

        res = await booster.setBoostFarmFactorPara(0,
                                                    baseBoostTokenAmount,//uint256 _baseBoostTokenAmount, 1000 ether
                                                    baseIncreaseRatio,//uint256 _baseIncreaseRatio,3%
                                                    boostTokenStepAmount,     //uint256 _boostTokenStepAmount,1000 ether
                                                    ratioIncreaseStep,// uint256 _ratioIncreaseStep,1%
                                                    maxIncRatio,//uint256 _maxIncRatio,4.5
                                                    lockTime,//uint256 _lockTime,
                                                    enableTokenBoost,    //bool    _enableTokenBoost,
                                                    flake.address     //address _boostToken
                                                );

        assert.equal(res.receipt.status,true);

    })

    it("[0010] stake lp in farm pool,should pass", async()=>{
         let poolInfo = await farminst.poolInfo(0);
         console.log(poolInfo);
        // console.log(mineInfo[0].toString(10),mineInfo[1].toString(10),
        //     mineInfo[2].toString(10),mineInfo[3].toString(10));

        // ////////////////////////staker1///////////////////////////////////////////////////////////
         res = await lp.approve(farminst.address,VAL_1B,{from:staker1});
         assert.equal(res.receipt.status,true);


         let preBal = await lp.balanceOf(farminst.address);
         console.log("prebalance=",preBal.toString(10));
         res = await farminst.deposit(0,VAL_100M,staker1,{from:staker1});
         assert.equal(res.receipt.status,true);
         time.increase(1);

        let pending = await farminst.pendingFlake(0,staker1);
        console.log("pending flake",pending[0].toString(10),pending[1].toString(10));

        //
        // utils.sleep(1000);
        // res = await farmproxyinst.deposit(0,VAL_99M,{from:staker3});
        // assert.equal(res.receipt.status,true);
        //
        // let afterBal = await pngInst.balanceOf(farmproxyinst.address);
        // console.log("afterbalance=",afterBal.toString(10));
        //

        //
        // let block = await web3.eth.getBlock(mineInfo[2]);
        // console.log("start block time",block.timestamp);

    })

/*
    it("[0020] check staker1 mined balance,should pass", async()=>{
        console.log("====================================================================================")
        time.increase(200000);
        let res = await farmproxyinst.totalStaked(0);
        console.log("totalstaked=" + res);

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("staker1 allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.allPendingReward(0,staker2)
        console.log("staker2 allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.allPendingReward(0,staker3)
        console.log("staker3 allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.getPoolInfo(0)
        console.log("poolinf=",res[0].toString(),res[1].toString(),res[2].toString(),
            res[3].toString(),res[4].toString(),res[5].toString(),
            res[6].toString(),res[7].toString(),res[8].toString());

        res = await farmproxyinst.getMineInfo(0);
        console.log(res[0].toString(),
            res[1].toString(),
            res[2].toString(),
            res[3].toString());

        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        let preBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));
        let preBalance3 = web3.utils.fromWei(await melt.balanceOf(staker3));
        //res = await farmproxyinst.getAllClaimableReward(0,staker1)
        //console.log("all claimable reward:", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);
        utils.sleep(1000);
        res = await farmproxyinst.withdraw(0,0,{from:staker2});
        assert.equal(res.receipt.status,true);
        utils.sleep(1000);
        res = await farmproxyinst.withdraw(0,0,{from:staker3});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2))
        console.log("staker2 melt reward=" + (afterBalance2 - preBalance2));

        let afterBalance3 = web3.utils.fromWei(await melt.balanceOf(staker3))
        console.log("staker3 melt reward=" + (afterBalance3 - preBalance3));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));
        console.log("====================================================================================")

    })

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //return (depositAmount,claimable,locked,claimed,joeReward);
    it("[0021] check locked and pending balance,should pass", async()=>{
        time.increase(day+1);

        // let staker1Claimed = web3.utils.fromWei(await tokenReleaseInt.userFarmClaimedBalances(staker1));
        // console.log("staker1 claimed reward=",staker1Claimed)
        // let staker1PendingReward = web3.utils.fromWei(await tokenReleaseInt.lockedBalances(staker1));
        // console.log("staker1 Pending reward=",staker1PendingReward);

        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })

    it("[0022] check staker1 withdraw reward,should pass", async()=>{

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));


        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));

        //res = await farmproxyinst.getAllClaimableReward(0,staker1)
        //console.log("all claimable reward:", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));
        console.log("====================================================================================")

    })

    it("[0023] check locked and pending balance,should pass", async()=>{

        time.increase(4*day+1);

        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })

    it("[0024] check staker1 withdraw reward,should pass", async()=>{

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));


        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));

        // res = await farmproxyinst.getAllClaimableReward(0,staker1)
        // console.log("all claimable reward:", web3.utils.fromWei(res[0]),web3.utils.fromWei(res[1]),web3.utils.fromWei(res[2]));

        res = await farmproxyinst.withdraw(0,0,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));

        console.log("====================================================================================")
    })

    it("[0025] check locked and pending balance,should pass", async()=>{
        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    it("[0030] check staker1 withdraw lp,should pass", async()=>{
        time.increase(2000);

        let block = await web3.eth.getBlock("latest");
        console.log("blocknum1=" + block.number)

        res = await farmproxyinst.allPendingReward(0,staker1)
        console.log("allpending=",res[0].toString(),res[1].toString(),res[2].toString());
        let stakeAmount = res[0];


        let preTeamBalance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let preTeamBalance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));

        let preBalance = web3.utils.fromWei(await melt.balanceOf(staker1));
        let pngpreBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));

        let lpprebalance = web3.utils.fromWei(await lp.balanceOf(staker1));

        res = await farmproxyinst.withdraw(0,stakeAmount,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBalance = web3.utils.fromWei(await melt.balanceOf(staker1))
        console.log("staker1 melt reward=" + (afterBalance - preBalance));

        let afterTeam1Balance1 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember1));
        let afterTeam1Balance2 = web3.utils.fromWei(await teamReward.claimableBalanceOf(teamMember2));
        console.log("team member1 melt reward=" + (afterTeam1Balance1 - preTeamBalance1));
        console.log("team member2 melt reward=" + (afterTeam1Balance2 - preTeamBalance2));

        let pngpafterBalance = web3.utils.fromWei(await pngInst.balanceOf(staker1));
        console.log("png reward=" + (pngpafterBalance - pngpreBalance));

        let lpafterbalance = web3.utils.fromWei(await lp.balanceOf(staker1));
        console.log("lp get back=" + (lpafterbalance - lpprebalance));

    })


//////////////////////////////////////////////////////////////////////////////////////////////////////////

    it("[0040] team withdraw reward,should pass", async()=>{
        let preBalance1 = web3.utils.fromWei(await melt.balanceOf(teamMember1));
        let preBalance2 = web3.utils.fromWei(await melt.balanceOf(teamMember2));

        let res = await teamReward.claimReward({from:teamMember1});
        assert.equal(res.receipt.status,true);

        res = await teamReward.claimReward({from:teamMember2});
        assert.equal(res.receipt.status,true);


        let afterBalance1 = web3.utils.fromWei(await melt.balanceOf(teamMember1));
        let afterBalance2 = web3.utils.fromWei(await melt.balanceOf(teamMember2));

        console.log("teamMember1 reward got=",afterBalance1-preBalance1);
        console.log("teamMember2 reward got=",afterBalance2-preBalance2);
    })
//////////////////////////////////////////////////////////////////////////////////
    it("[0050] check locked and pending balance,should pass", async()=>{
        let rewardInfo = await farmproxyinst.getRewardInfo(0,staker1);
        console.log("staker1 depositAmount",web3.utils.fromWei(rewardInfo[0]))  ;
        console.log("staker1 claimable",web3.utils.fromWei(rewardInfo[1]));
        console.log("staker1 locked",web3.utils.fromWei(rewardInfo[2]));
        console.log("staker1 claimed",web3.utils.fromWei(rewardInfo[3]));
        console.log("staker1 extern reward",web3.utils.fromWei(rewardInfo[4]));
        console.log("====================================================================================")
    })

    it("[0051] user withdraw reward in emergency,should pass", async()=>{
        let preBalance1 = web3.utils.fromWei(await melt.balanceOf(staker1));
        let preBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));
        console.log(preBalance1);

        let res = await tokenReleaseInt.setHalt(true);
        assert.equal(res.receipt.status,true);

        // res = await tokenReleaseInt.emergencyGetbackLeft();
        //   assert.equal(res.receipt.status,true);

        //console.log(res);
        // res = await tokenReleaseInt.emergencyGetbackLeft({from:staker2});
        // assert.equal(res.receipt.status,true);

        let afterBalance1 = web3.utils.fromWei(await melt.balanceOf(staker1));
        let afterBalance2 = web3.utils.fromWei(await melt.balanceOf(staker2));

        console.log("staker1 reward got=",afterBalance1-preBalance1);
        console.log("staker2 reward got=",afterBalance2-preBalance2);


    })
*/
})
