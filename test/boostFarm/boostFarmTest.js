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
    //let rewardOneDay = web3.utils.toWei(""+3600*24, 'ether');
    let rewardPerSec = web3.utils.toWei("1", 'ether');//new BN(rewardOneDay).div(new BN(3600*24));
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

    let VAL_1 = web3.utils.toWei('1', 'ether');
    let VAL_1000 =  web3.utils.toWei('1000', 'ether');
    let VAL_10000 =  web3.utils.toWei('10000', 'ether');
    let VAL_430000 =  web3.utils.toWei('43000', 'ether');

    let VAL_1M = web3.utils.toWei('1000000', 'ether');
    let VAL_10M = web3.utils.toWei('10000000', 'ether');
    let VAL_99M = web3.utils.toWei(  '99999999', 'ether');
    let VAL_100M = web3.utils.toWei('100000000', 'ether');
    let VAL_1B = web3.utils.toWei('1000000000', 'ether');
    let VAL_10B = web3.utils.toWei('10000000000', 'ether');

    let WITHTELIST_MINIMUM = VAL_1M ;

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
        res = await booster.setFixedTeamRatio(0,new BN(100));//10%
        assert.equal(res.receipt.status,true);

        res = await booster.setFixedWhitelistPara(0,new BN(100),WITHTELIST_MINIMUM);//10%,
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
                                                    boostToken.address     //address _boostToken
                                                );

        assert.equal(res.receipt.status,true);

    })

    it("[0010] stake lp in farm pool,should pass", async()=>{
         let poolInfo = await farminst.poolInfo(0);
         console.log(poolInfo[0].toString(10),poolInfo[1].toString(10),poolInfo[2].toString(10));

        // ////////////////////////staker1///////////////////////////////////////////////////////////
         res = await lp.approve(farminst.address,VAL_1B,{from:staker1});
         assert.equal(res.receipt.status,true);

         let preBal = await lp.balanceOf(farminst.address);
         console.log("prebalance=",preBal.toString(10));
         res = await farminst.deposit(0,VAL_1,staker1,{from:staker1});
         assert.equal(res.receipt.status,true);
         time.increase(1);

        let pending = await farminst.pendingFlake(0,staker1);
        console.log("pending flake",pending[0].toString(10),pending[1].toString(10),pending[2].toString(10));

    })

    it("[0020] withdraw reward,should pass", async()=>{
        let preBal = await flake.balanceOf(staker1);
        console.log("prebalance=",preBal.toString(10));
        res = await farminst.harvest(0,staker1,{from:staker1});
        assert.equal(res.receipt.status,true);

        let afterBal = await flake.balanceOf(staker1);
        console.log("afterbalance=",afterBal.toString(10));

        let diff = web3.utils.fromWei(afterBal) - web3.utils.fromWei(preBal);

        console.log("reward get:",diff);
    })

    it("[0030] boost token ,should pass", async()=>{
        res = await boostToken.approve(farminst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_1000,{from:staker1});
        assert.equal(res.receipt.status,true);

        let tokenBoostRatio = await booster.getUserBoostRatio(0,staker1);
        console.log(tokenBoostRatio[0].toString(10),tokenBoostRatio[0].toString(10))

        let pending = await farminst.pendingFlake(0,staker1);
        console.log("pending flake",pending[0].toString(10),pending[1].toString(10),pending[2].toString(10));
    })

})
