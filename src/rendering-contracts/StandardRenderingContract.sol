// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";
import {Strings} from "@openzeppelin-contracts-5.6.1/utils/Strings.sol";
import {IERC165} from "@openzeppelin-contracts-5.6.1/utils/introspection/IERC165.sol";
import {IRenderingContract} from "../interfaces/IRenderingContract.sol";

/// @title Standard Rendering Contract
/// @notice A rendering contract that maps a base uri to token id
/// @dev Base uri should NOT end in a slash and should point to a folder of files of the format `<tokenId>`
/// @dev Deployable directly or as an ERC-1167 minimal proxy clone (call `initialize` after cloning)
/// @author mpeyfuss
/// @custom:version 4.1.2
contract StandardRenderingContract is Initializable, IRenderingContract {
    /////////////////////////////////////////////////////////////////////
    // TYPES
    /////////////////////////////////////////////////////////////////////

    using Strings for uint256;

    /////////////////////////////////////////////////////////////////////
    // STORAGE
    /////////////////////////////////////////////////////////////////////

    address public nftContract;
    string private _baseUri;

    /////////////////////////////////////////////////////////////////////
    // EVENTS
    /////////////////////////////////////////////////////////////////////

    event BaseUriSet(string baseUri);

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
    /// @param initBaseUri The base uri (should NOT end in a slash)
    function initialize(address initNftContract, string memory initBaseUri) external initializer {
        if (initNftContract == address(0) || initNftContract.code.length == 0) revert InvalidAddress();
        nftContract = initNftContract;
        _baseUri = initBaseUri;

        emit BaseUriSet(initBaseUri);
    }

    /////////////////////////////////////////////////////////////////////
    // TOKEN URI FUNCTION
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IRenderingContract
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (msg.sender != nftContract) revert NotNftContract();
        return string(abi.encodePacked(_baseUri, "/", tokenId.toString()));
    }

    /////////////////////////////////////////////////////////////////////
    // READ FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /// @notice Function to get the base uri used to build each token pointer (`<baseUri>/<tokenId>`)
    function getBaseUri() external view returns (string memory) {
        return _baseUri;
    }

    /////////////////////////////////////////////////////////////////////
    // ERC-165
    /////////////////////////////////////////////////////////////////////

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IRenderingContract).interfaceId;
    }
}
