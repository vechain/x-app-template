import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { ChakraProvider } from "@chakra-ui/react";
import { Footer, Navbar, SubmissionModal } from "./components";
import { lightTheme } from "./theme";
import { Routes, Route, BrowserRouter } from "react-router-dom";
import Home from "./routes/home";
import Protected from "./routes/protected";
import Settings from "./routes/settings";
import Login from "./routes/login";
import Form from "./routes/form";
import Milestones from "./routes/milestones";
import Profile from "./routes/profile";

function App() {
  // const path = location.pathname;

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
          <div className="bg-[#506c4c]">
            <Navbar />
            <div className="min-h-screen relative">
              <Routes>
                <Route path="/" element={<Home />} />
                <Route path="/reduceForm" element={<Form type="reduce" />} />
                <Route path="/offsetForm" element={<Form type="offset" />} />
                <Route path="/protected" element={<Protected />} />
                <Route path="/settings" element={<Settings />} />
                <Route path="/login" element={<Login />} />
                <Route path="/milestones" element={<Milestones />} />
                <Route path="/profile" element={<Profile />} />
              </Routes>
            </div>

            {/* {path === "/" || path === "/form" ? null : <Footer />} */}
          </div>
          {/* MODALS  */}
          <SubmissionModal />
        </DAppKitProvider>
      </ChakraProvider>
    </BrowserRouter>
  );
}

export default App;
