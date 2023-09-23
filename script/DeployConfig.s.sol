// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract DeployConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subId;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 deployerPK;
    }

    uint256 public constant ANVIL_ACCOUNT_PK =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public activeConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeConfig = getSepoliaConfig();
        } else {
            activeConfig = getAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30 /* seconds */,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subId: 5274,
                callbackGasLimit: 500_000,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerPK: vm.envUint("PRIVATE_KEY")
            });
    }

    function getAnvilConfig() public returns (NetworkConfig memory) {
        if (activeConfig.vrfCoordinator != address(0)) {
            return activeConfig;
        }

        uint96 linkBaseFee = 0.25 ether;
        uint96 linkGasPrice = 1e9;

        vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
            linkBaseFee,
            linkGasPrice
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30 /* seconds */,
                vrfCoordinator: address(vrfCoordinator),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subId: 0,
                callbackGasLimit: 500_000,
                linkToken: address(link),
                deployerPK: ANVIL_ACCOUNT_PK
            });
    }
}
