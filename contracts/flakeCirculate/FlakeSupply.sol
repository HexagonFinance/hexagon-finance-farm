// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/SafeMath.sol";
import "../libraries/Ownable.sol";
import "./IERC20.sol";

contract FlakeSupply is Ownable{
    using SafeMath for uint256;
    address public tokenAddress;

    address[] public lockedBalAddress;
    address[] public fixedBalAddress;

    constructor(address _tokenAddress) public {
        tokenAddress = _tokenAddress;
    }

    function setTokenAddress(address _tokenAddress) public onlyOwner{
        tokenAddress = _tokenAddress;
    }

    function addFixedAddress(address _fixedBalAddress) public onlyOwner{
        fixedBalAddress.push(_fixedBalAddress);
    }

    function removeFixedAddress(address _fixedBalAddress) public onlyOwner{
        for(uint256 i=0;i< fixedBalAddress.length;i++) {
            if(fixedBalAddress[i] == _fixedBalAddress) {
                fixedBalAddress[i] = address(0);
            }
        }
    }

    function addLockedAddress(address _lockedBalAddress) public onlyOwner{
        lockedBalAddress.push(_lockedBalAddress);
    }

    function removeLockedAddress(address _lockedBalAddress) public onlyOwner{
        for(uint256 i=0;i<lockedBalAddress.length;i++) {
            if(lockedBalAddress[i] == _lockedBalAddress) {
                lockedBalAddress[i] = address(0);
            }
        }
    }

    function circulateSupply()
        public
        view
        returns (uint256)
    {
        uint256 fixedTotal = 0;
        for(uint256 i=0;i< fixedBalAddress.length;i++) {
            if(fixedBalAddress[i] != address (0)) {
               uint256 bal = IERC20(tokenAddress).balanceOf(fixedBalAddress[i]);
               fixedTotal = fixedTotal.add(bal);
            }
        }

        uint256 totalSupply = IERC20(tokenAddress).totalSupply();
        return totalSupply.sub(fixedTotal);
    }


    function lockedBalance()
    public
    view
    returns (uint256)
    {
        uint256 lockedTotal = 0;
        for(uint256 i=0;i< lockedBalAddress.length;i++) {
            if(lockedBalAddress[i] != address (0)) {
                uint256 bal = IERC20(tokenAddress).balanceOf(lockedBalAddress[i]);
                lockedTotal = lockedTotal.add(bal);
            }
        }

        return lockedTotal;
    }

    function lockedRatio()
    public
    view
    returns (uint256) {
        uint256 circulate = circulateSupply();

        if(circulate>0) {
          return lockedBalance().mul(1000).div(circulate);
        } else {
            return 0;
        }
    }



}
