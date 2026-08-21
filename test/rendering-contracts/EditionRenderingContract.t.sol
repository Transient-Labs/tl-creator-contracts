// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std-1.14.0/Test.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ERC721TL} from "src/erc-721/ERC721TL.sol";
import {EditionRenderingContract} from "src/rendering-contracts/EditionRenderingContract.sol";

contract EditionRenderingContractTest is Test {
    event UriSet(string uri);

    ERC721TL public nft;

    function setUp() public {
        address[] memory admins = new address[](0);
        nft = new ERC721TL(false);
        nft.initialize("Test721", "T721", address(this), 1000, address(this), admins, true, address(0), 0, address(0));

        nft.mint(address(this), "test1");
        nft.mint(address(this), "test2");
        nft.mint(address(this), "test3");
    }

    function _deploy(address initNftContract, string memory uri) internal returns (EditionRenderingContract) {
        EditionRenderingContract renderingContract = new EditionRenderingContract(false);
        renderingContract.initialize(initNftContract, uri);
        return renderingContract;
    }

    function test_initialize_setsStateAndEmits() public {
        EditionRenderingContract renderingContract = new EditionRenderingContract(false);

        vm.expectEmit(true, true, true, true);
        emit UriSet("ipfs://example");
        renderingContract.initialize(address(nft), "ipfs://example");

        assertEq(renderingContract.nftContract(), address(nft));
        assertEq(renderingContract.getUri(), "ipfs://example");
    }

    function test_initialize_errors() public {
        EditionRenderingContract renderingContract = new EditionRenderingContract(false);

        // fail on zero address
        vm.expectRevert(EditionRenderingContract.InvalidAddress.selector);
        renderingContract.initialize(address(0), "ipfs://example");

        // fail on address without code
        vm.expectRevert(EditionRenderingContract.InvalidAddress.selector);
        renderingContract.initialize(address(42), "ipfs://example");
    }

    function test_cannot_reinitialize() public {
        EditionRenderingContract renderingContract = _deploy(address(nft), "ipfs://example");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        renderingContract.initialize(address(nft), "ipfs://other");
    }

    function test_implementation_initializers_disabled() public {
        EditionRenderingContract impl = new EditionRenderingContract(true);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(address(nft), "ipfs://example");
    }

    function test_clone_works() public {
        EditionRenderingContract impl = new EditionRenderingContract(true);
        EditionRenderingContract renderingContract = EditionRenderingContract(Clones.clone(address(impl)));
        renderingContract.initialize(address(nft), "ipfs://example");
        nft.setRenderingContract(address(renderingContract));

        assertEq(nft.tokenURI(1), "ipfs://example");
    }

    function test_tokenURI_formatsExpectedUri() public {
        EditionRenderingContract renderingContract = _deploy(address(nft), "ipfs://example");
        nft.setRenderingContract(address(renderingContract));

        assertEq(nft.tokenURI(1), "ipfs://example");
        assertEq(nft.tokenURI(2), "ipfs://example");
        assertEq(nft.tokenURI(3), "ipfs://example");
    }

    function test_tokenURI_fails_when_not_called_by_nft_contract() public {
        EditionRenderingContract renderingContract = _deploy(address(nft), "ipfs://example");

        vm.expectRevert(EditionRenderingContract.NotNftContract.selector);
        renderingContract.tokenURI(1);
    }

    function test_supportsInterface() public {
        EditionRenderingContract renderingContract = _deploy(address(nft), "ipfs://example");

        assertTrue(renderingContract.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(renderingContract.supportsInterface(0xc87b56dd)); // IRenderingContract
        // not a generative art renderer
        assertFalse(renderingContract.supportsInterface(0xdd4085f1)); // IGenArtRenderingContract
        assertFalse(renderingContract.supportsInterface(0xffffffff));
    }
}
