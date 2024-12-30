// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /** Errors */
    error Raffle_NotNeedToPerformUpkeep(
        uint256 currBalance,
        uint256 playerNum,
        RaffleState state
    );
    error Raffle_SendMoreToRaffle();
    error Raffle_TransferFailed();
    error Raffle_RaffleNotOpen();

    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** Variables */
    uint32 private constant NUM_WORDS = 1;
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_subscriptionId;
    bytes32 private immutable i_keyHash;

    address payable private s_recenWinner;
    uint256 private i_interval;
    uint256 private immutable i_enterRaffleFee;
    uint256 private s_lastRaffleTime;
    address payable[] private s_players;
    RaffleState private s_raffleState = RaffleState.OPEN;

    /** Events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    constructor(
        uint256 subscriptionId,
        bytes32 keyHash,
        uint256 interval,
        uint256 enterRaffleFee,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_enterRaffleFee = enterRaffleFee;
        i_interval = interval;
        s_lastRaffleTime = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_enterRaffleFee) {
            revert Raffle_SendMoreToRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    function checkUpkeep(
        bytes memory
    ) public view override returns (bool, bytes memory) {
        bool timePassed = block.timestamp - s_lastRaffleTime >= i_interval;
        bool hasPlayers = s_players.length > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool upkeepNeeded = timePassed && hasPlayers && isOpen;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_NotNeedToPerformUpkeep(
                address(this).balance,
                s_players.length,
                s_raffleState
            );
        }

        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory requestId = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        s_vrfCoordinator.requestRandomWords(requestId);
    }

    function fulfillRandomWords(
        uint256,
        uint256[] calldata randomWords
    ) internal override {
        uint256 randomResult = randomWords[0];
        uint256 winnerIndex = randomResult % s_players.length;
        address payable winner = s_players[winnerIndex];
        s_recenWinner = winner;
        s_players = new address payable[](0);
        s_lastRaffleTime = block.timestamp;
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
        emit WinnerPicked(winner);
    }

    function getRecenWinner() public view returns (address) {
      return s_recenWinner;
    }

    function getPlayers() public view returns (address payable[] memory) {
      return s_players;
    }

    function getRaffleState() public view returns (RaffleState) {
      return s_raffleState;
    }

    function getLastRaffleTime() public view returns (uint256) {
      return s_lastRaffleTime;
    }
}
