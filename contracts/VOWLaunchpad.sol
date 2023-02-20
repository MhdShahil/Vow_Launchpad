// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";
import "./common/VOWControl.sol";
import "./PriceOracle/PriceOracle.sol";

//import "./interfaces/ITestERC20.sol";
import "./interfaces/IVOWProjectToken.sol";

contract VOWLaunchpad is VOWControl {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ITestERC20 public vowToken;
    IVOWProjectToken public projectToken;
    uint256 public constant PERCENT_DENOMINATOR = 10000;

    uint256 public feePercentage; // Percentage of Funds raised to be paid as fee
    uint256 public ETHFromFailedTransfers; // ETH left in the contract from failed transfers

    struct Project {
        bool projectType; // 0 for fixed returns and 1 for Dynamic returns
        string projectTokenName; // Name of the project token
        string projectTokenSymbol; //Symbol of the project token
        uint256 targetInvestmentInVow; // Funds targeted to be raised for the project
        uint256 minInvestmentInVow; // Minimum amount of vow token that can be invested
        uint256 projectOpenTime; // Timestamp at which the Project is open
        uint256 projectLockInTime; // Vow lock-in duration
        address[] acceptedTokens; //List of accepted tokens
        address projectReturnTokens; //ERC20 token in which returns are added to the project
        uint256 projectReturnAmount; // Amount of return tokens(zero for dynamic returns)
        address projectTreasury; //Address of the project treasury
    }
    struct ProjectInvestment {
        uint256 totalInvestment; // Total investment in payment token
        uint256 totalProjectTokensClaimed; // Total number of Project tokens claimed
        uint256 totalInvestors; // Total number of investors
        bool collected; // Boolean indicating if the investment raised in Project collected
    }

    struct Investor {
        uint256 investment; // Amount of vow tokens invested by the investor
        bool claimed; // Boolean indicating if user has claimed Project tokens
        bool refunded; // Boolean indicating if user is refunded
    }
    mapping(string => Project) private _projects; // Project ID => Project{}
    mapping(string => ProjectInvestment) private _projectInvestments; // Project ID => ProjectInvestment{}
    mapping(string => mapping(address => Investor)) private _projectInvestors; // Project ID => userAddress => Investor{}
    mapping(string => mapping(address => bool)) private _paymentSupported; // projectId => tokenAddress => Is token supported as payment

    /* Events */
    event SetFeePercentage(uint256 feePercentage);
    event AddPaymentToken(address indexed paymentToken);
    event RemovePaymentToken(address indexed paymentToken);
    event ProjectAdd(
        string projectId,
        string projectTokenName,
        uint256 projectLockInTime
    );
    event ProjectInvestmentCollect(string projectId);
    event ProjectInvest(
        string projectId,
        address indexed investor,
        uint256 investment
    );
    // event ProjectInvestmentClaim(
    //     string projectId,
    //     address indexed investor,
    //     uint256 tokenAmount
    // );
    // event ProjectInvestmentRefund(
    //     string projectId,
    //     address indexed investor,
    //     uint256 refundAmount
    // );
    event TransferOfETHFail(address indexed receiver, uint256 indexed amount);

    /* Modifiers */
    modifier onlyValid(string calldata projectId) {
        require(projectExist(projectId), "VOWLaunchpad: invalid Project");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _vowController) public initializer {
        __VOWControl_init(_vowController);
    }

    /**
     * @notice This method is used to set commission percentage for the launchpad
     * @param _feePercentage Percentage from raised funds to be set as fee
     */
    function setFee(uint256 _feePercentage) external onlyVowAdmin {
        require(
            _feePercentage <= 10000,
            "VOWLaunchpad: fee Percentage should be less than 10000"
        );
        feePercentage = _feePercentage;
        emit SetFeePercentage(_feePercentage);
    }

    /* Helper Functions */
    /* Payment Token */
    /**
     * @notice This method is used to add Payment token
     * @param projectId Id of the project
     * @param _paymentToken Address of payment token to be added
     */
    function addPaymentToken(
        string projectId,
        address _paymentToken
    ) external onlyVowAdmin {
        require(
            !_paymentSupported[_paymentToken],
            "VOWLaunchpad: token already added"
        );
        require(
            address(_paymentToken) != address(0),
            "VOWLaunchpad: Invalid payment token address"
        );
        _projects[projectId].acceptedTokens.push(_paymentToken);
        _paymentSupported[projectId][_paymentToken] = true;
        emit AddPaymentToken(_paymentToken);
    }

    /**
     * @notice This method is used to remove Payment token
     * @param projectId Id of the project
     * @param _paymentToken Address of payment token to be removed
     */
    function removePaymentToken(
        string projectId,
        address _paymentToken
    ) external onlyVowAdmin {
        require(
            _paymentSupported[projectId][_paymentToken],
            "VOWLaunchpad: token not added"
        );

        _paymentSupported[_paymentToken] = false;
        emit RemovePaymentToken(_paymentToken);
    }

    /**
     * @notice This method is used to remove Payment token
     * @param projectId Id of the project
     */
    function listPaymentTokens(
        string projectId
    ) public view returns (address[] memory) {
        return _projects[projectId].acceptedTokens;
    }

    // /**
    //  * @notice Helper function to transfer tokens based on type
    //  * @param receiver Address of the receiver
    //  * @param paymentToken Address of the token to be transferred
    //  * @param amount Number of tokens to transfer
    //  */
    // function transferTokens(
    //     address receiver,
    //     address paymentToken,
    //     uint256 amount
    // ) internal {
    //     if (amount != 0) {
    //         if (paymentToken != address(0)) {
    //             IERC20Upgradeable(paymentToken).safeTransfer(receiver, amount);
    //         } else {
    //             (bool success, ) = payable(receiver).call{value: amount}("");
    //             if (!success) {
    //                 ETHFromFailedTransfers += amount;
    //                 emit TransferOfETHFail(receiver, amount);
    //             }
    //         }
    //     }
    // }

    /* Project */
    /**
     * @notice This method is used to check if an Project exist
     * @param projectId ID of the Project
     */
    function projectExist(
        string calldata projectId
    ) public view returns (bool) {
        return _projects[projectId] ? true : false;
    }

    /**
     * @notice This method is used to get Project details
     * @param projectId ID of the Project
     */
    function getProject(
        string calldata projectId
    ) external view onlyValid(projectId) returns (Project memory) {
        return _projects[projectId];
    }

    /**
     * @notice This method is used to get Project Investment details
     * @param projectId ID of the Project
     */
    function getProjectInvestment(
        string calldata projectId
    ) external view onlyValid(projectId) returns (ProjectInvestment memory) {
        return _projectInvestments[projectId];
    }

    /**
     * @notice This method is used to get Project Investment details of an investor
     * @param projectId ID of the Project
     * @param investor Address of the investor
     */
    function getInvestor(
        string calldata projectId,
        address investor
    ) external view onlyValid(projectId) returns (Investor memory) {
        return _projectInvestors[projectId][investor];
    }

    /**
     * @notice This method is used to add a new project
     * @dev This method can only be called by the contract owner
     * @param projectId ID of the Project to be added
     * @param projectType Type of the project(0 for fixed returns and 1 for Dynamic returns)
     * @param projectTokenName Name of the project token
     * @param projectTokenSymbol Symbol of the project token
     * @param targetInvestmentInVow Targeted amount to be raised in Project
     * @param minInvestmentInVow Minimum amount of vow token that can be invested in Project
     * @param projectOpenTime Project open timestamp
     * @param projectLockInTime Vow lock-in duration
     * @param acceptedTokens Addresses of payment tokens accepted
     * @param projectReturnTokens Address of project return token
     * @param projectReturnAmount Amount of project return tokens
     * @param projectTreasury address of the treasury
     */
    function addProject(
        string calldata projectId,
        bool projectType,
        string projectTokenName,
        string projectTokenSymbol,
        uint256 targetInvestmentInVow,
        uint256 minInvestmentInVow,
        uint256 projectOpenTime,
        uint256 projectLockInTime,
        address[] acceptedTokens,
        address projectReturnTokens,
        uint256 projectReturnAmount,
        address projectTreasury
    ) external onlyVowAdmin {
        require(
            !projectExist(projectId),
            "VOWLaunchpad: Project id already exist"
        );
        require(
            projectTreasury != address(0),
            "VOWLaunchpad: Project Treasury zero"
        );

        require(targetInvestmentInVow != 0, "VOWLaunchpad: target amount zero");
        require(
            projectTokenName && projectTokenSymbol != "",
            "VOWLaunchpad: Project token name or symbol not given"
        );
        require(
            block.timestamp <= projectOpenTime,
            "VOWLaunchpad: Project invalid timestamps"
        );

        _projects[projectId] = Project(
            projectType,
            projectTokenName,
            projectTokenSymbol,
            targetInvestmentInVow,
            minInvestmentInVow,
            projectOpenTime,
            projectLockInTime,
            acceptedTokens,
            projectReturnTokens,
            projectReturnAmount,
            projectTreasury
        );
        projectToken.initialize(
            projectTokenName,
            projectTokenSymbol,
            vowController.vowAdmin()
        );
        if (_projects[projectId].projectType) {
            IERC20Upgradeable(_projects[projectId].projectReturnTokens)
                .transferFrom(
                    projectTreasury,
                    address(this),
                    projectReturnAmount
                );
        }
        emit ProjectAdd(projectId, projectTokenName, projectLockInTime);
    }

    // /**
    //  * @notice This method is used to cancel a Project
    //  * @dev This method can only be called by the contract owner
    //  * @param projectId ID of the Project
    //  */
    // function cancelProject(
    //     string calldata projectId
    // ) external onlyVowAdmin onlyValid(projectId) {
    //     Project memory project = _projects[projectId];
    //     require(!project.cancelled, "VOWLaunchpad: Project already cancelled");

    //     _projects[projectId].cancelled = true;
    //     // IERC20Upgradeable(project.projectToken).safeTransfer(
    //     //     project.projectOwner,
    //     //     project.tokensForDistribution
    //     // );
    // }

    // /**
    //  * @notice This method is used to claim investments of a user's project
    //  * @param projectId ID of the Project
    //  */
    // function InvestInProject(
    //     string calldata projectId,
    //     address _paymentToken
    // ) external onlyValid(projectId) {
    //     Project memory project = _projects[projectId];
    //     //require(!project.cancelled, "VOWLaunchpad: Project is cancelled");
    //     require(
    //         block.timestamp >= project.projectOpenTime,
    //         "VOWLaunchpad: Project not open"
    //     );
    //     require(
    //         _paymentSupported[projectId][_paymentToken],
    //         "VOWLaunchpad: Payment token not supported"
    //     );
    //     Investor memory investor = _projectInvestors[projectId][msg.sender];

    //     // validate enough days have passed from lock in period
    //     uint256 daysPassed = (block.timestamp - project.projectCloseTime) /
    //         1 days;

    //     require(
    //         daysPassed > projectLockInTime,
    //         "VOWLaunchpad: Project lock-in duration not over"
    //     );

    //     uint256 platformShare = feePercentage == 0
    //         ? 0
    //         : (feePercentage * projectInvestment.totalInvestment) /
    //             PERCENT_DENOMINATOR;

    //     _projectInvestors[projectId][msg.sender].claimed = true;

    //     transferTokens(vowController.vowTreasury(), vowToken, platformShare);
    //     transferTokens(
    //         project.projectOwner,
    //         vowToken,
    //         investor.investment - platformShare
    //     );

    //     emit ProjectInvestmentCollect(projectId);
    // }

    /**
     * @notice This method is used to invest in an Project
     * @dev User must send _amount in order to invest
     * @param projectId ID of the Project
     * @param _paymentToken Address of the payment token
     * @param _amount Amount of payment token the user wish to invest
     */
    function invest(
        string calldata projectId,
        address _paymentToken,
        uint256 _amount
    ) external payable onlyValid(projectId) {
        require(_amount != 0, "VOWLaunchpad: investment zero");

        Project memory project = _projects[projectId];
        require(
            block.timestamp >= project.projectOpenTime,
            "VOWLaunchpad: Project is not open"
        );
        require(
            _paymentSupported[projectId][_paymentToken],
            "VOWLaunchpad: Payment token not supported"
        );
        require(
            _amount >= project.minInvestmentInVow,
            "VOWLaunchpad: amount less than minimum investment"
        );
        ProjectInvestment storage projectInvestment = _projectInvestments[
            projectId
        ];

        require(
            project.targetInvestmentInVow >=
                projectInvestment.totalInvestment + _amount,
            "VOWLaunchpad: amount exceeds target"
        );

        projectInvestment.totalInvestment += _amount;
        if (_projectInvestors[projectId][msg.sender].investment == 0)
            ++projectInvestment.totalInvestors;
        _projectInvestors[projectId][msg.sender].investment += _amount;

        IERC20Upgradeable(_paymentToken).safeTransferFrom(
            msg.sender,
            vowController.vowTreasury(),
            _amount
        );
        uint256 amountOfVowTokens = PriceOracle.calculateTokensToVow(_amount);
        IERC20Upgradeable(vowToken).safeTransferFrom(
            Project.projectTreasury,
            address(this),
            amountOfVowTokens
        );
        projectToken.mint(msg.sender, amountOfVowTokens);

        emit ProjectInvest(projectId, msg.sender, _amount);
    }

    // /**
    //  * @notice This method is used to refund investment if Project is cancelled
    //  * @param projectId ID of the Project
    //  */
    // function refundInvestment(
    //     string calldata projectId
    // ) external onlyValid(projectId) {
    //     Project memory project = _projects[projectId];
    //     require(project.cancelled, "VOWLaunchpad: Project is not cancelled");

    //     Investor memory user = _projectInvestors[projectId][msg.sender];
    //     require(!user.refunded, "VOWLaunchpad: already refunded");
    //     require(user.investment != 0, "VOWLaunchpad: no investment found");

    //     _projectInvestors[projectId][msg.sender].refunded = true;
    //     transferTokens(msg.sender, project.paymentToken, user.investment);

    //     emit ProjectInvestmentRefund(projectId, msg.sender, user.investment);
    // }

    // function claimProjectTokens(
    //     string calldata projectId
    // ) external onlyValid(projectId) {
    //     Project memory project = _projects[projectId];

    //     require(!project.cancelled, "VOWLaunchpad: Project is cancelled");
    //     require(
    //         block.timestamp > project.projectCloseTime,
    //         "VOWLaunchpad: Project not closed yet"
    //     );

    //     Investor memory user = _projectInvestors[projectId][msg.sender];
    //     require(!user.claimed, "VOWLaunchpad: already claimed");
    //     require(user.investment != 0, "VOWLaunchpad: no investment found");

    //     uint256 projectTokens = estimateProjectTokens(
    //         project.projectToken,
    //         project.tokenPrice,
    //         user.investment
    //     );
    //     _projectInvestors[projectId][msg.sender].claimed = true;
    //     _projectInvestments[projectId]
    //         .totalProjectTokensClaimed += projectTokens;

    //     IERC20Upgradeable(project.projectToken).safeTransfer(
    //         msg.sender,
    //         projectTokens
    //     );

    //     emit ProjectInvestmentClaim(projectId, msg.sender, projectTokens);
    // }

    /**
     * @notice This method is to collect any ETH left from failed transfers.
     * @dev This method can only be called by the contract owner
     */
    function collectETHFromFailedTransfers() external onlyVowAdmin {
        uint256 ethToSend = ETHFromFailedTransfers;
        ETHFromFailedTransfers = 0;
        (bool success, ) = payable(vowController.vowTreasury()).call{
            value: ethToSend
        }("");
        require(success, "VOWLaunchpad: ETH transfer failed");
    }
}
