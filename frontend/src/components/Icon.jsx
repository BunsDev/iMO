import React from "react"
import cx from "classnames"

import icons from "../../public/icons"

import styles from "./Icon.module.scss"

const Icon = ({ className, name, onClick, ...other }) => {
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

export default Icon
