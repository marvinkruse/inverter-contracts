// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

interface IFM_DepositVault_v1 {
    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted when a deposit takes place.
    /// @param  _from The address depositing tokens.
    /// @param  _amount The amount of tokens deposited.
    event Deposit(address indexed _from, uint _amount);

    //--------------------------------------------------------------------------
    // Functions

    /// @notice Deposits a specified amount of tokens into the contract from the sender's account.
    /// @dev    When using the {TransactionForwarder_v1}, validate transaction success to prevent nonce
    ///         exploitation and ensure transaction integrity.
    /// @param  amount The number of tokens to deposit.
    function deposit(uint amount) external;
}
