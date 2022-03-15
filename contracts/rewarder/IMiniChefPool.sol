/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
pragma solidity 0.6.12;
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
interface IMiniChefPool {
    function lpToken(uint256 pid) external view returns (IERC20 _lpToken);
    function lpGauges(uint256 pid) external view returns (IERC20 _lpGauge);
}