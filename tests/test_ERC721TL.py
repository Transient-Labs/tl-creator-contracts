import pytest

from brownie import accounts, reverts

@pytest.fixture(scope="module")
def nft(ERC721TL):
  nft = accounts[0].deploy(ERC721TL)
  nft.initialize("Test Token", "TST", accounts[0].address, accounts[0].address, 10, True)
  nft.mint("testURI")
  nft.transferFrom(accounts[0].address, accounts[1].address, 1)
  return nft

##############################################################################
### Story Related Tests
##############################################################################
def test_addCreatorStory(nft):
    tx = nft.addCreatorStory(1, "[insert artist name]", "heres a story")
    assert 'CreatorStory' in tx.events.keys()
    assert tx.events['CreatorStory']['tokenId'] == 1
    assert tx.events['CreatorStory']['creatorAddress'] == accounts[0].address
    assert tx.events['CreatorStory']['creatorName'] == '[insert artist name]'
    assert tx.events['CreatorStory']['story'] == 'heres a story'

def test_addCreatorStory_reverts_onlyOwner(nft):
    with reverts(revert_msg='Ownable: caller is not the owner'):
        nft.addCreatorStory(1, "[insert artist name]", "heres a story", {'from': accounts[1]})

def test_setStoryEnabled_reverts_onlyOwner(nft):
    with reverts(revert_msg='Ownable: caller is not the owner'):
        nft.setStoryEnabled(False, {'from': accounts[1]})

def test_addCreatorStory_reverts_tokenNotExists(nft):
    with reverts(revert_msg='ERC721TL: token must exist'):
        nft.addCreatorStory(2, "[insert artist name]", "heres a story")

def test_addCreatorStory_reverts_storyDisabled(nft):
    nft.setStoryEnabled(False)
    with reverts(revert_msg='ERC721TL: Story must be enabled'):
        nft.addCreatorStory(2, "[insert artist name]", "heres a story")
    nft.setStoryEnabled(True)

def test_addStory(nft):
    tx = nft.addStory(1, "[insert collector name]", "heres a story", {'from': accounts[1]})
    assert 'Story' in tx.events.keys()
    assert tx.events['Story']['tokenId'] == 1
    assert tx.events['Story']['collectorAddress'] == accounts[1].address
    assert tx.events['Story']['collectorName'] == '[insert collector name]'
    assert tx.events['Story']['story'] == 'heres a story'

def test_addStory_reverts_onlyTokenOwner(nft):
    with reverts(revert_msg='ERC721TL: must be token owner'):
        nft.addStory(1, "[insert artist name]", "heres a story", {'from': accounts[2]})

def test_addStory_reverts_tokenNotExists(nft):
    with reverts(revert_msg='ERC721TL: nonexistent token'):
        nft.addStory(2, "[insert artist name]", "heres a story")

def test_addStory_reverts_storyDisabled(nft):
    nft.setStoryEnabled(False)
    with reverts(revert_msg='ERC721TL: Story must be enabled'):
        nft.addStory(1, "[insert collector name]", "heres a story", {'from': accounts[1]})
    nft.setStoryEnabled(True)

def test_storyEnabled(nft):
    is_enabled = nft.storyEnabled()
    assert is_enabled
    nft.setStoryEnabled(False)
    is_enabled = nft.storyEnabled()
    assert not is_enabled
