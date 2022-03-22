// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IBoost {
    function getTotalBoostedAmount(uint256 _pid,address _user,uint256 _lpamount,uint256 _baseamount)external view returns(uint256,uint256);
    function boostDeposit(uint256 _pid,address _account,uint256 _amount) external;
    function boostApplyWithdraw(uint256 _pid,address _account,uint256 _amount) external;
    function cancelAllBoostApplyWithdraw(uint256 _pid,address _account) external;
    function boostWithdraw(uint256 _pid,address _account) external;
    function boostStakedFor(uint256 _pid,address _account) external view returns (uint256);
    function boostTotalStaked(uint256 _pid) external view returns (uint256);
    function getBoostToken(uint256 _pid) external view returns(address);
    function boostTotalWithdrawPendingFor(uint256 _pid,address _account) external view returns (uint256);
    function boostAvailableWithdrawPendingFor(uint256 _pid,address _account) external view returns (uint256,uint256);
}