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
	forge fmt && forge clean && forge build

# Tests
quick_test:
	forge test --fuzz-runs 512

gas_test:
	forge test --gas-report

fuzz_test:
	forge test --fuzz-runs 10000

# Testnet Deployments
deploy_erc721tl_testnets:
	forge script script/Deployments.s.sol:DeployERC721TL --rpc-url goerli --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployERC721TL --rpc-url arb_goerli --ledger --sender ${SENDER} --broadcast --verify

deploy_erc1155tl_testnets:
	forge script script/Deployments.s.sol:DeployERC1155TL --rpc-url goerli --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployERC1155TL --rpc-url arb_goerli --ledger --sender ${SENDER} --broadcast --verify

deploy_shatter_testnets:
	forge script script/Deployments.s.sol:DeployShatter --rpc-url goerli --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployShatter --rpc-url arb_goerli --ledger --sender ${SENDER} --broadcast --verify

deploy_tl_creator_contract_factory_testnets:
	forge script script/Deployments.s.sol:DeployTLCreatorContractFactory --rpc-url goerli --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployTLCreatorContractFactory --rpc-url arb_goerli --ledger --sender ${SENDER} --broadcast --verify

# Deployments
deploy_erc721tl:
	forge script script/Deployments.s.sol:DeployERC721TL --rpc-url mainnet --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployERC721TL --rpc-url arb --ledger --sender ${SENDER} --broadcast --verify

deploy_erc1155tl:
	forge script script/Deployments.s.sol:DeployERC1155TL --rpc-url mainnet --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployERC1155TL --rpc-url arb --ledger --sender ${SENDER} --broadcast --verify

deploy_shatter:
	forge script script/Deployments.s.sol:DeployShatter --rpc-url mainnet --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployShatter --rpc-url arb --ledger --sender ${SENDER} --broadcast --verify

deploy_tl_creator_contract_factory:
	forge script script/Deployments.s.sol:DeployTLCreatorContractFactory --rpc-url mainnet --ledger --sender ${SENDER} --broadcast --verify
	forge script script/Deployments.s.sol:DeployTLCreatorContractFactory --rpc-url arb --ledger --sender ${SENDER} --broadcast --verify