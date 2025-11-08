// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Bloom} from "../../src/token/Bloom.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {GaslessDistroV1} from "../../src/core/GaslessDistroV1.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {console} from "forge-std/console.sol";

contract DeployGaslessDistroV1 is Script {
    function run() external returns (GaslessDistroV1, HelperConfig) {
        return deployGaslessDistroV1();
    }

    function deployGaslessDistroV1() internal returns (GaslessDistroV1, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfigByChainId(block.chainid);

        address deployer;
        uint256 deployerKey;

        address tokenAddress = networkConfig.bloomTokenAddress;
        address trustedForwarder;
        address voucherSigner;
        bytes32 initialMerkleRoot = bytes32(0);
        address initialOwner;

        if (block.chainid == 31337) {
            console.log("Deploying to  local anvil network");

            // Local Anvil network
            deployer = msg.sender; // first default account
            deployerKey = 0; // Not used for local broadcast
            trustedForwarder = address(0x456);
            voucherSigner = address(0x789);
            initialOwner = deployer;

            // Start broadcast for local deployment
            vm.startBroadcast();
        } else {
            console.log("Deploying to chainid:", block.chainid);

            deployerKey = vm.envUint("PRIVATE_KEY");
            deployer = vm.addr(deployerKey);
            trustedForwarder = vm.envAddress("TRUSTED_FORWARDER");
            voucherSigner = vm.envAddress("VOUCHER_SIGNER");
            initialOwner = deployer;

            vm.startBroadcast(deployerKey);
        }

        // Deploy the implementation contract
        GaslessDistroV1 gaslessDistroImpl = new GaslessDistroV1();
        console.log("GaslessDistroV1 Implementation deployed at:", address(gaslessDistroImpl));

        // Prepare initializer data
        bytes memory initializerData = abi.encodeWithSelector(
            GaslessDistroV1.initialize.selector, tokenAddress, initialMerkleRoot, initialOwner, voucherSigner
        );

        // Deploy the proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(gaslessDistroImpl), initializerData);
        console.log("GaslessDistroV1 Proxy deployed at:", address(proxy));

        GaslessDistroV1 gaslessDistroProxy = GaslessDistroV1(address(proxy));

        vm.stopBroadcast();

        return (gaslessDistroProxy, helperConfig);
    }
}
