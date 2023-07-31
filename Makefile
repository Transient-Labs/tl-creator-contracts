# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# Clean the repo
clean:
	forge clean

# Remove modules
remove:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install the Modules
install:
	forge install foundry-rs/forge-std --no-commit
	forge install OpenZeppelin/openzeppelin-contracts@v4.8.3 --no-commit
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v4.8.3 --no-commit
	forge install Transient-Labs/story-contract@4.0.2 --no-commit
	forge install Transient-Labs/tl-sol-tools@2.2.2 --no-commit
	forge install Transient-Labs/blocklist@4.0.1 --no-commit
	forge install 0xsequence/sstore2 --no-commit

# Update the modules
update: remove install

# Builds
build:
	forge fmt && forge clean && forge build --optimize --optimizer-runs 2000

# Tests
tests:
	forge test --gas-report -vvv
