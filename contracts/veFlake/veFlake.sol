// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import '../flake/ERC20.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';

contract veFlake is ERC20 {
    using SafeMath for uint256;
    IERC20 public flake;
    address public safeMulsig;

    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not mulsafe");
        _;
    }

    event Enter(address indexed user, uint256 indexed flakeAmount,uint256 indexed veFlakeAmount);
    event Leave(address indexed user, uint256 indexed flakeAmount,uint256 indexed veFlakeAmount);
    event ApplyLeave(address indexed user, uint256 indexed veFlakeAmount);
    event CancelLeave(address indexed user, uint256 indexed veFlakeAmount);

    string private name_;
    string private symbol_;
    uint8  private decimals_;

    uint64 public LeavingTerm = 90 days;
    struct pendingItem {
        uint192 pendingAmount;
        uint64 releaseTime;
    }
    struct pendingGroup {
        pendingItem[] pendingAry;
        uint192 pendingDebt;
        uint64 firstIndex;
    }

    mapping(address=>pendingGroup) internal userLeavePendingMap;
    // Define the token contract
    constructor(address _multiSignature,string memory tokenName,string memory tokenSymbol,uint256 tokenDecimal) public {
        safeMulsig = _multiSignature;
        name_ = tokenName;
        symbol_ = tokenSymbol;
        decimals_ = uint8(tokenDecimal);
    }

    function setFlake(IERC20 _flake) external onlyOrigin{
        flake = _flake;
    }

    function setLeavingTerm(uint64 _leavingTerm) external onlyOrigin{
        LeavingTerm = _leavingTerm;
    }


    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
        return name_;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
        return symbol_;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
        return decimals_;
    }


    function enter(uint256 _amount) public {
        // Gets the amount of locked in the contract
        uint256 totalFlake = flake.balanceOf(address(this));
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        // If no veFlake exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalFlake == 0) {
            _mint(msg.sender, _amount);
            emit Enter(msg.sender,_amount,_amount);
        }
        // Calculate and mint the amount of veFlake the flake is worth. The ratio will change overtime, as veFlake is burned/minted and flake deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalFlake);
            _mint(msg.sender, what);
            emit Enter(msg.sender,_amount,what);
        }

        // Lock the flake in the contract
        flake.transferFrom(msg.sender, address(this), _amount);


    }

    function leaveApply(uint256 _share) public {
        addPendingInfo(userLeavePendingMap[msg.sender],_share);
        _transfer(msg.sender, address(this), _share);
        emit ApplyLeave(msg.sender, _share);

        //require(getAllPendingAmount(userLeavePendingMap[msg.sender])>=_share,"veFlake: Leave insufficient amount");
    }

    function cancelLeave()public{
        pendingGroup storage userPendings = userLeavePendingMap[msg.sender];
        uint256 pendingLength = userPendings.pendingAry.length;
        require(pendingLength > 0,"veFlake : Empty leave pending queue!");
           // leave();
        uint256 amount = userPendings.pendingAry[uint256(pendingLength-1)].pendingAmount - userPendings.pendingDebt;
        transfer(msg.sender,amount);
        userPendings.firstIndex = uint64(pendingLength);
        userPendings.pendingDebt = userPendings.pendingAry[uint256(pendingLength-1)].pendingAmount;
        emit  CancelLeave(msg.sender,amount);
    }
    // Leave the bar. Claim back your flake.
    // Unlocks the staked + gained flake and burns veFlake
    function leave() public {
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        uint256 _share = updateUserPending(userLeavePendingMap[msg.sender],LeavingTerm);
        // Calculates the amount of flake the veFlake is worth
        uint256 what = _share.mul(flake.balanceOf(address(this))).div(
            totalShares
        );

        _burn(address(this), _share);

        flake.transfer(msg.sender, what);

        emit Leave(msg.sender, what,_share);

    }

    function searchPendingIndex(pendingItem[] memory pendingAry,uint64 firstIndex,uint64 searchTime) internal pure returns (int256){
        uint256 length = pendingAry.length;
        if (uint256(firstIndex)>=length || pendingAry[firstIndex].releaseTime > searchTime) {
            return int256(firstIndex) - 1;
        }
        uint256 min = firstIndex;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (pendingAry[mid].releaseTime == searchTime) {
                min = mid;
                break;
            }
            if (pendingAry[mid].releaseTime < searchTime) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return int256(min);
    }


    function addPendingInfo(pendingGroup storage userPendings,uint256 amount) internal {
        uint256 len = userPendings.pendingAry.length;
        if (len != 0){
            amount = amount.add(userPendings.pendingAry[len-1].pendingAmount);
        }
        userPendings.pendingAry.push(pendingItem(uint192(amount),currentTime()));
    }

    function getUserReleasePendingAmount(address account) public view returns (uint256){
        return getReleasePendingAmount(userLeavePendingMap[account],LeavingTerm);
    }

    function getUserAllPendingAmount(address account) external view returns (uint256) {
        return getAllPendingAmount(userLeavePendingMap[account]);
    }

    function getAllPendingAmount(pendingGroup memory userPendings) internal pure returns (uint256){
        uint256 len = userPendings.pendingAry.length;
        if(len == 0){
            return 0;
        }
        return SafeMath.sub(userPendings.pendingAry[len-1].pendingAmount,userPendings.pendingDebt);
    }

    function getReleasePendingAmount(pendingGroup memory userPendings,uint64 releaseTerm) internal view returns (uint256){
        uint64 curTime = currentTime()-releaseTerm;
        int256 index = searchPendingIndex(userPendings.pendingAry,userPendings.firstIndex,curTime);
        if (index<int256(userPendings.firstIndex)){
            return 0;
        }
        return SafeMath.sub(userPendings.pendingAry[uint256(index)].pendingAmount,userPendings.pendingDebt);
    }

    function updateUserPending(pendingGroup storage userPendings,uint64 releaseTerm)internal returns (uint256){
        uint64 curTime = currentTime()-releaseTerm;
        int256 index = searchPendingIndex(userPendings.pendingAry,userPendings.firstIndex,curTime);
        if (index<int256(userPendings.firstIndex)){
            return 0;
        }
        userPendings.firstIndex = uint64(index + 1);
        uint256 amount = SafeMath.sub(userPendings.pendingAry[uint256(index)].pendingAmount,userPendings.pendingDebt);
        userPendings.pendingDebt = userPendings.pendingAry[uint256(index)].pendingAmount;
        return amount;
    }

    function currentTime() internal view virtual returns(uint64){
        return uint64(block.timestamp);
    }
}