// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract TRACESigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(string memory version, address verifyingContract) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("T.R.A.C.E."),
                keccak256(bytes(version)),
                block.chainid,
                verifyingContract
            )
        );
    }

    /// @notice Function to hash the typed data
    function _hashVerifiedStory(address nftContract, uint256 tokenId, string memory story)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                // keccak256("VerifiedStory(address nftContract,uint256 tokenId,string story)"),
                0x76b12200216600191228eb643bc7cba6e319d03951a863e3306595415759682b,
                nftContract,
                tokenId,
                keccak256(bytes(story))
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(address nftContract, uint256 tokenId, string memory story)
        public
        view
        returns (bytes32)
    {
        bytes32 hash = _hashVerifiedStory(nftContract, tokenId, story);
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hash));
    }
}
