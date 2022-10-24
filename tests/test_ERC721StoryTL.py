import pytest

from brownie import accounts

@pytest.fixture(scope="module")
def story_nft(ERC721StoryTL):
    nft = accounts[0].deploy(ERC721StoryTL)
    nft.initialize("Test Token", "TST", accounts[0].address, accounts[0].address, 10)
    nft.mint("testURI")
    return nft

def test_addCreatorStory(story_nft):
  assert story_nft.ownerOf(1) == accounts[0].address
