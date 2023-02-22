// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IPriceOracle {
    function setPriceFeedAddress(string memory, address, address) external;

    //function getTokenPrice(address) public view returns (int);

    function calculateTokensToVow(uint256) external view returns (uint256);
}
