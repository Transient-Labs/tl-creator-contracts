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
# Deployments
########################################
CONTRACT_ID = $(CONTRACT).sol:$(CONTRACT)
CONTRACT_PATH = $(FOLDER)/$(CONTRACT_ID)

# Run as `make deploy_(testnets/mainnets) FOLDER=src/erc-721 CONTRACT=ERC721TL`

deploy_testnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "$(CONTRACT_ID)" true
	sleep 60
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --chain sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --chain arbitrum-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --chain base-sepolia --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --verifier blockscout --verifier-url https://sepolia.shapescan.xyz/api --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --verifier blockscout --verifier-url https://explorer.testnet.chain.robinhood.com/api --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

deploy_mainnets: build
	forge script --ledger --sender ${SENDER} --broadcast --sig "run(string,bool)" script/Deploy.s.sol:Deploy "$(CONTRACT_ID)" false
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --chain mainnet  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --chain arbitrum --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --chain base --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --verifier blockscout --verifier-url https://shapescan.xyz/api  --watch --constructor-args ${CONSTRUCTOR_ARGS}
	forge verify-contract $$(cat out.txt) $(CONTRACT_PATH) --verifier blockscout --verifier-url https://robinhoodchain.blockscout.com/api --watch --constructor-args ${CONSTRUCTOR_ARGS}
	@bash print_and_clean.sh

########################################
# Add to TLUniversalDeployer (testnet only)
########################################
add_to_universal_deployer:
	cast send --rpc-url $(CHAIN) --ledger 0x7c24805454F7972d36BEE9D139BD93423AA29f3f "addDeployableContract(string,(string,address))" 