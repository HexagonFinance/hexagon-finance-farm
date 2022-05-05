// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import './ERC20.sol';

contract FlakeToken is ERC20{

    string private name_ = "FLAKE";
    string private symbol_ = "FLAKE";
    uint8  private decimals_ = 18;

    //total tokens supply
    uint256 constant public AIRDROPS_LBP_AMOUNT = 5_000_000 ether;  //5%
    uint256 constant public TEAM_AMOUNT = 6_000_000 ether;  //6%
    uint256 constant public PARTNERS_AMOUNT = 12_000_000 ether;  //12%
    uint256 constant public TREASURE_AMOUNT = 12_000_000 ether;  //12%
    uint256 constant public LIQUIDITY_MINING_EMISSIONS_AMOUNT = 65_000_000 ether;  //65%


    address constant public AIRDROPS_LBP_ADDRESS = 0x0B15679740123FF6952480e6D6Fe375F50299014;
    address constant public TEAM_ADDRESS = 0x10A108faD8d396aCb42A7f00468d4d6f8429e250;
    address constant public PARTNERS_ADDRESS = 0x139C223371025f5289eE639757EbEcdc2359a725;
    address constant public TREASURE_ADDRESS = 0x76bED429d329756088eDd6327cb734dA2564bc57;
    address constant public LIQUIDITY_MINING_EMISSIONS_ADDRESS = 0xd61B65C0058ce0EC19A238cAC41BBbabBE7fE4F4;

    constructor()
        public
    {
        _mint(AIRDROPS_LBP_ADDRESS,AIRDROPS_LBP_AMOUNT);
        _mint(TEAM_ADDRESS,TEAM_AMOUNT);
        _mint(PARTNERS_ADDRESS,PARTNERS_AMOUNT);
        _mint(TREASURE_ADDRESS,TREASURE_AMOUNT);
        _mint(LIQUIDITY_MINING_EMISSIONS_ADDRESS,LIQUIDITY_MINING_EMISSIONS_AMOUNT);
    }

    /**
     * @return the name of the token.
     */
    function name() external view returns (string memory) {
        return name_;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() external view returns (string memory) {
        return symbol_;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() external view returns (uint8) {
        return decimals_;
    }

}