/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2020 defrost Protocol
 */
pragma solidity 0.6.12;

//import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "../libraries/SafeMath.sol";
//import "../libraries/proxyOwner.sol";

import "./veFlakeSavingsData.sol";
import "./veFlakeToken/veFlakeToken.sol";
/**
 * @title systemCoin deposit pool.
 * @dev Deposit systemCoin earn interest systemcoin.
 *
 */
contract veFlakeSavings is veFlakeSavingsData/*,proxyOwner*/{

    using SafeMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;

    //using SignedSafeMath for int256;


    /**
     * @dev default function for foundation input miner coins.
     */
    constructor (address _flake,
                 address _multiSignature//,
                // address _origin0,
                // address _origin1
                )
      // proxyOwner(_multiSignature,_origin0,_origin1)
       public
    {
        flake = _flake;
        veflake = new veFlakeToken("Hexagon Flake Token","FLAKE",18,address(this));
        safeMulsig = _multiSignature;
    }

//    function () external payable{
//        require(false);
//    }

    function setInterestMaxMinRatio(uint256 _maxRate, uint256 _minRate)
        external
        onlyOrigin {
        maxRate = _maxRate;
        minRate = _minRate;
    }

    function setInterestInfo(uint256 _interestRate,uint256 _interestInterval)
        external
        onlyOrigin
    {

        if (accumulatedRate == 0){
            accumulatedRate = rayDecimals;
        }

        require(_interestRate<=1e27,"input stability fee is too large");
        require(_interestInterval>0,"input mine Interval must larger than zero");

        uint256 newLimit = rpower(uint256(1e27+_interestRate),/*one year*/31536000/_interestInterval,rayDecimals);
        require(newLimit<=maxRate && newLimit>=minRate,"interest rate is out of range");

        _interestSettlement();

        interestRate = _interestRate;
        interestInterval = _interestInterval;

        emit SetInterestInfo(msg.sender,_interestRate,_interestInterval);
    }

    function newAccumulatedRate() internal view returns (uint256){
        uint256 newRate = rpower(uint256(1e27+interestRate),(currentTime()-latestSettleTime)/interestInterval,rayDecimals);
        return accumulatedRate.mul(newRate)/rayDecimals;
    }

    function currentTime() internal view returns (uint256){
        return block.timestamp;
    }

    function _interestSettlement() internal {
        uint256 _interestInterval = interestInterval;
        if (_interestInterval>0){
            uint256 newRate = newAccumulatedRate();
            accumulatedRate = newRate;
            latestSettleTime = currentTime()/_interestInterval*_interestInterval;
        }else{
            latestSettleTime = currentTime();
        }
    }

    function getFlakeAmount(uint256 _veFlakeAmount) public view returns (uint256) {
        uint256 newRate = newAccumulatedRate();
        return _veFlakeAmount.mul(newRate).div(rayDecimals);
    }

    function getVeFlakeAmount(uint256 _flakeAmount) public view returns (uint256) {
        uint256 newRate = newAccumulatedRate();
        return _flakeAmount.mul(rayDecimals)/newRate;
    }

    function deposit(uint256 _amount)
        external
        nonReentrant
        notHalted
    {
        require(interestRate>0,"interest rate is not set");

        IERC20(flake).safeTransferFrom(msg.sender, address(this), _amount);

        _interestSettlement();

        uint256 veFlakeAmount = _amount.mul(rayDecimals)/accumulatedRate;
        veflake.mint(msg.sender,veFlakeAmount);

        emit Save(msg.sender,address(flake), _amount);
    }

    //user possible to get veFlakeAmount by transfer from another address
    function withdraw( uint256 _veFlakeAmount/*veFlakeAmount amout*/)
        external
        nonReentrant
        notHalted
    {

        _interestSettlement();
        uint256 veFlakeAmountBal = veflake.balanceOf(msg.sender);
        if(_veFlakeAmount>veFlakeAmountBal) {
            _veFlakeAmount = veFlakeAmountBal;
        }
        uint256 flakeAmount = _veFlakeAmount.mul(accumulatedRate)/rayDecimals;

        veflake.burn(msg.sender,_veFlakeAmount);

        IERC20(flake).safeTransfer(msg.sender, flakeAmount);

        emit Withdraw(msg.sender,address(flake), flakeAmount);

    }

    function rpower(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
        assembly {
            switch x case 0 {switch n case 0 {z := base} default {z := 0}}
            default {
                switch mod(n, 2) case 0 { z := base } default { z := x }
                let half := div(base, 2)  // for rounding.
                for { n := div(n, 2) } n { n := div(n,2) } {
                let xx := mul(x, x)
                if iszero(eq(div(xx, x), x)) { revert(0,0) }
                let xxRound := add(xx, half)
                if lt(xxRound, xx) { revert(0,0) }
                x := div(xxRound, base)
                if mod(n,2) {
                    let zx := mul(z, x)
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0,0) }
                    let zxRound := add(zx, half)
                    if lt(zxRound, zx) { revert(0,0) }
                    z := div(zxRound, base)
                }
            }
            }
        }
    }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //    /**
    //     * @param addr The user to look up staking information for.
    //     * @return The number of staking tokens deposited for addr.
    //     */
    function totalStakedFor(address _account) public view returns (uint256) {
         return getFlakeAmount(veflake.balanceOf(_account));
    }

    function totalStaked() public view returns (uint256){
       return getFlakeAmount(veflake.totalSupply());
    }

    function getbackLeftMiningToken(address _reciever)  external
        onlyOrigin
    {

        uint256 totalasset = getFlakeAmount(veflake.totalSupply());
        //get back flake for future interest
        if(IERC20(flake).balanceOf(address(this))>totalasset) {
            uint256 bal =  IERC20(flake).balanceOf(address(this)).sub(totalasset);
            IERC20(flake).safeTransfer(_reciever,bal);
        }

    }

}