import { React } from "react"
import { cn } from "classnames"
import { Icon } from "./Icon"

import styles from "./Notification.module.scss"

export const Notification = ({
  className,
  severity = "info",
  message,
  onClose
}) => (
  <div
    tabIndex={0}
    role="button"
    className={cn(styles.root, styles[severity], className)}
    onClick={onClose}
  >
    <p className={styles.message}>{message}</p>
    <Icon
      name="btn-bg"
      preserveAspectRatio="none"
      className={styles.background}
    />
  </div>
)
