import { createContext, useState, useContext, useCallback, useEffect } from "react"
import { useSDK } from "@metamask/sdk-react"
import Web3 from "web3"
import { QUID, SDAI, addressQD, addressSDAI } from "../utils/constant"

const contextState = {
  account: "",
  connectToMetaMask: () => { },
  connected: false,
  connecting: false,
  provider: {},
  sdk: {},
  web3: {},
};

const AppContext = createContext(contextState)

export const AppContextProvider = ({ children }) => {
  const [account, setAccount] = useState("")
  const { sdk, connected, connecting, provider } = useSDK()

  const [quid, setQuid] = useState(null)
  const [sdai, setSdai] = useState(null)

  const connectToMetaMask = useCallback(async () => {
    try {
      const accounts = await sdk?.connect()
      setAccount(accounts?.[0])
    } catch (error) {
      console.warn(`failed to connect..`, error)
    }
  }, [sdk])

  useEffect(() => {
    if (!account) {
      if (!account) {
        connectToMetaMask()
    
        if (provider) {
          const web3Instance = new Web3(provider)
          const quidContract = new web3Instance.eth.Contract(QUID, addressQD)
          const sdaiContract = new web3Instance.eth.Contract(SDAI, addressSDAI)


          setQuid(quidContract)
          setSdai(sdaiContract)
        }
      }
    }
  }, [connectToMetaMask, account, provider])

  return (
    <AppContext.Provider
      value={{
        account,
        connectToMetaMask,
        connected,
        connecting,
        provider,
        sdk,
        quid,
        addressQD,
        sdai,
        addressSDAI
      }}
    >
      {children}
    </AppContext.Provider>
  )
}

export const useAppContext = () => useContext(AppContext)

export default AppContext