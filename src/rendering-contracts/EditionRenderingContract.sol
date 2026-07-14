// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {IRenderingContract} from "../interfaces/IRenderingContract.sol";

/// @title Edition Rendering Contract
/// @notice A rendering contract that returns a single uri for ERC-721 editions
/// @dev Deployable directly or as an ERC-1167 minimal proxy clone (call `initialize` after cloning)
/// @author mpeyfuss
/// @custom:version 4.1.1
contract EditionRenderingContract is Initializable, IRenderingContract {

    /////////////////////////////////////////////////////////////////////
    // STORAGE
    /////////////////////////////////////////////////////////////////////

    address public nftContract;
    string private _uri;

    /////////////////////////////////////////////////////////////////////
    // EVENTS
    /////////////////////////////////////////////////////////////////////

    event UriSet(string uri);

    /////////////////////////////////////////////////////////////////////
    // ERRORS
    /////////////////////////////////////////////////////////////////////

    error InvalidAddress();
    error NotNftContract();

    /////////////////////////////////////////////////////////////////////
    // CONSTRUCTOR
    /////////////////////////////////////////////////////////////////////

    /// @param disable Boolean to disable initialization for the implementation contract
    constructor(bool disable) {
        if (disable) _disableInitializers();
    }

    /////////////////////////////////////////////////////////////////////
    // INITIALIZER
    /////////////////////////////////////////////////////////////////////

    /// @param initNftContract The nft contract this renderer serves
    /// @param initUri The single uri returned for every token
    function initialize(address initNftContract, string memory initUri) external initializer {
        if (initNftContract == address(0) || initNftContract.code.length == 0) revert InvalidAddress();
        nftContract = initNftContract;
        _uri = initUri;

        emit UriSet(initUri);
    }

    /////////////////////////////////////////////////////////////////////
    // TOKEN URI FUNCTION
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IRenderingContract
    function tokenURI(uint256 /* tokenId */) external view returns (string memory) {
        if (msg.sender != nftContract) revert NotNftContract();
        return _uri;
    }

    /////////////////////////////////////////////////////////////////////
    // READ FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /// @notice Function to get the single uri returned for every token
    function getUri() external view returns (string memory) {
        return _uri;
    }

    /////////////////////////////////////////////////////////////////////
    // ERC-165
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IRenderingContract).interfaceId;
    }
}
