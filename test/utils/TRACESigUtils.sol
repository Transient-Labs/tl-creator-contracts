// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract TRACESigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(string memory name, string memory version, address verifyingContract) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                verifyingContract
            )
        );
    }

    /// @notice function to hash the typed data
    function _hashVerifiedStory(uint256 tokenId, uint256 nonce, address sender, string memory story)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                // keccak256("VerifiedStory(uint256 nonce,uint256 tokenId,address sender,string story)"),
                0x3ea278f3e0e25a71281e489b82695f448ae01ef3fc312598f1e61ac9956ab954,
                nonce,
                tokenId,
                sender,
                keccak256(bytes(story))
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(uint256 tokenId, uint256 nonce, address sender, string memory story)
        public
        view
        returns (bytes32)
    {
        bytes32 hash = _hashVerifiedStory(tokenId, nonce, sender, story);
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash));
    }
}
