// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std-1.14.0/Test.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ERC721TL} from "src/erc-721/ERC721TL.sol";
import {StandardRenderingContract} from "src/rendering-contracts/StandardRenderingContract.sol";

contract StandardRenderingContractTest is Test {
    event BaseUriSet(string baseUri);

    ERC721TL public nft;

    function setUp() public {
        address[] memory admins = new address[](0);
        nft = new ERC721TL(false);
        nft.initialize("Test721", "T721", address(this), 1000, address(this), admins, true, address(0), 0, address(0));

        nft.mint(address(this), "test1");
        nft.mint(address(this), "test2");
        nft.mint(address(this), "test3");
    }

    function _deploy(address initNftContract, string memory baseUri) internal returns (StandardRenderingContract) {
        StandardRenderingContract renderingContract = new StandardRenderingContract(false);
        renderingContract.initialize(initNftContract, baseUri);
        return renderingContract;
    }

    function test_initialize_setsStateAndEmits() public {
        StandardRenderingContract renderingContract = new StandardRenderingContract(false);

        vm.expectEmit(true, true, true, true);
        emit BaseUriSet("ipfs://example-base");
        renderingContract.initialize(address(nft), "ipfs://example-base");

        assertEq(renderingContract.nftContract(), address(nft));
        assertEq(renderingContract.getBaseUri(), "ipfs://example-base");
    }

    function test_initialize_errors() public {
        StandardRenderingContract renderingContract = new StandardRenderingContract(false);

        // fail on zero address
        vm.expectRevert(StandardRenderingContract.InvalidAddress.selector);
        renderingContract.initialize(address(0), "ipfs://example-base");

        // fail on address without code
        vm.expectRevert(StandardRenderingContract.InvalidAddress.selector);
        renderingContract.initialize(address(42), "ipfs://example-base");
    }

    function test_cannot_reinitialize() public {
        StandardRenderingContract renderingContract = _deploy(address(nft), "ipfs://example-base");

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        renderingContract.initialize(address(nft), "ipfs://other");
    }

    function test_implementation_initializers_disabled() public {
        StandardRenderingContract impl = new StandardRenderingContract(true);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(address(nft), "ipfs://example-base");
    }

    function test_clone_works() public {
        StandardRenderingContract impl = new StandardRenderingContract(true);
        StandardRenderingContract renderingContract = StandardRenderingContract(Clones.clone(address(impl)));
        renderingContract.initialize(address(nft), "ipfs://example-base");
        nft.setRenderingContract(address(renderingContract));

        assertEq(nft.tokenURI(1), "ipfs://example-base/1");
    }

    function test_tokenURI_formatsExpectedUri() public {
        StandardRenderingContract renderingContract = _deploy(address(nft), "ipfs://example-base");
        nft.setRenderingContract(address(renderingContract));

        assertEq(nft.tokenURI(1), "ipfs://example-base/1");
        assertEq(nft.tokenURI(2), "ipfs://example-base/2");
        assertEq(nft.tokenURI(3), "ipfs://example-base/3");
    }

    function test_tokenURI_fails_when_not_called_by_nft_contract() public {
        StandardRenderingContract renderingContract = _deploy(address(nft), "ipfs://example-base");

        vm.expectRevert(StandardRenderingContract.NotNftContract.selector);
        renderingContract.tokenURI(1);
    }

    function test_supportsInterface() public {
        StandardRenderingContract renderingContract = _deploy(address(nft), "ipfs://example-base");

        assertTrue(renderingContract.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(renderingContract.supportsInterface(0xc87b56dd)); // IRenderingContract
        // not a generative art renderer
        assertFalse(renderingContract.supportsInterface(0xdd4085f1)); // IGenArtRenderingContract
        assertFalse(renderingContract.supportsInterface(0xffffffff));
    }
}
