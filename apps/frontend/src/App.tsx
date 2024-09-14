import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { ChakraProvider } from "@chakra-ui/react";
import { Footer, Navbar, SubmissionModal } from "./components";
import { lightTheme } from "./theme";
import { Routes, Route, BrowserRouter } from "react-router-dom";
import Home from "./routes/home";
import Protected from "./routes/protected";
import Settings from "./routes/settings";
import Login from "./routes/login";

function App() {
  const path = location.pathname;
  
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
          <div className="">
            {path != "/" ? <Navbar /> : <></>}
            <div className="min-h-[80vh] relative">
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/protected" element={<Protected />} />
                <Route path="/settings" element={<Settings />} />
                <Route path="/login" element={<Login />} />
              </Routes>
            </div>
            {path != "/" ? <Footer /> : <></>}
          </div>
          {/* MODALS  */}
          <SubmissionModal />
        </DAppKitProvider>
      </ChakraProvider>
    </BrowserRouter>
  );
}

export default App;
