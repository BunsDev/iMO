import { Web3Provider } from "@ethersproject/providers"
import { useCallback, useEffect, useState } from "react"
import { MetamaskConnector } from "../utils/MetamaskConnector"
import { defaultProvider } from "../utils/constant"

export const connector = new MetamaskConnector(defaultProvider)
export const provider = connector.provider

export const useWallet = () => {
  const [state, setState] = useState({
    isActivating: false,
    accounts: [],
    chainId: null,
    error: null,
    connector: null
  })
  
  const updateState = useCallback(
    partialState => {
      return setState(prevState => ({ ...prevState, ...partialState }))
    },
    [setState]
  )

  const connect = useCallback(async () => {
    if (!connector) {
      throw new Error(
        "[UseWallet]: Connector is not defined! Please define connector before using connect!"
      )
    }

    updateState({ isActivating: true })

    const { chainId, accounts } = await connector.activate()

    updateState({ chainId, accounts, isActivating: false })
  }, [connector, updateState])

  useEffect(() => {
    if (!connector) {
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

    connector.provider.on("connect", handleConnect)
    connector.provider.on("disconnect", handleDisconnect)
    connector.provider.on("chainChanged", handleChainChanged)
    connector.provider.on("accountsChanged", handleAccountsChanged)

    connector.isConnected().then(isConnected => {
      isConnected && connect()
    })

    return () => {
      connector.provider.removeListener("connect", handleConnect)
      connector.provider.removeListener("disconnect", handleDisconnect)
      connector.provider.removeListener("chainChanged", handleChainChanged)
      connector.provider.removeListener(
        "accountsChanged",
        handleAccountsChanged
      )
    }
  }, [connect, connector, updateState])

  const setNewConnector = useCallback(
    connector => {
      updateState({
        connector
      })
      connector = new MetamaskConnector(defaultProvider)
      provider = new Web3Provider(connector.provider)
    },
    [updateState]
  )

  return {
    ...state,
    selectedAccount: state.accounts[0] || null,
    provider,
    connect,
    setConnector: setNewConnector
  }
}
