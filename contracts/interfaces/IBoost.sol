// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IBoost {
    function getTotalBoostedAmount(uint256 _pid,address _user,uint256 _lpamount,uint256 _baseamount)external view returns(uint256,uint256);
    function boostDeposit(uint256 _pid,address _account,uint256 _amount) external;

    function boostWithdraw(uint256 _pid,address _account,uint256 _amount) external;
    function boostStakedFor(uint256 _pid,address _account) external view returns (uint256);
    function boostTotalStaked(uint256 _pid) external view returns (uint256);
    function getBoostToken(uint256 _pid) external view returns(address);

    function setBoostFunctionPara(uint256 _pid,uint256 _para0,uint256 _para1, uint256 _para2) external;
    function setBoostFarmFactorPara(uint256 _pid, bool  _enableTokenBoost, address _boostToken, uint256 _minBoostAmount, uint256 _maxIncRatio) external;
    function setWhiteListMemberStatus(uint256 _pid,address _user,bool _status)  external;

    function setFixedWhitelistPara(uint256 _pid,uint256 _incRatio,uint256 _whiteListfloorLimit) external;
    function setFixedTeamRatio(uint256 _pid,uint256 _ratio) external;
    //function setMulsigAndFarmChef ( address _multiSignature,  address _farmChef) external;

    function whiteListLpUserInfo(uint256 _pid,address _user) external view returns (bool);

}