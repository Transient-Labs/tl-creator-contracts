import pytest
import brownie

from brownie import accounts

@pytest.fixture(scope="module")
def story_nft(ERC721StoryTL):
  nft = accounts[0].deploy(ERC721StoryTL)
  nft.initialize("Test Token", "TST", accounts[0].address, accounts[0].address, 10)
  nft.mint("testURI")
  nft.transferFrom(accounts[0].address, accounts[1].address, 1)
  return nft

def test_addCreatorStory(story_nft):
    tx = story_nft.addCreatorStory(1, "[insert artist name]", "heres a story")
    assert 'CreatorStory' in tx.events.keys()
    assert tx.events['CreatorStory']['tokenId'] == 1
    assert tx.events['CreatorStory']['creatorAddress'] == accounts[0].address
    assert tx.events['CreatorStory']['creatorName'] == '[insert artist name]'
    assert tx.events['CreatorStory']['story'] == 'heres a story'

def test_addCreatorStory_reverts_onlyOwner(story_nft):
    with brownie.reverts(revert_msg='Ownable: caller is not the owner'):
        story_nft.addCreatorStory(1, "[insert artist name]", "heres a story", {'from': accounts[1]})

def test_addCreatorStory_reverts_tokenNotExists(story_nft):
    with brownie.reverts(revert_msg='ERC721TERC721TLStory: token must exist'):
        story_nft.addCreatorStory(2, "[insert artist name]", "heres a story")

def test_addStory(story_nft):
    tx = story_nft.addStory(1, "[insert collector name]", "heres a story", {'from': accounts[1]})
    assert 'Story' in tx.events.keys()
    assert tx.events['Story']['tokenId'] == 1
    assert tx.events['Story']['collectorAddress'] == accounts[1].address
    assert tx.events['Story']['collectorName'] == '[insert collector name]'
    assert tx.events['Story']['story'] == 'heres a story'

def test_addStory_reverts_onlyTokenOwner(story_nft):
    with brownie.reverts(revert_msg='ERC721TLStory: must be token owner'):
        story_nft.addStory(1, "[insert artist name]", "heres a story", {'from': accounts[2]})

def test_addStory_reverts_tokenNotExists(story_nft):
    with brownie.reverts(revert_msg='ERC721TL: nonexistent token'):
        story_nft.addStory(2, "[insert artist name]", "heres a story")
