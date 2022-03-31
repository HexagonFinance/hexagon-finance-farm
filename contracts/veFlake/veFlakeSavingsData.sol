/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2020 defrost Protocol
 */
pragma solidity 0.6.12;

import "../libraries/ReentrancyGuard.sol";
import "../libraries/Halt.sol";
import "./veFlakeToken/veFlakeToken.sol";

contract veFlakeSavingsData is Halt,ReentrancyGuard {

    uint256 public maxRate = 30e26;//1+200%
    uint256 public minRate = 0;

////////////////////////////////////////////////////////////////////
    address  public flake;

    veFlakeToken  public veflake;
    //Special decimals for calculation
    uint256 constant internal rayDecimals = 1e27;

    uint256 public totalAssetAmount;

    //interest rate
    uint256  public interestRate;
    uint256 public interestInterval;


    // latest time to settlement
    uint256 public latestSettleTime;
    uint256 public accumulatedRate;

    address public safeMulsig;
    //for test or use safe mulsig
    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not setting safe contract");
        _;
    }

    event SetInterestInfo(address indexed from,uint256 _interestRate,uint256 _interestInterval);
    event AddAsset(address indexed recieptor,uint256 amount);
    event SubAsset(address indexed account,uint256 amount,uint256 subOrigin);

    event InitContract(address indexed sender,address stakeToken,uint256 interestRate,uint256 interestInterval,
        uint256 assetCeiling,uint256 assetFloor);
    event Save(address indexed sender, address indexed account, uint256 amount);
    event Withdraw(address indexed sender, address indexed account, uint256 amount);
}