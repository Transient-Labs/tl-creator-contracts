import numpy as np
import matplotlib.pyplot as plt

gas_cost = np.genfromtxt("data/erc_7160_add_token_uris.csv", dtype=np.uint64)

plt.plot(gas_cost)
plt.xlabel("Batch Number (batches of 200 tokens)")
plt.ylabel("Estimated Gas Cost (gas units)")
plt.title("Gas Cost Over Time for ERC-7160 Metadata Additions")
plt.show()