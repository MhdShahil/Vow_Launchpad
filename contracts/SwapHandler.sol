// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.17;

// import "@openzeppelin/contracts-upgradeable/token/ERC777/IERC777RecipientUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "./common/VOWControl.sol";

// contract SwapHandler is VOWControl, IERC777RecipientUpgradeable {
//     using SafeERC20Upgradeable for IERC20Upgradeable;
//     struct Project {
//         uint256 vowAllocated;
//         uint256 vowReclaimed;
//         uint256 swapped;
//         bool added;
//     }

//     mapping(address => Project) private projects;

//     /// @custom:oz-upgrades-unsafe-allow constructor
//     constructor() initializer {}

//     function initialize(address _vowController) external initializer {
//         __VOWControl_init(_vowController);
//     }

//     function addProject(address _projectToken, uint256 _vowAllocated)
//         external
//         onlyLaunchpad
//     {
//         require(
//             !projects[_projectToken].added,
//             "SwapHandler: project already added"
//         );
//         projects[_projectToken] = Project(_vowAllocated, 0, 0, true);
//         IERC20Upgradeable(vowController.vow()).safeTransferFrom(
//             vowController.vowTreasury(),
//             address(this),
//             _vowAllocated
//         );
//     }

//     function cancelProject(address _projectToken) external onlyLaunchpad {
//         require(
//             projects[_projectToken].added,
//             "SwapHandler: project not added"
//         );

//         Project memory project = projects[_projectToken];
//         projects[_projectToken].vowReclaimed = project.vowAllocated;

//         IERC20Upgradeable(vowController.vow()).safeTransfer(
//             vowController.vowTreasury(),
//             project.vowAllocated
//         );
//     }

//     function closeProject(address _projectToken) external onlyLaunchpad {
//         require(
//             projects[_projectToken].added,
//             "SwapHandler: project not added"
//         );

//         Project memory project = projects[_projectToken];

        
//         projects[_projectToken].vowReclaimed = project.vowAllocated;

//         IERC20Upgradeable(vowController.vow()).safeTransfer(
//             vowController.vowTreasury(),
//             project.vowAllocated
//         );
//     }

//     function tokensReceived(
//         address operator,
//         address from,
//         address to,
//         uint256 amount,
//         bytes calldata userData,
//         bytes calldata operatorData
//     ) external {}
// }
