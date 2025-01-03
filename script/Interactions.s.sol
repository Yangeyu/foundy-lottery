// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubscription(vrfCoordinatorV2_5, account);
    }

    function createSubscription(address vrfCoordinatorV2_5, address account) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinatorV2_5);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is CodeConstants, Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address link = helperConfig.getConfigByChainId(block.chainid).link;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
        uint256 subId = helperConfig.getConfigByChainId(block.chainid).subscriptionId;
        fundSubscription(vrfCoordinatorV2_5, link, subId, account);
    }

    function fundSubscription(address vrfCoordinatorV2_5, address link, uint256 subId, address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Funding subscription on chainId: ", block.chainid);
        console.log("Funding subscription with accout: ", account);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2_5, FUND_AMOUNT, abi.encode(subId)
            );
            vm.stopBroadcast();
        }
        console.log("Subscription funded successfully");
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
      HelperConfig helperConfig = new HelperConfig();
      address vrfCoordinatorV2_5 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV2_5;
      address account = helperConfig.getConfigByChainId(block.chainid).account;
      uint256 subId = helperConfig.getConfigByChainId(block.chainid).subscriptionId;
      addConsumer(mostRecentlyDeployed, vrfCoordinatorV2_5, subId, account);
    }

    function addConsumer(address mostRecentlyDeployed, address vrfCoordinatorV2_5, uint256 subId, address account) public {
      console.log("Adding consumer to: ", mostRecentlyDeployed);
      console.log("Adding consumer on chainId: ", block.chainid);
      console.log("Adding consumer with accout: ", account);
      vm.startBroadcast(account);
      VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).addConsumer(subId, mostRecentlyDeployed);
      vm.stopBroadcast();
      console.log("Consumer added successfully");
    }

    function run() external {
      address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
      addConsumerUsingConfig(mostRecentlyDeployed);
    }
} 
