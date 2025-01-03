import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test, CodeConstants {
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("player");
    uint256 public raffleEntranceFee;
    address vrfCoordinatorV2_5;
    uint256 subscriptionId;
    uint256 automationUpdateInterval;
    bytes32 keyHash;
    LinkToken link;

    modifier raffleEntrance() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);
        _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        vm.deal(PLAYER, STARTING_USER_BALANCE);

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        raffleEntranceFee = config.raffleEntranceFee;
        subscriptionId = config.subscriptionId;
        keyHash = config.keyHash;
        automationUpdateInterval = config.automationUpdateInterval;
        raffleEntranceFee = config.raffleEntranceFee;
        vrfCoordinatorV2_5 = config.vrfCoordinatorV2_5;
        link = LinkToken(config.link);

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fundSubscription(subscriptionId, LINK_BALANCE);
        }
        link.approve(vrfCoordinatorV2_5, LINK_BALANCE);
        vm.stopPrank();
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWHenYouDontPayEnought() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_SendMoreToRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleSuccessWithPayment() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        address player = raffle.getPlayer(0);
        assert(player == PLAYER);
    }

    function testRaffleStateChangesToCalculating() public raffleEntrance {
        raffle.performUpkeep("");
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testRaffleRevertsWhenNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);
        raffle.performUpkeep("");

        // Act & Assert
        vm.expectRevert(Raffle.Raffle_RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    function testEnterRaffleEmitsRaffleEnterEvent() public {
        vm.prank(PLAYER);
        // vm.expectEmit(true, false ,false, false, address(raffle));
        // emit RaffleEnter(PLAYER);
        vm.recordLogs();
        raffle.enterRaffle{value: raffleEntranceFee}();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assert(entries.length == 1);
        // console.log('==========================');
        // console.logBytes32(bytes32(entries[0].topics[1]));
        // console.logBytes32(bytes32(uint256(uint160(PLAYER))));
        // console.log('==========================');

        assert(entries[0].topics[0] == keccak256("RaffleEnter(address)"));
        assert(entries[0].topics[1] == bytes32(uint256(uint160(PLAYER))));
    }

    // ========  CHECLUPKEEP  ========
    function testCheckUpKeepReturnsFalseWhenNoPlayers() public view {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckupKeepReturnsFalseIfNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);
        raffle.performUpkeep("");

        // Act & Assert
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfHasNoBalanceOrHasNoPlayers() public {
        // Arrange
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfHasntEnoughTimePassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpKeepReturnsTrueWhenParametersAreRight() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded == true);
    }

    // ========  PERFORMUPKEEP  ========
    function testPerformUpkeepRevertsWhenCheckUpkeepIsFalse() public {
        uint256 balance = 0;
        uint256 playersLength = 0;
        Raffle.RaffleState raffleState = Raffle.RaffleState.OPEN;
        vm.expectRevert(
          abi.encodeWithSelector(Raffle.Raffle_NotNeedToPerformUpkeep.selector, balance, playersLength, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpKeepSuccessWhenCheckUpKeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);
        raffle.performUpkeep("");
    }

    function testPerformUpKeepEmitsRequestIdWhenSuccess() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Assert
        assert(entries[1].topics[0] == keccak256("RequestedRaffleWinner(uint256)"));
        assert(entries[1].topics[1] != 0);
    }

    // ========  FULFILLUPKEEP  ========
    function testFulfillRandomWordsSuccess() public raffleEntrance {
        address expectWinner = address(1);
        uint256 startIndex = 1;
        uint256 additionalEntraces = 3;
        
        // Arrange
        for (uint256 i = startIndex; i < startIndex + additionalEntraces; ++i) {
            address player = address(uint160(i));
            hoax(player, 1 ether);
            raffle.enterRaffle{value: raffleEntranceFee}();
        }

        uint256 startTimestamp = raffle.getLastRaffleTime();
        uint256 expectWinnerBalance = expectWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        
        VRFCoordinatorV2_5Mock(vrfCoordinatorV2_5).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address winner = raffle.getRecenWinner();
        uint256 lastRaffleTime = raffle.getLastRaffleTime(); 

        assert(winner == expectWinner);
        assert(lastRaffleTime > startTimestamp);
        assert(expectWinner.balance == (additionalEntraces + 1) * raffleEntranceFee + expectWinnerBalance);
    }
}
