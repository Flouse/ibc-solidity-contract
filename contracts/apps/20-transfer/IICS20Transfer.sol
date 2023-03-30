// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../../core/05-port/IIBCModule.sol";

interface IICS20Transfer is IIBCModule {
    function sendTransfer(
        string calldata denom,
        uint64 amount,
        address receiver,
        string calldata sourcePort,
        string calldata sourceChannel,
        uint64 timeoutHeight
    ) external;
}
