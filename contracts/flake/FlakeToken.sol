// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import './ERC20.sol';

contract FlakeToken is ERC20{

    string private name_;
    string private symbol_;
    uint8  private decimals_;

    //total tokens supply
    uint256 constant public MAX_TOTAL_TOKEN_AMOUNT = 100_000_000 ether;
    uint256 constant public MAX_RESERVE_AMOUNT = 10_000_000 ether;     //10% for reserve
    uint256 constant public MAX_BUSINESS_EXPANDING = 5_000_000 ether;  //5% for business expanding

    constructor(string memory tokenName,
                string memory tokenSymbol,
                uint8 tokenDecimal,
                address initHolder,
                address reserveHolder,
                address businessHolder)
        public
    {
        name_ = tokenName;
        symbol_ = tokenSymbol;
        decimals_ = tokenDecimal;

        _mint(reserveHolder,MAX_RESERVE_AMOUNT);
        _mint(businessHolder,MAX_BUSINESS_EXPANDING);
        _mint(initHolder,MAX_TOTAL_TOKEN_AMOUNT.sub(MAX_RESERVE_AMOUNT).sub(MAX_BUSINESS_EXPANDING));
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