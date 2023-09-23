// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployConfig} from "../../script/DeployConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    event EnteredRaffle(address indexed player);
    event PickedWinner(address indexed winner);

    uint256 private constant STARTING_BALANCE = 100 ether;

    Raffle private raffle;
    DeployConfig private config;
    address private user = makeAddr("John");

    uint256 private entranceFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private gasLane;
    uint64 private subId;
    uint32 private callbackGasLimit;
    address private link;

    modifier enterRaffle() {
        vm.prank(user);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier localTest() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, config) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subId,
            callbackGasLimit,
            link,

        ) = config.activeConfig();
        vm.deal(user, STARTING_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getState() == Raffle.State.OPEN);
    }

    function testRaffleRevertsWhenNotEnoughETHPayed() public {
        vm.prank(user);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerOnEnter() public {
        vm.prank(user);
        raffle.enterRaffle{value: entranceFee}();
        address player = raffle.getPlayer(0);
        assert(player == user);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(user);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(user);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterWhenRaffleIsCalculting() public {
        vm.prank(user);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(user);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotOpen() public enterRaffle {
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        vm.prank(user);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrue() public enterRaffle {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    function testPerformUpkeep() public enterRaffle {
        raffle.performUpkeep("");
    }

    function testPerformUpkeepReverts() public localTest {
        uint256 expectedBalance = 0;
        uint256 expectedPlayers = 0;
        Raffle.State expectedState = raffle.getState();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                expectedBalance,
                expectedPlayers,
                expectedState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepEmitsRequestId() public enterRaffle {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];
        assert(uint256(requestId) > 0);
    }

    function testFulfillRandomWordsReverts(
        uint256 randomReqId
    ) public localTest enterRaffle {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomReqId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksWinner() public localTest enterRaffle {
        uint256 players = 5; // one entered through enterRaffle modifier
        for (uint256 i = 1; i < players; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 expectedPrize = entranceFee * players;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        uint256[] memory usersIndex = new uint256[](1);
        usersIndex[0] = 0;

        vm.recordLogs();
        uint256 previousTimestamp = raffle.getLastTimestamp();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWordsWithOverride(
            uint256(requestId),
            address(raffle),
            usersIndex
        );
        logs = vm.getRecordedLogs();

        assert(raffle.getState() == Raffle.State.OPEN);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayersLength() == 0);
        assert(raffle.getLastTimestamp() > previousTimestamp);
        assert(address(uint160(uint256(logs[0].topics[1]))) == user);
        assert(user.balance == STARTING_BALANCE + expectedPrize - entranceFee);
    }
}
