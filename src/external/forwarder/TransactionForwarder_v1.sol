// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

// Internal Interfaces
import {ITransactionForwarder_v1} from
    "src/external/forwarder/interfaces/ITransactionForwarder_v1.sol";

// External Dependencies
import {ERC2771ForwarderUpgradeable} from
    "@oz-up/metatx/ERC2771ForwarderUpgradeable.sol";
import {
    ERC2771ContextUpgradeable,
    ContextUpgradeable
} from "@oz-up/metatx/ERC2771ContextUpgradeable.sol";

/**
 * @title   Inverter Meta-Transaction & Multicall Forwarder
 *
 * @notice  This contract enables users to interact with smart contracts indirectly through
 *          a trusted forwarder. It supports meta transactions, allowing transactions to be
 *          sent by one party but signed and paid for by another. It also handles batch
 *          transactions (multi-call), facilitating complex, multi-step interactions within a single
 *          transaction.
 *
 * @dev     Integrates {ERC2771Forwarder} and {Context} to manage and relay meta transactions.
 *          It handles nonce management, signature verification, and ensures only trusted calls
 *          are forwarded.
 *
 * @custom:security-contact security@inverter.network
 *                          In case of any concerns or findings, please refer to our Security Policy
 *                          at security.inverter.network or email us directly!
 *  +
 * @author  Inverter Network
 */
contract TransactionForwarder_v1 is
    ITransactionForwarder_v1,
    ERC2771ForwarderUpgradeable,
    ContextUpgradeable
{
    //--------------------------------------------------------------------------
    // Storage

    /// @dev	Storage gap for future upgrades.
    uint[50] private __gap;

    //--------------------------------------------------------------------------
    // Constructor
    constructor() {
        _disableInitializers();
    }

    //--------------------------------------------------------------------------
    // Initialization

    function init() external initializer {
        __ERC2771Forwarder_init("Inverter TransactionForwarder_v1");
    }

    //--------------------------------------------------------------------------
    // Metatransaction Helper Functions

    /// @inheritdoc ITransactionForwarder_v1
    function createDigest(ForwardRequestData memory req)
        external
        view
        returns (bytes32 digest)
    {
        return _hashTypedDataV4(_getStructHash(req));
    }

    //--------------------------------------------------------------------------
    // Multicall Functions

    /// @inheritdoc ITransactionForwarder_v1
    function executeMulticall(SingleCall[] calldata calls)
        external
        returns (Result[] memory results)
    {
        uint length = calls.length;
        results = new Result[](length);

        SingleCall calldata calli;
        bytes memory data;

        // run through all of the calls
        for (uint i = 0; i < length; i++) {
            calli = calls[i];
            // Check if the target actually trusts the forwarder
            if (!__isTrustedByTarget(calli.target)) {
                revert ERC2771UntrustfulTarget(calli.target, address(this));
            }

            // Add call target to the end of the calldata
            // This will be read by the {ERC2771Context} of the target contract
            data = abi.encodePacked(calli.callData, _msgSender());

            // Do the call
            (bool success, bytes memory returnData) = calli.target.call(data);

            // In case call fails check if it its allowed to fail
            if (!success && !calli.allowFailure) {
                revert CallFailed(calli);
            }

            // set result correctly
            results[i] = Result(success, returnData);
        }
    }

    //--------------------------------------------------------------------------
    // Internal

    /// @notice Returns the digest for the given `ForwardRequestData`.
    /// @param  req The ForwardRequest you want to get the digest from.
    /// @return digest The digest needed to create a signature for the request.
    function _getStructHash(
        ERC2771ForwarderUpgradeable.ForwardRequestData memory req
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _FORWARD_REQUEST_TYPEHASH,
                req.from,
                req.to,
                req.value,
                req.gas,
                nonces(req.from),
                req.deadline,
                keccak256(req.data)
            )
        );
    }

    // Copied from the {ERC2771Forwarder} as it isnt declared internally
    // Added an underscore because it can not be overwritten
    function __isTrustedByTarget(address target) private view returns (bool) {
        bytes memory encodedParams = abi.encodeCall(
            ERC2771ContextUpgradeable.isTrustedForwarder, (address(this))
        );

        bool success;
        uint returnSize;
        uint returnValue;
        /// @solidity memory-safe-assembly
        assembly {
            // Perform the staticcal and save the result in the scratch space.
            // | Location  | Content  | Content (Hex)                                                      |
            // |-----------|----------|--------------------------------------------------------------------|
            // |           |          |                                                           result ↓ |
            // | 0x00:0x1F | selector | 0x0000000000000000000000000000000000000000000000000000000000000001 |
            success :=
                staticcall(
                    gas(),
                    target,
                    add(encodedParams, 0x20),
                    mload(encodedParams),
                    0,
                    0x20
                )
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
    }
}
