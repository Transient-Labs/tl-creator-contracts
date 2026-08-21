// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std-1.14.0/Test.sol";
import {Initializable} from "@openzeppelin-contracts-upgradeable-5.6.1/proxy/utils/Initializable.sol";
import {Clones} from "@openzeppelin-contracts-5.6.1/proxy/Clones.sol";
import {ERC721TL} from "src/erc-721/ERC721TL.sol";
import {GenArtRenderingContract} from "src/rendering-contracts/GenArtRenderingContract.sol";
import {IGenArtRenderingContract} from "src/interfaces/IGenArtRenderingContract.sol";
import {IMutableMetadata} from "src/interfaces/IMutableMetadata.sol";

contract GenArtRenderingContractTest is Test {
    // gen art events
    event GenerativeScriptChunk(uint256 indexed version, uint256 indexed chunkIndex, bytes chunk);
    event ActiveScriptVersionSet(uint256 indexed version);
    event BaseUriSet(string baseUri);
    event ScriptUriSet(string scriptUri);
    event ExtraParamsSet(uint256 indexed tokenId, IGenArtRenderingContract.ExtraParams[] extraParams);
    event SeedSet(uint256 indexed tokenId, bool indexed enabled, bytes32 indexed seed);
    // erc-4906 metadata events (emitted by the nft contract)
    event MetadataUpdate(uint256 _tokenId);
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    ERC721TL public nft;

    string public constant BASE_URI = "https://render-gen-art.com";
    address public constant ADMIN = address(0xA11CE);
    address public constant NOT_APPROVED = address(0xBEEF);

    function setUp() public {
        address[] memory admins = new address[](0);
        nft = new ERC721TL(false);
        nft.initialize("Test721", "T721", address(this), 1000, address(this), admins, true, address(0), 0, address(0));

        nft.mint(address(this), "test1");
        nft.mint(address(this), "test2");
        nft.mint(address(this), "test3");
    }

    /////////////////////////////////////////////////////////////////////
    // HELPERS
    /////////////////////////////////////////////////////////////////////

    /// @dev Deploys a renderer for `nft` but does NOT wire it as the active rendering contract.
    function _deploy(address initNftContract, string memory baseUri) internal returns (GenArtRenderingContract) {
        GenArtRenderingContract renderingContract = new GenArtRenderingContract(false);
        renderingContract.initialize(initNftContract, baseUri);
        return renderingContract;
    }

    /// @dev Deploys a renderer and wires it as the nft's active rendering contract. Setters that emit
    ///      metadata-update events require this wiring, so most functional tests use it.
    function _deployActive() internal returns (GenArtRenderingContract) {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);
        nft.setRenderingContract(address(renderingContract));
        return renderingContract;
    }

    function _grantAdmin(address account) internal {
        address[] memory admins = new address[](1);
        admins[0] = account;
        nft.setRole(nft.ADMIN_ROLE(), admins, true);
    }

    /////////////////////////////////////////////////////////////////////
    // INITIALIZATION & CLONING
    /////////////////////////////////////////////////////////////////////

    function test_initialize_setsState() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        assertEq(renderingContract.nftContract(), address(nft));
        assertEq(renderingContract.getActiveScriptVersion(), 1);
        assertEq(renderingContract.getBaseUri(), BASE_URI);
        assertEq(renderingContract.getScriptUri(), "");
    }

    function test_initialize_emitsBaseUriSet() public {
        GenArtRenderingContract renderingContract = new GenArtRenderingContract(false);

        vm.expectEmit(true, true, true, true);
        emit BaseUriSet(BASE_URI);
        renderingContract.initialize(address(nft), BASE_URI);
    }

    function test_initialize_errors() public {
        GenArtRenderingContract renderingContract = new GenArtRenderingContract(false);

        // fail on zero address
        vm.expectRevert(GenArtRenderingContract.InvalidAddress.selector);
        renderingContract.initialize(address(0), BASE_URI);

        // fail on address without code
        vm.expectRevert(GenArtRenderingContract.InvalidAddress.selector);
        renderingContract.initialize(address(42), BASE_URI);
    }

    function test_cannot_reinitialize() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        renderingContract.initialize(address(nft), "https://other.com");
    }

    function test_implementation_initializers_disabled() public {
        GenArtRenderingContract impl = new GenArtRenderingContract(true);

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        impl.initialize(address(nft), BASE_URI);
    }

    function test_clone_works() public {
        GenArtRenderingContract impl = new GenArtRenderingContract(true);
        GenArtRenderingContract renderingContract = GenArtRenderingContract(Clones.clone(address(impl)));
        renderingContract.initialize(address(nft), BASE_URI);
        nft.setRenderingContract(address(renderingContract));

        assertEq(renderingContract.nftContract(), address(nft));
        assertEq(renderingContract.getActiveScriptVersion(), 1);
        assertEq(nft.tokenURI(1), "https://render-gen-art.com/1");
    }

    /////////////////////////////////////////////////////////////////////
    // TOKEN URI
    /////////////////////////////////////////////////////////////////////

    function test_tokenURI_formatsExpectedUri() public {
        _deployActive();

        assertEq(nft.tokenURI(1), "https://render-gen-art.com/1");
        assertEq(nft.tokenURI(2), "https://render-gen-art.com/2");
        assertEq(nft.tokenURI(3), "https://render-gen-art.com/3");
    }

    function test_tokenURI_fails_when_not_called_by_nft_contract() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(GenArtRenderingContract.NotNftContract.selector);
        renderingContract.tokenURI(1);
    }

    /////////////////////////////////////////////////////////////////////
    // setBaseUri
    /////////////////////////////////////////////////////////////////////

    function test_setBaseUri_byOwner_updatesTokenUriAndRefreshes() public {
        GenArtRenderingContract renderingContract = _deployActive();

        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(1, nft.totalSupply());
        vm.expectEmit(true, true, true, true);
        emit BaseUriSet("ipfs://new-cid");
        renderingContract.setBaseUri("ipfs://new-cid");

        assertEq(renderingContract.getBaseUri(), "ipfs://new-cid");
        assertEq(nft.tokenURI(1), "ipfs://new-cid/1");
        assertEq(nft.tokenURI(3), "ipfs://new-cid/3");
    }

    function test_setBaseUri_byAdmin() public {
        GenArtRenderingContract renderingContract = _deployActive();
        _grantAdmin(ADMIN);

        vm.prank(ADMIN);
        renderingContract.setBaseUri("ipfs://admin-cid");

        assertEq(nft.tokenURI(2), "ipfs://admin-cid/2");
    }

    function test_setBaseUri_reverts_whenNotApproved() public {
        GenArtRenderingContract renderingContract = _deployActive();

        vm.expectRevert(GenArtRenderingContract.NotApprovedSender.selector);
        vm.prank(NOT_APPROVED);
        renderingContract.setBaseUri("ipfs://nope");
    }

    function test_setBaseUri_reverts_whenRendererNotWired() public {
        // deployed but not set as the nft's rendering contract -> nft rejects the metadata-update callback
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(IMutableMetadata.NotRenderingContract.selector);
        renderingContract.setBaseUri("ipfs://new-cid");
    }

    /////////////////////////////////////////////////////////////////////
    // setScriptUri
    /////////////////////////////////////////////////////////////////////

    function test_setScriptUri_byOwner_storesAndRefreshes() public {
        GenArtRenderingContract renderingContract = _deployActive();

        assertEq(renderingContract.getScriptUri(), "");

        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(1, nft.totalSupply());
        vm.expectEmit(true, true, true, true);
        emit ScriptUriSet("ipfs://script-cid");
        renderingContract.setScriptUri("ipfs://script-cid");

        assertEq(renderingContract.getScriptUri(), "ipfs://script-cid");
    }

    function test_setScriptUri_byAdmin() public {
        GenArtRenderingContract renderingContract = _deployActive();
        _grantAdmin(ADMIN);

        vm.prank(ADMIN);
        renderingContract.setScriptUri("ipfs://admin-script");

        assertEq(renderingContract.getScriptUri(), "ipfs://admin-script");
    }

    function test_setScriptUri_reverts_whenNotApproved() public {
        GenArtRenderingContract renderingContract = _deployActive();

        vm.expectRevert(GenArtRenderingContract.NotApprovedSender.selector);
        vm.prank(NOT_APPROVED);
        renderingContract.setScriptUri("ipfs://nope");
    }

    /////////////////////////////////////////////////////////////////////
    // setExtraParams
    /////////////////////////////////////////////////////////////////////

    function _params(string memory n0, string memory v0, string memory n1, string memory v1)
        internal
        pure
        returns (IGenArtRenderingContract.ExtraParams[] memory)
    {
        IGenArtRenderingContract.ExtraParams[] memory params = new IGenArtRenderingContract.ExtraParams[](2);
        params[0] = IGenArtRenderingContract.ExtraParams({name: n0, value: v0});
        params[1] = IGenArtRenderingContract.ExtraParams({name: n1, value: v1});
        return params;
    }

    function _assertParamsEq(
        IGenArtRenderingContract.ExtraParams[] memory got,
        IGenArtRenderingContract.ExtraParams[] memory want
    ) internal pure {
        assertEq(got.length, want.length);
        for (uint256 i; i < want.length; ++i) {
            assertEq(got[i].name, want[i].name);
            assertEq(got[i].value, want[i].value);
        }
    }

    function test_setExtraParams_byOwner_storesEmitsAndRefreshes() public {
        GenArtRenderingContract renderingContract = _deployActive();
        IGenArtRenderingContract.ExtraParams[] memory params = _params("palette", "warm", "density", "5");

        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.expectEmit(true, true, true, true);
        emit ExtraParamsSet(1, params);
        renderingContract.setExtraParams(1, params);

        _assertParamsEq(renderingContract.getExtraParams(1), params);
    }

    function test_setExtraParams_replacesPriorSet() public {
        GenArtRenderingContract renderingContract = _deployActive();

        renderingContract.setExtraParams(1, _params("a", "1", "b", "2"));
        IGenArtRenderingContract.ExtraParams[] memory replacement = _params("c", "3", "d", "4");
        renderingContract.setExtraParams(1, replacement);

        // fully replaced (no leftover entries, no growth)
        _assertParamsEq(renderingContract.getExtraParams(1), replacement);
    }

    function test_setExtraParams_emptyArrayClears() public {
        GenArtRenderingContract renderingContract = _deployActive();

        renderingContract.setExtraParams(1, _params("a", "1", "b", "2"));
        IGenArtRenderingContract.ExtraParams[] memory empty = new IGenArtRenderingContract.ExtraParams[](0);
        renderingContract.setExtraParams(1, empty);

        assertEq(renderingContract.getExtraParams(1).length, 0);
    }

    function test_getExtraParams_defaultsEmpty() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);
        assertEq(renderingContract.getExtraParams(99).length, 0);
    }

    function test_setExtraParams_byAdmin() public {
        GenArtRenderingContract renderingContract = _deployActive();
        _grantAdmin(ADMIN);
        IGenArtRenderingContract.ExtraParams[] memory params = _params("x", "y", "z", "w");

        vm.prank(ADMIN);
        renderingContract.setExtraParams(2, params);

        _assertParamsEq(renderingContract.getExtraParams(2), params);
    }

    function test_setExtraParams_reverts_whenNotApproved() public {
        GenArtRenderingContract renderingContract = _deployActive();

        vm.expectRevert(GenArtRenderingContract.NotApprovedSender.selector);
        vm.prank(NOT_APPROVED);
        renderingContract.setExtraParams(1, _params("a", "1", "b", "2"));
    }

    /////////////////////////////////////////////////////////////////////
    // setSeed
    /////////////////////////////////////////////////////////////////////

    function test_setSeed_byOwner_storesEmitsAndRefreshes() public {
        GenArtRenderingContract renderingContract = _deployActive();
        bytes32 seedVal = keccak256("curated-seed");

        vm.expectEmit(true, true, true, true);
        emit MetadataUpdate(1);
        vm.expectEmit(true, true, true, true);
        emit SeedSet(1, true, seedVal);
        renderingContract.setSeed(1, IGenArtRenderingContract.Seed({enabled: true, seed: seedVal}));

        IGenArtRenderingContract.Seed memory got = renderingContract.getSeed(1);
        assertTrue(got.enabled);
        assertEq(got.seed, seedVal);
    }

    function test_setSeed_canDisable() public {
        GenArtRenderingContract renderingContract = _deployActive();
        bytes32 seedVal = keccak256("curated-seed");

        renderingContract.setSeed(1, IGenArtRenderingContract.Seed({enabled: true, seed: seedVal}));
        renderingContract.setSeed(1, IGenArtRenderingContract.Seed({enabled: false, seed: seedVal}));

        IGenArtRenderingContract.Seed memory got = renderingContract.getSeed(1);
        assertFalse(got.enabled);
        assertEq(got.seed, seedVal);
    }

    function test_getSeed_defaultsDisabled() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        IGenArtRenderingContract.Seed memory got = renderingContract.getSeed(99);
        assertFalse(got.enabled);
        assertEq(got.seed, bytes32(0));
    }

    function test_setSeed_byAdmin() public {
        GenArtRenderingContract renderingContract = _deployActive();
        _grantAdmin(ADMIN);
        bytes32 seedVal = keccak256("admin-seed");

        vm.prank(ADMIN);
        renderingContract.setSeed(3, IGenArtRenderingContract.Seed({enabled: true, seed: seedVal}));

        IGenArtRenderingContract.Seed memory got = renderingContract.getSeed(3);
        assertTrue(got.enabled);
        assertEq(got.seed, seedVal);
    }

    function test_setSeed_reverts_whenNotApproved() public {
        GenArtRenderingContract renderingContract = _deployActive();

        vm.expectRevert(GenArtRenderingContract.NotApprovedSender.selector);
        vm.prank(NOT_APPROVED);
        renderingContract.setSeed(1, IGenArtRenderingContract.Seed({enabled: true, seed: keccak256("x")}));
    }

    /////////////////////////////////////////////////////////////////////
    // storeScriptChunk
    /////////////////////////////////////////////////////////////////////

    function test_storeScriptChunk_emits_byOwner() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        bytes memory chunk = bytes("(function(){/* art.js part 1 */})();");

        vm.expectEmit(true, true, true, true);
        emit GenerativeScriptChunk(1, 0, chunk);
        renderingContract.storeScriptChunk(1, 0, chunk);
    }

    function test_storeScriptChunk_emits_byAdmin() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);
        _grantAdmin(ADMIN);

        bytes memory chunk = bytes("/* admin chunk */");

        vm.expectEmit(true, true, true, true);
        emit GenerativeScriptChunk(2, 0, chunk);
        vm.prank(ADMIN);
        renderingContract.storeScriptChunk(2, 0, chunk);
    }

    function test_storeScriptChunk_reverts_whenNotApproved() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(GenArtRenderingContract.NotApprovedSender.selector);
        vm.prank(NOT_APPROVED);
        renderingContract.storeScriptChunk(1, 0, bytes("nope"));
    }

    function test_storeScriptChunk_multipleChunks_sameVersion() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        bytes[3] memory chunks = [bytes("chunk-a"), bytes("chunk-b"), bytes("chunk-c")];

        for (uint256 i; i < chunks.length; ++i) {
            vm.expectEmit(true, true, true, true);
            emit GenerativeScriptChunk(1, i, chunks[i]);
            renderingContract.storeScriptChunk(1, i, chunks[i]);
        }
    }

    function test_storeScriptChunk_supportsEmptyAndLargeChunks() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        // empty chunk is allowed (e.g. terminator semantics decided off-chain)
        vm.expectEmit(true, true, true, true);
        emit GenerativeScriptChunk(1, 0, bytes(""));
        renderingContract.storeScriptChunk(1, 0, bytes(""));

        // large chunk round-trips intact through the log
        bytes memory big = new bytes(8192);
        for (uint256 i; i < big.length; ++i) {
            big[i] = bytes1(uint8(i % 256));
        }
        vm.expectEmit(true, true, true, true);
        emit GenerativeScriptChunk(1, 1, big);
        renderingContract.storeScriptChunk(1, 1, big);
    }

    /////////////////////////////////////////////////////////////////////
    // setActiveScriptVersion
    /////////////////////////////////////////////////////////////////////

    function test_activeScriptVersion_defaultsToOne() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);
        assertEq(renderingContract.getActiveScriptVersion(), 1);
    }

    function test_setActiveScriptVersion_byOwner_setsEmitsAndRefreshes() public {
        GenArtRenderingContract renderingContract = _deployActive();

        vm.expectEmit(true, true, true, true);
        emit BatchMetadataUpdate(1, nft.totalSupply());
        vm.expectEmit(true, true, true, true);
        emit ActiveScriptVersionSet(2);
        renderingContract.setActiveScriptVersion(2);

        assertEq(renderingContract.getActiveScriptVersion(), 2);
    }

    function test_setActiveScriptVersion_byAdmin() public {
        GenArtRenderingContract renderingContract = _deployActive();
        _grantAdmin(ADMIN);

        vm.prank(ADMIN);
        renderingContract.setActiveScriptVersion(3);
        assertEq(renderingContract.getActiveScriptVersion(), 3);
    }

    function test_setActiveScriptVersion_reverts_whenRendererNotWired() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(IMutableMetadata.NotRenderingContract.selector);
        renderingContract.setActiveScriptVersion(2);
    }

    function test_setActiveScriptVersion_reverts_whenNotApproved() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(GenArtRenderingContract.NotApprovedSender.selector);
        vm.prank(NOT_APPROVED);
        renderingContract.setActiveScriptVersion(2);
    }

    function test_setActiveScriptVersion_reverts_onZero() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        vm.expectRevert(GenArtRenderingContract.InvalidScriptVersion.selector);
        renderingContract.setActiveScriptVersion(0);
    }

    /////////////////////////////////////////////////////////////////////
    // ERC-165
    /////////////////////////////////////////////////////////////////////

    function test_supportsInterface() public {
        GenArtRenderingContract renderingContract = _deploy(address(nft), BASE_URI);

        // ERC-165
        assertTrue(renderingContract.supportsInterface(0x01ffc9a7));
        // rendering contract interface (backend detects any renderer)
        assertTrue(renderingContract.supportsInterface(0xc87b56dd));
        // gen art interface (backend detects a generative art renderer specifically)
        assertTrue(renderingContract.supportsInterface(0xdd4085f1));
        // unsupported
        assertFalse(renderingContract.supportsInterface(0xffffffff));
        assertFalse(renderingContract.supportsInterface(0xdeadbeef));
    }
}
