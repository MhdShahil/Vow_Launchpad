// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "./common/VOWControl.sol";

contract VOWLaunchpad is VOWControl {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    ITestERC20 public vowToken;
    uint256 public constant PERCENT_DENOMINATOR = 10000;

    uint256 public feePercentage; // Percentage of Funds raised to be paid as fee
    uint256 public ETHFromFailedTransfers; // ETH left in the contract from failed transfers

    struct Project {
        address projectOwner; // Address of the Project owner
        uint256 targetAmountInVow; // Funds targeted to be raised for the project
        uint256 minInvestmentAmountInVow; // Minimum amount of payment token that can be invested
        address projectToken; // Address of the Project token
        uint256 projectOpenTime; // Timestamp at which the Project is open
        uint256 projectLockInTime; // Vow lock-in duration
        uint256 projectCloseTime; // Timestamp at which the Project is closed
        bool cancelled; // Boolean indicating if Project is cancelled
    }

    struct ProjectInvestment {
        uint256 totalInvestmentInVow; // Total investment in vow token
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

    /* Events */
    event SetFeePercentage(uint256 feePercentage);
    //event ProjectChangeCloseTime(string projectId, uint256 newProjectCloseTime);
    event ProjectCancel(string projectId);
    event ProjectInvestmentCollect(string projectId);
    event ProjectInvest(
        string projectId,
        address indexed investor,
        uint256 investment
    );
    event ProjectInvestmentClaim(
        string projectId,
        address indexed investor,
        uint256 tokenAmount
    );
    event ProjectInvestmentRefund(
        string projectId,
        address indexed investor,
        uint256 refundAmount
    );
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
    /**
     * @notice Helper function to transfer tokens based on type
     * @param receiver Address of the receiver
     * @param paymentToken Address of the token to be transferred
     * @param amount Number of tokens to transfer
     */
    function transferTokens(
        address receiver,
        address paymentToken,
        uint256 amount
    ) internal {
        if (amount != 0) {
            if (paymentToken != address(0)) {
                IERC20Upgradeable(paymentToken).safeTransfer(receiver, amount);
            } else {
                (bool success, ) = payable(receiver).call{value: amount}("");
                if (!success) {
                    ETHFromFailedTransfers += amount;
                    emit TransferOfETHFail(receiver, amount);
                }
            }
        }
    }

    /* Project */
    /**
     * @notice This method is used to check if an Project exist
     * @param projectId ID of the Project
     */
    function projectExist(
        string calldata projectId
    ) public view returns (bool) {
        return _projects[projectId].projectToken != address(0) ? true : false;
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
     * @param projectOwner Address of the Project owner
     * @param targetAmountInVow Targeted amount to be raised in Project
     * @param minInvestmentAmountInVow Minimum amount of payment token that can be invested in Project
     * @param projectToken Address of Project token
     * @param projectOpenTime Project open timestamp
     * @param projectLockInTime Vow lock-in duration
     */
    function addProject(
        string calldata projectId,
        address projectOwner,
        uint256 targetAmountInVow,
        uint256 minInvestmentAmountInVow,
        address projectToken,
        uint256 projectOpenTime,
        uint256 projectLockInTime
    ) external onlyVowAdmin {
        require(
            !projectExist(projectId),
            "VOWLaunchpad: Project id already exist"
        );
        require(projectOwner != address(0), "VOWLaunchpad: Project owner zero");

        require(targetAmountInVow != 0, "VOWLaunchpad: target amount zero");
        require(
            projectToken != address(0),
            "VOWLaunchpad: Project token address zero"
        );
        require(
            block.timestamp <= projectOpenTime,
            "VOWLaunchpad: Project invalid timestamps"
        );

        _projects[projectId] = Project(
            projectOwner,
            targetAmountInVow,
            minInvestmentAmountInVow,
            projectToken,
            projectOpenTime,
            projectLockInTime,
            projectCloseTime,
            false
        );

        // IERC20Upgradeable(_projects[projectId].projectToken).mint(
        //     address(this),
        //     targetAmountInVow
        // );
        emit ProjectAdd(projectId, projectOwner, projectToken);
    }

    // /**
    //  * @notice This method is used to change Project close time
    //  * @dev This method can only be called by the contract owner
    //  * @param projectId ID of the Project
    //  * @param newProjectCloseTime new close timestamp for Project
    //  */
    // function changeProjectCloseTime(
    //     string calldata projectId,
    //     uint256 newProjectCloseTime
    // ) external onlyVowAdmin onlyValid(projectId) {
    //     Project memory project = _projects[projectId];
    //     require(
    //         block.timestamp < project.projectCloseTime,
    //         "VOWLaunchpad: Project is closed"
    //     );
    //     require(!project.cancelled, "VOWLaunchpad: Project is cancelled");
    //     require(
    //         block.timestamp < newProjectCloseTime,
    //         "VOWLaunchpad: new Project close time is less than current time"
    //     );

    //     _projects[projectId].projectCloseTime = newProjectCloseTime;

    //     emit ProjectChangeCloseTime(projectId, newProjectCloseTime);
    // }

    /**
     * @notice This method is used to cancel a Project
     * @dev This method can only be called by the contract owner
     * @param projectId ID of the Project
     */
    function cancelProject(
        string calldata projectId
    ) external onlyVowAdmin onlyValid(projectId) {
        Project memory project = _projects[projectId];
        require(!project.cancelled, "VOWLaunchpad: Project already cancelled");

        _projects[projectId].cancelled = true;
        // IERC20Upgradeable(project.projectToken).safeTransfer(
        //     project.projectOwner,
        //     project.tokensForDistribution
        // );

        emit ProjectCancel(projectId);
    }

    /**
     * @notice This method is used to claim investments of a user's project
     * @param projectId ID of the Project
     */
    function collectProjectInvestment(
        string calldata projectId
    ) external onlyValid(projectId) {
        Project memory project = _projects[projectId];
        require(!project.cancelled, "VOWLaunchpad: Project is cancelled");

        Investor memory investor = _projectInvestors[projectId][msg.sender];

        require(
            investor.investment != 0,
            "VOWLaunchpad: Project investment already collected"
        );
        require(
            !investor.claim,
            "VOWLaunchpad: Project investment already claimed"
        );

        // validate enough days have passed from lock in period
        uint256 daysPassed = (block.timestamp - project.projectCloseTime) /
            1 days;

        require(
            daysPassed > projectLockInTime,
            "VOWLaunchpad: Project lock-in duration not over"
        );

        uint256 platformShare = feePercentage == 0
            ? 0
            : (feePercentage * projectInvestment.totalInvestment) /
                PERCENT_DENOMINATOR;

        _projectInvestors[projectId][msg.sender].claimed = true;

        transferTokens(vowController.vowTreasury(), vowToken, platformShare);
        transferTokens(
            project.projectOwner,
            vowToken,
            investor.investment - platformShare
        );

        emit ProjectInvestmentCollect(projectId);
    }

    /**
     * @notice This method is used to invest in an Project
     * @dev User must send _amount(vow) in order to invest
     * @param projectId ID of the Project
     */
    function invest(
        string calldata projectId,
        uint256 _amount
    ) external payable onlyValid(projectId) {
        require(_amount != 0, "VOWLaunchpad: investment zero");

        Project memory project = _projects[projectId];
        require(
            block.timestamp >= project.projectOpenTime,
            "VOWLaunchpad: Project is not open"
        );
        require(
            block.timestamp < project.projectCloseTime,
            "VOWLaunchpad: Project has closed"
        );
        require(!project.cancelled, "VOWLaunchpad: Project cancelled");
        require(
            _amount >= project.minInvestmentAmountInVow,
            "VOWLaunchpad: amount less than minimum investment"
        );
        ProjectInvestment storage projectInvestment = _projectInvestments[
            projectId
        ];

        require(
            project.targetAmountInVow >=
                projectInvestment.totalInvestment + _amount,
            "VOWLaunchpad: amount exceeds target"
        );

        projectInvestment.totalInvestment += _amount;
        if (_projectInvestors[projectId][msg.sender].investment == 0)
            ++projectInvestment.totalInvestors;
        _projectInvestors[projectId][msg.sender].investment += _amount;

        require(
            address(vowToken) != address(0),
            "VOWLaunchpad: Invalid vow token address"
        );

        IERC20Upgradeable(vowToken).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );
        IERC20Upgradeable(_projects[projectId].projectToken).mint(
            msg.sender,
            _amount
        );

        emit ProjectInvest(projectId, msg.sender, _amount);
    }

    /**
     * @notice This method is used to refund investment if Project is cancelled
     * @param projectId ID of the Project
     */
    function refundInvestment(
        string calldata projectId
    ) external onlyValid(projectId) {
        Project memory project = _projects[projectId];
        require(project.cancelled, "VOWLaunchpad: Project is not cancelled");

        Investor memory user = _projectInvestors[projectId][msg.sender];
        require(!user.refunded, "VOWLaunchpad: already refunded");
        require(user.investment != 0, "VOWLaunchpad: no investment found");

        _projectInvestors[projectId][msg.sender].refunded = true;
        transferTokens(msg.sender, project.paymentToken, user.investment);

        emit ProjectInvestmentRefund(projectId, msg.sender, user.investment);
    }

    function claimProjectTokens(
        string calldata projectId
    ) external onlyValid(projectId) {
        Project memory project = _projects[projectId];

        require(!project.cancelled, "VOWLaunchpad: Project is cancelled");
        require(
            block.timestamp > project.projectCloseTime,
            "VOWLaunchpad: Project not closed yet"
        );

        Investor memory user = _projectInvestors[projectId][msg.sender];
        require(!user.claimed, "VOWLaunchpad: already claimed");
        require(user.investment != 0, "VOWLaunchpad: no investment found");

        uint256 projectTokens = estimateProjectTokens(
            project.projectToken,
            project.tokenPrice,
            user.investment
        );
        _projectInvestors[projectId][msg.sender].claimed = true;
        _projectInvestments[projectId]
            .totalProjectTokensClaimed += projectTokens;

        IERC20Upgradeable(project.projectToken).safeTransfer(
            msg.sender,
            projectTokens
        );

        emit ProjectInvestmentClaim(projectId, msg.sender, projectTokens);
    }

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
