import cx from "classnames"
import { Icon } from "./Icon"
import styles from "./Footer.module.scss"
import { useEffect, useRef, useState } from "react"

const Footer = () => {
  const [isPlaying, setIsPlaying] = useState(false)
  const player = useRef()

  const togglePlay = () => {
    if (!player.current) return
    if (isPlaying) {
      setIsPlaying(false)
      player.current.pause()
    } else {
      setIsPlaying(true)
      player.current.play()
    }
  }

  useEffect(() => {
    const play = () => {
      setIsPlaying(false)
      document.removeEventListener("mousedown", play)
      document.removeEventListener("keydown", play)
      document.removeEventListener("touchstart", play)
    }
    document.addEventListener("mousedown", play)
    document.addEventListener("keydown", play)
    document.addEventListener("touchstart", play)
  }, [])

  return (
    <footer className={styles.root}>
      <div className={styles.media}>
        <audio ref={el => (player.current = el)} autoPlay={false} loop>
          <source src="/sounds/song.mp3" type="audio/mpeg" />
        </audio>
        <button className={styles.music} onClick={togglePlay}>
          <Icon name="music-wave" className={styles.musicWave} />
          Music is {isPlaying ? "on" : "off"}
        </button>
        <div className={styles.spacer} />
        <a href="https://youtu.be/ndQM3kVb06I"
          target="_blank"
          rel="noreferrer"
          className={styles.youtube}>
          <Icon name="youtube" className={styles.youtubeIcon} />
          ETHdenver
        </a>
      </div>
      <div className={styles.socialLinks}>
        <a href="https://twitter.com/quidmint"
          className={cx(styles.socialLink, styles.socialLink2)}>
          <Icon name="twitter" className={styles.socialIcon} />
          <Icon name="link-hover-2" className={styles.socialIconHover} />
        </a>
        <a href="https://mirror.xyz/quid.eth"
          className={cx(styles.socialLink, styles.socialLink3)}>
          <Icon name="medium" className={styles.socialIcon} />
          <Icon name="link-hover-3" className={styles.socialIconHover} />
        </a>
        <a href="https://github.com/QuidLabs/iMO/blob/main/README.md"
          target="_blank"
          rel="noreferrer"
          className={cx(styles.socialLink, styles.socialLink2)}>
          <Icon name="github" className={styles.socialIcon} />
          <Icon name="link-hover-2" className={styles.socialIconHover} />
        </a>
        <a href="mailto:john@quid.io"
          className={cx(styles.socialLink, styles.socialLink3)}>
          <Icon name="email" className={styles.socialIcon} />
          <Icon name="link-hover-3" className={styles.socialIconHover} />
        </a>
      </div>
    </footer>
  )
}

export default Footer
