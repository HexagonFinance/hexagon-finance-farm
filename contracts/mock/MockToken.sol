// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../flake/ERC20.sol";
import "../libraries/Ownable.sol";

contract MockToken is ERC20, Ownable {
    string public name;
    uint256 public decimal;
    string public symbol;

    constructor(string memory _name,string memory _symbol,uint256 _decimal) public {
        name = _name;
        symbol = _symbol;
        decimal = _decimal;
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (WanSwapFarm).
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}