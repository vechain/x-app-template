import { DAppKitProvider } from "@vechain/dapp-kit-react";
import { ChakraProvider, Container, Flex } from "@chakra-ui/react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import {
  Dropzone,
  Footer,
  InfoCard,
  Instructions,
  Navbar,
  SubmissionModal,
} from "./components";
import { lightTheme } from "./theme";
import MealPlanning from "./components/MealPlanning";
import ViewSavedPlans from "./components/ViewSavedPlans";
import LoginPage from "./components/LoginPage";
import SignUpPage from "./components/SignupPage";
import { useState } from "react";
import Inventory from "./components/Inventory";

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  const handleLogin = (credentials: { email: string; password: string }) => {
    // Implement your login logic here
    setIsAuthenticated(true); // Set to true if login is successful
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
  };

  return (
    <ChakraProvider theme={lightTheme}>
      <DAppKitProvider
        usePersistence
        requireCertificate={false}
        genesis="test"
        nodeUrl="https://testnet.vechain.org/"
        logLevel={"DEBUG"}
      >
        <Router>
        <Navbar isAuthenticated={isAuthenticated} onLogout={handleLogout} />
          <Flex flex={1}>
            <Container
              mt={{ base: 4, md: 10 }}
              maxW={"container.xl"}
              mb={{ base: 4, md: 10 }}
              display={"flex"}
              flex={1}
              alignItems={"center"}
              justifyContent={"flex-start"}
              flexDirection={"column"}
            >
              <Routes>
                {/* Public Routes */}
                <Route path="/login" element={<LoginPage onLogin={handleLogin} />} />
                <Route path="/signup" element={<SignUpPage />} />

                {/* Protected Routes */}
                {isAuthenticated ? (
                  <>
                    <Route path="/" element={<InfoCard />} />
                    <Route path="/meal-planning" element={<MealPlanning />} />
                    <Route path="/instructions" element={<Instructions />} />
                    <Route path="/upload" element={<Dropzone />} />
                    <Route path="/viewSavedPlans" element={<ViewSavedPlans />} />
                    <Route path="*" element={<Navigate to="/" replace />} />
                  </>
                ) : (
                  <Route path="*" element={<Navigate to="/login" replace />} />
                )}
                <Route path="/" element={<InfoCard />} />
                <Route path="/meal-planning" element={<MealPlanning />} />
                <Route path="/instructions" element={<Instructions />} />
                <Route path="/upload" element={<Dropzone />} />
                <Route path="/Inventory" element={<Inventory />} />
              </Routes>
            </Container>
          </Flex>
          {/* <Footer /> */}
          <SubmissionModal />
        </Router>
      </DAppKitProvider>
    </ChakraProvider>
  );
}

export default App;

