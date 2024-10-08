// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {LibMetadata} from "src/modules/lib/LibMetadata.sol";

import {
    IModuleFactory_v1,
    IInverterBeacon_v1,
    IModule_v1,
    IOrchestrator_v1
} from "src/factories/interfaces/IModuleFactory_v1.sol";

import {IOrchestratorFactory_v1} from
    "src/factories/interfaces/IOrchestratorFactory_v1.sol";
import {ModuleV1Mock} from "test/utils/mocks/modules/base/ModuleV1Mock.sol";

import {FundingManagerV1Mock} from
    "test/utils/mocks/modules/FundingManagerV1Mock.sol";
import {AuthorizerV1Mock} from "test/utils/mocks/modules/AuthorizerV1Mock.sol";
import {PaymentProcessorV1Mock} from
    "test/utils/mocks/modules/PaymentProcessorV1Mock.sol";

import {Clones} from "@oz/proxy/Clones.sol";

contract ModuleFactoryV1Mock is IModuleFactory_v1 {
    IInverterBeacon_v1 private _beacon;

    uint public howManyCalls;

    address public governor = address(0x999999);
    address public reverter = address(0x111111);

    IOrchestratorFactory_v1.WorkflowConfig public givenWorkflowConfig;

    IModule_v1.Metadata fundingManagerMetadata = IModule_v1.Metadata(
        1, 0, 0, "https://fundingmanager.com", "FundingManager"
    );

    IModule_v1.Metadata authorizerMetadata =
        IModule_v1.Metadata(1, 0, 0, "https://authorizer.com", "Authorizer");

    IModule_v1.Metadata paymentProcessorMetadata = IModule_v1.Metadata(
        1, 1, 0, "https://paymentprocessor.com", "PP_Simple_v1"
    );

    function createAndInitModule(
        IModule_v1.Metadata memory metadata,
        IOrchestrator_v1,
        bytes memory,
        IOrchestratorFactory_v1.WorkflowConfig memory workflowConfig
    ) external returns (address) {
        givenWorkflowConfig = workflowConfig;
        if (
            LibMetadata.identifier(metadata)
                == LibMetadata.identifier(fundingManagerMetadata)
        ) {
            return address(new FundingManagerV1Mock());
        } else if (
            LibMetadata.identifier(metadata)
                == LibMetadata.identifier(authorizerMetadata)
        ) {
            return address(new AuthorizerV1Mock());
        } else if (
            LibMetadata.identifier(metadata)
                == LibMetadata.identifier(paymentProcessorMetadata)
        ) {
            return address(new PaymentProcessorV1Mock());
        } else {
            return address(new ModuleV1Mock());
        }
    }

    function createModuleProxy(
        IModule_v1.Metadata memory,
        IOrchestrator_v1,
        IOrchestratorFactory_v1.WorkflowConfig memory
    ) external returns (address) {
        return Clones.clone(address(new ModuleV1Mock()));
    }

    function getBeaconAndId(IModule_v1.Metadata memory metadata)
        external
        view
        returns (IInverterBeacon_v1, bytes32)
    {
        return (_beacon, LibMetadata.identifier(metadata));
    }

    function getOrchestratorOfProxy(address /*proxy*/ )
        external
        view
        returns (address)
    {
        // we return msg.sender here, because this is just a mocked factory.
        // this means, that when we are using this, we are not actually testing the
        // real functionality of the factory, but of another contract.
        // the calling contract (ModuleManager) expects the returned address to be
        // itself, if the module proxy was created for it properly.
        return msg.sender;
    }

    function registerMetadata(IModule_v1.Metadata memory, IInverterBeacon_v1)
        external
    {
        howManyCalls++;
    }
}
