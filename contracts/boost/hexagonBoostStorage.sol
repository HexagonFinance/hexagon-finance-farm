// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "../libraries/SmallNumbers.sol";

contract hexagonBoostStorage {
    address public safeMulsig;
    address public farmChef;
    uint256 constant public RATIO_DENOM = 1000;

    uint256 constant internal rayDecimals = 1e8;//100%
    //pid => totalSupply for boost token
    mapping(uint256=>uint256) internal totalsupplies;
    //pid => user => boost token balance
    mapping(uint256=>mapping(address => uint256)) internal balances;

    //pid => user => whitelist user
    mapping(uint256=>mapping(address => bool)) public whiteListLpUserInfo;

//    log(LOG_PARA0)(amount+LOG_PARA1)- LOG_PARA2
//    uint256 public LOG_PARA0 = 5;
//    uint256 public LOG_PARA1 = 500000e18;
//    uint256 public LOG_PARA2 = 329*SmallNumbers.FIXED_ONE/10;


    struct poolBoostPara{
        uint256 fixedTeamRatio;  //default 8%
        uint256 fixedWhitelistRatio;  //default 20%
        uint256 whiteListfloorLimit; //default 500 thousands
        bool enableTokenBoost;
        uint256 lockTime;
        address boostToken;
        bool emergencyWithdraw;

        uint256 minBoostAmount;
        uint256 maxIncRatio;//5.5 multiple

        uint256 log_para0;//5;
        uint256 log_para1; //500000e18
        uint256 log_para2;// 329*SmallNumbers.FIXED_ONE/10;

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
    event CancelBoostApplyWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);
    event BoostWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);
}