import * as React from "react"
import Button from "@mui/material/Button"
import Dialog from "@mui/material/Dialog"
import DialogActions from "@mui/material/DialogActions"
import DialogContent from "@mui/material/DialogContent"
import DialogContentText from "@mui/material/DialogContentText"
import DialogTitle from "@mui/material/DialogTitle"
import { createTheme, ThemeProvider } from "@mui/material/styles"

const theme = createTheme({
  palette: {
    mode: "dark"
  }
})

export function Modal({ open = false, handleAgree, handleClose }) {
  const descriptionElementRef = React.useRef(null)
  React.useEffect(() => {
    if (open) {
      const { current: descriptionElement } = descriptionElementRef
      if (descriptionElement !== null) {
        descriptionElement.focus()
      }
    }
  }, [open])
  return (
    <ThemeProvider theme={theme}>
      <Dialog
        open={open}
        onClose={handleClose}
        scroll="paper"
        aria-labelledby="scroll-dialog-title"
        aria-describedby="scroll-dialog-description"
        maxWidth={"md"}>
        <DialogTitle id="scroll-dialog-title">Terms</DialogTitle>
        <DialogContent dividers>
          <DialogContentText
            id="scroll-dialog-description"
            ref={descriptionElementRef}
            tabIndex={-1}>
            I submit my consent to the following terms of QU!D LTD, a company
            incorporated in the BVI. I confirm that I am at least 18 years of
            age, or the age of majority in the jurisdiction where I reside, if
            greater than 18 years of age. I confirm that I am not a citizen of
            the United States or lawful permanent resident of the United States.
            I confirm that I am not currently physically located in the United
            States, or using any technology such as a virtual private network,
            proxy or similar service. I confirm, to the best of my knowledge,
            that I am not acting on behalf of, or at the direction of, or in
            coordination with, a U.S. person (i.e. any citizen of the United
            States, or lawful permanent resident of the United States, or any
            other entity, organization or group that is incorporated to do
            business in the United States). I have obtained adequate technical,
            administrative and legal advice, and by accessing quid.io I am
            expressly declaring and confirming that I am not a citizen or
            resident of any country or jurisdiction under any form of
            international sanctions, black or grey-listing, that would forbid my
            activity on quid.io or require any form of licensing or
            authorization to obtain QD tokens or use any kind of blockchain
            and/or cryptocurrency platform, software, or interface. I
            acknowledge that interacting with quid.io cannot be construed as
            engagement in an investment contract with expectation of future
            profit, nor is it an invitation or offer to invest into any common
            enterprise.
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleClose}>Cancel</Button>
          <Button onClick={handleAgree}>I agree</Button>
        </DialogActions>
      </Dialog>
    </ThemeProvider>
  )
}
