// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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
        address boostToken;

        uint256 minBoostAmount;
        uint256 maxIncRatio;

        uint256 log_para0;//5;
        uint256 log_para1; //500000e18
        uint256 log_para2; //329*rayDecimals/10

    }

    mapping(uint256=>poolBoostPara) public boostPara;


    event BoostDeposit(uint256 indexed _pid,address indexed user,  uint256 amount);
    event BoostApplyWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);
    event CancelBoostApplyWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);
    event BoostWithdraw(uint256 indexed _pid,address indexed user, uint256 amount);


    event SetFixedTeamRatio(uint256 indexed _pid,uint256 indexed _ratio);

    event SetFixedWhitelistPara(uint256 indexed _pid,uint256 indexed _incRatio,uint256 indexed _whiteListfloorLimit);

    event SetWhiteListMemberStatus(uint256 indexed _pid,address indexed _user,bool indexed _status);

    event SetBoostFarmFactorPara(uint256 indexed _pid, bool indexed _enableTokenBoost, address indexed _boostToken, uint256 _minBoostAmount, uint256 _maxIncRatio);

    event SetBoostFunctionPara(uint256 indexed _pid,uint256 indexed _para0,uint256 indexed _para1, uint256 _para2);

}