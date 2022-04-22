// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../flake/ERC20.sol";
import "../libraries/Ownable.sol";

contract MockToken is ERC20, Ownable {
    string public name;
    uint256 public decimals_;
    string public symbol;

    constructor(string memory _name,string memory _symbol,uint256 _decimal) public {
        name = _name;
        symbol = _symbol;
        decimals_ = _decimal;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return uint8(decimals_);
    }

}