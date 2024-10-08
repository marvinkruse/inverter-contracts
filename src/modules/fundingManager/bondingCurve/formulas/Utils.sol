pragma solidity 0.8.23;

/// @title  Aragon Bancor Formula Utils
/// @author https://github.com/AragonBlack/fundraising/blob/master/apps/bancor-formula/contracts/utility/Utils.sol
/// @notice The sole modification implemented in the contract involves altering the Soldity version number
///         while also removing the 'public' keyword from the constructor, as per version-specified.

/*
    Utilities & Common Modifiers
*/
contract Utils {
    /**
     * constructor
     */
    constructor() {}

    // verifies that an amount is greater than zero
    modifier greaterThanZero(uint _amount) {
        require(_amount > 0);
        _;
    }

    // verifies that the address is different than this contract address
    modifier notThis(address _address) {
        require(_address != address(this));
        _;
    }
}
