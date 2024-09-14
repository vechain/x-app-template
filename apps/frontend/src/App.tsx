import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { ChakraProvider, Container, Flex } from "@chakra-ui/react";
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Navbar,
  SubmissionModal,
} from "./components";
import { lightTheme } from "./theme";
import Home from "./routes/home";
import { Routes, Route, BrowserRouter } from 'react-router-dom'

function App() {
  return (
    <BrowserRouter>
      <ChakraProvider theme={lightTheme}>
        <DAppKitProvider
          usePersistence
          requireCertificate={false}
          genesis="test"
          nodeUrl="https://testnet.vechain.org/"
          logLevel={"DEBUG"}
        >
          <Navbar />

          <Routes>
            <Route path="/" element={<Home />} />
          </Routes>
          <Footer />

          {/* MODALS  */}
          <SubmissionModal />
        </DAppKitProvider>
      </ChakraProvider>
    </BrowserRouter>
  );
}

export default App;
