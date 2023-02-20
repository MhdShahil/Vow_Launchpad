// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVOWController {
    function vow() external view returns (address);

    function vowAdmin() external view returns (address);

    function proxyAdmin() external view returns (address);

    function launchpad() external view returns (address);

    function swapHandler() external view returns (address);

    function vowTreasury() external view returns (address);

    function projectSwapWallet() external view returns (address);
}
