// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableAccessControlUpgradeable, NotRoleOrOwner} from "tl-sol-tools/upgradeable/access/OwnableAccessControlUpgradeable.sol";
import {IERC721} from "openzeppelin/interfaces/IERC721.sol";
import {SSTORE2} from "sstore2/SSTORE2.sol";

contract OnChainArt is ERC1967Proxy {

	// bytes32(uint256(keccak256('erc721.tl.onchain')) - 1);
    bytes32 public constant METADATA_STORAGE_SLOT = 0xaa722c9862d77ef84ead3759e5fa0d850912eaa701dffd53d5d94ed98406237c;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    error Unauthorized();

    error NotTokenOwner();
	
	struct OnChainArtStorage {
		address[][] tokenURIs;
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
    {
        OnChainArtStorage storage store;

        assembly {
            store.slot := METADATA_STORAGE_SLOT
        }

        store.tokenURIs.push();
    }

    function addToURI(uint256 _tokenId, string calldata _uriPart) external {
        if (msg.sender != OwnableAccessControlUpgradeable(address(this)).owner() && !OwnableAccessControlUpgradeable(address(this)).hasRole(ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }

        OnChainArtStorage storage store;

        assembly {
            store.slot := METADATA_STORAGE_SLOT
        }

        if (store.tokenURIs.length < _tokenId + 1) store.tokenURIs.push();

        if (IERC721(address(this)).ownerOf(_tokenId) != msg.sender) revert NotTokenOwner();

        store.tokenURIs[_tokenId].push(SSTORE2.write(bytes(_uriPart)));
    }

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        IERC721(address(this)).ownerOf(_tokenId);

    	OnChainArtStorage storage store;

        assembly {
            store.slot := METADATA_STORAGE_SLOT
        }

        return string(abi.encodePacked(
        	'data:application/json;base64,',
            _pack(store.tokenURIs[_tokenId])
        ));
    }

    function _pack(address[] storage _tokenURIs) internal view returns (bytes memory) {
        bytes memory res = bytes("");

        for (uint256 i = 0; i < _tokenURIs.length; i++) res = abi.encodePacked(res, SSTORE2.read(_tokenURIs[i]));

        return res;
    }
}
