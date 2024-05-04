import { useMemo } from "react"
import { Contract } from "@ethersproject/contracts"
import { Web3Provider, JsonRpcProvider, InfuraProvider } from "@ethersproject/providers"
import { useCallback, useEffect, useState } from "react"
import { address, QUID, SDAI } from "../utils/constant"
import { withRetryHandling } from '../utils/wrap-with-retry-handling';

// let defaultProvider = new Web3Provider(window.ethereum);
// let defaultProvider = new JsonRpcProvider('https://testnet-archive.plexnode.wtf')
let defaultProvider = new InfuraProvider('sepolia', 'b5f82a82234f4acbb433a964256ed97f')

export const createQuidContract = (defaultProvider) => {
  return new Contract(
    address, QUID,
    defaultProvider
  )
}
export const useQuidContract = () => {
  return new Contract(address, QUID, defaultProvider);
};
export const useSdaiContract = () => { // TODO currently set to cNOTE on CANTO testnet
  return new Contract('0x522902E55db6F870a80B21c69BC6b9903D1560f8', SDAI, defaultProvider)
};

export const waitTransaction = withRetryHandling(
  async hash => {
    const receipt = await defaultProvider.getTransactionReceipt(hash)

    if (!receipt) {
      throw new Error(`Transaction is not complited!`)
    }
  },
  { baseDelay: 2000, numberOfTries: 30 }
)

export const useWallet = () => {
  const [state, setState] = useState({
    isActivating: false,
    accounts: [],
    chainId: null,
    error: null,
    provider: null,
  })

  const isConnected = () => {
    const accounts = state.provider.request(
        { method: "eth_accounts" }
    )
    return accounts.length !== 0
  }

  const activate = () => {
    console.log("[MetaMask]: Start MetaMask activation!")

    try {
      const accountsPromise = state.provider.request({
          method: "eth_requestAccounts"
      })
      const chainIdPromise = state.provider.request({
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

  const updateState = useCallback(
    partialState => {
      return setState(prevState => ({ ...prevState, ...partialState }))
    },
    [setState]
  )

  const connect = useCallback(async () => {
    if (!state.provider) {
      throw new Error(
        "[UseWallet]: Provider is not defined! Please define provider before using connect!"
      )
    }

    updateState({ isActivating: true })

    const { chainId, accounts } = await activate()

    updateState({ chainId, accounts, isActivating: false })
  }, [state.provider, updateState])

  useEffect(() => {
    if (!state.provider) {
      return
    }

    const handleConnect = ({ chainId }) => {
      updateState({ chainId })
    }

    const handleDisconnect = error => {
      updateState({ error })
    }

    const handleChainChanged = chainId => {
      updateState({ chainId })
    }

    const handleAccountsChanged = accounts => {
      updateState({ accounts })
    }

    state.provider.on("connect", handleConnect)
    state.provider.on("disconnect", handleDisconnect)
    state.provider.on("chainChanged", handleChainChanged)
    state.provider.on("accountsChanged", handleAccountsChanged)

    isConnected().then(isConnected => {
      isConnected && connect()
    })

    return () => {
      state.provider.removeListener("connect", handleConnect)
      state.provider.removeListener("disconnect", handleDisconnect)
      state.provider.removeListener("chainChanged", handleChainChanged)
      state.provider.removeListener(
        "accountsChanged",
        handleAccountsChanged
      )
    }
  }, [connect, state.provider, updateState])

  const setNewProvider = useCallback(
    provider => {
      updateState({
        provider
      })
      provider = defaultProvider
    },
    [updateState]
  )

  return {
    ...state,
    selectedAccount: state.accounts[0] || null,
    provider: state.provider,
    connect,
    setProvider: setNewProvider
  }
}
