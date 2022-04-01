// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import '../flake/ERC20.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';

contract veFlake is ERC20 {
    using SafeMath for uint256;
    IERC20 public flake;

    string private name_;
    string private symbol_;
    uint8  private decimals_;

    // Define the token contract
    constructor(IERC20 _flake,string memory tokenName,string memory tokenSymbol,uint256 tokenDecimal) public {
        flake = _flake;
        name_ = tokenName;
        symbol_ = tokenSymbol;
        decimals_ = uint8(tokenDecimal);
    }

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return name_;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return symbol_;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return decimals_;
    }


    function enter(uint256 _amount) public {
        // Gets the amount of locked in the contract
        uint256 totalFlake = flake.balanceOf(address(this));
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        // If no veFlake exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalFlake == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of veFlake the flake is worth. The ratio will change overtime, as veFlake is burned/minted and flake deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalFlake);
            _mint(msg.sender, what);
        }

        // Lock the flake in the contract
        flake.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your flake.
    // Unlocks the staked + gained flake and burns veFlake
    function leave(uint256 _share) public {
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of flake the veFlake is worth
        uint256 what = _share.mul(flake.balanceOf(address(this))).div(
            totalShares
        );

        _burn(msg.sender, _share);

        flake.transfer(msg.sender, what);
    }
}