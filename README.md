# Decenger - Decentralized Messenger with Integrated Wallet

A Web3-native simple messaging solution combining secure communication with crypto wallet functionality, built entirely on-chain.

## Features

 **Decentralized Messaging**
- Peer-to-peer encrypted messaging
- Group chat functionality
- Expirable self-destructing messages
- Message forwarding capabilities
- Edit/delete message controls (24h edit window)

 **Integrated Wallet**
- Native ETH transfers between users
- Balance management system
- Secure transaction handling with reentrancy protection

 **Security Features**
- Non-custodial message storage
- Admin-controlled system alerts
- Input validation guards
- Immutable message timestamps

## Installation

1. Clone repository:
```bash
git clone https://github.com/arefxv/Decenger.git
cd Decenger
```

2. Install dependencies:

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

3. Build contract:

```bash
forge build
```

## Usage

### Contract Interaction

**Send Message**:

```solidity
// Send to individual
sendMessage(receiverAddress, "Hello XV!");

// Broadcast to group
sendMessageToGroup(groupId, "GM everyone!");
```

**Manage Messages**:

```solidity
editMessage(0, "Updated message"); // Edit within 24h
deleteSentMessage(1); // Remove from history
```

### Wallet Management

**Deposit Funds**:

```solidity
wallet().value(0.1 ether); // Add ETH to balance
```

**Transfer Funds**:

```solidity
sendFunds(recipientAddress).value(0.05 ether); // Secure transfer
```

---
# THANKS!

---
## ArefXV
