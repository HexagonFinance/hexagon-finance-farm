// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../libraries/Halt.sol";

contract hexagonBoostStorage is Halt {
    address public safeMulsig;
    address public farmChef;
    uint256 public RATIO_DENOM = 1000;

    //pid => totalSupply for boost token
    mapping(uint256=>uint256) internal totalsupplies;
    //pid => user => boost token balance
    mapping(uint256=>mapping(address => uint256)) internal balances;

    struct pendingItem {
        uint192 pendingAmount;
        uint64 releaseTime;
    }

    struct pendingGroup {
        pendingItem[] pendingAry;
        uint64 firstIndex;
        uint256 totalPending;
    }

    //pid => user => token release time for withdraw
    mapping(uint256=>mapping(address=>pendingGroup)) public userUnstakePending;
    //pid => user => whitelist user
    mapping(uint256=>mapping(address => bool)) public whiteListLpUserInfo;

    uint256 constant internal rayDecimals = 1000e18;//100%

    struct poolBoostPara{
        uint256 fixedTeamRatio;  //default 8%
        uint256 fixedWhitelistRatio;  //default 20%
        uint256 whiteListfloorLimit; //default 500 thousands
        uint256 baseBoostTokenAmount;//1000 ether;
        uint256 baseIncreaseRatio; //3%
        uint256 ratioIncreaseStep;// 1%
        uint256 boostTokenStepAmount;//1000 ether;
        uint256 maxIncRatio;//5.5 multiple
        bool enableTokenBoost;
        uint256 lockTime;
        address boostToken;
    }

    mapping(uint256=>poolBoostPara) public boostPara;

    //uint256 public fixedTeamRatio = 80;  //default 8%
    //uint256 public fixedWhitelistRatio = 200;  //default 20%
    //uint256 public whiteListfloorLimit = 500000 ether; //default 500 thousands
    //uint256 constant internal rayDecimals = 1000e18;//100%
    //uint256 public BaseBoostTokenAmount = 1000e18;//1000 ether;
    //uint256 public BaseIncreaseRatio = 30e18; //3%
    //uint256 public RatioIncreaseStep = 10e18;// 1%
    //uint256 public BoostTokenStepAmount = 1000e18;//1000 ether;
    //uint256 public MaxFactor = 5500e18;//5.5 multiple

    event BoostDeposit(uint256 indexed _pid,address indexed user,  uint256 amount);
    event BoostApplyWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);
    event BoostWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);
}