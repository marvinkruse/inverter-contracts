// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

// Internal Interfaces
import {IOrchestrator_v1} from
    "src/orchestrator/interfaces/IOrchestrator_v1.sol";
import {IAuthorizer_v1} from "@aut/IAuthorizer_v1.sol";
import {ILM_PC_Bounties_v1} from "@lm/interfaces/ILM_PC_Bounties_v1.sol";
import {
    IERC20PaymentClientBase_v1,
    IPaymentProcessor_v1
} from "@lm/abstracts/ERC20PaymentClientBase_v1.sol";

// Internal Dependencies
import {
    ERC20PaymentClientBase_v1,
    Module_v1
} from "@lm/abstracts/ERC20PaymentClientBase_v1.sol";

// External Dependencies
import {ERC165Upgradeable} from
    "@oz-up/utils/introspection/ERC165Upgradeable.sol";

// Internal Libraries
import {LinkedIdList} from "src/modules/lib/LinkedIdList.sol";

// External Libraries
import {EnumerableSet} from "@oz/utils/structs/EnumerableSet.sol";

/**
 * @title   Inverter Bounty Manager
 *
 * @notice  Provides functionality to manage bounties and process claims,
 *          allowing participants to propose, update, and claim bounties securely
 *          and transparently.
 *
 * @dev     Extends {ERC20PaymentClientBase_v1} to integrate payment processing with
 *          bounty management, supporting dynamic additions, updates, and the locking
 *          of bounties. Utilizes roles for managing permissions and maintaining robust
 *          control over bounty operations.
 *
 * @custom:security-contact security@inverter.network
 *                          In case of any concerns or findings, please refer to our Security Policy
 *                          at security.inverter.network or email us directly!
 *
 * @author  Inverter Network
 */
contract LM_PC_Bounties_v1 is ILM_PC_Bounties_v1, ERC20PaymentClientBase_v1 {
    /// @inheritdoc ERC165Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC20PaymentClientBase_v1)
        returns (bool)
    {
        return interfaceId == type(ILM_PC_Bounties_v1).interfaceId
            || super.supportsInterface(interfaceId);
    }

    using EnumerableSet for EnumerableSet.UintSet;
    using LinkedIdList for LinkedIdList.List;

    //--------------------------------------------------------------------------
    // Modifiers

    /// @dev	Checks if the sender is a contributor of the given claimId.
    /// @param  claimId The id of the claim to check.
    modifier onlyClaimContributor(uint claimId) {
        address sender = _msgSender();
        Contributor[] memory contribs = _claimRegistry[claimId].contributors;
        uint length = contribs.length;
        uint i;
        for (i; i < length;) {
            if (contribs[i].addr == sender) {
                // sender was found in contrib list
                break;
            }

            unchecked {
                ++i;
            }
        }

        // If i is length or higher the sender wasnt found in the contib list
        if (i >= length) {
            revert Module__LM_PC_Bounty__OnlyClaimContributor();
        }
        _;
    }

    /// @dev	Checks if the payout amounts are valid.
    /// @param  minimumPayoutAmount The minimum payout amount.
    /// @param  maximumPayoutAmount The maximum payout amount.
    modifier validPayoutAmounts(
        uint minimumPayoutAmount,
        uint maximumPayoutAmount
    ) {
        _validPayoutAmounts(minimumPayoutAmount, maximumPayoutAmount);
        _;
    }

    /// @dev    Checks if the array lengths are valid
    /// @param  minimumPayoutAmountLength The minimum payout amount length
    /// @param  maximumPayoutAmountLength The maximum payout amount length
    /// @param  detailArrayLength The detail array length
    modifier validArrayLengths(
        uint minimumPayoutAmountLength,
        uint maximumPayoutAmountLength,
        uint detailArrayLength
    ) {
        if (
            minimumPayoutAmountLength == 0
                || maximumPayoutAmountLength != minimumPayoutAmountLength
                || detailArrayLength != minimumPayoutAmountLength
        ) {
            revert Module__LM_PC_Bounty__InvalidArrayLengths();
        }
        _;
    }

    /// @dev	Checks if the bountyId is valid.
    /// @param  bountyId The id of the bounty to check.
    modifier validBountyId(uint bountyId) {
        if (!isExistingBountyId(bountyId)) {
            revert Module__LM_PC_Bounty__InvalidBountyId();
        }
        _;
    }

    /// @dev	Checks if the claimId is valid.
    /// @param  claimId The id of the claim to check.
    modifier validClaimId(uint claimId) {
        if (!isExistingClaimId(claimId)) {
            revert Module__LM_PC_Bounty__InvalidClaimId();
        }
        _;
    }

    /// @dev	Checks if the contributors are valid for the given bounty.
    /// @param  contributors The contributors to check.
    /// @param  bounty The bounty to check.
    function _validContributorsForBounty(
        Contributor[] memory contributors,
        Bounty memory bounty
    ) internal view {
        // @update to be in correct range
        uint length = contributors.length;
        // length cant be zero
        if (length == 0) {
            revert Module__LM_PC_Bounty__InvalidContributorsLength();
        }
        uint totalAmount;
        uint currentAmount;
        address contrib;
        address orchestratorAddress = address(__Module_orchestrator);
        for (uint i; i < length;) {
            currentAmount = contributors[i].claimAmount;

            // amount cant be zero
            if (currentAmount == 0) {
                revert Module__LM_PC_Bounty__InvalidContributorAmount();
            }

            contrib = contributors[i].addr;
            if (
                contrib == address(0) || contrib == address(this)
                    || contrib == orchestratorAddress
            ) {
                revert Module__LM_PC_Bounty__InvalidContributorAddress();
            }

            totalAmount += currentAmount;
            unchecked {
                ++i;
            }
        }

        if (
            totalAmount > bounty.maximumPayoutAmount
                || totalAmount < bounty.minimumPayoutAmount
        ) {
            revert Module__LM_PC_Bounty__ClaimExceedsGivenPayoutAmounts();
        }
    }

    /// @dev	Checks if the bounty is not locked.
    /// @param  bountyId The id of the bounty to check.
    modifier notLocked(uint bountyId) {
        if (_bountyRegistry[bountyId].locked) {
            revert Module__LM_PC_Bounty__BountyLocked();
        }
        _;
    }

    /// @dev	Checks if the claim is not claimed.
    /// @param  claimId The id of the claim to check.
    modifier notClaimed(uint claimId) {
        if (_claimRegistry[claimId].claimed) {
            revert Module__LM_PC_Bounty__AlreadyClaimed();
        }
        _;
    }

    /// @dev	Checks if the contributors have not changed.
    /// @param  claimId The id of the claim to check.
    /// @param  contributors The new contributors to check.
    function _contributorsNotChanged(
        uint claimId,
        Contributor[] memory contributors
    ) internal view {
        Contributor[] memory claimContribs =
            _claimRegistry[claimId].contributors;

        uint length = contributors.length;
        // Validate contributor array is the same length
        if (claimContribs.length != length) {
            revert Module__LM_PC_Bounty__ContributorsChanged();
        }
        for (uint i; i < length;) {
            if (
                contributors[i].addr != claimContribs[i].addr
                    || contributors[i].claimAmount != claimContribs[i].claimAmount
            ) revert Module__LM_PC_Bounty__ContributorsChanged();
            unchecked {
                i++;
            }
        }
    }

    //--------------------------------------------------------------------------
    // Constants

    /// @dev	Marks the beginning of the list.
    uint internal constant _SENTINEL = type(uint).max;

    /// @dev	Role for the bounty issuer.
    bytes32 public constant BOUNTY_ISSUER_ROLE = "BOUNTY_ISSUER";
    /// @dev	Role for the claimant.
    bytes32 public constant CLAIMANT_ROLE = "CLAIMANT";
    /// @dev	Role for the verifier.
    bytes32 public constant VERIFIER_ROLE = "VERIFIER";

    //--------------------------------------------------------------------------
    // Storage

    /// @dev	Value for what the next id will be.
    uint private _nextId;

    /// @dev	Registry mapping ids to Bounty structs id => Bounty.
    mapping(uint => Bounty) private _bountyRegistry;

    /// @dev	List of Bounty id's.
    LinkedIdList.List _bountyList;

    /// @dev	Registry mapping ids to Claim struct id => Claim.
    mapping(uint => Claim) private _claimRegistry;

    /// @dev	List of Claim id's.
    LinkedIdList.List _claimList;

    /// @dev	Connects contributor addresses to claim Ids contributor address => claim ids.
    mapping(address => EnumerableSet.UintSet) contributorAddressToClaimIds;

    /// @dev	Storage gap for future upgrades.
    uint[50] private __gap;

    //--------------------------------------------------------------------------
    // Initialization

    /// @inheritdoc Module_v1
    function init(
        IOrchestrator_v1 orchestrator_,
        Metadata memory metadata,
        bytes memory
    ) external override(Module_v1) initializer {
        __Module_init(orchestrator_, metadata);
        // init empty list of bounties and claims
        _bountyList.init();
        _claimList.init();
    }

    //--------------------------------------------------------------------------
    // Getter Functions

    /// @inheritdoc ILM_PC_Bounties_v1
    function getBountyInformation(uint bountyId)
        external
        view
        validBountyId(bountyId)
        returns (Bounty memory)
    {
        return _bountyRegistry[bountyId];
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function listBountyIds() external view returns (uint[] memory) {
        return _bountyList.listIds();
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function isExistingBountyId(uint bountyId) public view returns (bool) {
        return _bountyList.isExistingId(bountyId);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function getClaimInformation(uint claimId)
        external
        view
        validClaimId(claimId)
        returns (Claim memory)
    {
        return _claimRegistry[claimId];
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function listClaimIds() external view returns (uint[] memory) {
        return _claimList.listIds();
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function isExistingClaimId(uint claimId) public view returns (bool) {
        return _claimList.isExistingId(claimId);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function listClaimIdsForContributorAddress(address contributorAddrs)
        external
        view
        returns (uint[] memory)
    {
        return contributorAddressToClaimIds[contributorAddrs].values();
    }

    //--------------------------------------------------------------------------
    // Mutating Functions

    /// @inheritdoc ILM_PC_Bounties_v1
    function addBounty(
        uint minimumPayoutAmount,
        uint maximumPayoutAmount,
        bytes calldata details
    )
        external
        onlyModuleRole(BOUNTY_ISSUER_ROLE)
        validPayoutAmounts(minimumPayoutAmount, maximumPayoutAmount)
        returns (uint id)
    {
        return _addBounty(minimumPayoutAmount, maximumPayoutAmount, details);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function addBountyBatch(
        uint[] calldata minimumPayoutAmounts,
        uint[] calldata maximumPayoutAmounts,
        bytes[] calldata detailArray
    )
        external
        onlyModuleRole(BOUNTY_ISSUER_ROLE)
        validArrayLengths(
            minimumPayoutAmounts.length,
            maximumPayoutAmounts.length,
            detailArray.length
        )
        returns (uint[] memory ids)
    {
        uint arrayLength = minimumPayoutAmounts.length;
        // create new array to return
        ids = new uint[](arrayLength);

        for (uint i = 0; i < arrayLength; i++) {
            // check payout amounts
            _validPayoutAmounts( //@note should I check first and then add in a different loop?
            minimumPayoutAmounts[i], maximumPayoutAmounts[i]);
            // add bounty
            ids[i] = _addBounty(
                minimumPayoutAmounts[i], maximumPayoutAmounts[i], detailArray[i]
            );
        }
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function updateBounty(uint bountyId, bytes calldata details)
        external
        onlyModuleRole(BOUNTY_ISSUER_ROLE)
        validBountyId(bountyId)
        notLocked(bountyId)
    {
        _bountyRegistry[bountyId].details = details;

        emit BountyUpdated(bountyId, details);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function lockBounty(uint bountyId)
        external
        onlyModuleRole(BOUNTY_ISSUER_ROLE)
        validBountyId(bountyId)
        notLocked(bountyId)
    {
        _bountyRegistry[bountyId].locked = true;

        emit BountyLocked(bountyId);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function addClaim(
        uint bountyId,
        Contributor[] calldata contributors,
        bytes calldata details
    )
        external
        onlyModuleRole(CLAIMANT_ROLE)
        validBountyId(bountyId)
        notLocked(bountyId)
        returns (uint id)
    {
        _validContributorsForBounty(contributors, _bountyRegistry[bountyId]);
        // Count up shared nextId by one
        uint claimId = ++_nextId;

        // Add Claim id to the list.
        _claimList.addId(claimId);

        Claim storage c = _claimRegistry[claimId];

        // Add Claim instance to registry.
        c.bountyId = bountyId;

        uint length = contributors.length;
        for (uint i; i < length;) {
            c.contributors.push(contributors[i]);
            // add ClaimId to each contributor address accordingly
            contributorAddressToClaimIds[contributors[i].addr].add(claimId);
            unchecked {
                ++i;
            }
        }

        c.details = details;

        emit ClaimAdded(claimId, bountyId, contributors, details);

        return claimId;
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function updateClaimContributors(
        uint claimId,
        Contributor[] calldata contributors
    )
        external
        validClaimId(claimId)
        notClaimed(claimId)
        notLocked(_claimRegistry[claimId].bountyId)
        onlyModuleRole(CLAIMANT_ROLE)
    {
        _validContributorsForBounty(
            contributors, _bountyRegistry[_claimRegistry[claimId].bountyId]
        );
        Claim storage c = _claimRegistry[claimId];

        uint length = c.contributors.length;
        for (uint i; i < length;) {
            // remove ClaimId for each contributor address
            contributorAddressToClaimIds[c.contributors[i].addr].remove(claimId);
            unchecked {
                ++i;
            }
        }

        delete c.contributors;

        length = contributors.length;

        for (uint i; i < length;) {
            c.contributors.push(contributors[i]);
            // add ClaimId again to each contributor address
            contributorAddressToClaimIds[contributors[i].addr].add(claimId);
            unchecked {
                ++i;
            }
        }

        emit ClaimContributorsUpdated(claimId, contributors);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function updateClaimDetails(uint claimId, bytes calldata details)
        external
        validClaimId(claimId)
        notClaimed(claimId)
        notLocked(_claimRegistry[claimId].bountyId)
        onlyClaimContributor(claimId)
    {
        _claimRegistry[claimId].details = details;

        emit ClaimDetailsUpdated(claimId, details);
    }

    /// @inheritdoc ILM_PC_Bounties_v1
    function verifyClaim(uint claimId, Contributor[] calldata contributors)
        external
        onlyModuleRole(VERIFIER_ROLE)
        validClaimId(claimId)
        notClaimed(claimId)
        notLocked(_claimRegistry[claimId].bountyId)
    {
        _contributorsNotChanged(claimId, contributors);

        Contributor[] memory contribs = _claimRegistry[claimId].contributors;

        uint length = contribs.length;

        // current contributor in loop
        Contributor memory contrib;

        // For each Contributor add payments according to the claimAmount specified
        for (uint i; i < length;) {
            contrib = contribs[i];

            _addPaymentOrder(
                PaymentOrder({
                    recipient: contrib.addr,
                    paymentToken: address(orchestrator().fundingManager().token()),
                    amount: contrib.claimAmount,
                    start: block.timestamp,
                    cliff: 0,
                    end: block.timestamp // end date is now
                })
            );
            unchecked {
                ++i;
            }
        }

        // when done process the Payments correctly
        __Module_orchestrator.paymentProcessor().processPayments(
            IERC20PaymentClientBase_v1(address(this))
        );

        // Set completed to true
        _claimRegistry[claimId].claimed = true;

        emit ClaimVerified(claimId);
    }

    // --------------------------------------------------------------------------
    // Internal Functions

    /// @dev    Internal function to check if the payout amounts are valid
    /// @param  minimumPayoutAmount The minimum payout amount
    /// @param  maximumPayoutAmount The maximum payout amount
    function _validPayoutAmounts(
        uint minimumPayoutAmount,
        uint maximumPayoutAmount
    ) internal pure {
        if (
            minimumPayoutAmount == 0
                || maximumPayoutAmount < minimumPayoutAmount
        ) {
            revert Module__LM_PC_Bounty__InvalidPayoutAmounts();
        }
    }

    /// @dev    Internal function to add a bounty
    /// @param  minimumPayoutAmount The minimum payout amount
    /// @param  maximumPayoutAmount The maximum payout amount
    /// @param  details The details of the bounty
    /// @return bountyId The id of the bounty
    function _addBounty(
        uint minimumPayoutAmount,
        uint maximumPayoutAmount,
        bytes calldata details
    ) internal returns (uint bountyId) {
        // Note ids start at 1.
        bountyId = ++_nextId;

        // Add Bounty id to the list.
        _bountyList.addId(bountyId);

        Bounty storage b = _bountyRegistry[bountyId];

        b.minimumPayoutAmount = minimumPayoutAmount;
        b.maximumPayoutAmount = maximumPayoutAmount;
        b.details = details;

        emit BountyAdded(
            bountyId, minimumPayoutAmount, maximumPayoutAmount, details
        );

        return bountyId;
    }
}
