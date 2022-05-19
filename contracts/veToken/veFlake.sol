// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import '../flake/ERC20.sol';
import '../libraries/SafeMath.sol';
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

contract veFlake is ERC20 {
    using SafeMath for uint256;
    using BoringERC20 for IERC20;

    IERC20 immutable public flake;
    address public safeMulsig;

    modifier onlyOrigin() {
        require(msg.sender==safeMulsig, "not mulsig address");
        _;
    }

    event Enter(address indexed user, uint256 flakeAmount,uint256 veFlakeAmount);
    event Leave(address indexed user, uint256 flakeAmount,uint256 veFlakeAmount);
    event ApplyLeave(address indexed user, uint256 veFlakeAmount);
    event CancelLeave(address indexed user, uint256 veFlakeAmount);

    string private name_;
    string private symbol_;
    uint8  private decimals_;

    uint64 public LeavingTerm = 90 days;

    struct pendingItem {
        uint192 pendingAmount;
        uint64 timestamp;
    }

    struct pendingGroup {
        pendingItem[] pendingArray;
        uint192 pendingDebt;
        uint64 firstIndex;
    }

    mapping(address=>pendingGroup) public userLeavePendingMap;
    // Define the token contract
    constructor(IERC20 _flake,address _multiSignature,string memory tokenName,string memory tokenSymbol,uint8 tokenDecimal) public {
        safeMulsig = _multiSignature;
        flake = _flake;

        name_ = tokenName;
        symbol_ = tokenSymbol;
        decimals_ = tokenDecimal;
    }

    function toUint192(uint256 a) internal pure returns (uint192 c) {
        require(a <= uint192(-1), "BoringMath: uint192 Overflow");
        c = uint192(a);
    }
//    function setFlake(IERC20 _flake) external onlyOrigin{
//        flake = _flake;
//    }

//    function setLeavingTerm(uint64 _leavingTerm) external onlyOrigin{
//        LeavingTerm = _leavingTerm;
//    }

//    function setMulsig(address _multiSignature) external onlyOrigin{
//        safeMulsig = _multiSignature;
//    }

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


    function enter(uint256 _amount) external {
        require(_amount>0,"amount need to over zero!");
        // Gets the amount of locked flake in the contract
        uint256 totalFlake = flake.balanceOf(address(this));
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        // If no veFlake exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalFlake == 0) {
            require(_amount > 1 ether,"the init amount is too small");
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
        flake.safeTransferFrom(msg.sender, address(this), _amount);


    }

    function leaveApply(uint256 _share) external {
        require(_share>0,"_share need to over zero!");

        addPendingInfo(userLeavePendingMap[msg.sender],_share);
        _transfer(msg.sender, address(this), _share);
        emit ApplyLeave(msg.sender, _share);
      }

    function cancelLeave() external {
        pendingGroup storage userPendings = userLeavePendingMap[msg.sender];
        uint256 pendingLength = userPendings.pendingArray.length;
        require(pendingLength > 0,"veFlake : Empty leave pending queue!");
           // leave();
        uint256 amount = userPendings.pendingArray[uint256(pendingLength-1)].pendingAmount - userPendings.pendingDebt;
        _transfer(address(this),msg.sender,amount);

        userPendings.firstIndex = uint64(pendingLength);
        userPendings.pendingDebt = userPendings.pendingArray[uint256(pendingLength-1)].pendingAmount;
        emit  CancelLeave(msg.sender,amount);
    }
    // Leave the bar. Claim back your flake.
    // Unlocks the staked + gained flake and burns veFlake
    function leave() external {
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        uint256 _share = updateUserPending(userLeavePendingMap[msg.sender],LeavingTerm);

        require(_share>0,"pending share need to be over 0!");

        // Calculates the amount of flake the veFlake is worth
        uint256 what = _share.mul(flake.balanceOf(address(this))).div(
            totalShares
        );

        _burn(address(this), _share);

        flake.safeTransfer(msg.sender, what);

        emit Leave(msg.sender, what,_share);

    }

    function searchPendingIndex(pendingItem[] storage pendingArray,uint64 firstIndex,uint64 searchTime) internal view returns (int256){
        uint256 length = pendingArray.length;
        if (uint256(firstIndex)>=length || pendingArray[firstIndex].timestamp > searchTime) {
            return int256(firstIndex) - 1;
        }
        uint256 min = firstIndex;
        uint256 max = length - 1;
        while (max > min) {
            uint256 mid = (max + min + 1) / 2;
            if (pendingArray[mid].timestamp == searchTime) {
                min = mid;
                break;
            }
            if (pendingArray[mid].timestamp < searchTime) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return int256(min);
    }


    function addPendingInfo(pendingGroup storage userPendings,uint256 amount) internal {
        uint256 len = userPendings.pendingArray.length;
        if (len != 0){
            uint64 curTime = currentTime();
            if (userPendings.pendingArray[len-1].timestamp == curTime){
                userPendings.pendingArray[len-1].pendingAmount= toUint192(amount.add(userPendings.pendingArray[len-1].pendingAmount));
            }else{
                userPendings.pendingArray.push(pendingItem(toUint192(amount.add(userPendings.pendingArray[len-1].pendingAmount)),curTime));
            }
        }else{
            userPendings.pendingArray.push(pendingItem(toUint192(amount),currentTime()));
        }
    }



    function getUserReleasePendingAmount(address account) external view returns (uint256){
        return getReleasePendingAmount(userLeavePendingMap[account],LeavingTerm);
    }

    function getUserAllPendingAmount(address account) external view returns (uint256) {
        return getAllPendingAmount(userLeavePendingMap[account]);
    }

    function getAllPendingAmount(pendingGroup storage userPendings) internal view returns (uint256){
        uint256 len = userPendings.pendingArray.length;
        if(len == 0){
            return 0;
        }
        return SafeMath.sub(userPendings.pendingArray[len-1].pendingAmount,userPendings.pendingDebt);
    }

    function getReleasePendingAmount(pendingGroup storage userPendings,uint64 releaseTerm) internal view returns (uint256){
        uint64 curTime = uint64(SafeMath.sub(currentTime(),releaseTerm));
        int256 index = searchPendingIndex(userPendings.pendingArray,userPendings.firstIndex,curTime);
        if (index<int256(userPendings.firstIndex)){
            return 0;
        }
        return SafeMath.sub(userPendings.pendingArray[uint256(index)].pendingAmount,userPendings.pendingDebt);
    }

    function getFlakeAmount(uint256 _share) external view returns (uint256) {
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        if(totalShares==0) {
            return _share;
        }
        // Calculates the amount of flake the veFlake is worth
        return _share.mul(flake.balanceOf(address(this))).div(totalShares);

    }

    function getVeFlakeShare(uint256 _amount) external view returns (uint256) {
        uint256 totalFlake = flake.balanceOf(address(this));
        // Gets the amount of veFlake in existence
        uint256 totalShares = totalSupply();
        // If no veFlake exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalFlake == 0) {
            return _amount;
        }
         else {
            return _amount.mul(totalShares).div(totalFlake);
        }
    }


    function updateUserPending(pendingGroup storage userPendings,uint64 releaseTerm)internal returns (uint256){

        uint64 curTime = uint64(SafeMath.sub(currentTime(),releaseTerm));
        int256 index = searchPendingIndex(userPendings.pendingArray,userPendings.firstIndex,curTime);
        if (index<int256(userPendings.firstIndex)){
            return 0;
        }
        userPendings.firstIndex = uint64(index + 1);
        uint256 amount = SafeMath.sub(userPendings.pendingArray[uint256(index)].pendingAmount,userPendings.pendingDebt);
        userPendings.pendingDebt = userPendings.pendingArray[uint256(index)].pendingAmount;
        return amount;
    }

    function currentTime() internal view virtual returns(uint64){
        return uint64(block.timestamp);
    }


    function getLeaveApplyHistory(address account) external view returns(uint256[] memory,uint256[] memory) {
        pendingGroup memory userPendings = userLeavePendingMap[account];
        uint256 firstIndex = userPendings.firstIndex;

        uint256 len = userPendings.pendingArray.length - userPendings.firstIndex;
        uint256[] memory amounts = new uint256[](len);
        uint256[] memory timeStamps = new uint256[](len);

        for(uint256 i=firstIndex;i<userPendings.pendingArray.length;i++) {
            uint256 idx = i-firstIndex;
            timeStamps[idx] = userPendings.pendingArray[i].timestamp;

            if(i==0) {
                amounts[idx] = userPendings.pendingArray[i].pendingAmount;
            } else {
                amounts[idx] = userPendings.pendingArray[i].pendingAmount - userPendings.pendingArray[i-1].pendingAmount;
            }
        }


        return (amounts,timeStamps);
    }
}