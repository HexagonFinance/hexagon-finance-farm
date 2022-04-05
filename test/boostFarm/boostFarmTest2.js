const { time, expectEvent} = require("@openzeppelin/test-helpers");
const MinePool = artifacts.require('MiniChefV2');

const LpToken = artifacts.require('MockToken');
const FlakeToken = artifacts.require("MockToken");
const BoostToken = artifacts.require("MockToken");

const BoostSc = artifacts.require("hexagonBoost");

const assert = require('chai').assert;
const Web3 = require('web3');

const BN = require("bignumber.js");
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
    let maxIncRatio = new BN("450000000");//uint256 _maxIncRatio,4.5
    let lockTime =  new BN(""+30*3600*24);//uint256 _lockTime,
    let enableTokenBoost = true;    //bool    _enableTokenBoost,
    let boostToken;   //address _boostToken

////////////////////////////////////////////////////////////////////////
    let staker1 = accounts[2];
    let staker2 = accounts[3];
    let staker3 = accounts[6];

    let VAL_1 = web3.utils.toWei('1', 'ether');
    let VAL_1000 =  web3.utils.toWei('1000', 'ether');
    let VAL_2800 =  web3.utils.toWei('2800', 'ether');
    let VAL_10000 =  web3.utils.toWei('10000', 'ether');
    let VAL_448000 =  web3.utils.toWei('448000', 'ether');
    let VAL_548000 =  web3.utils.toWei('548000', 'ether');

    let VAL_1M = web3.utils.toWei('1000000', 'ether');
    let VAL_10M = web3.utils.toWei('10000000', 'ether');
    let VAL_99M = web3.utils.toWei(  '99999999', 'ether');
    let VAL_100M = web3.utils.toWei('100000000', 'ether');
    let VAL_1B = web3.utils.toWei('1000000000', 'ether');
    let VAL_10B = web3.utils.toWei('10000000000', 'ether');

    let VAL_2000000 = web3.utils.toWei('20000000', 'ether');
    let VAL_1000000 = web3.utils.toWei('10000000', 'ether');

    let WITHTELIST_MINIMUM = VAL_1M ;

    let farminst;
    let lp;//stake token

    let booster;

    async function havestTest(staker) {
        let preBal = await flake.balanceOf(staker);
        console.log("prebalance=",preBal.toString(10));

        res = await farminst.harvest(0,staker,{from:staker});
        assert.equal(res.receipt.status,true);

        let afterBal = await flake.balanceOf(staker);
        console.log("afterbalance=",afterBal.toString(10));

        let diff = web3.utils.fromWei(afterBal) - web3.utils.fromWei(preBal);

        console.log("reward get:",diff);
    }

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
        res = await farminst.setFixedTeamRatio(0,new BN(100));//10%
        assert.equal(res.receipt.status,true);

        res = await farminst.setFixedWhitelistPara(0,new BN(100),WITHTELIST_MINIMUM);//10%,
        assert.equal(res.receipt.status,true);

        res = await farminst.setWhiteList(0,[accounts[8],accounts[9]]);
        assert.equal(res.receipt.status,true);

        res = await farminst.setBoostFarmFactorPara( 0,
                                                    lockTime,//uint256 _lockTime,
                                                    enableTokenBoost,    //bool    _enableTokenBoost,
                                                    boostToken.address,     //address _boostToken
                                                    baseBoostTokenAmount,//uint256 _baseBoostTokenAmount, 1000 ether
                                                    maxIncRatio//uint256 _maxIncRatio,4.5
                                                );

        assert.equal(res.receipt.status,true);

        let para0 = new BN(5);
        let para1 = web3.utils.toWei('500000', 'ether');
        let para2 = new BN(3290000000);
        res = await farminst.setBoostFunctionPara( 0,
                                                  para0,//uint256 _lockTime,
                                                  para1,
                                                  para2
                                                );
        assert.equal(res.receipt.status,true);


    })

    it("[0001] boost token ratio,should pass", async()=>{
        res = await boostToken.approve(farminst.address,VAL_10B,{from:staker2});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_2000000,{from:staker2});
        assert.equal(res.receipt.status,true);

        let tokenBoostRatio = await booster.getUserBoostRatio(0,staker2);
        let ratio = new BN(tokenBoostRatio[0].toString(10)).div(new BN(tokenBoostRatio[1].toString(10))).toString(10);
        console.log(ratio);

        res = await boostToken.approve(farminst.address,VAL_10B,{from:staker3});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_1000000,{from:staker3});
        assert.equal(res.receipt.status,true);

        tokenBoostRatio = await booster.getUserBoostRatio(0,staker3);
         ratio = new BN(tokenBoostRatio[0].toString(10)).div(new BN(tokenBoostRatio[1].toString(10))).toString(10);
        console.log(ratio);

    })

    it("[0010] check team ratio,should pass", async()=>{
        let teamRatio = await booster.getTeamRatio(0);
        let percent = new BN(teamRatio[0].toString(10)).div(new BN(teamRatio[1].toString(10))).toString(10);
        console.log(percent);
        assert.equal(percent,""+0.1,"team ratio is 0.1")
    })

    it("[0020] boost token ratio,should pass", async()=>{
        res = await boostToken.approve(farminst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_1000,{from:staker1});
        assert.equal(res.receipt.status,true);

        let tokenBoostRatio = await booster.getUserBoostRatio(0,staker1);

        console.log(new BN(tokenBoostRatio[0].toString(10)).div(new BN(tokenBoostRatio[1].toString(10))).toString(10));

    })

    it("[0030] boost token ratio,should pass", async()=>{
        res = await boostToken.approve(farminst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_1000,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_1000,{from:staker1});
        assert.equal(res.receipt.status,true);

        let tokenBoostRatio = await booster.getUserBoostRatio(0,staker1);
        let ratio = new BN(tokenBoostRatio[0].toString(10)).div(new BN(tokenBoostRatio[1].toString(10))).toString(10);
        console.log(ratio);
       // assert.equal(ratio,"0.05","2000 boost ratio should be same");

        res = await farminst.boostDeposit(0,VAL_2800,{from:staker1});
        assert.equal(res.receipt.status,true);

        tokenBoostRatio = await booster.getUserBoostRatio(0,staker1);
        ratio = new BN(tokenBoostRatio[0].toString(10)).div(new BN(tokenBoostRatio[1].toString(10))).toString(10);
        console.log(ratio);
        //assert.equal(ratio,"0.078","2000 boost ratio should be same");

    })



    it("[0040] MAX ratio,should pass", async()=>{
        res = await boostToken.approve(farminst.address,VAL_1B,{from:staker1});
        assert.equal(res.receipt.status,true);

        res = await farminst.boostDeposit(0,VAL_448000,{from:staker1});
        assert.equal(res.receipt.status,true);

        let tokenBoostRatio = await booster.getUserBoostRatio(0,staker1);
        let ratio = new BN(tokenBoostRatio[0].toString(10)).div(new BN(tokenBoostRatio[1].toString(10))).toString(10);
        console.log(ratio);
       // assert.equal(ratio,"4.5","448000 boost ratio should be same");
    })


    it("[0040] whitelist ratio,should pass", async()=>{
       // [accounts[8],accounts[9]
        let whiteListRatio = await booster.getWhiteListIncRatio(0,accounts[8],0);
        let ratio = new BN(whiteListRatio[0].toString(10)).div(new BN(whiteListRatio[1].toString(10))).toString(10);
        console.log(ratio);
       // assert.equal(ratio,"0","448000 boost ratio should be same");

        whiteListRatio = await booster.getWhiteListIncRatio(0,accounts[8],WITHTELIST_MINIMUM);
        ratio = new BN(whiteListRatio[0].toString(10)).div(new BN(whiteListRatio[1].toString(10))).toString(10);
        console.log(ratio);
       // assert.equal(ratio,"0.1","448000 boost ratio should be same");

        whiteListRatio = await booster.getWhiteListIncRatio(0,accounts[9],WITHTELIST_MINIMUM);
        ratio = new BN(whiteListRatio[0].toString(10)).div(new BN(whiteListRatio[1].toString(10))).toString(10);
        console.log(ratio);
        //assert.equal(ratio,"0.1","448000 boost ratio should be same");
    })

})
