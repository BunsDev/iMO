import { useContext, useEffect, useState } from 'react'
import { Swiper, SwiperSlide } from 'swiper/react'

// import 'swiper/swiper.min.css'
import styles from './App.scss'

import { NotificationList } from './components/NotificationList'
import { Summary } from './components/Summary'
import { Footer } from './components/Footer'
import { Header } from './components/Header'
import { Mint } from './components/Mint'

import { NotificationContext, NotificationProvider } from './contexts/NotificationProvider'
import { useWallet, useQuidContract } from './contexts/use-wallet'

function App() {
  //const [swiperRef, setSwiperRef] = useState(null)
  const [userInfo, setUserInfo] = useState(null)

  const { notify } = useContext(NotificationContext);

  const { chainId, selectedAccount } = useWallet();
  const quidContract = useQuidContract()

  // TODO set price by owner (deployer)

  useEffect(() => {
    // if (chainId && parseInt(chainId, 16) !== 7701) { // TODO change 7701
    if (chainId && parseInt(chainId, 16) !== 11155111) { // TODO change 7701
      notify({
        autoHideDuration: 3500,
        severity: 'error',
        message: `Wrong network selected please switch to CANTO`,
      });
    }

    const fetchData = () => {
      if (selectedAccount) {
        // quidContract?.get_info(selectedAccount).then(setUserInfo)
      } else {
        setUserInfo(null)
      }
    }
    quidContract.on("Minted", fetchData)
    fetchData()
    return () => {
      quidContract.removeListener("Minted", fetchData)
    }
  }, [notify, quidContract, selectedAccount, chainId])

  return (
    <NotificationProvider>
      <NotificationList />
      <div className={styles.root}>
        <Header userInfo={userInfo} />
        <main className={styles.main}>
          <div className={styles.root}>
            <Swiper 
            /*onSwiper={(swiper) => setSwiperRef(swiper)}*/
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
