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
	forge install Transient-Labs/tl-sol-tools@3.0.0 --no-commit

# Update the modules
update: remove install

# Builds
build:
	forge fmt && forge clean && forge build

# Tests
quick_test:
	forge test --fuzz-runs 256

std_test:
	forge test

gas_test:
	forge test --gas-report

fuzz_test:
	forge test --fuzz-runs 10000

# Testnet Deployments