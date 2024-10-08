// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {IOrchestrator_v1} from
    "src/orchestrator/interfaces/IOrchestrator_v1.sol";

// External Interfaces
import {IERC20} from "@oz/token/ERC20/IERC20.sol";

// Internal Interfaces
import {IModuleManagerBase_v1} from
    "src/orchestrator/interfaces/IModuleManagerBase_v1.sol";
import {IFundingManager_v1} from "@fm/IFundingManager_v1.sol";
import {IAuthorizer_v1} from "@aut/IAuthorizer_v1.sol";
import {IPaymentProcessor_v1} from
    "src/modules/paymentProcessor/IPaymentProcessor_v1.sol";
import {IGovernor_v1} from "@ex/governance/interfaces/IGovernor_v1.sol";

contract OrchestratorV1AccessMock is IOrchestrator_v1 {
    IERC20 public token;
    IPaymentProcessor_v1 public paymentProcessor;
    IFundingManager_v1 public fundingManager;
    IGovernor_v1 public governor;

    function cancelAuthorizerUpdate(IAuthorizer_v1 authorizer_) external {}

    function cancelPaymentProcessorUpdate(
        IPaymentProcessor_v1 paymentProcessor_
    ) external {}

    function cancelFundingManagerUpdate(IFundingManager_v1 fundingManager_)
        external
    {}

    function cancelModuleUpdate(address module) external {}

    function initiateAddModuleWithTimelock(address module) external {}

    function initiateRemoveModuleWithTimelock(address module) external {}

    function executeAddModule(address module) external {}

    function executeRemoveModule(address module) external {}

    function isModule(address module) external view returns (bool) {}

    function listModules() external view returns (address[] memory) {}

    function modulesSize() external view returns (uint8) {}

    function grantRole(bytes32 role, address account) external {}

    function revokeRole(bytes32 role, address account) external {}

    function renounceRole(address module, bytes32 role) external {}

    function hasRole(address module, bytes32 role, address account)
        external
        returns (bool)
    {}

    function init(
        uint,
        address,
        address[] calldata,
        IFundingManager_v1,
        IAuthorizer_v1,
        IPaymentProcessor_v1,
        IGovernor_v1
    ) external {}

    function initiateSetAuthorizerWithTimelock(IAuthorizer_v1 authorizer_)
        external
    {}

    function initiateSetFundingManagerWithTimelock(
        IFundingManager_v1 fundingManager_
    ) external {}

    function initiateSetPaymentProcessorWithTimelock(
        IPaymentProcessor_v1 paymentProcessor_
    ) external {}

    function executeSetAuthorizer(IAuthorizer_v1 authorizer_) external {}

    function executeSetFundingManager(IFundingManager_v1 fundingManager_)
        external
    {
        fundingManager = fundingManager_;
    }

    function executeSetPaymentProcessor(IPaymentProcessor_v1 paymentProcessor_)
        external
    {
        paymentProcessor = paymentProcessor_;
    }

    function orchestratorId() external view returns (uint) {}

    function authorizer() external view returns (IAuthorizer_v1) {}

    function version() external pure returns (string memory) {}

    function manager() external view returns (address) {}

    function verifyAddressIsPaymentProcessor(address paymentProcessorAddress)
        external
        view
        returns (bool)
    {}

    function verifyAddressIsRecurringPaymentManager(
        address recurringPaymentManager
    ) external view returns (bool) {}

    function verifyAddressIsFundingManager(address fundingManagerAddress)
        external
        view
        returns (bool)
    {}

    function verifyAddressIsAuthorizerModule(address authModule)
        external
        view
        returns (bool)
    {}

    function isTrustedForwarder(address forwarder)
        external
        view
        returns (bool)
    {}

    function trustedForwarder() external view returns (address) {}

    //-------------------------------------------------------------------
    // Mock Helper Functions
    function setToken(IERC20 token_) external {
        token = token_;
    }
}
