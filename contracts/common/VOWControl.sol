// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../interfaces/IVOWController.sol";

contract VOWControl is Initializable {
    IVOWController public vowController;

    function __VOWControl_init(
        address _vowController
    ) internal onlyInitializing {
        require(
            _vowController != address(0),
            "VOWControl: zero controller address"
        );
        vowController = IVOWController(_vowController);
    }

    modifier onlyVowAdmin() {
        require(
            msg.sender == vowController.vowAdmin(),
            "VOWControl: only vow admin"
        );
        _;
    }

    modifier onlyProxyAdmin() {
        require(
            msg.sender == vowController.proxyAdmin(),
            "VOWControl: only proxy admin"
        );
        _;
    }

    modifier onlyLaunchpad() {
        require(
            msg.sender == vowController.launchpad(),
            "VOWControl: only launchpad"
        );
        _;
    }
}
