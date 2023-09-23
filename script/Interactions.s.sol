// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {DeployConfig} from "./DeployConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function run() external returns (uint64) {
        return createSubscription();
    }

    function createSubscription() public returns (uint64) {
        DeployConfig config = new DeployConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerPK) = config
            .activeConfig();
        return createSubscription(vrfCoordinator, deployerPK);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerPK
    ) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerPK);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Sub id: ", subId);
        return subId;
    }
}

contract FundSubscription is Script {
    uint96 public constant LINK_AMOUNT = 3 ether;

    function run() external {
        fundSubscription();
    }

    function fundSubscription() public {
        DeployConfig config = new DeployConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerPK
        ) = config.activeConfig();
        fundSubscription(vrfCoordinator, subId, link, deployerPK);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerPK
    ) public {
        console.log("Funding subscription: ", subId);
        console.log("Using VRFCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerPK);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                LINK_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerPK);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                LINK_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumer(raffle);
    }

    function addConsumer(address raffle) public {
        DeployConfig config = new DeployConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerPK
        ) = config.activeConfig();
        addConsumer(raffle, vrfCoordinator, subId, deployerPK);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerPK
    ) public {
        console.log("Adding consumer contract: ", raffle);
        console.log("Using VRFCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        vm.startBroadcast(deployerPK);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }
}
