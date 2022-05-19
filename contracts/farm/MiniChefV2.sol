// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";

import "../libraries/SignedSafeMath.sol";
import "../interfaces/IRewarder.sol";
import "./lpGauge.sol";
import "../interfaces/IBoost.sol";


/// @notice The (older) MasterChef contract gives out a constant number of tokens per block.
/// It is the only address with minting rights for token.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this pool on MCV1 is the total allocation point for all pools that receive double incentives.
contract MiniChefV2 {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    using SignedSafeMath for int256;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of token entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.

    struct PoolInfo {
        uint128 accTokenPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    IBoost public booster;
    address public royaltyReceiver;
    address public safeMulsig;
    //for test or use safe mulsig
    modifier onlyMultisig() {
        require(msg.sender==safeMulsig, "not setting safe contract");
        _;
    }

    /// @notice Address of token contract.
    IERC20 public TOKEN;

    /// @notice Info of each MCV2 pool.
    PoolInfo[] public poolInfo;
    /// @notice Address of the LP token for each MCV2 pool.
    IERC20[] public lpToken;
        /// @notice Address of the LP Gauge for each MCV2 pool.
    lpGauge[] public lpGauges;
    /// @notice Address of each `IRewarder` contract in MCV2.
    IRewarder[] public rewarder;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    /// @dev Tokens added
    mapping (address => bool) public addedTokens;

    /// @dev Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;

    uint256 public tokenPerSecond;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount,uint256 boostedAmount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accTokenPerShare);
    event LogTokenPerSecond(uint256 tokenPerSecond);

    event OnBalanceChange(address indexed user, uint256 indexed pid, uint256 amount, bool increase);

    event SetBooster(address indexed booster);

    /// @param _token The token contract address.
    constructor(address _multiSignature,
                IERC20 _token)
        public
    {
        TOKEN = _token;
        safeMulsig = _multiSignature;
    }

//    function setMulsigAndRewardToken(address _multiSignature,
//                                     address _token)
//        onlyMultisig
//        public
//    {
//        TOKEN = IERC20(_token);
//        safeMulsig = _multiSignature;
//    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() external view returns (uint256 pools) {
        pools = poolInfo.length;
    }
    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Address of the rewarder delegate.
    function add(uint256 allocPoint, IERC20 _lpToken, IRewarder _rewarder) external onlyMultisig {
        require(addedTokens[address(_lpToken)] == false, "Token already added");
        totalAllocPoint = totalAllocPoint.add(allocPoint);
        lpToken.push(_lpToken);
        rewarder.push(_rewarder);
        uint256 _pid = lpToken.length.sub(1);
        string memory gaugeName = string(abi.encodePacked("lpGauge",toString(_pid)));
        lpGauges.push(new lpGauge(gaugeName,gaugeName,_pid));

        poolInfo.push(PoolInfo({
            allocPoint: allocPoint.to64(),
            lastRewardTime: block.timestamp.to64(),
            accTokenPerShare: 0
        }));
        addedTokens[address(_lpToken)] = true;
        emit LogPoolAddition(_pid, allocPoint, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's TOKEN allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarder Address of the rewarder delegate.
    /// @param overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
    function set(uint256 _pid, uint256 _allocPoint, IRewarder _rewarder, bool overwrite) external onlyMultisig {
        updatePool(_pid);

        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint.to64();
        if (overwrite) { rewarder[_pid] = _rewarder; }
        emit LogSetPool(_pid, _allocPoint, overwrite ? _rewarder : rewarder[_pid], overwrite);
    }

    /// @notice Sets the TOKEN per second to be distributed. Can only be called by the owner.
    /// @param _tokenPerSecond The amount of TOKEN to be distributed per second.
    function setTokenPerSecond(uint256 _tokenPerSecond) external onlyMultisig {
        tokenPerSecond = _tokenPerSecond;
        emit LogTokenPerSecond(_tokenPerSecond);
    }


    /// @notice View function to see pending TOKEN on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// return pending TOKEN reward for a given user.
    function pendingToken(uint256 _pid, address _user) external view returns (uint256 wholePending,uint256 incAmount,uint256 teamRoyalty) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = lpGauges[_pid].totalSupply();
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0 && totalAllocPoint > 0) {
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            uint256 tokenReward = time.mul(tokenPerSecond).mul(pool.allocPoint) / totalAllocPoint;
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }
        uint256 pending = int256(user.amount.mul(accTokenPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).toUInt256();

        ///////////////////////////////////////////////////////////////////////////
        (wholePending,incAmount,teamRoyalty) = boostRewardAndGetTeamRoyalty(_pid,_user,user.amount,pending);
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (PoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = lpGauges[pid].totalSupply();
            if (lpSupply > 0 && totalAllocPoint > 0) {
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                uint256 tokenReward = time.mul(tokenPerSecond).mul(pool.allocPoint) / totalAllocPoint;
                pool.accTokenPerShare = pool.accTokenPerShare.add((tokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply).to128());
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accTokenPerShare);
        }
    }

    function onTransfer(uint256 pid,address from,address to) external {
        PoolInfo memory pool = updatePool(pid);
        onBalanceChange(pool,pid,from);
        onBalanceChange(pool,pid,to);
    }

    function onBalanceChange(PoolInfo memory pool,uint256 pid,address _usr)internal {
        if (_usr != address(0)){
            UserInfo storage user = userInfo[pid][_usr];
            uint256 amount = lpGauges[pid].balanceOf(_usr);
            if (amount > user.amount){
                depositPending(pool,pid,amount.sub(user.amount),_usr);

                emit OnBalanceChange(_usr,pid,amount.sub(user.amount), true);

            }else if (amount<user.amount){
                withdrawPending(pool,pid,user.amount.sub(amount),_usr);

                emit OnBalanceChange(_usr,pid,user.amount.sub(amount), false);
            }
        }

    }
    /// @notice Deposit LP tokens to MCV2 for TOKEN allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 pid, uint256 amount, address to) external {
        PoolInfo memory pool = updatePool(pid);
        //UserInfo storage user = userInfo[pid][to];

        depositPending(pool,pid,amount,to);
        lpGauges[pid].mint(to,amount);
        lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
    }

    function depositPending(PoolInfo memory pool,uint256 pid, uint256 amount, address to)internal {
        UserInfo storage user = userInfo[pid][to];
        uint256 oldAmount = user.amount;
        user.amount = user.amount.add(amount);
        user.rewardDebt = user.rewardDebt.add(int256(amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION));

        // Interactions
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onTokenReward(pid, to, to, oldAmount, user.amount,false);
        }
    }
    /// @notice Withdraw LP tokens from MCV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(uint256 pid, uint256 amount, address to) external {
        PoolInfo memory pool = updatePool(pid);
        withdrawPending(pool,pid,amount,msg.sender);
        lpGauges[pid].burn(msg.sender,amount);
        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
    }

    function withdrawPending(PoolInfo memory pool,uint256 pid, uint256 amount, address _usr) internal {
        UserInfo storage user = userInfo[pid][_usr];
        // Effects
        uint256 oldAmount = user.amount;
        user.rewardDebt = user.rewardDebt.sub(int256(amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION));
        user.amount = user.amount.sub(amount);

        // Interactions
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onTokenReward(pid, _usr, _usr, oldAmount, user.amount,false);
        }
    }

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of token rewards.
    function harvest(uint256 pid,address to) public {
        harvestAccount(pid,msg.sender,to);
    }

    function harvestAccount(uint256 pid,address account,address to) internal {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][account];
        int256 accumulatedToken = int256(user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION);
        uint256 _pendingToken = accumulatedToken.sub(user.rewardDebt).toUInt256();
        /////////////////////////////////////////////////////////////////////////
        //get the reward after boost
        uint256 incReward = 0;
        uint256 teamRoyalty = 0;
        (_pendingToken,incReward,teamRoyalty) = boostRewardAndGetTeamRoyalty(pid,account,user.amount, _pendingToken);
        //for team royalty
        if(teamRoyalty>0&& royaltyReceiver !=address(0)) {
            TOKEN.safeTransfer(royaltyReceiver, teamRoyalty);
        }

        //////////////////////////////////////////////////////////////////////////

        // Effects
        user.rewardDebt = accumulatedToken;

        // Interactions
        if (_pendingToken != 0) {
            TOKEN.safeTransfer(to, _pendingToken);
        }

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onTokenReward( pid, account, to, user.amount, user.amount,true);
        }

        emit Harvest(account, pid, _pendingToken,incReward);
    }

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and TOKEN rewards.
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 oldAmount = user.amount;
        int256 accumulatedToken = int256(user.amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION);
        uint256 _pendingToken = accumulatedToken.sub(user.rewardDebt).toUInt256();
        ////////////////////////////////////////////////////////////////////////
        //get the reward after boost
        uint256 incReward = 0;
        uint256 teamRoyalty = 0;
        (_pendingToken,incReward,teamRoyalty) = boostRewardAndGetTeamRoyalty(pid,msg.sender,user.amount, _pendingToken);
        //for team royalty
        if(teamRoyalty>0&& royaltyReceiver !=address(0)) {
            TOKEN.safeTransfer(royaltyReceiver, teamRoyalty);
        }
        //////////////////////////////////////////////////////////////////////////
        // Effects
        user.rewardDebt = accumulatedToken.sub(int256(amount.mul(pool.accTokenPerShare) / ACC_TOKEN_PRECISION));
        user.amount = user.amount.sub(amount);
        // Interactions
        TOKEN.safeTransfer(to, _pendingToken);

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onTokenReward(pid, msg.sender, to, oldAmount, user.amount,true);
        }


        lpToken[pid].safeTransfer(to, amount);
        lpGauges[pid].burn(msg.sender,amount);
        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingToken,incReward);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) external {
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        IRewarder _rewarder = rewarder[pid];

        if (address(_rewarder) != address(0)) {
            _rewarder.onTokenReward(pid, msg.sender, to, 0, 0,false);
        }

        lpGauges[pid].burn(msg.sender,amount);
        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }
///////////////////////////////////////////////////////////////////////////////
    function setBooster(address _booster) external onlyMultisig {
        booster = IBoost(_booster);
        emit SetBooster(_booster);
    }

    function setRoyaltyReciever(address _royaltyReciever) external onlyMultisig {
        royaltyReceiver = _royaltyReciever;
    }

    function setBoostFunctionPara(uint256 _pid,uint256 _para0,uint256 _para1, uint256 _para2) external onlyMultisig {
        booster.setBoostFunctionPara(_pid,_para0,_para1,_para2);
    }

    function setBoostFarmFactorPara(uint256 _pid, bool  _enableTokenBoost, address _boostToken, uint256 _minBoostAmount, uint256 _maxIncRatio) external onlyMultisig {
        booster.setBoostFarmFactorPara(_pid,_enableTokenBoost, _boostToken, _minBoostAmount, _maxIncRatio);
        //init to default value
        booster.setBoostFunctionPara(_pid,0,0,0);
    }

    function setWhiteListMemberStatus(uint256 _pid,address _user,bool _status)  external onlyMultisig {
        //settle for the user
        harvest(_pid, msg.sender);

        booster.setWhiteListMemberStatus(_pid,_user,_status);
    }

    function setWhiteList(uint256 _pid,address[] memory _user) external onlyMultisig {
        require(_user.length>0,"array length is 0");
        for(uint256 i=0;i<_user.length;i++) {

            if(booster.whiteListLpUserInfo(_pid,_user[i])) {
                //settle for the user
                harvest(_pid, msg.sender);
            }

            booster.setWhiteListMemberStatus(_pid,_user[i],true);
        }
    }

    function setFixedWhitelistPara(uint256 _pid,uint256 _incRatio,uint256 _whiteListfloorLimit) external onlyMultisig {
        booster.setFixedWhitelistPara(_pid,_incRatio,_whiteListfloorLimit);
    }

    function setFixedTeamRatio(uint256 _pid,uint256 _ratio) external onlyMultisig {
        booster.setFixedTeamRatio(_pid,_ratio);
    }

    function boostRewardAndGetTeamRoyalty(uint256 _pid,address _user,uint256 _userLpAmount,uint256 _pendingToken) view public returns(uint256,uint256,uint256) {
        if(address(booster)==address(0)) {
            return (_pendingToken,0,0);
        }
        //record init reward
        uint256 incReward = _pendingToken;
        uint256 teamRoyalty = 0;
        (_pendingToken,teamRoyalty) = booster.getTotalBoostedAmount(_pid,_user,_userLpAmount, _pendingToken);
        //(_pendingToken+teamRoyalty) is total (boosted reward inclued baseAnount + init reward)
        incReward = _pendingToken.add(teamRoyalty).sub(incReward);

        return (_pendingToken,incReward,teamRoyalty);
    }

    function boostDeposit(uint256 _pid,uint256 _amount) external {
        require(address(booster)!=address(0),"booster is not set");

        //need to harvest when boost amount changed
        harvest(_pid, msg.sender);

        booster.boostDeposit(_pid,msg.sender,_amount);

        address boostToken = booster.getBoostToken(_pid);
        IERC20(boostToken).safeTransferFrom(msg.sender,address(booster), _amount);
    }


    function boostWithdraw(uint256 _pid,uint256 _amount) external {
        require(address(booster)!=address(0),"booster is not set");

        //need to harvest when boost amount changed
        harvest(_pid, msg.sender);

        booster.boostWithdraw(_pid,msg.sender,_amount);
    }

    function boostStakedFor(uint256 _pid,address _account) external view returns (uint256) {
        require(address(booster)!=address(0),"booster is not set");
        return booster.boostStakedFor(_pid,_account);
    }

    function boostTotalStaked(uint256 _pid) external view returns (uint256) {
        require(address(booster)!=address(0),"booster is not set");
        return booster.boostTotalStaked(_pid);
    }

    function getPoolId(address _lp) external view returns (uint256) {
        for(uint256 i=0;i<lpToken.length;i++) {
            if(_lp==address(lpToken[i])) {
                return i;
            }
        }
        return uint256(-1);
    }


}