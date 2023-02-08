// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "./common/VOWControl.sol";

contract VOWLaunchpad is VOWControl {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    uint256 public constant PERCENT_DENOMINATOR = 10000;

    uint256 public feePercentage; // Percentage of Funds raised to be paid as fee
    uint256 public ETHFromFailedTransfers; // ETH left in the contract from failed transfers

    struct Project {
        address projectOwner; // Address of the Project owner
        address paymentToken; // Address of the payment token
        uint256 targetAmount; // Funds targeted to be raised for the project
        uint256 minInvestmentAmount; // Minimum amount of payment token that can be invested
        address projectToken; // Address of the Project token
        uint256 tokensForDistribution; // Number of tokens to be distributed
        uint256 tokenPrice; // Token price in payment token (Decimals same as payment token)
        uint256 projectOpenTime; // Timestamp at which the Project is open
        uint256 projectCloseTime; // Timestamp at which the Project is closed
        bool cancelled; // Boolean indicating if Project is cancelled
    }

    struct ProjectInvestment {
        uint256 totalInvestment; // Total investment in payment token
        uint256 totalProjectTokensClaimed; // Total number of Project tokens claimed
        uint256 totalInvestors; // Total number of investors
        bool collected; // Boolean indicating if the investment raised in Project collected
    }

    struct Investor {
        uint256 investment; // Amount of payment tokens invested by the investor
        bool claimed; // Boolean indicating if user has claimed Project tokens
        bool refunded; // Boolean indicating if user is refunded
    }

    mapping(string => Project) private _projects; // Project ID => Project{}

    mapping(string => ProjectInvestment) private _projectInvestments; // Project ID => ProjectInvestment{}

    mapping(string => mapping(address => Investor)) private _projectInvestors; // Project ID => userAddress => Investor{}

    mapping(address => bool) private _paymentSupported; // tokenAddress => Is token supported as payment

    /* Events */
    event SetFeePercentage(uint256 feePercentage);
    event AddPaymentToken(address indexed paymentToken);
    event RemovePaymentToken(address indexed paymentToken);
    event ProjectAdd(
        string projectId,
        address projectOwner,
        address projectToken
    );
    event ProjectChangeCloseTime(string projectId, uint256 newProjectCloseTime);
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

    /* Payment Token */
    /**
     * @notice This method is used to add Payment token
     * @param _paymentToken Address of payment token to be added
     */
    function addPaymentToken(address _paymentToken) external onlyVowAdmin {
        require(
            !_paymentSupported[_paymentToken],
            "VOWLaunchpad: token already added"
        );
        _paymentSupported[_paymentToken] = true;
        emit AddPaymentToken(_paymentToken);
    }

    /**
     * @notice This method is used to remove Payment token
     * @param _paymentToken Address of payment token to be removed
     */
    function removePaymentToken(address _paymentToken) external onlyVowAdmin {
        require(
            _paymentSupported[_paymentToken],
            "VOWLaunchpad: token not added"
        );
        _paymentSupported[_paymentToken] = false;
        emit RemovePaymentToken(_paymentToken);
    }

    /**
     * @notice This method is used to check if a payment token is supported
     * @param _paymentToken Address of the token
     */
    function isPaymentTokenSupported(address _paymentToken)
        external
        view
        returns (bool)
    {
        return _paymentSupported[_paymentToken];
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

    /**
     * @notice Helper function to estimate Project token amount for payment
     * @param amount Amount of payment tokens
     * @param projectToken Address of the Project token
     * @param tokenPrice Price for Project token
     */
    function estimateProjectTokens(
        address projectToken,
        uint256 tokenPrice,
        uint256 amount
    ) public view returns (uint256 projectTokenCount) {
        uint256 projectTokenDecimals = uint256(
            IERC20MetadataUpgradeable(projectToken).decimals()
        );
        projectTokenCount = (amount * 10**projectTokenDecimals) / tokenPrice;
    }

    /**
     * @notice Helper function to estimate Project token amount for payment
     * @param projectId ID of the Project
     * @param amount Amount of payment tokens
     */
    function estimateProjectTokensById(
        string calldata projectId,
        uint256 amount
    ) external view onlyValid(projectId) returns (uint256 projectTokenCount) {
        uint256 projectTokenDecimals = uint256(
            IERC20MetadataUpgradeable(_projects[projectId].projectToken)
                .decimals()
        );
        projectTokenCount =
            (amount * 10**projectTokenDecimals) /
            _projects[projectId].tokenPrice;
    }

    /* Project */
    /**
     * @notice This method is used to check if an Project exist
     * @param projectId ID of the Project
     */
    function projectExist(string calldata projectId)
        public
        view
        returns (bool)
    {
        return _projects[projectId].projectToken != address(0) ? true : false;
    }

    /**
     * @notice This method is used to get Project details
     * @param projectId ID of the Project
     */
    function getProject(string calldata projectId)
        external
        view
        onlyValid(projectId)
        returns (Project memory)
    {
        return _projects[projectId];
    }

    /**
     * @notice This method is used to get Project Investment details
     * @param projectId ID of the Project
     */
    function getProjectInvestment(string calldata projectId)
        external
        view
        onlyValid(projectId)
        returns (ProjectInvestment memory)
    {
        return _projectInvestments[projectId];
    }

    /**
     * @notice This method is used to get Project Investment details of an investor
     * @param projectId ID of the Project
     * @param investor Address of the investor
     */
    function getInvestor(string calldata projectId, address investor)
        external
        view
        onlyValid(projectId)
        returns (Investor memory)
    {
        return _projectInvestors[projectId][investor];
    }

    /**
     * @notice This method is used to add a new project
     * @dev This method can only be called by the contract owner
     * @param projectId ID of the Project to be added
     * @param projectOwner Address of the Project owner
     * @param paymentToken Payment token to be used for the Project
     * @param targetAmount Targeted amount to be raised in Project
     * @param minInvestmentAmount Minimum amount of payment token that can be invested in Project
     * @param projectToken Address of Project token
     * @param tokenPrice Project token price in terms of payment token
     * @param projectOpenTime Project open timestamp
     * @param projectCloseTime Project close timestamp
     */
    function addProject(
        string calldata projectId,
        address projectOwner,
        address paymentToken,
        uint256 targetAmount,
        uint256 minInvestmentAmount,
        address projectToken,
        uint256 tokenPrice,
        uint256 projectOpenTime,
        uint256 projectCloseTime
    ) external onlyVowAdmin {
        require(
            !projectExist(projectId),
            "VOWLaunchpad: Project id already exist"
        );
        require(projectOwner != address(0), "VOWLaunchpad: Project owner zero");
        require(
            _paymentSupported[paymentToken],
            "VOWLaunchpad: payment token not supported"
        );
        require(targetAmount != 0, "VOWLaunchpad: target amount zero");
        require(
            projectToken != address(0),
            "VOWLaunchpad: Project token address zero"
        );
        require(tokenPrice != 0, "VOWLaunchpad: token price zero");
        require(
            block.timestamp <= projectOpenTime &&
                projectOpenTime < projectCloseTime,
            "VOWLaunchpad: Project invalid timestamps"
        );
        uint256 tokensForDistribution = estimateProjectTokens(
            projectToken,
            tokenPrice,
            targetAmount
        );

        _projects[projectId] = Project(
            projectOwner,
            paymentToken,
            targetAmount,
            minInvestmentAmount,
            projectToken,
            tokensForDistribution,
            tokenPrice,
            projectOpenTime,
            projectCloseTime,
            false
        );

        IERC20Upgradeable(_projects[projectId].projectToken).safeTransferFrom(
            projectOwner,
            address(this),
            tokensForDistribution
        );
        emit ProjectAdd(projectId, projectOwner, projectToken);
    }

    /**
     * @notice This method is used to change Project close time
     * @dev This method can only be called by the contract owner
     * @param projectId ID of the Project
     * @param newProjectCloseTime new close timestamp for Project
     */
    function changeProjectCloseTime(
        string calldata projectId,
        uint256 newProjectCloseTime
    ) external onlyVowAdmin onlyValid(projectId) {
        Project memory project = _projects[projectId];
        require(
            block.timestamp < project.projectCloseTime,
            "VOWLaunchpad: Project is closed"
        );
        require(!project.cancelled, "VOWLaunchpad: Project is cancelled");
        require(
            block.timestamp < newProjectCloseTime,
            "VOWLaunchpad: new Project close time is less than current time"
        );

        _projects[projectId].projectCloseTime = newProjectCloseTime;

        emit ProjectChangeCloseTime(projectId, newProjectCloseTime);
    }

    /**
     * @notice This method is used to cancel a Project
     * @dev This method can only be called by the contract owner
     * @param projectId ID of the Project
     */
    function cancelProject(string calldata projectId)
        external
        onlyVowAdmin
        onlyValid(projectId)
    {
        Project memory project = _projects[projectId];
        require(!project.cancelled, "VOWLaunchpad: Project already cancelled");
        require(
            block.timestamp < project.projectCloseTime,
            "VOWLaunchpad: Project is closed"
        );

        _projects[projectId].cancelled = true;

        IERC20Upgradeable(project.projectToken).safeTransfer(
            project.projectOwner,
            project.tokensForDistribution
        );

        emit ProjectCancel(projectId);
    }

    /**
     * @notice This method is used to distribute investment raised in Project
     * @dev This method can only be called by the contract owner
     * @param projectId ID of the Project
     */
    function collectProjectInvestment(string calldata projectId)
        external
        onlyVowAdmin
        onlyValid(projectId)
    {
        Project memory project = _projects[projectId];
        require(!project.cancelled, "VOWLaunchpad: Project is cancelled");
        require(
            block.timestamp > project.projectCloseTime,
            "VOWLaunchpad: Project is open"
        );

        ProjectInvestment memory projectInvestment = _projectInvestments[
            projectId
        ];

        require(
            !projectInvestment.collected,
            "VOWLaunchpad: Project investment already collected"
        );
        require(
            projectInvestment.totalInvestment != 0,
            "VOWLaunchpad: Project investment zero"
        );

        uint256 platformShare = feePercentage == 0
            ? 0
            : (feePercentage * projectInvestment.totalInvestment) /
                PERCENT_DENOMINATOR;

        _projectInvestments[projectId].collected = true;

        transferTokens(
            vowController.vowTreasury(),
            project.paymentToken,
            platformShare
        );
        transferTokens(
            project.projectOwner,
            project.paymentToken,
            projectInvestment.totalInvestment - platformShare
        );

        uint256 projectTokensLeftover = project.tokensForDistribution -
            estimateProjectTokens(
                project.projectToken,
                project.tokenPrice,
                projectInvestment.totalInvestment
            );
        transferTokens(
            project.projectOwner,
            project.projectToken,
            projectTokensLeftover
        );

        emit ProjectInvestmentCollect(projectId);
    }

    /**
     * @notice This method is used to invest in an Project
     * @dev User must send _amount in order to invest
     * @param projectId ID of the Project
     */
    function invest(string calldata projectId, uint256 _amount)
        external
        payable
        onlyValid(projectId)
    {
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
            _amount >= project.minInvestmentAmount,
            "VOWLaunchpad: amount less than minimum investment"
        );
        ProjectInvestment storage projectInvestment = _projectInvestments[
            projectId
        ];

        require(
            project.targetAmount >= projectInvestment.totalInvestment + _amount,
            "VOWLaunchpad: amount exceeds target"
        );

        projectInvestment.totalInvestment += _amount;
        if (_projectInvestors[projectId][msg.sender].investment == 0)
            ++projectInvestment.totalInvestors;
        _projectInvestors[projectId][msg.sender].investment += _amount;

        if (project.paymentToken == address(0)) {
            require(
                msg.value == _amount,
                "VOWLaunchpad: msg.value not equal to amount"
            );
        } else {
            require(
                msg.value == 0,
                "VOWLaunchpad: msg.value not equal to zero"
            );
            IERC20Upgradeable(project.paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }

        emit ProjectInvest(projectId, msg.sender, _amount);
    }

    /**
     * @notice This method is used to refund investment if Project is cancelled
     * @param projectId ID of the Project
     */
    function refundInvestment(string calldata projectId)
        external
        onlyValid(projectId)
    {
        Project memory project = _projects[projectId];
        require(project.cancelled, "VOWLaunchpad: Project is not cancelled");

        Investor memory user = _projectInvestors[projectId][msg.sender];
        require(!user.refunded, "VOWLaunchpad: already refunded");
        require(user.investment != 0, "VOWLaunchpad: no investment found");

        _projectInvestors[projectId][msg.sender].refunded = true;
        transferTokens(msg.sender, project.paymentToken, user.investment);

        emit ProjectInvestmentRefund(projectId, msg.sender, user.investment);
    }

    function claimProjectTokens(string calldata projectId)
        external
        onlyValid(projectId)
    {
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
