// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/SafeMath.sol";
import "../libraries/Ownable.sol";
import "./IERC20.sol";

contract FlakeSupply is Ownable{
    using SafeMath for uint256;
    address public tokenAddress;
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
        for(uint256 i=0;i<fixedBalAddress.length;i++) {
            if(fixedBalAddress[i] == _fixedBalAddress) {
                fixedBalAddress[i] = address(0);
            }
        }
    }

    function getPriceTokenDecimal(address _tokenAddress) public view returns(uint256){
        return (10**IERC20(_tokenAddress).decimals());
    }

    function circulateSupply()
        public
        view
        returns (uint256)
    {
        uint256 fixedTotal = 0;
        for(uint256 i=0;i<fixedBalAddress.length;i++) {
            if(fixedBalAddress[i] != address (0)) {
               uint256 bal = IERC20(tokenAddress).balanceOf(fixedBalAddress[i]);
               fixedTotal = fixedTotal.add(bal);
            }
        }

        uint256 totalSupply = IERC20(tokenAddress).totalSupply();
        uint256 decimal = getPriceTokenDecimal(tokenAddress);
        return totalSupply.sub(fixedTotal).div(decimal);
    }

}
