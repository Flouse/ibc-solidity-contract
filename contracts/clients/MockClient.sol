// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "../core/02-client/ILightClient.sol";
import "../core/02-client/IBCHeight.sol";
import "../proto/Client.sol";
import {IbcLightclientsMockV1ClientState as ClientState, IbcLightclientsMockV1ConsensusState as ConsensusState, IbcLightclientsMockV1Header as Header} from "../proto/MockClient.sol";
import {GoogleProtobufAny as Any} from "../proto/GoogleProtobufAny.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

// MockClient implements https://github.com/datachainlab/ibc-mock-client
// WARNING: This client is intended to be used for testing purpose. Therefore, it is not generally available in a production, except in a fully trusted environment.
contract MockClient is ILightClient {
    using BytesLib for bytes;
    using IBCHeight for Height.Data;

    string private constant HEADER_TYPE_URL =
        "/ibc.lightclients.mock.v1.Header";
    string private constant CLIENT_STATE_TYPE_URL =
        "/ibc.lightclients.mock.v1.ClientState";
    string private constant CONSENSUS_STATE_TYPE_URL =
        "/ibc.lightclients.mock.v1.ConsensusState";

    bytes32 private constant HEADER_TYPE_URL_HASH =
        keccak256(abi.encodePacked(HEADER_TYPE_URL));
    bytes32 private constant CLIENT_STATE_TYPE_URL_HASH =
        keccak256(abi.encodePacked(CLIENT_STATE_TYPE_URL));
    bytes32 private constant CONSENSUS_STATE_TYPE_URL_HASH =
        keccak256(abi.encodePacked(CONSENSUS_STATE_TYPE_URL));

    // mapping(string => ClientState.Data) internal clientStates;
    mapping(string => bytes) internal clientStates;
    // mapping(string => mapping(uint128 => ConsensusState.Data))
    //     internal consensusStates;
    mapping(string => bytes) internal consensusStates;

    /**
     * @dev createClient creates a new client with the given state
     */
    function createClient(
        string calldata clientId,
        bytes calldata clientStateBytes,
        bytes calldata consensusStateBytes
    )
        external
        override
        returns (
            bytes32 clientStateCommitment,
            ConsensusStateUpdate memory update,
            bool ok
        )
    {
        clientStates[clientId] = clientStateBytes;
        consensusStates[clientId] = consensusStateBytes;
        return (
            keccak256(clientStateBytes),
            ConsensusStateUpdate({
                consensusStateCommitment: bytes32(0),
                height: Height.Data({revisionNumber: 0, revisionHeight: 9999})
            }),
            true
        );
    }

    /**
     * @dev getTimestampAtHeight returns the timestamp of the consensus state at the given height.
     */
    function getTimestampAtHeight(
        string calldata clientId,
        Height.Data calldata height
    ) external view override returns (uint64, bool) {
        return (9223372036854775807, true);
    }

    /**
     * @dev getLatestHeight returns the latest height of the client state corresponding to `clientId`.
     */
    function getLatestHeight(
        string calldata clientId
    ) external pure override returns (Height.Data memory, bool) {
        return (Height.Data({revisionNumber: 0, revisionHeight: 9999}), true);
    }

    /**
     * @dev updateClient is intended to perform the followings:
     * 1. verify a given client message(e.g. header)
     * 2. check misbehaviour such like duplicate block height
     * 3. if misbehaviour is found, update state accordingly and return
     * 4. update state(s) with the client message
     * 5. persist the state(s) on the host
     */
    function updateClient(
        string calldata clientId,
        bytes calldata clientMessageBytes
    )
        external
        override
        returns (
            bytes32 clientStateCommitment,
            ConsensusStateUpdate[] memory updates,
            bool ok
        )
    {
        return (bytes32(0), new ConsensusStateUpdate[](0), true);
    }

    /**
     * @dev verifyMembership is a generic proof verification method which verifies a proof of the existence of a value at a given CommitmentPath at the specified height.
     * The caller is expected to construct the full CommitmentPath from a CommitmentPrefix and a standardized path (as defined in ICS 24).
     */
    function verifyMembership(
        string calldata clientId,
        Height.Data calldata height,
        uint64,
        uint64,
        bytes calldata proof,
        bytes memory,
        bytes memory,
        bytes calldata value
    ) external view override returns (bool) {
        return true;
    }

    /**
     * @dev verifyNonMembership is a generic proof verification method which verifies the absence of a given CommitmentPath at a specified height.
     * The caller is expected to construct the full CommitmentPath from a CommitmentPrefix and a standardized path (as defined in ICS 24).
     */
    function verifyNonMembership(
        string calldata clientId,
        Height.Data calldata height,
        uint64,
        uint64,
        bytes calldata proof,
        bytes memory,
        bytes memory
    ) external view override returns (bool) {
        return true;
    }

    /* State accessors */

    /**
     * @dev getClientState returns the clientState corresponding to `clientId`.
     *      If it's not found, the function returns false.
     */
    function getClientState(
        string calldata clientId
    ) external view returns (bytes memory clientStateBytes, bool) {
        string memory result = string.concat(
            clientId,
            "|",
            string(clientStates[clientId])
        );
        return (bytes(result), true);
    }

    /**
     * @dev getConsensusState returns the consensusState corresponding to `clientId` and `height`.
     *      If it's not found, the function returns false.
     */
    function getConsensusState(
        string calldata clientId,
        Height.Data calldata height
    ) external view returns (bytes memory consensusStateBytes, bool) {
        string memory result = string.concat(
            clientId,
            "|",
            string(consensusStates[clientId])
        );
        return (bytes(result), true);
    }

    /* Internal functions */

    function parseHeader(
        bytes memory bz
    ) internal pure returns (Height.Data memory, uint64) {
        Any.Data memory any = Any.decode(bz);
        require(
            keccak256(abi.encodePacked(any.typeUrl)) == HEADER_TYPE_URL_HASH,
            "invalid header type"
        );
        Header.Data memory header = Header.decode(any.value);
        require(
            header.height.revisionNumber == 0 &&
                header.height.revisionHeight != 0 &&
                header.timestamp != 0,
            "invalid header"
        );
        return (header.height, header.timestamp);
    }

    function unmarshalClientState(
        bytes calldata bz
    ) internal pure returns (ClientState.Data memory clientState, bool ok) {
        Any.Data memory anyClientState = Any.decode(bz);
        if (
            keccak256(abi.encodePacked(anyClientState.typeUrl)) !=
            CLIENT_STATE_TYPE_URL_HASH
        ) {
            return (clientState, false);
        }
        return (ClientState.decode(anyClientState.value), true);
    }

    function unmarshalConsensusState(
        bytes calldata bz
    )
        internal
        pure
        returns (ConsensusState.Data memory consensusState, bool ok)
    {
        Any.Data memory anyConsensusState = Any.decode(bz);
        if (
            keccak256(abi.encodePacked(anyConsensusState.typeUrl)) !=
            CONSENSUS_STATE_TYPE_URL_HASH
        ) {
            return (consensusState, false);
        }
        return (ConsensusState.decode(anyConsensusState.value), true);
    }
}
