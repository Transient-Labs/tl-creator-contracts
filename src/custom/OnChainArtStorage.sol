// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract OnChainArtStorage is ERC1967Proxy {

	// bytes32(uint256(keccak256('erc721.tl.onchain')) - 1);
    bytes32 public constant METADATA_STORAGE_SLOT = 0xaa722c9862d77ef84ead3759e5fa0d850912eaa701dffd53d5d94ed98406237c;
	
	struct OnChainArtStore {
		string[] tokenURIs;
	}

	constructor(
        address implementation,
        string memory name,
        string memory symbol,
        address defaultRoyaltyRecipient,
        uint256 defaultRoyaltyPercentage,
        address initOwner,
        address[] memory admins,
        bool enableStory,
        address blockListRegistry
    )
        ERC1967Proxy(
            implementation,
            abi.encodeWithSelector(
                0x1fbd2402, // selector for "initialize(string,string,address,uint256,address,address[],bool,address)"
                name,
                symbol,
                defaultRoyaltyRecipient,
                defaultRoyaltyPercentage,
                initOwner,
                admins,
                enableStory,
                blockListRegistry
            )
        )
    {}

    function tokenURI(uint256 tokenId) public view returns (string memory) {
    	OnChainArtStore storage store;

        assembly {
            store.slot := METADATA_STORAGE_SLOT
        }

        return abi.encodePacked(
        	'data:application/json;base64,',

        );
    }
}
