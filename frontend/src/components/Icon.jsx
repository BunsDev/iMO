import React from "react"
import cx from "classnames"
import styles from "./Icon.module.scss"

import arrowDown from '../icons/arrow-down.svg'
import book from '../icons/book.svg'
import btnBg from '../icons/btn-bg.svg'
import compositeBtnL1 from '../icons/composite-btn-l1.svg'
import compositeBtnL2 from '../icons/composite-btn-l2.svg'
import compositeBtnL3 from '../icons/composite-btn-l3.svg'
import email from '../icons/email.svg'
import github from '../icons/github.svg'
import information from '../icons/information.svg'
import linkHover1 from '../icons/link-hover-1.svg'
import linkHover2 from '../icons/link-hover-2.svg'
import linkHover3 from '../icons/link-hover-3.svg'
import musicWave from '../icons/music-wave.svg'
import twitter from '../icons/twitter.svg'
import youtube from '../icons/youtube.svg'


export const Icon = ({ className, name, onClick, ...other }) => {
  const icons = {
    'arrow-down': arrowDown,
    book,
    'btn-bg': btnBg,
    'composite-btn-l1': compositeBtnL1,
    'composite-btn-l2': compositeBtnL2,
    'composite-btn-l3': compositeBtnL3,
    email,
    github,
    information,
    'link-hover-1': linkHover1,
    'link-hover-2': linkHover2,
    'link-hover-3': linkHover3,
    'music-wave': musicWave,
    twitter,
    youtube,
  };
  const { viewBox, url } = icons[name]
  return (
    <svg
      viewBox={viewBox}
      className={cx(styles.root, className)}
      onClick={onClick}
      {...other}>
      <use xlinkHref={`${String(url)}`} />
    </svg>
  )
}
