# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

################################################################ Modules ################################################################
remove:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:
	forge install foundry-rs/forge-std --no-commit
	forge install Transient-Labs/tl-sol-tools@3.1.1 --no-commit

update: remove install

################################################################ Build ################################################################
clean:
	forge fmt && forge clean

build:
	forge build --evm-version paris

clean_build: clean build

################################################################ Test ################################################################
quick_test:
	forge test --fuzz-runs 256

std_test:
	forge test

gas_test:
	forge test --gas-report

fuzz_test:
	forge test --fuzz-runs 10000

################################################################ Init Code ################################################################
build_init_code:
	@echo see README!

################################################################ ERC721TL Deployments ################################################################
deploy_ERC721TL_sepolia: build
	forge script script/Deploy.s.sol:DeployERC721TL --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployERC721TL --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_base_sepolia: build
	forge script script/Deploy.s.sol:DeployERC721TL --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --verifier-url https://api-sepolia.basescan.org/api --etherscan-api-key ${BASESCAN_KEY}  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_mainnet: build
	forge script script/Deploy.s.sol:DeployERC721TL --evm-version paris --rpc-url mainnet --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployERC721TL --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_base: build
	forge script script/Deploy.s.sol:DeployERC721TL --evm-version paris --rpc-url base --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################ ERC1155TL Deployments ################################################################
deploy_ERC1155TL_sepolia: build
	forge script script/Deploy.s.sol:DeployERC1155TL --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployERC1155TL --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_base_sepolia: build
	forge script script/Deploy.s.sol:DeployERC1155TL --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --verifier-url https://api-sepolia.basescan.org/api --etherscan-api-key ${BASESCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_mainnet: build
	forge script script/Deploy.s.sol:DeployERC1155TL --evm-version paris --rpc-url mainnet --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployERC1155TL --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_base: build
	forge script script/Deploy.s.sol:DeployERC1155TL --evm-version paris --rpc-url base --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################ Shatter Deployments ################################################################
deploy_Shatter_sepolia: build
	forge script script/Deploy.s.sol:DeployShatter --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Shatter_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployShatter --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Shatter_base_sepolia: build
	forge script script/Deploy.s.sol:DeployShatter --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --verifier-url https://api-sepolia.basescan.org/api --etherscan-api-key ${BASESCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Shatter_mainnet: build
	forge script script/Deploy.s.sol:DeployShatter --evm-version paris --rpc-url mainnet --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Shatter_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployShatter --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Shatter_base: build
	forge script script/Deploy.s.sol:DeployShatter --evm-version paris --rpc-url base --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################ ERC7160TL Deployments ################################################################
deploy_ERC7160TL_sepolia: build
	forge script script/Deploy.s.sol:DeployERC7160TL --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployERC7160TL --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_base_sepolia: build
	forge script script/Deploy.s.sol:DeployERC7160TL --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --verifier-url https://api-sepolia.basescan.org/api --etherscan-api-key ${BASESCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_mainnet: build
	forge script script/Deploy.s.sol:DeployERC7160TL --evm-version paris --rpc-url mainnet --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployERC7160TL --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_base: build
	forge script script/Deploy.s.sol:DeployERC7160TL --evm-version paris --rpc-url base --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################ Doppelganger Deployments ################################################################
deploy_Doppelganger_sepolia: build
	forge script script/Deploy.s.sol:DeployDoppelganger --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/Doppelganger.sol:Doppelganger --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Doppelganger_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployDoppelganger --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/Doppelganger.sol:Doppelganger --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Doppelganger_base_sepolia: build
	forge script script/Deploy.s.sol:DeployDoppelganger --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/Doppelganger.sol:Doppelganger --verifier-url https://api-sepolia.basescan.org/api --etherscan-api-key ${BASESCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Doppelganger_mainnet: build
	forge script script/Deploy.s.sol:DeployDoppelganger --evm-version paris --rpc-url mainnet --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/Doppelganger.sol:Doppelganger --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Doppelganger_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployDoppelganger --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/Doppelganger.sol:Doppelganger --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Doppelganger_base: build
	forge script script/Deploy.s.sol:DeployDoppelganger --evm-version paris --rpc-url base --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/Doppelganger.sol:Doppelganger --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################ CollectorsChoice Deployments ################################################################
deploy_CollectorsChoice_sepolia: build
	forge script script/Deploy.s.sol:DeployCollectorsChoice --evm-version paris --rpc-url sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_CollectorsChoice_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployCollectorsChoice --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_CollectorsChoice_base_sepolia: build
	forge script script/Deploy.s.sol:DeployCollectorsChoice --evm-version paris --rpc-url base_sepolia --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --verifier-url https://api-sepolia.basescan.org/api --etherscan-api-key ${BASESCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_CollectorsChoice_mainnet: build
	forge script script/Deploy.s.sol:DeployCollectorsChoice --evm-version paris --rpc-url mainnet --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_CollectorsChoice_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployCollectorsChoice --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_CollectorsChoice_base: build
	forge script script/Deploy.s.sol:DeployCollectorsChoice --evm-version paris --rpc-url base --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################ TRACE Deployments ################################################################
deploy_TRACE_arbitrum_sepolia: build
	forge script script/Deploy.s.sol:DeployTRACE --evm-version paris --rpc-url arbitrum_sepolia --ledger --sender ${SENDER} --broadcast --skip-simulation
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --verifier-url https://api-sepolia.arbiscan.io/api --etherscan-api-key ${ARBISCAN_KEY} --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_TRACE_arbitrum_one: build
	forge script script/Deploy.s.sol:DeployTRACE --evm-version paris --rpc-url arbitrum --ledger --sender ${SENDER} --broadcast
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh