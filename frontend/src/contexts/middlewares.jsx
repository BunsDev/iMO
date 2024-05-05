import { InfuraProvider } from "@ethersproject/providers"
import { useMemo } from 'react';

export const defaultProvider = new InfuraProvider('sepolia', 'b5f82a82234f4acbb433a964256ed97f')

export const useIsConnected = (provider) => {
    const isConnected = useMemo(() => {
      if (!provider) return false
  
      const accounts = provider.request({ method: "eth_accounts" });
      return accounts.length !== 0;
    }, [provider]);
  
    return isConnected;
  }

export const useActivate = (provider) => {
    if (!provider) return false

    console.log("[MetaMask]: Start MetaMask activation!")

    try {
      const accountsPromise = provider.request({
          method: "eth_requestAccounts"
      })
      const chainIdPromise = provider.request({
          method: "eth_chainId"
      })

      const [accounts, chainId] = Promise.all([
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