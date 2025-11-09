// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC2771ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import {ContextUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract GaslessDistroV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC2771ContextUpgradeable {
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    // ---------------- State Variables ----------------
    IERC20 public token; // ERC20 token to distribute
    bytes32 public merkleRoot; // Merkle root for on-chain claims
    BitMaps.BitMap private _hasClaimed; // Tracks which users claimed via Merkle
    BitMaps.BitMap private _usedNonces; // Tracks used voucher nonces
    address public voucherSigner; // Backend signer for voucher claims
    uint256 public amountToClaim; // Default claim amount

    // ---------------- Events ----------------
    event TokensClaimed(address indexed user, uint256 indexed amount);
    event TokensClaimedWithVoucher(address indexed user, uint256 indexed amount);
    event MerkleRootUpdated(bytes32 indexed newRoot);

    // ---------------- Errors ----------------
    error GaslessDistroV1__AlreadyClaimed();
    error GaslessDistroV1__InvalidProof();
    error GaslessDistroV1__VoucherExpired();
    error GaslessDistroV1__AlreadyUsed();
    error GaslessDistroV1__InvalidVoucherSigner();

    // ---------------- Constructor ----------------
    constructor() ERC2771ContextUpgradeable(msg.sender) {
        _disableInitializers(); // Prevent initialization of implementation contract
    }

    // ---------------- Initializer ----------------
    function initialize(address _tokenAddress, bytes32 _initialRoot, address initialOwner, address _voucherSigner)
        public
        initializer
    {
        __Ownable_init(initialOwner);

        token = IERC20(_tokenAddress);
        merkleRoot = _initialRoot;
        voucherSigner = _voucherSigner;
        amountToClaim = 1000e18; // default amount
    }

    // ---------------- Merkle Claim Function ----------------
    function claimTokens(bytes32[] calldata _merkleProof) external {
        address user = _msgSender();
        uint256 userKey = uint256(uint160(user));

        if (_hasClaimed.get(userKey)) revert GaslessDistroV1__AlreadyClaimed();

        bytes32 leaf = keccak256(abi.encode(user, amountToClaim));
        if (!MerkleProof.verify(_merkleProof, merkleRoot, leaf)) revert GaslessDistroV1__InvalidProof();

        _hasClaimed.set(userKey);

        token.safeTransfer(user, amountToClaim);

        emit TokensClaimed(user, amountToClaim);
    }

    // ---------------- Voucher Claim Function ----------------
    function claimWithVoucher(address user, uint256 nonce, uint256 expiry, bytes calldata signature) external {
        if (block.timestamp > expiry) revert GaslessDistroV1__VoucherExpired();
        if (_usedNonces.get(nonce)) revert GaslessDistroV1__AlreadyUsed();

        bytes32 messageHash = keccak256(abi.encodePacked(user, amountToClaim, nonce, expiry, address(this)));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        address recovered = ECDSA.recover(ethSignedMessageHash, signature);
        if (recovered != voucherSigner) revert GaslessDistroV1__InvalidVoucherSigner();

        _usedNonces.set(nonce);

        token.safeTransfer(user, amountToClaim);

        emit TokensClaimedWithVoucher(user, amountToClaim);
    }

    // ---------------- Admin Functions ----------------
    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // ---------------- View Functions ----------------
    function hasClaimed(address user) external view returns (bool) {
        return _hasClaimed.get(uint256(uint160(user)));
    }

    // ---------------- ERC2771 Overrides ----------------
    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        sender = ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }
}
