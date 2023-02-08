// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";
import "../common/Singleton.sol";
import "../common/VOWControl.sol";

contract VOWProjectToken is Singleton, VOWControl, ERC777Upgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(
        string memory _name,
        string memory _symbol,
        address _vowController
    ) external initializer {
        address[] memory defaultOperators;
        __ERC777_init(_name, _symbol, defaultOperators);
        __VOWControl_init(_vowController);
    }

    /**
     * @notice This function is to upgrade the proxy to a new implementation
     * @dev Only proxy admin can call this function
     * @param _singleton Address of the new implementation contract
     */
    function upgradeSingleton(address _singleton) external onlyProxyAdmin {
        singleton = _singleton;
    }

    /**
     * @notice This function is to used to mint new tokens
     * @dev Only launchpad can call this function
     * @param account Address to which new tokens are minted to
     * @param amount Amount of tokens to mint
     */
    function mint(address account, uint256 amount) external onlyLaunchpad {
        _mint(account, amount, "", "", false);
    }

    /**
     * @notice This function is to used to burn tokens
     * @dev Only launchpad can call this function
     * @param account Address from which tokens would be burned
     * @param amount Amount of tokens to burn
     */
    function burn(address account, uint256 amount) external onlyLaunchpad {
        _burn(account, amount, "", "");
    }
}
