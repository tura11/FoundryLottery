// SPDX-LIcense_identifier: MIT

pragma solidity 0.8.19;

/**
 *@title Raffle contract
 *@author Tura11
 *@notice This contrac creating sample raffe
 *@dev Implements Chailink VRFv2.5
 */


contract Raffle {

    error Raffle_NotEnoughETH();



    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // duration of the lottery in seconds
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    event RaffleEtnered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if(msg.value < i_entranceFee){
            revert Raffle_NotEnoughETH();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEtnered(msg.sender);
        
    }
    function pickWinner() external {
        if((block.timestamp - s_lastTimeStamp) < i_interval){
            revert();
        }
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    // Getter funciotns

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
