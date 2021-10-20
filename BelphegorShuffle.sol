// SPDX-License-Identifier: Commercial
// remember Open Source != Free Software
// for usage contact us at x@to.wtf
// created by https://to.wtf @ 19 Oct 2021
// named after https://web.archive.org/web/20160411083428/http://sprott.physics.wisc.edu/pickover/pc/1000000000000066600000000000001.html
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// ██████  ███████ ██      ██████  ██   ██ ███████  ██████   ██████  ██████      ███    ██ ███████ ████████     ██   ██ ██ ████████
// ██   ██ ██      ██      ██   ██ ██   ██ ██      ██       ██    ██ ██   ██     ████   ██ ██         ██        ██  ██  ██    ██
// ██████  █████   ██      ██████  ███████ █████   ██   ███ ██    ██ ██████      ██ ██  ██ █████      ██        █████   ██    ██
// ██   ██ ██      ██      ██      ██   ██ ██      ██    ██ ██    ██ ██   ██     ██  ██ ██ ██         ██        ██  ██  ██    ██
// ██████  ███████ ███████ ██      ██   ██ ███████  ██████   ██████  ██   ██     ██   ████ ██         ██        ██   ██ ██    ██
contract BelphegorNFTKit is VRFConsumerBase, Ownable {
	bytes32 internal keyHash;
	uint256 internal fee;

	uint256[] public randomResults; //keeps track of the random number from chainlink
	uint256[][] public expandedResults; //winners list
	uint256[] public winnerResults; //one winner list
	uint256 public totalDraws = 0; //drawID is drawID-1!
	string[] public ipfsProof; //whatever IPFS proof you want
	mapping(bytes32 => uint256) public requestIdToDrawIndex;

	//shuffling process
	uint256 public nftMaxSupply = 7777;
	uint256[] public shuffledNFTs;

	event IPFSProofAdded(string proof, uint256 drawID);
	event RandomRequested(bytes32 requestId, address roller);
	event RandomLanded(bytes32 requestId, uint256 drawID, uint256 result);
	event Winners(uint256 randomResult, uint256[] expandedResult);
	event Winner(uint256 randomResult, uint256 winningNumber);

	constructor(
		address _vrfCoordinator,
		address _linkToken,
		bytes32 _keyHash,
		uint256 _fee
	) VRFConsumerBase(_vrfCoordinator, _linkToken) {
		keyHash = _keyHash;
		fee = _fee;
	}

	//Given two integers a and b which are coprime,
	//then (a * x + b) modulo n will visit all integers from 0 to n - 1 exactly once.
	function shuffleNFTs(
		uint256 drawID,
		uint256 start,
		uint256 limit
	) external onlyOwner {
		require(shuffledNFTs.length < nftMaxSupply, "shuffled completed");
		uint256 a = 1000000000000066600000000000001; //# Random prime
		uint256 b = randomResults[drawID]; // # VRF

		for (uint256 i = start; i < limit; i++) {
			uint256 winner = ((a * i) + b) % nftMaxSupply;
			if (shuffledNFTs.length < nftMaxSupply) {
				shuffledNFTs.push(winner);
			}
		}
	}

	//you start by calling this function and having in IPFS the list of participants
	//or image hashes
	function addIPFSProof(string memory ipfsHash) external onlyOwner {
		ipfsProof.push(ipfsHash);
		emit IPFSProofAdded(ipfsHash, totalDraws);
	}

	/**
	 * Requests randomness
	 */
	function getRandomNumber() public onlyOwner returns (bytes32 requestId) {
		require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK in the contract");
		requestId = requestRandomness(keyHash, fee);
		emit RandomRequested(requestId, msg.sender);
		requestIdToDrawIndex[requestId] = totalDraws;
		return requestId;
	}

	/**
	 * Callback function used by VRF Coordinator
	 */
	function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
		randomResults.push(randomness);
		emit RandomLanded(requestId, totalDraws, randomness);
		totalDraws++;
	}

	//or just one winner
	function pickOneWinner(uint256 drawId, uint256 totalEntries) external onlyOwner {
		uint256 winner = (uint256(keccak256(abi.encode(randomResults[drawId], 1))) % totalEntries) + 1;
		winnerResults.push(winner);
		emit Winner(randomResults[drawId], winner);
	}

	//max 500 numWinners or out of gas
	function pickManyWinners(
		uint256 numWinners,
		uint256 drawId,
		uint256 totalEntries
	) external onlyOwner {
		uint256[] memory expandedValues = new uint256[](numWinners);
		for (uint256 i = 0; i < numWinners; i++) {
			expandedValues[i] =
				(uint256(keccak256(abi.encode(randomResults[drawId], i))) % totalEntries) +
				1;
		}
		expandedResults.push(expandedValues);
		emit Winners(randomResults[drawId], expandedValues);
	}

	//unused LINK shouldn't go to waste
	function withdrawLink() external {
		LINK.transfer(owner(), LINK.balanceOf(address(this)));
	}
}
