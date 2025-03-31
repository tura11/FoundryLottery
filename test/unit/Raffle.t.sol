// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/Deploy.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitialzesOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle_NotEnoughETH.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEtneringRaffleEvent() public {
        vm.prank(PLAYER);

        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFaleIfHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsFaleIfRaffleIsntOpen() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        (bool upKeepNeeded,) = raffle.checkUpkeep("");
        assert(!upKeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Advance time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Time hasn't passed enough
        // Do NOT advance time

        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded); // Should be false since not enough time has passed
    }
    // Add this test for getEntranceFee

    function testGetEntranceFee() public {
        uint256 fee = raffle.getEntranceFee();
        assertEq(fee, entranceFee);
    }

    // Add this test for the missing branch in performUpKeep
    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange: Don't add any players, so checkUpkeep will return false

        // Act & Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpKeepNotNeeded.selector,
                0, // balance
                0, // players length
                uint256(Raffle.RaffleState.OPEN) // raffle state
            )
        );
        raffle.performUpKeep("");
    }

    // Add this test for fulfillRandomWords
    function testFulfillRandomWordsPicksWinnerAndResetState() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Add more players to make it interesting
        address playerA = makeAddr("playerA");
        address playerB = makeAddr("playerB");
        vm.deal(playerA, STARTING_PLAYER_BALANCE);
        vm.deal(playerB, STARTING_PLAYER_BALANCE);

        vm.prank(playerA);
        raffle.enterRaffle{value: entranceFee}();
        vm.prank(playerB);
        raffle.enterRaffle{value: entranceFee}();

        uint256 startingTimeStamp = raffle.getLastTimeStamp();

        // Move forward time so performUpkeep can be triggered
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Pretend to be the Chainlink VRF to trigger fulfillRandomWords
        raffle.performUpKeep(""); // This changes the state to calculating

        uint256 previousBalance = address(PLAYER).balance;

        // Pretend to be the VRF Coordinator and call fulfillRandomWords
        // We need to figure out which player will win based on the random number
        // For this test, let's say the random number will select PLAYER (index 0)
        uint256 requestId = 1; // Doesn't matter for this test
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0; // This will select the first player (index 0 % 3 = 0)

        // Expect the WinnerPicked event
        vm.expectEmit(true, false, false, false);
        emit WinnerPicked(PLAYER);

        // Act
        vm.prank(vrfCoordinator);
        raffle.rawFulfillRandomWords(requestId, randomWords);

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 playersLength = raffle.getPlayersLength();
        uint256 newTimeStamp = raffle.getLastTimeStamp();

        assert(recentWinner == PLAYER);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(playersLength == 0);
        assert(newTimeStamp > startingTimeStamp);
        assert(address(PLAYER).balance == previousBalance + entranceFee * 3); // Winner gets all the ETH
    }

    function testFullFillRanodmWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 requestId) public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
    }
}
