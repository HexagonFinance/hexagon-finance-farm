// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "../libraries/SignedSafeMath.sol";
import "../libraries/proxyOwner.sol";
import "../interfaces/IRewarder.sol";
import "./lpGauge.sol";
import "../interfaces/IBoost.sol";

interface IMigratorChef {
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    function migrate(IERC20 token) external returns (IERC20);
}


/// @notice The (older) MasterChef contract gives out a constant number of FLAKE tokens per block.
/// It is the only address with minting rights for FLAKE.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this pool on MCV1 is the total allocation point for all pools that receive double incentives.
contract MiniChefV2 is BoringOwnable, BoringBatchable/*,proxyOwner*/ {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;
    using SignedSafeMath for int256;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of FLAKE entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of FLAKE to distribute per block.
    struct PoolInfo {
        uint128 accFlakePerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    IBoost public booster;
    address public royaltyReciever;
    address public safeMulsig;
    //for test or use safe mulsig
    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not setting safe contract");
        _;
    }

    /// @notice Address of FLAKE contract.
    IERC20 public immutable FLAKE;
    // @notice The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

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

    uint256 public flakePerSecond;
    uint256 private constant ACC_FLAKE_PRECISION = 1e12;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount,uint256 boostedAmount);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed lpToken, IRewarder indexed rewarder);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint, IRewarder indexed rewarder, bool overwrite);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accFlakePerShare);
    event LogFlakePerSecond(uint256 flakePerSecond);

    /// @param _flake The FLAKE token contract address.
    constructor(address _multiSignature,
               // address _origin0,
               // address _origin1,
                IERC20 _flake)
        //proxyOwner(_multiSignature, _origin0, _origin1)
        public
    {
        FLAKE = _flake;
        safeMulsig = _multiSignature;
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _rewarder Address of the rewarder delegate.
    function add(uint256 allocPoint, IERC20 _lpToken, IRewarder _rewarder) public onlyOrigin {
        require(addedTokens[address(_lpToken)] == false, "Token already added");
        totalAllocPoint = totalAllocPoint.add(allocPoint);
        lpToken.push(_lpToken);
        rewarder.push(_rewarder);
        lpGauges.push(new lpGauge("lpGauge","lpGauge",lpToken.length.sub(1)));

        poolInfo.push(PoolInfo({
            allocPoint: allocPoint.to64(),
            lastRewardTime: block.timestamp.to64(),
            accFlakePerShare: 0
        }));
        addedTokens[address(_lpToken)] = true;
        emit LogPoolAddition(lpToken.length.sub(1), allocPoint, _lpToken, _rewarder);
    }

    /// @notice Update the given pool's FLAKE allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    /// @param _rewarder Address of the rewarder delegate.
    /// @param overwrite True if _rewarder should be `set`. Otherwise `_rewarder` is ignored.
    function set(uint256 _pid, uint256 _allocPoint, IRewarder _rewarder, bool overwrite) public onlyOrigin {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint.to64();
        if (overwrite) { rewarder[_pid] = _rewarder; }
        emit LogSetPool(_pid, _allocPoint, overwrite ? _rewarder : rewarder[_pid], overwrite);
    }

    /// @notice Sets the FLAKE per second to be distributed. Can only be called by the owner.
    /// @param _flakePerSecond The amount of FLAKE to be distributed per second.
    function setFlakePerSecond(uint256 _flakePerSecond) public onlyOrigin {
        flakePerSecond = _flakePerSecond;
        emit LogFlakePerSecond(_flakePerSecond);
    }

    /// @notice Set the `migrator` contract. Can only be called by the owner.
    /// @param _migrator The contract address to set.
    function setMigrator(IMigratorChef _migrator) public onlyOrigin {
        migrator = _migrator;
    }

    /// @notice Migrate LP token to another LP contract through the `migrator` contract.
    /// @param _pid The index of the pool. See `poolInfo`.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "IMiniChefV2: no migrator set");
        IERC20 _lpToken = lpToken[_pid];
        uint256 bal = _lpToken.balanceOf(address(this));
        _lpToken.approve(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(_lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "IMiniChefV2: migrated balance must match");
        require(addedTokens[address(newLpToken)] == false, "Token already added");
        addedTokens[address(newLpToken)] = true;
        addedTokens[address(_lpToken)] = false;
        lpToken[_pid] = newLpToken;
    }

    /// @notice View function to see pending FLAKE on frontend.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending FLAKE reward for a given user.
    function pendingFlake(uint256 _pid, address _user) external view returns (uint256 pending) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFlakePerShare = pool.accFlakePerShare;
        uint256 lpSupply = lpGauges[_pid].totalSupply();
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            uint256 flakeReward = time.mul(flakePerSecond).mul(pool.allocPoint) / totalAllocPoint;
            accFlakePerShare = accFlakePerShare.add(flakeReward.mul(ACC_FLAKE_PRECISION) / lpSupply);
        }
        pending = int256(user.amount.mul(accFlakePerShare) / ACC_FLAKE_PRECISION).sub(user.rewardDebt).toUInt256();
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
            if (lpSupply > 0) {
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                uint256 flakeReward = time.mul(flakePerSecond).mul(pool.allocPoint) / totalAllocPoint;
                pool.accFlakePerShare = pool.accFlakePerShare.add((flakeReward.mul(ACC_FLAKE_PRECISION) / lpSupply).to128());
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accFlakePerShare);
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
                depoistPending(pool,pid,amount-user.amount,_usr);
            }else if (amount<user.amount){
                withdrawPending(pool,pid,user.amount-amount,_usr);
            }
        }
    }
    /// @notice Deposit LP tokens to MCV2 for FLAKE allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][to];

        depoistPending(pool,pid,amount,to);
        lpGauges[pid].mint(to,amount);
        lpToken[pid].safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(msg.sender, pid, amount, to);
    }

    function depoistPending(PoolInfo memory pool,uint256 pid, uint256 amount, address to)internal {
        UserInfo storage user = userInfo[pid][to];
        user.amount = user.amount.add(amount);
        user.rewardDebt = user.rewardDebt.add(int256(amount.mul(pool.accFlakePerShare) / ACC_FLAKE_PRECISION));

        // Interactions
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onFlakeReward(pid, to, to, 0, user.amount,false);
        }
    }
    /// @notice Withdraw LP tokens from MCV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        withdrawPending(pool,pid,amount,to);
        lpGauges[pid].burn(msg.sender,amount);
        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
    }

    function withdrawPending(PoolInfo memory pool,uint256 pid, uint256 amount, address to) internal {
        UserInfo storage user = userInfo[pid][msg.sender];
        // Effects
        user.rewardDebt = user.rewardDebt.sub(int256(amount.mul(pool.accFlakePerShare) / ACC_FLAKE_PRECISION));
        user.amount = user.amount.sub(amount);

        // Interactions
        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onFlakeReward(pid, msg.sender, to, 0, user.amount,false);
        }
    }
    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of FLAKE rewards.
    function harvest(uint256 pid, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulatedFlake = int256(user.amount.mul(pool.accFlakePerShare) / ACC_FLAKE_PRECISION);
        uint256 _pendingFlake = accumulatedFlake.sub(user.rewardDebt).toUInt256();
        /////////////////////////////////////////////////////////////////////////
        //get the reward after boost
        uint256 boostedReward = _pendingFlake;
        uint256 teamRoyalty = 0;
        (_pendingFlake,teamRoyalty) = booster.getTotalBoostedAmount(pid,msg.sender,user.amount,_pendingFlake);
        if(teamRoyalty>0) {
            FLAKE.safeTransfer(royaltyReciever, teamRoyalty);
        }

        if(_pendingFlake>boostedReward) {
            boostedReward = _pendingFlake.sub(boostedReward);
        }
        //////////////////////////////////////////////////////////////////////////

        // Effects
        user.rewardDebt = accumulatedFlake;

        // Interactions
        if (_pendingFlake != 0) {
            FLAKE.safeTransfer(to, _pendingFlake);
        }

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onFlakeReward( pid, msg.sender, to, _pendingFlake, user.amount,true);
        }

        emit Harvest(msg.sender, pid, _pendingFlake,boostedReward);
    }

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and FLAKE rewards.
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) public {
        PoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][msg.sender];
        int256 accumulatedFlake = int256(user.amount.mul(pool.accFlakePerShare) / ACC_FLAKE_PRECISION);
        uint256 _pendingFlake = accumulatedFlake.sub(user.rewardDebt).toUInt256();
        ////////////////////////////////////////////////////////////////////////
        //get the reward after boost
        uint256 boostedReward = _pendingFlake;
        uint256 teamRoyalty = 0;
        (_pendingFlake,teamRoyalty) = booster.getTotalBoostedAmount(pid,msg.sender,user.amount,_pendingFlake);
        if(teamRoyalty>0) {
            FLAKE.safeTransfer(royaltyReciever, teamRoyalty);
        }

        if(_pendingFlake>boostedReward) {
            boostedReward = _pendingFlake.sub(boostedReward);
        }
        //////////////////////////////////////////////////////////////////////////
        // Effects
        user.rewardDebt = accumulatedFlake.sub(int256(amount.mul(pool.accFlakePerShare) / ACC_FLAKE_PRECISION));
        user.amount = user.amount.sub(amount);
        lpGauges[pid].burn(msg.sender,amount);

        // Interactions
        FLAKE.safeTransfer(to, _pendingFlake);

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onFlakeReward(pid, msg.sender, to, _pendingFlake, user.amount,true);
        }


        lpToken[pid].safeTransfer(to, amount);

        emit Withdraw(msg.sender, pid, amount, to);
        emit Harvest(msg.sender, pid, _pendingFlake,boostedReward);
    }

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) public {
        UserInfo storage user = userInfo[pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        lpGauges[pid].burn(msg.sender,amount);

        IRewarder _rewarder = rewarder[pid];
        if (address(_rewarder) != address(0)) {
            _rewarder.onFlakeReward(pid, msg.sender, to, 0, 0,false);
        }

        // Note: transfer can fail or succeed if `amount` is zero.
        lpToken[pid].safeTransfer(to, amount);
        emit EmergencyWithdraw(msg.sender, pid, amount, to);
    }
///////////////////////////////////////////////////////////////////////////////
    function setBooster(address _booster) public onlyOrigin {
        booster = IBoost(_booster);
    }

    function boostDeposit(uint256 _pid,uint256 _amount) external {
        booster.boostDeposit(_pid,msg.sender,_amount);
        FLAKE.safeTransferFrom(msg.sender,address(booster), _amount);
    }

    function boostApplyWithdraw(uint256 _pid,uint256 _amount) external {
        booster.boostApplyWithdraw(_pid,msg.sender,_amount);
    }

    function boostWithdraw(uint256 _pid) external {
        booster.boostWithdraw(_pid,msg.sender);
    }

    function boostStakedFor(uint256 _pid,address _account) external view returns (uint256) {
        booster.boostStakedFor(_pid,_account);
    }

    function boostTotalStaked(uint256 _pid) external view returns (uint256) {
        booster.boostTotalStaked(_pid);
    }

}