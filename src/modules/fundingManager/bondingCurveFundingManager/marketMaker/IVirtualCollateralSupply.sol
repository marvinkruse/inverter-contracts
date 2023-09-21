// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.8.19;

interface IVirtualCollateralSupply {
    //--------------------------------------------------------------------------
    // Errors

    // @notice Subtracting would result in an underflow.
    error VirtualCollateralSupply__SubtractResultsInUnderflow();

    /// @notice Adding would result in and overflow.
    error VirtualCollateralSupply_AddResultsInOverflow();

    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when virtual collateral supply has been set
    event VirtualCollateralSupplySet(
        uint indexed newSupply, uint indexed oldSupply
    );

    /// @notice Event emitted when virtual collateral amount has been added
    event VirtualCollateralAmountAdded(
        uint indexed amountAdded, uint indexed newSupply
    );

    /// @notice Event emitted when virtual collateral amount has ben subtracted
    event VirtualCollateralAmountSubtracted(
        uint indexed amountSubtracted, uint indexed newSupply
    );

    //--------------------------------------------------------------------------
    // Functions

    /// @notice Sets the virtual collateral supply to a new value.
    /// @dev This function calls the internal function `_setVirtualCollateralSupply`.
    /// @param _virtualSupply The new value to set for the virtual collateral supply.
    function setVirtualCollateralSupply(uint _virtualSupply) external;

    /// @notice Returns the current virtual collateral supply.
    /// @dev This function returns the virtual supply by calling the
    /// internal `_getVirtualCollateralSupply` function.
    /// @return The current virtual collateral supply as a uint.
    function getVirtualCollateralSupply() external view returns (uint);
}
