// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IRewarder.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "./IMiniChefPool.sol";
/// @author @0xKeno
contract MultiRewarderTime is IRewarder,  BoringOwnable{
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;

    IERC20 private immutable lpGaugeToken;

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of Flake entitled to the user.
    struct UserInfo {
        uint256 rewardDebt;
        uint256 unpaidRewards;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of Flake to distribute per block.
    struct PoolInfo {
        uint128 accFlakePerShare;
        uint64 lastRewardTime;
        uint256 rewardPerSecond;
        IERC20 rewardToken;
    }

    /// @notice Info of each pool.

    PoolInfo[] public poolInfos;

    /// @notice Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    address private immutable MASTERCHEF_V2;
    uint256 private constant ACC_TOKEN_PRECISION = 1e12;
    uint256 internal unlocked;
    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    event LogOnReward(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event LogPoolAddition(uint256 indexed pid,address indexed rewardToken, uint256 rewardPerSecond);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accFlakePerShare);
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event LogInit();

    constructor (address _MASTERCHEF_V2,uint256 pid) public {
        MASTERCHEF_V2 = _MASTERCHEF_V2;
        lpGaugeToken = IMiniChefPool(_MASTERCHEF_V2).lpGauges(pid);
        unlocked = 1;
    }


    function onFlakeReward (uint256 pid, address _user, address to, uint256 oldAmount, uint256 lpToken,bool bHarvest) onlyMCV2 lock override external {
        uint nLen = poolInfos.length;
        for (uint i=0;i<nLen;i++){
            onPoolReward(i,_user,to,oldAmount,lpToken,bHarvest);
        }
    }
    function onPoolReward (uint256 index, address _user, address to,uint256 oldAmount, uint256 lpToken,bool bHarvest) internal {
        PoolInfo memory pool = updatePool(index);
        UserInfo storage user = userInfo[index][_user];
        uint256 pending;
        if (oldAmount > 0) {
            pending =
                (oldAmount.mul(pool.accFlakePerShare) / ACC_TOKEN_PRECISION).sub(
                    user.rewardDebt
                ).add(user.unpaidRewards);
            uint256 balance = pool.rewardToken.balanceOf(address(this));
            if (!bHarvest){
                user.unpaidRewards = pending;
            }else{
                if (pending > balance) {
                    pool.rewardToken.safeTransfer(to, balance);
                    user.unpaidRewards = pending - balance;
                } else {
                    pool.rewardToken.safeTransfer(to, pending);
                    user.unpaidRewards = 0;
                }
            }
        }
        user.rewardDebt = lpToken.mul(pool.accFlakePerShare) / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, index, pending - user.unpaidRewards, to);
    }
    function pendingTokens(uint256 pid, address user, uint256) override external view returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts) {
        uint nLen = poolInfos.length;
        IERC20[] memory _rewardTokens = new IERC20[](nLen);
        uint256[] memory _rewardAmounts = new uint256[](nLen);
        for (uint i=0;i<nLen;i++){
            
            _rewardTokens[i] = poolInfos[i].rewardToken;
            _rewardAmounts[i] = pendingToken(i, user);
        }
        return (_rewardTokens, _rewardAmounts);
    }
    
    /// @notice Sets the Flake per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of Flake to be distributed per second.
    function setRewardPerSecond(uint256 index,uint256 _rewardPerSecond) public onlyOwner {
        poolInfos[index].rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }

    modifier onlyMCV2 {
        require(
            msg.sender == MASTERCHEF_V2,
            "Only MCV2 can call this function."
        );
        _;
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() public view returns (uint256 pools) {
        pools = poolInfos.length;
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param rewardToken AP of the new pool.
    /// @param _rewardPerSecond Pid on MCV2
    function add(address rewardToken,uint256 _rewardPerSecond) public onlyOwner {
        uint256 lastRewardTime = block.timestamp;
        poolInfos.push(PoolInfo({
            rewardPerSecond: _rewardPerSecond,
            lastRewardTime: lastRewardTime.to64(),
            accFlakePerShare: 0,
            rewardToken:IERC20(rewardToken)
        }));
        
        emit LogPoolAddition(poolInfos.length-1, rewardToken,_rewardPerSecond);
    }

    /// @notice Update the given pool's Flake allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _rewardPerSecond New reward per second of the pool.
    function set(uint256 _pid, uint256 _rewardPerSecond) public onlyOwner {
        require(poolInfos.length>_pid,"rewarder : pid is not overflow!");
        poolInfos[_pid].rewardPerSecond = _rewardPerSecond;
        emit LogSetPool(_pid, _rewardPerSecond);
    }

    /// @notice Allows owner to reclaim/withdraw any tokens (including reward tokens) held by this contract
    /// @param token Token to reclaim, use 0x00 for Ethereum
    /// @param amount Amount of tokens to reclaim
    /// @param to Receiver of the tokens, first of his name, rightful heir to the lost tokens,
    /// reightful owner of the extra tokens, and ether, protector of mistaken transfers, mother of token reclaimers,
    /// the Khaleesi of the Great Token Sea, the Unburnt, the Breaker of blockchains.
    function reclaimTokens(address token, uint256 amount, address payable to) public onlyOwner {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending Flake reward for a given user.
    function pendingToken(uint256 _pid, address _user) public view returns (uint256 pending) {
        PoolInfo memory pool = poolInfos[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFlakePerShare = pool.accFlakePerShare;
        uint256 lpSupply = totalSupply();
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            uint256 flakeReward = time.mul(pool.rewardPerSecond);
            accFlakePerShare = accFlakePerShare.add(flakeReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }
        pending = (lpGaugeToken.balanceOf(_user).mul(accFlakePerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(user.unpaidRewards);
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
        pool = poolInfos[pid];
        if (block.timestamp > pool.lastRewardTime) {
            uint256 lpSupply = totalSupply();

            if (lpSupply > 0) {
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                uint256 flakeReward = time.mul(pool.rewardPerSecond);
                pool.accFlakePerShare = pool.accFlakePerShare.add((flakeReward.mul(ACC_TOKEN_PRECISION) / lpSupply).to128());
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfos[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accFlakePerShare);
        }
    }
    function totalSupply()internal view returns (uint256){
        lpGaugeToken.totalSupply();
    }
}
