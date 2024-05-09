import { useContext, useEffect, useState } from 'react'
import { Swiper, SwiperSlide } from 'swiper/react'

import styles from './App.scss'

import { NotificationList } from './components/NotificationList'
import { Summary } from './components/Summary'
import { Footer } from './components/Footer'
import { Header } from './components/Header'
import { Mint } from './components/Mint'

import { NotificationContext, NotificationProvider } from './contexts/NotificationProvider'
import { useAppContext } from "./contexts/AppContext";

function App() {
  
  const { quid, account } =
    useAppContext();

  const [userInfo, setUserInfo] = useState(null)

  const { notify } = useContext(NotificationContext);


  // TODO set price by owner (deployer)

  useEffect(() => {
    const fetchData = async () => {
      if (account) await quid.methods.get_info(account)
        .call()
        .then(info => {
          setUserInfo(info)
          console.log("THERE IS INFO: ", info)
        })
      
    }
    // quidContract.on("Minted", fetchData) TODO!!!!
    fetchData() // TODO repeating too often, only do once, then do after Minted
    // return () => {
    //   quidContract.removeListener("Minted", fetchData)
    // }
  }, [notify, quid, account])

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
