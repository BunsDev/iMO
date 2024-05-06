import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import MetamaskProvider from "./contexts/MetamaskProvider";
import { AppContextProvider } from "./contexts/AppContext";

const letsgo = ReactDOM.createRoot(document.getElementById('letsgo'));
letsgo.render(
  <React.StrictMode>
      <MetamaskProvider>
          <AppContextProvider>
              <App />
          </AppContextProvider>
      </MetamaskProvider>
  </React.StrictMode>
);

