//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import  {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
/**
 * @title A sample Raffle contract 
 * @author Bhavya Gor
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRFv2
 */


contract Raffle is VRFConsumerBaseV2 {
  error Raffle__NotEnoughETHSent();
  error Raffle__TransferFailed();
  error Raffle__CannotEnterRaffle();
  error Raffle__TimeNotPassed(uint256 timeStamp,RaffleState raffleState,uint256 currentBalance, uint256 numOfPlayers);
 
  enum RaffleState {
    Open,       // 0
    Calculating // 1
  }

  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private constant NUM_OF_WORDS = 1;

  uint256 private immutable i_enteranceFee;
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  uint256 private immutable i_interval;
  uint64 private immutable i_subscriptionId;
  uint32 private immutable i_callbackGasLimit;
  bytes32 private immutable i_gasLane;

  address payable[] private s_members;
  uint256 private s_timeStamp;
  address private s_recentWinner;
  RaffleState private s_raffleState;

  /** Events section */
  event EnteredRaffle(address indexed player,uint256 indexed entranceFee);
  event PickedWinner(address indexed winner,uint256 indexed amountWon,uint256 timestamp);

  constructor (uint256 entranceFee,uint256 intervalTime, address vrfCoordinator,bytes32 gasLane,uint64 subscriptionId,uint32 callbackGasLimit)VRFConsumerBaseV2(vrfCoordinator) {
    i_enteranceFee = entranceFee;
    i_interval = intervalTime;
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    s_timeStamp = block.timestamp;
    s_raffleState = RaffleState.Open;
    
  }

  function enterRaffle() external payable {
      if(msg.value < i_enteranceFee){
        revert Raffle__NotEnoughETHSent();
      }
      if(s_raffleState != RaffleState.Open){
        revert Raffle__CannotEnterRaffle();
      }
      s_members.push(payable(msg.sender));
      emit EnteredRaffle(msg.sender,msg.value);
    
  }

   function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
       bool timeHasPassed = (block.timestamp - s_timeStamp) >= i_interval;
       bool raffleIsOpen = RaffleState.Open == s_raffleState;
       bool hasBalance = address(this).balance > 0;
       bool hasPlayers = s_members.length > 0;
      upkeepNeeded = (timeHasPassed && raffleIsOpen && hasBalance && hasPlayers);
      return (upkeepNeeded, "0x0");
    }

  function performUpkeep(bytes calldata /* performData */) external {
    (bool upkeepNeeded,) = checkUpkeep("");
    if(!upkeepNeeded){
     revert Raffle__TimeNotPassed(
      block.timestamp,
      s_raffleState,
      address(this).balance,
      s_members.length
     );
    }

    s_raffleState = RaffleState.Calculating;
    // 1. Get a random number in scope to array (chainlink vrf)
    // Will revert if subscription is not set and funded.
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_OF_WORDS
    );
  }

  function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
      uint256 indexOfWinner = _randomWords[0] % s_members.length;
      address payable winner = s_members[indexOfWinner];
      s_recentWinner = winner;
      s_members = new address payable[](0);
      s_timeStamp = block.timestamp;
      
      s_raffleState = RaffleState.Open;
      emit PickedWinner(winner,address(this).balance,block.timestamp);
      (bool success,) = winner.call{value:address(this).balance}("");
      if(!success){
        revert Raffle__TransferFailed();
      }

      

    }
  /** View and pure functions */
  function getEntranceFee() external view returns (uint256) {
    return i_enteranceFee;
  }

  function getPlayers() external view returns (address payable[] memory) {
    return s_members;
  }
}