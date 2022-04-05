// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

import "../libraries/SafeMath.sol";
import "./hexagonBoostStorage.sol";
import "../libraries/SmallNumbers.sol";
import "../interfaces/IMiniChefV2.sol";

contract hexagonBoost is hexagonBoostStorage/*,proxyOwner*/{
    using SafeMath for uint256;
    using BoringERC20 for IERC20;


    modifier onlyMCV2() {
        require(msg.sender==farmChef, "not farmChef");
        _;
    }

    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not mulsafe");
        _;
    }

    constructor ( address _multiSignature,
                  address _farmChef )
        public
    {
        safeMulsig = _multiSignature;
        farmChef = _farmChef;
    }

    function setMulsigAndFarmChef ( address _multiSignature,
                                    address _farmChef)
        external
        onlyOrigin
    {
        safeMulsig = _multiSignature;
        farmChef = _farmChef;
    }

    function setFixedTeamRatio(uint256 _pid,uint256 _ratio)
        external onlyMCV2
    {
        boostPara[_pid].fixedTeamRatio = _ratio;
    }

    function setFixedWhitelistPara(uint256 _pid,uint256 _incRatio,uint256 _whiteListfloorLimit)
        external onlyMCV2
    {
        //_incRatio,0 whiteList increase will stop
        boostPara[_pid].fixedWhitelistRatio = _incRatio;
        boostPara[_pid].whiteListfloorLimit = _whiteListfloorLimit;
    }

    function setWhiteListMemberStatus(uint256 _pid,address _user,bool _status)
        external onlyMCV2
    {
            whiteListLpUserInfo[_pid][_user] = _status;
    }

    function setBoostFarmFactorPara(uint256 _pid,
                                    uint256 _lockTime,
                                    bool    _enableTokenBoost,
                                    address _boostToken,
                                    uint256 _minBoostAmount,
                                    uint256 _maxIncRatio)
        external
        onlyMCV2
    {
        boostPara[_pid].lockTime = _lockTime;
        boostPara[_pid].enableTokenBoost = _enableTokenBoost;
        boostPara[_pid].boostToken = _boostToken;
        boostPara[_pid].emergencyWithdraw = false;

        if(_minBoostAmount==0) {
            boostPara[_pid].minBoostAmount = _minBoostAmount;
        } else {
            boostPara[_pid].minBoostAmount = 500 ether;
        }

        if(_maxIncRatio==0) {
            boostPara[_pid].maxIncRatio = 50*SmallNumbers.FIXED_ONE;
        } else {
            boostPara[_pid].maxIncRatio = _maxIncRatio;
        }

        IERC20(boostPara[_pid].boostToken).approve(farmChef,uint256(-1));
    }

    function setBoostFunctionPara(uint256 _pid,
        uint256 _para0,
        uint256 _para1,
        uint256 _para2)
        external
        onlyMCV2
    {
        //log(5)(amount+LOG_PARA1)- LOG_PARA2
        if(_para0==0) {
            boostPara[_pid].log_para0 = 5;
        } else {
            boostPara[_pid].log_para0 = _para0;
        }

        if(_para1==0) {
            boostPara[_pid].log_para1 = 500000e18;
        } else {
            boostPara[_pid].log_para1 = _para1;
        }

        if(_para2==0) {
            boostPara[_pid].log_para2 = 329*rayDecimals/10;
        } else {
            boostPara[_pid].log_para2 = _para2;
        }
    }
    //////////////////////////////////////////////////////////////////////////////////////////////////////
    function getTotalBoostedAmount(uint256 _pid,address _user,uint256 _lpamount,uint256 _baseamount)
        public view returns(uint256,uint256)
    {
       uint256 whiteListBoostAmount = 0;
       if(isWhiteListBoost(_pid)) {
           whiteListBoostAmount = getWhiteListIncAmount(_pid,_user,_lpamount,_baseamount);
       }

       uint256  tokenBoostAmount = 0;
       if(isTokenBoost(_pid)) {
           //increased amount + _baseamount
           tokenBoostAmount = getUserBoostIncAmount(_pid,_user,_baseamount);
       }

       uint256 totalBoostAmount = tokenBoostAmount.add(whiteListBoostAmount);

       if(isTeamRoyalty(_pid)) {
           uint256 teamAmount = getTeamAmount(_pid,totalBoostAmount);
           return (totalBoostAmount.sub(teamAmount),teamAmount);
       } else {
           return (totalBoostAmount,0);
       }
    }

    function getTeamRatio(uint256 _pid)
        public view returns(uint256,uint256)
    {
          return (boostPara[_pid].fixedTeamRatio,RATIO_DENOM);
    }

    function getTeamAmount(uint256 _pid,uint256 _baseamount)
        public view returns(uint256)
    {
        return _baseamount.mul(boostPara[_pid].fixedTeamRatio).div(RATIO_DENOM);
    }

    function getWhiteListIncRatio(uint256 _pid,address _user,uint256 _lpamount)
        public view returns(uint256,uint256)
    {
        uint256 userIncRatio = 0;
        //current stake must be over minimum require lp amount
        if (whiteListLpUserInfo[_pid][_user]&&_lpamount >= boostPara[_pid].whiteListfloorLimit) {
            userIncRatio = boostPara[_pid].fixedWhitelistRatio;
        }

        return (userIncRatio,RATIO_DENOM);
    }

    function getWhiteListIncAmount(uint256 _pid,address _user,uint256 _lpamount,uint256 _baseamount)
        public view returns(uint256)
    {
        (uint256 ratio,uint256 denom) = getWhiteListIncRatio(_pid,_user,_lpamount);
        return _baseamount.mul(ratio).div(denom);
    }

    function getUserBoostRatio(uint256 _pid,address _account)
        external view returns(uint256,uint256)
    {
        return  boostRatio(_pid,balances[_pid][_account]);
    }

    function getUserBoostIncAmount(uint256 _pid,address _account,uint256 _baseamount)
        public view returns(uint256)
    {
        (uint256 ratio,uint256 denom) =  boostRatio(_pid,balances[_pid][_account]);
        //ratio is 1.0.....
        return _baseamount.mul(ratio).div(denom);
    }

    function getBoostToken(uint256 _pid)
        external view returns(address)
    {
        return boostPara[_pid].boostToken;
    }

    function boostRatio(uint256 _pid,uint256 _amount)
        public view returns(uint256,uint256)
    {

        if(_amount<boostPara[_pid].minBoostAmount
            ||!boostPara[_pid].enableTokenBoost
            ||boostPara[_pid].log_para0==0
            ||boostPara[_pid].log_para1==0
            ||boostPara[_pid].log_para2==0
        ) {
            return (rayDecimals,rayDecimals);
        } else {
            //log(LOG_PARA0)(amount+LOG_PARA1)- LOG_PARA2
            _amount = SmallNumbers.FIXED_ONE.mul(_amount.add(boostPara[_pid].log_para1));
            uint256 log2_x = SmallNumbers.fixedLog2(_amount);
            uint256 log2_5 = SmallNumbers.fixedLog2(boostPara[_pid].log_para0.mul(SmallNumbers.FIXED_ONE));
            uint256 ratio = log2_x.mul(rayDecimals).div(log2_5);
            //log_para2 already mul raydecimals
            ratio = ratio.sub(boostPara[_pid].log_para2);
            if(ratio>boostPara[_pid].maxIncRatio) {
                ratio = boostPara[_pid].maxIncRatio;
            }
            return (ratio,rayDecimals);
        }
    }

    function boostDeposit(uint256 _pid,address _account,uint256 _amount)
        external onlyMCV2
    {

        require(boostPara[_pid].enableTokenBoost,"pool is not allow boost");

        totalsupplies[_pid] = totalsupplies[_pid].add(_amount);
        balances[_pid][_account] = balances[_pid][_account].add(_amount);

        emit BoostDeposit(_pid,_account,_amount);
    }

    function boostWithdraw(uint256 _pid,address _account,uint256 _amount)
        external onlyMCV2
    {
        require(balances[_pid][_account]>=_amount);

        totalsupplies[_pid] = totalsupplies[_pid].sub(_amount);
        balances[_pid][_account] = balances[_pid][_account].sub(_amount);

        IERC20(boostPara[_pid].boostToken).safeTransfer(_account, _amount);


        emit BoostWithdraw(_pid,_account, _amount);
    }

    function boostStakedFor(uint256 _pid,address _account) public view returns (uint256) {
        return balances[_pid][_account];
    }

    function boostTotalStaked(uint256 _pid) public view returns (uint256){
        return totalsupplies[_pid];
    }

    function isTokenBoost(uint256 _pid) public view returns (bool){
        return boostPara[_pid].enableTokenBoost;
    }

    function isWhiteListBoost(uint256 _pid) public view returns (bool){
        return  boostPara[_pid].fixedWhitelistRatio>0;
    }

    function isTeamRoyalty(uint256 _pid) public view returns (bool){
        return  boostPara[_pid].fixedTeamRatio>0;
    }

}