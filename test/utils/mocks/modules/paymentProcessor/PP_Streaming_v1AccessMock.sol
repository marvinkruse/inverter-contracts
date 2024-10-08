// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

// Internal Interfaces
import {IERC20PaymentClientBase_v1} from
    "@lm/interfaces/IERC20PaymentClientBase_v1.sol";
// Internal Dependencies
import {PP_Streaming_v1} from "@pp/PP_Streaming_v1.sol";

contract PP_Streaming_v1AccessMock is PP_Streaming_v1 {
    //--------------------------------------------------------------------------
    // Getter Functions

    function getUnclaimableStreams(
        address client,
        address token,
        address sender
    ) public view returns (uint[] memory ids) {
        return unclaimableStreams[client][token][sender];
    }

    function getUnclaimableAmountForStreams(
        address client,
        address token,
        address sender,
        uint id
    ) public view returns (uint amount) {
        return unclaimableAmountsForStream[client][token][sender][id];
    }

    function original_validPaymentReceiver(address addr)
        external
        view
        returns (bool)
    {
        return _validPaymentReceiver(addr);
    }

    function original__validTotal(uint _total) external pure returns (bool) {
        return _validTotal(_total);
    }

    function original_validTimes(uint _start, uint _cliff, uint _end)
        external
        pure
        returns (bool)
    {
        return _validTimes(_start, _cliff, _end);
    }

    function original_validPaymentToken(address _token)
        external
        returns (bool)
    {
        return _validPaymentToken(_token);
    }
}
