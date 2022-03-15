pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

import "../libraries/SafeMath.sol";
import "../libraries/proxyOwner.sol";
import "./hexagonBoostStorage.sol";

contract hexagonBoost is hexagonBoostStorage/*,proxyOwner*/{
    using SafeMath for uint256;
    using BoringERC20 for IERC20;

    modifier notZeroAddress(address inputAddress) {
        require(inputAddress != address(0), "input zero address");
        _;
    }

    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not setting safe contract");
        _;
    }

    constructor ( address _multiSignature,
                  // address _origin0,
                  // address _origin1
                  address _farmChef
    )
       /* proxyOwner(_multiSignature, _origin0, _origin1)*/
        public
    {
        safeMulsig = _multiSignature;
        farmChef = _farmChef;
    }


    function setFixedTeamRatio(uint256 _pid,uint256 _ratio)
        public onlyOrigin
    {
        boostPara[_pid].fixedTeamRatio = _ratio;
    }

    function setFixedWhitelistPara(uint256 _pid,uint256 _incRatio,uint256 _whiteListfloorLimit)
        public onlyOrigin
    {
        //_incRatio,0 whiteList increase will stop
        boostPara[_pid].fixedWhitelistRatio = _incRatio;
        boostPara[_pid].whiteListfloorLimit = _whiteListfloorLimit;
    }

    function setWhiteList(uint256 _pid,address[] memory _user)
        public onlyOrigin
    {
        require(_user.length>0,"array length is 0");
        for(uint256 i=0;i<_user.length;i++) {
            whiteListLpUserInfo[_pid][_user[i]] = true;
        }
    }

    function setWhiteListMemberStatus(uint256 _pid,address _user,bool _status)
     public onlyOrigin
    {
        whiteListLpUserInfo[_pid][_user] = _status;
    }

    function setBoostFarmFactorPara(uint256 _pid,
                                    uint256 _baseBoostTokenAmount,
                                    uint256 _baseIncreaseRatio,
                                    uint256 _boostTokenStepAmount,
                                    uint256 _ratioIncreaseStep,
                                    uint256 _maxIncRatio,
                                    uint256 _lockTime,
                                    bool    _enableTokenBoost,
                                    address _boostToken)
        external
        onlyOrigin
    {
        boostPara[_pid].baseBoostTokenAmount = _baseBoostTokenAmount; //default 1000 ether
        boostPara[_pid].baseIncreaseRatio = _baseIncreaseRatio; //default 3%
        boostPara[_pid].ratioIncreaseStep = _ratioIncreaseStep;//default 1%
        boostPara[_pid].boostTokenStepAmount = _boostTokenStepAmount; //default 1000 ether
        boostPara[_pid].maxIncRatio = _maxIncRatio;
        boostPara[_pid].lockTime = _lockTime;
        boostPara[_pid].enableTokenBoost = _enableTokenBoost;
        boostPara[_pid].boostToken = _boostToken;
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////
    function getTotalBoostedAmount(uint256 _pid,address _user,uint256 _lpamount,uint256 _baseamount)
        public view returns(uint256,uint256)
    {
       uint256 whiteListBoostAmount =  getWhiteListIncAmount(_pid,_user,_lpamount,_baseamount);
       uint256  tokenBoostAmount = getWhiteListIncAmount(_pid,_user,_lpamount,_baseamount);
       uint256 totalBoostAmount = _baseamount.add(whiteListBoostAmount).add(tokenBoostAmount);

       uint256 teamAmount = getTeamAmount(_pid,_baseamount);

       return (totalBoostAmount.sub(teamAmount),teamAmount);
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
        return _baseamount.mul(ratio).div(denom);
    }

    function boostRatio(uint256 _pid,uint256 _amount)
        public view returns(uint256,uint256)
    {

        if(_amount<boostPara[_pid].baseBoostTokenAmount
            ||!boostPara[_pid].enableTokenBoost) {
            return (0,rayDecimals);
        } else {
            //amount(wei)*(increase step)/per wei
            uint256 incRatio = _amount.sub(boostPara[_pid].baseBoostTokenAmount)
                                    .mul(boostPara[_pid].ratioIncreaseStep)
                                    .div(boostPara[_pid].boostTokenStepAmount);

            incRatio = boostPara[_pid].baseIncreaseRatio.add(incRatio);

            if(incRatio > boostPara[_pid].maxIncRatio) {
                incRatio = boostPara[_pid].maxIncRatio;
            }

            return (incRatio,rayDecimals);
        }
    }

    function boostDeposit(uint256 _pid,address _account,uint256 _amount) nonReentrant external {
        require(boostPara[_pid].enableTokenBoost,"pool is not allow boost");
        totalsupplies[_pid] = totalsupplies[_pid].add(_amount);
        balances[_pid][_account] = balances[_pid][_account].add(_amount);
        IERC20(boostPara[_pid].boostToken).safeTransferFrom(_account,address(this), _amount);
        emit BoostDeposit(_pid,_account,_amount);
    }

    function boostApplyWithdraw(uint256 _pid,address _account,uint256 _amount) nonReentrant external{
        totalsupplies[_pid] = totalsupplies[_pid].sub(_amount);
        balances[_pid][_account] = balances[_pid][_account].sub(_amount);
        uint64 unlockTime = currentTime()+uint64(boostPara[_pid].lockTime);
        userUnstakePending[_pid][_account].pendingAry.push(pendingItem(uint192(_amount),unlockTime));
        emit BoostApplyWithdraw(_pid,_account, _amount);
    }

    function boostWithdraw(uint256 _pid,address _account) external nonReentrant{
        pendingGroup storage userPendings = userUnstakePending[_pid][_account];
        (uint256 amount,uint256 index) = boostWithdrawPendingFor(_pid,_account);

        if(amount>0) {
            for(uint64 i=userPendings.firstIndex;i<index;i++) {
                userPendings.pendingAry[i].pendingAmount = 0;
            }
            userPendings.firstIndex = uint64(index+1);
            IERC20(boostPara[_pid].boostToken).safeTransfer(_account, amount);
            emit BoostWithdraw(_pid,_account, amount);
        }
    }

    function boostWithdrawPendingFor(uint256 _pid,address _account) public view returns (uint256,uint256) {
        pendingGroup storage userPendings = userUnstakePending[_pid][_account];

        if( userPendings.pendingAry.length==0
           ||userPendings.firstIndex>=userPendings.pendingAry.length) {
            return(0,0);
        }

        uint256 index = searchPendingIndex(userPendings.pendingAry,userPendings.firstIndex,currentTime());
        //control tx num lower than 200
        if(index-userPendings.firstIndex>200) {
            index = userPendings.firstIndex+200;
        }

        uint256 amount = 0;
        for(uint64 i=userPendings.firstIndex;i<index;i++) {
            amount = amount.add(userPendings.pendingAry[i].pendingAmount);
        }
        return (amount,index);
    }

    function boostStakedFor(uint256 _pid,address _account) public view returns (uint256) {
        return balances[_pid][_account];
    }

    function boostTotalStaked(uint256 _pid) public view returns (uint256){
        return totalsupplies[_pid];
    }

    function currentTime() internal view returns(uint64){
        return uint64(block.timestamp);
    }

    function searchPendingIndex(pendingItem[] memory pendingAry,uint64 firstIndex,uint64 searchTime)
        internal
        pure
        returns (uint256)
    {
        uint256 length = pendingAry.length;
        //if first idx release time is not passed,return directly
        if(pendingAry[firstIndex].releaseTime >= searchTime) {
            return firstIndex;
        }

        uint256 min = firstIndex;
        uint256 max = length - 1;
        uint256 mid = 0;

        while (max > min) {
            mid = (max + min) / 2;
            //release time need to be bigger target time
            if(pendingAry[mid].releaseTime==searchTime) {
                 break;
            }
            if (pendingAry[mid].releaseTime < searchTime) {
                min = mid;
                //[i]<searchTime<=[i+1]
                if(pendingAry[mid+1].releaseTime>=searchTime) {
                    //outer use <, not include
                    mid = mid+1;
                    break;
                }
            } else {
                max = mid;
            }
        }

        return mid;
    }
}