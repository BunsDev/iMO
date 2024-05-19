import React from "react";
import { MetaMaskProvider } from "@metamask/sdk-react";
import icon from "../icons/quid-logo-angel.png";

const MetamaskProvider = ({ children }) => {
  return (
    <>
      <MetaMaskProvider
        debug={true}
        sdkOptions={{
          dappMetadata: {
            name: "QU!D",
            url: window.location.host,
            iconUrl: icon,
          },
        }}
      >
        {children}
      </MetaMaskProvider>
    </>
  );
};

export default MetamaskProvider;