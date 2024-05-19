export const shortedHash = hashSum => {
    if (hashSum) return `${hashSum.slice(0, 6)}...${hashSum.slice(-4)}`
  
    return hashSum
  }
  
  