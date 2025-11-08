// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {Test, console} from "forge-std/Test.sol";
import {DeployBloom} from "../script/deploy/DeployBloom.s.sol";
import {Bloom} from "../src/token/Bloom.sol";
import {DeployGaslessDistroV1} from "../script/deploy/DeployGaslessDistroV1.s.sol";
import {GaslessDistroV1} from "../src/core/GaslessDistroV1.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";


contract GaslessDistroV1Test is Test {

    DeployGaslessDistroV1 deployGaslessDistroV1;
    GaslessDistroV1 gaslessDistroV1;
    HelperConfig helperConfig;

    function setUp() external {
        deployGaslessDistroV1 = new DeployGaslessDistroV1();
        (gaslessDistroV1, helperConfig) = deployGaslessDistroV1.run();
    }


    function testTransfer() external {


    }
}

