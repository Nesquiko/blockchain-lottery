// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Contract for manaing a raffle
 * @author Nesquiko
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 numPlayers,
        State state
    );

    enum State {
        OPEN,
        CALCULATING
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant RANDOM_NUMBERS = 1;

    uint256 private immutable entranceFee;
    uint256 private immutable interval;
    bytes32 private immutable gasLane;
    uint64 private immutable subId;
    uint32 private immutable callbackGasLimit;
    VRFCoordinatorV2Interface private immutable vrfCoordinator;

    address payable[] private players;
    uint256 private lastTimestamp;
    State private state;
    address private recentWinner;

    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        entranceFee = _entranceFee;
        interval = _interval;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        gasLane = _gasLane;
        subId = _subId;
        callbackGasLimit = _callbackGasLimit;
        lastTimestamp = block.timestamp;
        state = State.OPEN;
    }

    function enterRaffle() external payable {
        if (state != State.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        if (msg.value < entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool, bytes memory) {
        bool isReady = (block.timestamp - lastTimestamp >= interval);
        bool isOpen = state == State.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = players.length > 0;

        bool upkeepNeeded = isReady && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                players.length,
                state
            );
        }

        state = State.CALCULATING;
        uint256 requestId = vrfCoordinator.requestRandomWords(
            gasLane,
            subId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            RANDOM_NUMBERS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % players.length;
        address payable winner = players[winnerIndex];
        state = State.OPEN;
        players = new address payable[](0);
        lastTimestamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        recentWinner = winner;
        emit PickedWinner(winner);
    }

    function getEntranceFee() external view returns (uint256) {
        return entranceFee;
    }

    function getInterval() external view returns (uint256) {
        return interval;
    }

    function getState() external view returns (State) {
        return state;
    }

    function getPlayer(uint256 idx) external view returns (address payable) {
        return players[idx];
    }

    function getPlayersLength() external view returns (uint256) {
        return players.length;
    }

    function getRecentWinner() external view returns (address) {
        return recentWinner;
    }

    function getLastTimestamp() external view returns (uint256) {
        return lastTimestamp;
    }
}
