// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Decenger} from "src/Decenger.sol";
import {DeployDecenger} from "script/DeployDecenger.s.sol";

contract MessengerTest is Test {
    Decenger decenger;

    address SENDER = makeAddr("sender");
    address RECEIVER = makeAddr("receiver");
    address RECEIVER2 = makeAddr("receiver");
    address RECEIVER3 = makeAddr("receiver");
    string public message = "hey XV!";

    uint256 constant BALANCE = 10 ether;
    uint256 public constant MAX_EDIT_TIME = 1 days;

    function setUp() public {
        DeployDecenger deployer = new DeployDecenger();
        decenger = deployer.run();

        vm.deal(SENDER, BALANCE);
        vm.deal(RECEIVER, BALANCE);
    }

    function testUserCanSendMessage() public {
        vm.startPrank(SENDER);
        decenger.sendMessage(RECEIVER, message);
        vm.stopPrank();

        vm.startPrank(RECEIVER);
        Decenger.Message[] memory messages = decenger.getReceivedMessages();
        vm.stopPrank();

        console.log("Messages length:", messages.length);
        console.log("Sender:", messages[0].sender);
        console.log("Receiver:", messages[0].receiver);
        console.log("Message:", messages[0].message);
        console.log("Timestamp:", messages[0].timestamp);

        assertEq(messages.length, 1);
    }

    function testCantDeletAMessageWhichDoesntExist() public {
        vm.prank(RECEIVER);
        vm.expectRevert();
        decenger.deleteSentMessage(1);
    }

    function testCanDeleteSentMessage() public {
        vm.prank(SENDER);
        decenger.sendMessage(RECEIVER, message);

        vm.prank(SENDER);
        decenger.deleteSentMessage(0);
    }

    function testCanDeleteReceivedMessages() public {
        vm.prank(SENDER);
        decenger.sendMessage(RECEIVER, message);

        vm.prank(RECEIVER);
        decenger.deleteReceivedMessage(0);
    }

    function testDeleteReceivedMessageFailsIfMessageNotExists() public {
        vm.prank(RECEIVER);
        vm.expectRevert(Decenger.Decenger__MessageNotFound.selector);
        decenger.deleteReceivedMessage(0);
    }

    function testSenderCanSendMessageAndReceiverReceivesExactMessage() public {
        vm.startPrank(SENDER);
        decenger.sendMessage(RECEIVER, message);

        Decenger.Message[] memory msgs = decenger.getSentMessage();
        assertEq(msgs[0].sender, SENDER);
        assertEq(msgs[0].receiver, RECEIVER);
        assertEq(msgs[0].message, message);
        assertEq(msgs[0].timestamp, block.timestamp);
        assertEq(decenger.getSentMessagesCount(), 1);
        vm.stopPrank();

        vm.startPrank(RECEIVER);
        Decenger.Message[] memory recMsgs = decenger.getReceivedMessages();

        assertEq(recMsgs[0].sender, SENDER);
        assertEq(recMsgs[0].receiver, RECEIVER);
        assertEq(recMsgs[0].message, message);
        assertEq(recMsgs[0].timestamp, block.timestamp);
        assertEq(decenger.getReceivedMessagesCount(), 1);
        vm.stopPrank();
    }

    function testNonSenderCantEditMessage() public {
        vm.prank(SENDER);
        decenger.sendMessage(RECEIVER, message);

        vm.startPrank(RECEIVER);
        vm.expectRevert();
        decenger.editMessage(0, "hi");
    }

    function testSenderCantEditMessageAfterOneDay() public {
        vm.startPrank(SENDER);
        decenger.sendMessage(RECEIVER, message);

        vm.warp(block.timestamp + MAX_EDIT_TIME + 1);
        vm.roll(block.number + 1);

        vm.expectRevert(Decenger.Decenger__CannotEditMessageAfterOneDay.selector);
        decenger.editMessage(0, "hi");
        vm.stopPrank();
    }

    function testSenderCanEditMessage() public {
        vm.startPrank(SENDER);

        decenger.sendMessage(RECEIVER, message);

        Decenger.Message[] memory msgs = decenger.getSentMessage();

        string memory orgMsg = msgs[0].message;

        decenger.editMessage(0, "hi");

        msgs = decenger.getSentMessage();

        string memory editedMsg = msgs[0].message;

        assertEq(orgMsg, message);
        assertEq(editedMsg, "hi");
        vm.stopPrank();
    }

    function testSendMessageToMultipleReceivers() public {
        address[] memory receivers = new address[](3);
        receivers[0] = RECEIVER;
        receivers[1] = RECEIVER2;
        receivers[2] = RECEIVER3;

        vm.startPrank(SENDER);
        decenger.sendMessageToMultipleReceivers(receivers, message);

        Decenger.Message[] memory msgs = decenger.getSentMessage();
        assertEq(msgs.length, 3);
        vm.stopPrank();

        vm.startPrank(RECEIVER);
        Decenger.Message[] memory receivedMessages = decenger.getReceivedMessages();
        assertEq(receivedMessages[0].message, message);
        vm.stopPrank();

        vm.startPrank(RECEIVER2);
        receivedMessages = decenger.getReceivedMessages();
        assertEq(receivedMessages[0].sender, SENDER);
        vm.stopPrank();

        vm.startPrank(RECEIVER3);
        receivedMessages = decenger.getReceivedMessages();
        assertEq(receivedMessages[0].timestamp, block.timestamp);
        vm.stopPrank();
    }

    function testMonOwnerCantSendSystemMessage() public {
        vm.prank(SENDER);
        vm.expectRevert();
        decenger.sendSystemMessage("hi");
    }

    function testOwnerCanSendSystemMessages() public {
        address admin = decenger.getAdmin();
        vm.prank(admin);
        decenger.sendSystemMessage("hi");

        string[] memory systemMessages = decenger.getSystemMessages();

        assertEq(systemMessages[0], "hi");
    }

    function testUsersCanSendExpirableMessage() public {
        vm.startPrank(SENDER);
        decenger.sendExpirableMessage(RECEIVER, message, 1 days);

        Decenger.Message[] memory expMsg = decenger.getSentExpirableMessages();

        assertEq(expMsg.length, 1);
        assertEq(expMsg[0].message, message);
        vm.stopPrank();

        vm.startPrank(RECEIVER);

        Decenger.Message[] memory expRecMsg = decenger.getReceivedExpirableMessages();
        assertEq(expRecMsg.length, 1);
        assertEq(expRecMsg[0].message, message);
        vm.stopPrank();
    }

    function testUsersCantSeeExpiredMessages() public {
        vm.startPrank(SENDER);
        decenger.sendExpirableMessage(RECEIVER, message, 1 days);
        

        vm.warp(block.timestamp + 1 days + 1);
        vm.roll(block.number + 1);

        vm.expectRevert(Decenger.Decenger__MessageExpired.selector);
        decenger.getSentExpirableMessages();

        vm.stopPrank();

        vm.prank(RECEIVER);
        vm.expectRevert(Decenger.Decenger__MessageExpired.selector);
        decenger.getReceivedExpirableMessages();
    }

    function testCanCreateGroup() public {
        address[] memory members = new address[](3);
        members[0] = RECEIVER;
        members[1] = RECEIVER2;
        members[2] = RECEIVER3;
        string memory groupName = "A";

        vm.startPrank(SENDER);
        decenger.createGroup(members, groupName);

        Decenger.Group memory group = decenger.getGroup(0);
        assertEq(group.members , members);
        assertEq(group.groupName, groupName);
        assertEq(decenger.getGroupsCount(), 1);
        vm.stopPrank();
    }

    function testCanSendMessageToGroupe() public {
        address[] memory members = new address[](3);
        members[0] = RECEIVER;
        members[1] = RECEIVER2;
        members[2] = RECEIVER3;
        string memory groupName = "A";

        vm.startPrank(SENDER);
        decenger.createGroup(members, groupName);
        decenger.sendMessageToGroup(0, "hi!");
        vm.stopPrank();

        vm.prank(RECEIVER);
        decenger.sendMessageToGroup(0, "hi!");
    }
}
