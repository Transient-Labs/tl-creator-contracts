# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

########################################
# Dependencies
########################################
remove:
	rm -rf dependencies

install:
	forge soldeer install

update: remove install

########################################
# Format & Lint
########################################
fmt:
	forge fmt

analyze:
	uv run slither . --filter-path "dependencies/"

install-commit-hooks:
	uv run pre-commit install

########################################
# Build
########################################
clean:
	forge fmt && forge clean

build:
	forge build --sizes

clean-build: clean build

########################################
# Test
########################################
test-quick: build
	forge test --fuzz-runs 256

test-std: build
	forge test

test-gas: build
	forge test --gas-report

test-cov: build
	forge coverage --no-match-coverage "(script|test|Foo|Bar)"

test-fuzz: build
	forge test --fuzz-runs 10000


########################################
# ERC721TL Deployments
########################################
deploy_ERC721TL_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC721TL.sol:ERC721TL" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain 1115511 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC721TL_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC721TL.sol:ERC721TL" false
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain 1  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/ERC721TL.sol:ERC721TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# ERC1155TL Deployments
########################################
deploy_ERC1155TL_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC1155TL.sol:ERC1155TL" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain 1115511 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC1155TL_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC1155TL.sol:ERC1155TL" false
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain 1  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-1155/ERC1155TL.sol:ERC1155TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# ERC7160TL Deployments
########################################
deploy_ERC7160TL_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TL.sol:ERC7160TL" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain 1115511 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TL_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TL.sol:ERC7160TL" false
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain 1  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TL.sol:ERC7160TL --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# ERC7160TLEditions Deployments
########################################
deploy_ERC7160TLEditions_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TLEditions.sol:ERC7160TLEditions" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain 1115511 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_ERC7160TLEditions_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "ERC7160TLEditions.sol:ERC7160TLEditions" false
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain 1  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/multi-metadata/ERC7160TLEditions.sol:ERC7160TLEditions --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# TRACE Deployments
########################################
deploy_TRACE_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "TRACE.sol:TRACE" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain 1115511 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_TRACE_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "TRACE.sol:TRACE" false
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain 1 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/erc-721/trace/TRACE.sol:TRACE --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# StandardRenderingContract Deployments
########################################

deploy_StandardRenderingContract_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "StandardRenderingContract.sol:StandardRenderingContract" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --chain 11155111 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_StandardRenderingContract_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "StandardRenderingContract.sol:StandardRenderingContract" false
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --chain 1 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/StandardRenderingContract.sol:StandardRenderingContract --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# GenArtRenderingContract Deployments
########################################

deploy_GenArtRenderingContract_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "GenArtRenderingContract.sol:GenArtRenderingContract" true
	sleep 60
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --chain 11155111 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --chain 421614 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --chain 84532 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_GenArtRenderingContract_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "GenArtRenderingContract.sol:GenArtRenderingContract" false
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --chain 1 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --chain 42161 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --chain 8453 --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) src/rendering-contracts/GenArtRenderingContract.sol:GenArtRenderingContract --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh