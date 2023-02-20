// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract VOWController {
    address public vow; // Address of VOW token
    address public vowAdmin; // Address of VOW admin
    address public vowPotentialAdmin; // Address of VOW potential admin
    address public proxyAdmin; // Address of the admin capable of upgrading project token proxies
    address public launchpad; // Address of VOW launchpad
    address public swapHandler; // Address of the contract that handles logic for sending VOW tokens on project token transfers to project Treasury
    address public vowTreasury; // Address in which VOW tokens resides and have set allowance for launchpad
    address public projectSwapWallet; // Address to which project tokens are send to swap for VOW

    /* Events */
    event AdminChange(address newAdmin);
    event NominateAdmin(address potentialAdmin);

    constructor(
        address _vow,
        address _vowTreasury,
        address _projectSwapWallet
    ) {
        vow = _vow;
        vowTreasury = _vowTreasury;
        projectSwapWallet = _projectSwapWallet;
        vowAdmin = msg.sender;
    }

    /* Modifiers */
    modifier onlyVowAdmin() {
        require(msg.sender == vowAdmin, "VOWController: only vow admin");
        _;
    }

    /* Functions */

    /**
     * @notice This function is used to add a potential admin for the contract
     * @dev Only the admin can call this function
     * @param _vowPotentialAdmin Address of the potential admin
     */
    function addPotentialAdmin(
        address _vowPotentialAdmin
    ) external onlyVowAdmin {
        require(
            _vowPotentialAdmin != address(0),
            "VOWController: potential admin zero"
        );
        require(
            _vowPotentialAdmin != vowAdmin,
            "VOWController: potential owner same as admin"
        );
        vowPotentialAdmin = _vowPotentialAdmin;
        emit NominateAdmin(_vowPotentialAdmin);
    }

    /**
     * @notice This function is used to accept admin invite for the contract
     */
    function acceptAdminInvite() external {
        require(
            msg.sender == vowPotentialAdmin,
            "VOWController: only potential admin"
        );
        vowAdmin = vowPotentialAdmin;
        delete vowPotentialAdmin;
        emit AdminChange(vowAdmin);
    }

    /**
     * @notice This function is used to set address of the VOW launchpad
     * @dev Only the admin can call this function
     * @param _launchpad Address of the launchpad
     */
    function setLaunchpad(address _launchpad) external onlyVowAdmin {
        launchpad = _launchpad;
    }

    /**
     * @notice This function is used to set address of the project token swap handler
     * @dev Only the admin can call this function
     * @param _swapHandler Address of the swap handler
     */
    function setSwapHandler(address _swapHandler) external onlyVowAdmin {
        swapHandler = _swapHandler;
    }

    /**
     * @notice This function is used to set address of the VOW token treasury
     * @dev Only the admin can call this function
     * @param _vowTreasury Address of the vow token treasury
     */
    function setVOWTreasury(address _vowTreasury) external onlyVowAdmin {
        vowTreasury = _vowTreasury;
    }

    /**
     * @notice This function is used to set address of project token swap wallet
     * @dev Only the admin can call this function
     * @param _projectSwapWallet Address of the project swap wallet
     */
    function setProjectSwapWallet(
        address _projectSwapWallet
    ) external onlyVowAdmin {
        projectSwapWallet = _projectSwapWallet;
    }
}
