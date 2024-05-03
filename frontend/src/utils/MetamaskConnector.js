
export class MetamaskConnector {
  
    constructor(provider) {
        this.provider = provider
    }
    
    async isConnected() {
        const accounts = await this.provider.request(
            { method: "eth_accounts" }
        )
        return accounts.length !== 0
    }

    async activate() {
        console.log("[MetaMask]: Start MetaMask activation!")

        try {
        const accountsPromise = this.provider.request({
            method: "eth_requestAccounts"
        })
        const chainIdPromise = this.provider.request({
            method: "eth_chainId"
        })

        const [accounts, chainId] = await Promise.all([
            accountsPromise,
            chainIdPromise
        ])

        return { accounts, chainId }
        } catch (err) {
        if (err.code === 4001) {
            // EIP-1193 userRejectedRequest error
            // If this happens, the user rejected the connection request.
            console.log("[MetaMask]: Please connect to MetaMask.")
        }

        throw err
        }
    }

    async deactivate() {
        throw new Error("Method not implemented.")
    }
}
