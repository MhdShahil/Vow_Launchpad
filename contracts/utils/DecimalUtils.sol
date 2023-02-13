// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library DecimalUtils {
    function to18Decimals(
        int256 amount,
        uint8 decimals
    ) internal pure returns (uint256) {
        if (decimals < 18)
            return uint256(amount) * 10 ** uint256(18 - decimals);
        else if (decimals > 18)
            return uint256(amount) / 10 ** uint256(decimals - 18);
        else return uint256(amount);
    }

    function to18Decimals(
        uint256 amount,
        address token
    ) internal view returns (uint256) {
        uint8 decimals = ERC20Detailed(token).decimals();
        if (decimals < 18) return amount * 10 ** uint256(18 - decimals);
        else if (decimals > 18) return amount / 10 ** uint256(decimals - 18);
        else return amount;
    }

    function from18Decimals(
        uint256 amount,
        address token
    ) internal view returns (uint256) {
        uint8 decimals = ERC20Detailed(token).decimals();
        if (decimals < 18) return amount / 10 ** uint256(18 - decimals);
        else if (decimals > 18) return amount * 10 ** uint256(decimals - 18);
        else return amount;
    }
}
