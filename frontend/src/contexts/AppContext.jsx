import { createContext, useState, useContext, useEffect } from "react";
import { useSDK } from "@metamask/sdk-react";
import Web3 from "web3";
import { QUID, SDAI, addressQD, addressSDAI } from "../utils/constant";

const contextState = {
  account: "",
  connectToMetaMask: () => {},
  connected: false,
  connecting: false,
  provider: {},
  sdk: {},
  web3: {},
};

const AppContext = createContext(contextState);

export const AppContextProvider = ({ children }) => {
  const [account, setAccount] = useState("");
  const { sdk, connected, connecting, provider } = useSDK();

  const connectToMetaMask = async () => {
    try {
      const accounts = await sdk?.connect();
      setAccount(accounts?.[0]);
    } catch (err) {
      console.warn(`failed to connect..`, err);
    }
  };

  const app = new Web3(provider);
  const quid = new app.eth.Contract(QUID, addressQD);
  const sdai = new app.eth.Contract(SDAI, addressSDAI);

  useEffect(() => {
    if (!account) {
      connectToMetaMask();
    }
  }, [connected]);

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
  );
};

export const useAppContext = () => useContext(AppContext);
export default AppContext;