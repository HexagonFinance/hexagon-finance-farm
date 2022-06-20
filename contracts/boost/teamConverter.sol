// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;


import '../libraries/SafeMath.sol';
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

interface ITeamRewardSC {
    function inputTeamReward(uint256 _amount) external;
}

contract teamConverter is BoringOwnable{
    using BoringERC20 for IERC20;
    address public safeMulsig;
    address public teamRewardSc = 0x6d4beC7C0eB40C3744c7aEF49Abf8D5478Fbc7D5;
    address public melt = 0x47EB6F7525C1aA999FBC9ee92715F5231eB1241D;

    function setMulSig (address _multiSignature)
        public
        onlyOwner
    {
        safeMulsig = _multiSignature;
    }

    modifier onlyMultisig() {
        require(msg.sender==safeMulsig, "not setting safe contract");
        _;
    }


    function forwardMeltToTeamDisContract() external {
        uint256 teamReward = IERC20(melt).balanceOf(address(this));
        if(teamReward>0) {
            IERC20(melt).approve(teamRewardSc,teamReward);
            ITeamRewardSC(teamRewardSc).inputTeamReward(teamReward);
        }
    }

    function reclaimTokens(address token, uint256 amount, address payable to) public onlyMultisig {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }




}
