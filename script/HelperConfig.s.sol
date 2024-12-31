// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "lib/forge-std/src/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 subscriptionId;
        bytes32 keyHash;
        uint256 automationUpdateInterval;
        uint256 raffleEntranceFee;
        address vrfCoordinatorV2_5;
        address link;
        address account;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;
    NetworkConfig public localNetworkConfig;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepolliaConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinatorV2_5 != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepolliaConfig() public pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            subscriptionId: 0,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            automationUpdateInterval: 30,
            raffleEntranceFee: 0.001 ether,
            vrfCoordinatorV2_5: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });
    }

    function getMainConfig() public pure returns (NetworkConfig memory config) {
        config = NetworkConfig({
            subscriptionId: 0,
            keyHash: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9,
            automationUpdateInterval: 30,
            raffleEntranceFee: 0.001 ether,
            vrfCoordinatorV2_5: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinatorV2_5 != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            subscriptionId: 0,
            keyHash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c, // doesn't really matter
            automationUpdateInterval: 30,
            raffleEntranceFee: 0.001 ether,
            vrfCoordinatorV2_5: address(vrfCoordinator),
            link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
            account: FOUNDRY_DEFAULT_SENDER
        });
        vm.deal(localNetworkConfig.account, 100 ether);

        return localNetworkConfig;
    }

    function setConfig(uint256 chainid, NetworkConfig memory config) public {
      networkConfigs[chainid] = config;
    }
}
