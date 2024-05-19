import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import MetamaskProvider from "./contexts/MetamaskProvider";
import { AppContextProvider } from "./contexts/AppContext";

const letsgo = ReactDOM.createRoot(document.getElementById('letsgo'));
letsgo.render(
  <React.StrictMode>
      <MetamaskProvider 
         sdkOptions={{
            dappMetadata: {
              name: "QU!D",
              url: window.location.href,
            },
            infuraAPIKey: 'b5f82a82234f4acbb433a964256ed97f',
            // Other options
          }}>
          <AppContextProvider>
              <App />
          </AppContextProvider>
      </MetamaskProvider>
  </React.StrictMode>
);

