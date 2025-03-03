// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";

/**
 * @title Decenger - Decentralized Messenger with Integrated Wallet
 * @author ArefXV https://github.com/arefxv
 * @notice A permissionless messaging system with crypto wallet functionality
 * @dev Features include:
 * - Peer-to-peer messaging with edit/delete functionality
 * - Group messaging capabilities
 * - Expirable messages with time-based self-destruction
 * - Integrated ETH wallet with fund transfer capabilities
 * - System messages from admin
 * - Message forwarding system
 */
contract Decenger is ReentrancyGuard {
    /*/////////////////////////////////////////////////
                            ERRORS
    /////////////////////////////////////////////////*/
    error Decenger__MessageNotFound();
    error Decenger__AmountMustBeMoreThanZero();
    error Decenger__CannotSendFundsToAddressZero();
    error Decenger__InsufficientBalance(uint256, uint256);
    error Decenger__onlySenderCanEditMessage();
    error Decenger__CannotEditMessageAfterOneDay();
    error Decenger__GroupDoesnotExist();
    error Decenger__OnlyAdmin();
    error Decenger__MessageExpired();

    /*/////////////////////////////////////////////////
                            TYPES
    /////////////////////////////////////////////////*/
    /**
     * @dev Message structure containing:
     * @param sender Message origin address
     * @param receiver Message recipient address
     * @param message Content of the message
     * @param timestamp Block timestamp when sent
     */
    struct Message {
        address sender; 
        address receiver; 
        string message; 
        uint256 timestamp; 
    }

    /**
     * @dev Group structure containing:
     * @param members Array of member addresses
     * @param groupName Name identifier for the group
     */
    struct Group {
        address[] members;
        string groupName;
    }

    /**
     * @dev Expirable message structure containing:
     * @param message Base message structure
     * @param expirationTime Timestamp when message becomes inaccessible
     */
    struct ExpirableMessage {
        Message message;
        uint256 expirationTime;
    }

    /*/////////////////////////////////////////////////
                       STATE VARIABLES
    /////////////////////////////////////////////////*/

    uint256 private constant MAX_EDIT_TIME = 1 days;
    address private immutable i_admin;

    /// @dev Mapping of sent messages per address
    mapping(address => Message[]) private s_sentMessages;
    /// @dev Mapping of received messages per address
    mapping(address => Message[]) private s_receivedMessages;
    /// @dev Mapping of user ETH balances
    mapping(address => uint256) private s_balance;
    /// @dev Mapping of group ID to Group structure
    mapping(uint256 => Group) private s_groups;
    /// @dev Mapping of sent expirable messages per address
    mapping(address => ExpirableMessage[]) private s_sendExpirableMessages;
    /// @dev Mapping of received expirable messages per address
    mapping(address => ExpirableMessage[]) private s_receiveExpirableMessages;
    /// @dev Mapping of system messages (admin broadcasts)
    mapping(address => string[]) private s_systemMessages;
    /// @dev Counter for total groups created
    uint256 private s_groupsCount;
    /// @dev Array tracking group creators
    address[] private s_groupCreator;

    /*/////////////////////////////////////////////////
                            EVENTS
    /////////////////////////////////////////////////*/

    event MessageSent(address indexed sender, address indexed receiver,  uint256 time);
    event MessageReceived(address indexed sender, address indexed receiver, uint256 time);
    event MessageSentToMultiple(address sender, address[] receivers, uint256 time);
    event MessageReceivedToMultiple(address sender, address[] receivers, uint256 time);
    event ExpirableMessageSent(address sender, address receivers, uint256 expirationTime, uint256 time);
    event ExpirableMessageReceived(address sender, address receivers, uint256 expirationTime, uint256 time);
    event GroupCreated(address creator, string name);
    event MessageSentToGroup(uint256 groupId);
    event MessageReceivedInGroup(uint256 groupId);
    event ForwardMessageSent(address _address, address orgSender, address receiver);
    event ForwardMessageReceived(address _address, address orgSender, address receiver);
    event SentMessageDeleted(uint256 index); 
    event ReceivedMessageDeleted(uint256 index);
    event MessageEdited(address _address, uint256 index);
    event Deposited(address from, uint256 value);
    event Withdrawn(address from , uint256 value, address to);

    /*/////////////////////////////////////////////////
                            MODIFIERS
    /////////////////////////////////////////////////*/

    modifier moreThanZero(uint256 value) {
        if (value == 0) {
            revert Decenger__AmountMustBeMoreThanZero();
        }
        _;
    }

    /*/////////////////////////////////////////////////
                            FUNCTIONS
    /////////////////////////////////////////////////*/

    constructor() {
        i_admin = msg.sender;
        s_groupsCount = 0;
    }

    /*/////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS
    /////////////////////////////////////////////////*/

    /**
     * @notice Admin-only system message broadcast
     * @dev Stores message in system messages mapping
     * @param message System message content
     */
    function sendSystemMessage(string calldata message) external {
        if (i_admin != msg.sender) {
            revert Decenger__OnlyAdmin();
        }

        s_systemMessages[address(0)].push(message);
    }

    /**
     * @notice Send message to single recipient
     * @dev Stores message in both sender's and receiver's message history
     * @param receiver Recipient address
     * @param message Content to send
     */
    function sendMessage(address receiver, string calldata message) external {
        
        Message memory newMessage =
            Message({sender: msg.sender, receiver: receiver, message: message, timestamp: block.timestamp});

        s_sentMessages[msg.sender].push(newMessage);
        emit MessageSent(msg.sender, receiver,  block.timestamp);

        s_receivedMessages[receiver].push(newMessage);
        emit MessageReceived(msg.sender, receiver,  block.timestamp);
    }

    /**
     * @notice Send message to multiple recipients
     * @dev Loops through receiver list to store messages
     * @param receivers Array of recipient addresses
     * @param message Content to broadcast
     */
    function sendMessageToMultipleReceivers(address[] calldata receivers, string calldata message) external {
       
        for (uint256 i = 0; i < receivers.length; i++) {
            s_sentMessages[msg.sender].push(
                Message({sender: msg.sender, receiver: receivers[i], message: message, timestamp: block.timestamp})
            );

            emit MessageSentToMultiple(msg.sender, receivers, block.timestamp);

            s_receivedMessages[receivers[i]].push(
                Message({sender: msg.sender, receiver: receivers[i], message: message, timestamp: block.timestamp})
            );
        }
        emit MessageReceivedToMultiple(msg.sender, receivers, block.timestamp);
    }

    /**
     * @notice Send message with expiration timer
     * @dev Stores message with expiration timestamp in separate mapping
     * @param receiver Recipient address
     * @param message Content to send
     * @param expirationTime Seconds until message expires
     */
    function sendExpirableMessage(address receiver, string calldata message, uint256 expirationTime) external {
        s_sendExpirableMessages[msg.sender].push(
            ExpirableMessage({
                message: Message({sender: msg.sender, receiver: receiver, message: message, timestamp: block.timestamp}),
                expirationTime: block.timestamp + expirationTime
            })
        );

        emit ExpirableMessageSent(msg.sender, receiver, expirationTime, block.timestamp);

        s_receiveExpirableMessages[receiver].push(
            ExpirableMessage({
                message: Message({sender: msg.sender, receiver: receiver, message: message, timestamp: block.timestamp}),
                expirationTime: block.timestamp + expirationTime
            })
        );

        emit ExpirableMessageReceived(msg.sender, receiver, expirationTime, block.timestamp);
    }

    /**
     * @notice Create new messaging group
     * @dev Increments group counter and stores new group
     * @param members Initial member addresses
     * @param groupName Identifier for the group
     */
    function createGroup(address[] calldata members, string calldata groupName) external {
        s_groups[s_groupsCount] = Group({members: members, groupName: groupName});
        s_groupsCount++;

        emit GroupCreated(msg.sender, groupName);
    }

    /**
     * @notice Broadcast message to group members
     * @dev Requires valid group ID, sends to all group members
     * @param groupId ID of target group
     * @param message Content to broadcast
     */
    function sendMessageToGroup(uint256 groupId, string calldata message) external {
        if (groupId > s_groupsCount) {
            revert Decenger__GroupDoesnotExist();
        }
        Group storage groups = s_groups[groupId];
        for (uint256 i = 0; i < groups.members.length; i++) {
            s_sentMessages[msg.sender].push(
                Message({sender: msg.sender, receiver: groups.members[i], message: message, timestamp: block.timestamp})
            );

            emit MessageSentToGroup(groupId);

            s_receivedMessages[groups.members[i]].push(
                Message({sender: msg.sender, receiver: groups.members[i], message: message, timestamp: block.timestamp})
            );

            emit MessageReceivedInGroup(groupId);
        }
    }

    /**
     * @notice Forward existing message to new recipient
     * @dev Copies message content with new sender/receiver
     * @param originalSender Address of original message sender
     * @param index Message index in sender's history
     * @param newReceiver Address of new recipient
     */
    function forwardMessage(address originalSender, uint256 index, address newReceiver) external {
        Message memory originalMessage = s_sentMessages[originalSender][index];
        s_sentMessages[msg.sender].push(
            Message({
                sender: msg.sender,
                receiver: newReceiver,
                message: originalMessage.message,
                timestamp: block.timestamp
            })
        );

        emit ForwardMessageSent(msg.sender, originalSender, newReceiver);

        s_receivedMessages[newReceiver].push(
            Message({
                sender: msg.sender,
                receiver: newReceiver,
                message: originalMessage.message,
                timestamp: block.timestamp
            })
        );
        emit ForwardMessageReceived(msg.sender, originalSender, newReceiver);
    }

    /**
     * @notice Delete sent message by index
     * @param index Position in sender's message array
     */
    function deleteSentMessage(uint256 index) external {
       
        if (index >= s_sentMessages[msg.sender].length) {
            revert Decenger__MessageNotFound();
        }

        emit SentMessageDeleted(index);

        delete s_sentMessages[msg.sender][index];
    }

    /**
     * @notice Delete received message by index
     * @param index Position in receiver's message array
     */
    function deleteReceivedMessage(uint256 index) external {
       
        if (index >= s_receivedMessages[msg.sender].length) {
            revert Decenger__MessageNotFound();
        }

        emit ReceivedMessageDeleted(index);

        delete s_receivedMessages[msg.sender][index];
    }

    /**
     * @notice Edit existing message content
     * @dev Requires:
     * - Message sender is function caller
     * - Within 24h of original timestamp
     * @param index Message position in sender's array
     * @param newMessage Updated content
     */
    function editMessage(uint256 index, string calldata newMessage) external {
        
        if (s_sentMessages[msg.sender][index].sender != msg.sender) {
            revert Decenger__onlySenderCanEditMessage();
        }

        if (block.timestamp >= s_sentMessages[msg.sender][index].timestamp + MAX_EDIT_TIME) {
            revert Decenger__CannotEditMessageAfterOneDay();
        }

        emit MessageEdited(msg.sender, index);

        s_sentMessages[msg.sender][index].message = newMessage;
    }

    /**
     * @notice Deposit ETH into user wallet
     * @dev Uses nonReentrant guard and moreThanZero modifier
     */
    function wallet() external payable nonReentrant moreThanZero(msg.value) {
        s_balance[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice Transfer ETH from wallet to another address
     * @dev Implements checks:
     * - Valid recipient address
     * - Sufficient sender balance
     * - Reentrancy protection
     * @param to Recipient address
     */
    function sendFunds(address to) external payable nonReentrant moreThanZero(msg.value) {
        if (to == address(0)) {
            revert Decenger__CannotSendFundsToAddressZero();
        }

        if (s_balance[msg.sender] < msg.value) {
            revert Decenger__InsufficientBalance(s_balance[msg.sender], msg.value);
        }

        s_balance[msg.sender] -= msg.value;

        (bool success,) = payable(to).call{value: msg.value}("");
        require(success);

        emit Withdrawn(msg.sender, msg.value, to);

        // increase the receiver's balance after call to reduce reentrancy attack risk
        s_balance[to] += msg.value;
    }

    /*/////////////////////////////////////////////////
                      GETTER FUNCTIONS
    /////////////////////////////////////////////////*/

    function getSentMessage() external view returns (Message[] memory) {
       
        return s_sentMessages[msg.sender];
    }

    function getReceivedMessages() external view returns (Message[] memory) {
      
        return s_receivedMessages[msg.sender];
    }

    function getSentMessagesCount() public view returns (uint256) {
       
        return s_sentMessages[msg.sender].length;
    }

    function getReceivedMessagesCount() public view returns (uint256) {
        
        return s_receivedMessages[msg.sender].length;
    }

    function getSentExpirableMessages() external view returns (Message[] memory) {
        ExpirableMessage[] storage expMessages = s_sendExpirableMessages[msg.sender];
        uint256 validCount = 0;

        for (uint256 i = 0; i < expMessages.length; i++) {
            if (expMessages[i].expirationTime > block.timestamp) {
                validCount++;
            }
        }

        if (validCount == 0) {
            revert Decenger__MessageExpired();
        }

        Message[] memory validMessages = new Message[](validCount);
        uint256 index = 0;

        for (uint256 i = 0; i < expMessages.length; i++) {
            if (expMessages[i].expirationTime > block.timestamp) {
                validMessages[index] = expMessages[i].message;
                index++;
            }
        }

        return validMessages;
    }

    function getReceivedExpirableMessages() external view returns (Message[] memory) {
        ExpirableMessage[] storage expMessages = s_receiveExpirableMessages[msg.sender];

        uint256 validCount = 0;
        for (uint256 i = 0; i < expMessages.length; i++) {
            if (expMessages[i].expirationTime > block.timestamp) {
                validCount++;
            }
        }

        if (validCount == 0) {
            revert Decenger__MessageExpired();
        }

        Message[] memory validMessages = new Message[](validCount);
        uint256 index = 0;

        for (uint256 i = 0; i < expMessages.length; i++) {
            if (expMessages[i].expirationTime > block.timestamp) {
                validMessages[index] = expMessages[i].message;
                index++;
            }
        }

        return validMessages;
    }

    function getSystemMessages() external view returns (string[] memory) {
        return s_systemMessages[address(0)];
    }

    function getAdmin() external view returns (address) {
        return i_admin;
    }

    function getGroup(uint256 id) external view returns(Group memory){
        return s_groups[id];
    } 

    function getGroupsCount() external view returns(uint256){
        return s_groupsCount;
    }

    function getBalance(address _address) external view returns(uint256){
        return s_balance[_address];
    }

}
