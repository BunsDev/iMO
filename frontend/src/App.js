import { useContext, useEffect, useState } from 'react'
import { Swiper, SwiperSlide } from 'swiper/react'

import 'swiper/swiper.min.css'
import styles from './App.scss'
import {
  NotificationList,
  NotificationProvider,
  Footer, Header, Mint,
  Summary
} from './components'
import NotificationContext from './contexts/NotificationProvider'
import useWallet from './contexts/use-wallet'
import useQuidContract from './utils/constant'
import MetamaskConnector from './utils/MetamaskConnector'

// export UserInfo = {
//   address: '',
//   costInUsd: 0,
//   qdAmount: 0,
// };

function App() {
  const [swiperRef, setSwiperRef] = useState(null)
  const [userInfo, setUserInfo] = useState(null)

  const { notify } = useContext(NotificationContext);
  
  const { chainId, selectedAccount, setConnector } = useWallet();
  const quidContract = useQuidContract()

  useEffect(() => {
    if (chainId && parseInt(chainId, 16) !== 7701) { // TODO change 7701
      notify({
        autoHideDuration: 3500,
        severity: 'error',
        message: `Wrong network selected please switch to CANTO`,
      });
    }    
  }, [chainId, notify]);

  useEffect(() => {
    if (window.ethereum) {
      setConnector(new MetamaskConnector(window.ethereum))
    }
  }, [setConnector])

  // TODO set price by owner (deployer)

  useEffect(() => {


    const fetchData = () => {
      if (selectedAccount) {
        getAccountInfo(selectedAccount).then(setUserInfo) // TODO
      } else {
        setUserInfo(null)
      }
    }
    quidContract.on("Mint", fetchData)
    fetchData()
    return () => {
      quidContract.removeListener("Mint", fetchData)
    }
  }, [quidContract, selectedAccount])

  return (
      <NotificationProvider>
          <NotificationList />
          <div className={styles.root}>
              <Header userInfo={userInfo} />
              <main className={styles.main}> 
                  <div className={styles.root}>
                      <Swiper onSwiper={(swiper) => setSwiperRef(swiper)}
                      slidesPerView={1} direction={'vertical'}
                      className={styles.carousel} allowTouchMove={false}>
                          <SwiperSlide className={styles.slide}>
                              <div className={styles.side}>
                                <Summary />
                              </div>
                              <div className={styles.content}>
                                <div className={styles.mintContainer}>
                                  <Mint />
                                </div>
                              </div>
                              <div className={styles.fakeCol} />
                          </SwiperSlide>  
                      </Swiper>
                  </div>
              </main>    
              <Footer />
          </div>
      </NotificationProvider>
  );
}

export default App;
