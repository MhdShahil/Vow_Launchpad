// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ILaunchpad {
    function getIDO(
        string calldata
    )
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            bool
        );
}
