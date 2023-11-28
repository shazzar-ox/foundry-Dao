// SPDX-License-Identifier:MIT

pragma solidity ~0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Box} from "../src/Box.sol";
import {MyToken} from "../src/GovToken.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    Box box;
    MyToken myToken;
    MyGovernor myGovernor;
    TimeLock timeLock;
    address public user = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MINDELAY = 3600;
    uint256 public constant VOTING_DELAY = 1; // how many blocks till our vote is active...
    uint256 public constant VOTING_PERIOD = 50400;
    address[] proposers;
    address[] executors;
    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    function setUp() external {
        // vm.startBroadcast();
        myToken = new MyToken();
        myToken.mint(user, INITIAL_SUPPLY);
        vm.startPrank(user);
        myToken.delegate(user);
        timeLock = new TimeLock(MINDELAY, proposers, executors);
        myGovernor = new MyGovernor(myToken, timeLock);

        bytes32 proposalRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposalRole, address(myGovernor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, user);

        // console.log("proposal state", uint256(myGovernor.state(proposalId)));

        vm.stopPrank();
        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store one in box";
        bytes memory encodeFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodeFunctionCall);
        targets.push(address(box));
        // 1. propose on the DAO 
        uint256 proposalId = myGovernor.propose(targets, values, calldatas, description);
        console.log("proposal state", uint256(myGovernor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_PERIOD + 3);
        vm.roll(block.number + VOTING_PERIOD + 3);

        console.log("proposal state", uint256(myGovernor.state(proposalId)));

        // 2.vote
        string memory reason = "cuz blue is cool";
        uint8 voteWay = 1; //voting yes

        vm.prank(user);
        myGovernor.castVoteWithReason(proposalId, voteWay, reason);
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 3. queue the transaction
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        myGovernor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // 4. Execute
        myGovernor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.getNumber(), valueToStore);
    }
}
