// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {DeployConfig} from "./DeployConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, DeployConfig) {
        DeployConfig config = new DeployConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerPK
        ) = config.activeConfig();

        if (subId == 0) {
            subId = new CreateSubscription().createSubscription(
                vrfCoordinator,
                deployerPK
            );

            new FundSubscription().fundSubscription(
                vrfCoordinator,
                subId,
                link,
                deployerPK
            );
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        new AddConsumer().addConsumer(
            address(raffle),
            vrfCoordinator,
            subId,
            deployerPK
        );
        return (raffle, config);
    }
}
