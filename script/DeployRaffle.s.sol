// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        AddConsumer addConsumer = new AddConsumer();
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5, config.account);
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.link, config.subscriptionId, config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.keyHash,
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();
        console.log("Raffle Address: ", address(raffle));
        addConsumer.addConsumer(address(raffle), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        return (raffle, helperConfig);
    }
}
