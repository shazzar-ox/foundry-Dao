// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ~0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    constructor() Ownable(msg.sender) {}

    event NumberChanged(uint256 number);

    function store(uint256 newNumber) public onlyOwner {
        s_number = newNumber;
        emit NumberChanged(newNumber);
    }

    function getNumber() external view returns (uint256 num) {
        num = s_number;
    }
}
