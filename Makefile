# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

################################################################ Modules ################################################################
remove:
	rm -rf dependencies

install:
	forge soldeer install

update: remove install

################################################################ Build ################################################################
clean:
	forge fmt && forge clean

build:
	forge build --evm-version paris --sizes

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

################################################################ 
# ERC721TL Deployments
################################################################
deploy_ERC721TL_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC721TL.sol:ERC721TL" true
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC721TL.sol:ERC721TL" false
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################
# ERC1155TL Deployments
################################################################
deploy_ERC1155TL_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC1155TL.sol:ERC1155TL" true
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC1155TL.sol:ERC1155TL" false
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################
# Shatter Deployments
################################################################
deploy_Shatter_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "Shatter.sol:Shatter" true
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_Shatter_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "Shatter.sol:Shatter" false
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/shatter/Shatter.sol:Shatter --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################
# ERC7160TL Deployments
################################################################
deploy_ERC7160TL_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TL.sol:ERC7160TL" true
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TL.sol:ERC7160TL" false
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################
# ERC7160TLEditions Deployments
################################################################
deploy_ERC7160TLEditions_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TLEditions.sol:ERC7160TLEditions" true
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TLEditions_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TLEditions.sol:ERC7160TLEditions" false
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################
# CollectorsChoice Deployments
################################################################
deploy_CollectorsChoice_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "CollectorsChoice.sol:CollectorsChoice" true
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_CollectorsChoice_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "CollectorsChoice.sol:CollectorsChoice" false
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/CollectorsChoice.sol:CollectorsChoice --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

################################################################
# TRACE Deployments
################################################################
deploy_TRACE_testnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "TRACE.sol:TRACE" true
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --verifier blockscout --verifier-url https://explorer-sepolia.shape.network/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_TRACE_mainnets: build
	forge script --evm-version paris --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "TRACE.sol:TRACE" false
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --chain mainnet --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/TRACE.sol:TRACE --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh